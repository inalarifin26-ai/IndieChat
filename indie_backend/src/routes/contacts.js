const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const { serializeMessage, setReaction, buildAttachment, snippet } = require('../lib/messages');

const router = express.Router();
router.use(requireAuth);

const T = 'contact_messages';

function serializeContact(row) {
  const last = db.prepare(`SELECT * FROM ${T} WHERE contact_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 1`).get(row.id);
  return {
    id: row.id,
    name: row.name,
    initials: row.initials,
    status: row.status,
    info: row.info || '',
    group: row.grp || '',
    pinned: !!row.pinned,
    muted: !!row.muted,
    unread: row.unread || 0,
    lastMessage: last
      ? { sender: last.sender, kind: last.kind || 'text', text: snippet(last), status: last.status || null, deleted: !!last.deleted, createdAt: last.created_at }
      : null,
  };
}

function ownedContact(req, res) {
  const c = db.prepare('SELECT * FROM contacts WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!c) res.status(404).json({ error: 'Not found' });
  return c;
}

function initialsOf(name) {
  const p = name.trim().split(/\s+/);
  return ((p[0] || '?')[0] + (p[1] ? p[1][0] : p[0][1] || '')).toUpperCase();
}

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM contacts WHERE user_id = ? ORDER BY pinned DESC, name ASC').all(req.userId);
  res.json(rows.map(serializeContact));
});

// Contacts are people only. Agents are never created here — they come from
// the Orchestrator (routes/orchestrator.js), keeping "Contact = communicates
// with me, Agent = works for me" intact.
router.post('/', (req, res) => {
  const { name, info, group } = req.body || {};
  const errors = {};
  if (!name || !String(name).trim()) errors.name = 'Name is required';
  if (!info || !String(info).trim()) errors.info = 'Enter an Indie ID, phone number or email';
  if (Object.keys(errors).length) return res.status(400).json({ error: 'Validation failed', fields: errors });
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at, info, grp)
     VALUES (?, ?, ?, ?, 'New contact', 0, ?, ?, ?)`
  ).run(id, req.userId, String(name).trim(), initialsOf(String(name)), new Date().toISOString(), String(info).trim(), group || '');
  logAudit(req.userId, 'contact_added', `contact=${id}`);
  res.status(201).json(serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(id)));
});

router.patch('/:id', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  const { name, info, group, muted, pinned } = req.body || {};
  if (name !== undefined && !String(name).trim()) return res.status(400).json({ error: 'Name cannot be empty' });
  if (info !== undefined && !String(info).trim()) return res.status(400).json({ error: 'Contact info cannot be empty' });
  db.prepare(
    `UPDATE contacts SET name = ?, initials = ?, info = ?, grp = ?, muted = ?, pinned = ? WHERE id = ?`
  ).run(
    name !== undefined ? String(name).trim() : c.name,
    name !== undefined ? initialsOf(String(name)) : c.initials,
    info !== undefined ? String(info).trim() : c.info,
    group !== undefined ? group : c.grp,
    muted !== undefined ? (muted ? 1 : 0) : c.muted,
    pinned !== undefined ? (pinned ? 1 : 0) : c.pinned,
    c.id
  );
  logAudit(req.userId, 'contact_updated', `contact=${c.id}`);
  res.json(serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(c.id)));
});

router.delete('/:id', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  db.prepare('DELETE FROM contacts WHERE id = ?').run(c.id);
  logAudit(req.userId, 'contact_deleted', `contact=${c.id}`);
  res.json({ ok: true });
});

// Opening a room marks it read.
router.get('/:id/messages', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  db.prepare('UPDATE contacts SET unread = 0 WHERE id = ?').run(c.id);
  const rows = db.prepare(`SELECT * FROM ${T} WHERE contact_id = ? ORDER BY created_at ASC, rowid ASC`).all(c.id);
  res.json(rows.map((r) => serializeMessage(T, r)));
});

router.post('/:id/messages', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  const att = buildAttachment(req.userId, req.body || {});
  if (att.error) return res.status(400).json({ error: att.error });

  let replyToId = null;
  if (req.body.replyToId) {
    const orig = db.prepare(`SELECT id FROM ${T} WHERE id = ? AND contact_id = ?`).get(req.body.replyToId, c.id);
    if (!orig) return res.status(400).json({ error: 'replyToId must be a message in this chat' });
    replyToId = orig.id;
  }

  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO ${T} (id, user_id, contact_id, sender, text, created_at, kind, payload_json, status, reply_to_id)
     VALUES (?, ?, ?, 'user', ?, ?, ?, ?, 'sent', ?)`
  ).run(id, req.userId, c.id, att.text, new Date().toISOString(), att.kind, att.payload ? JSON.stringify(att.payload) : null, replyToId);

  if (att.output) {
    db.prepare('UPDATE vault_outputs SET shared = 1 WHERE id = ?').run(att.output.id);
    logAudit(req.userId, 'output_shared', `output=${att.output.id} recipient=${c.id} via=chat`);
  }
  logAudit(req.userId, 'contact_message_sent', `contact=${c.id} kind=${att.kind}`);

  // Simulated delivery receipts (there is no second human on the other end
  // in this MVP): sent -> delivered -> read. Real receipts need a real peer.
  const bump = (status, ms) =>
    setTimeout(() => {
      try {
        db.prepare(`UPDATE ${T} SET status = ? WHERE id = ? AND deleted = 0`).run(status, id);
      } catch {}
    }, ms).unref();
  bump('delivered', 500);
  bump('read', 2000);

  res.status(201).json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(id)));
});

function ownedMessage(req, res, c) {
  const m = db.prepare(`SELECT * FROM ${T} WHERE id = ? AND contact_id = ?`).get(req.params.mid, c.id);
  if (!m) res.status(404).json({ error: 'Message not found' });
  return m;
}

router.patch('/:id/messages/:mid/reaction', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  const m = ownedMessage(req, res, c);
  if (!m) return;
  if (m.deleted) return res.status(409).json({ error: 'Message was deleted' });
  const r = setReaction(T, m, req.body && req.body.emoji !== undefined ? req.body.emoji : null);
  if (r.error) return res.status(400).json({ error: r.error });
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

router.post('/:id/messages/:mid/save', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  const m = ownedMessage(req, res, c);
  if (!m) return;
  if (!['file', 'output'].includes(m.kind)) return res.status(400).json({ error: 'Only files and results can be saved' });
  db.prepare(`UPDATE ${T} SET saved = 1 WHERE id = ?`).run(m.id);
  logAudit(req.userId, 'chat_item_saved', `message=${m.id}`);
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

// Only your own messages can be deleted; the row stays as a tombstone.
router.delete('/:id/messages/:mid', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  const m = ownedMessage(req, res, c);
  if (!m) return;
  if (m.sender !== 'user') return res.status(403).json({ error: 'You can only delete your own messages' });
  db.prepare(`UPDATE ${T} SET deleted = 1, text = '', payload_json = NULL, reactions_json = '{}', my_reaction = NULL WHERE id = ?`).run(m.id);
  logAudit(req.userId, 'contact_message_deleted', `message=${m.id}`);
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

router.delete('/:id/messages', (req, res) => {
  const c = ownedContact(req, res);
  if (!c) return;
  db.prepare(`DELETE FROM ${T} WHERE contact_id = ?`).run(c.id);
  logAudit(req.userId, 'contact_history_cleared', `contact=${c.id}`);
  res.json({ ok: true });
});

module.exports = router;
