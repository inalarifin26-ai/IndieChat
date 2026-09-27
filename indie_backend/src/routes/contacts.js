const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');

const router = express.Router();
router.use(requireAuth);

function serializeContact(row) {
  const last = db
    .prepare('SELECT * FROM contact_messages WHERE contact_id = ? ORDER BY created_at DESC LIMIT 1')
    .get(row.id);
  return {
    id: row.id,
    name: row.name,
    initials: row.initials,
    status: row.status,
    pinned: !!row.pinned,
    lastMessage: last ? { sender: last.sender, text: last.text, createdAt: last.created_at } : null,
  };
}

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM contacts WHERE user_id = ? ORDER BY pinned DESC, name ASC').all(req.userId);
  res.json(rows.map(serializeContact));
});

router.post('/', (req, res) => {
  const { name, initials, status } = req.body || {};
  if (!name) return res.status(400).json({ error: 'name is required' });
  const id = crypto.randomUUID();
  db.prepare(
    'INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)'
  ).run(id, req.userId, name, initials || name.slice(0, 2).toUpperCase(), status || '', new Date().toISOString());
  res.status(201).json(serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(id)));
});

router.get('/:id/messages', (req, res) => {
  const contact = db.prepare('SELECT * FROM contacts WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!contact) return res.status(404).json({ error: 'Not found' });
  const messages = db
    .prepare('SELECT * FROM contact_messages WHERE contact_id = ? ORDER BY created_at ASC')
    .all(contact.id);
  res.json(messages.map((m) => ({ id: m.id, sender: m.sender, text: m.text, createdAt: m.created_at })));
});

router.post('/:id/messages', (req, res) => {
  const contact = db.prepare('SELECT * FROM contacts WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!contact) return res.status(404).json({ error: 'Not found' });
  const { text } = req.body || {};
  if (!text) return res.status(400).json({ error: 'text is required' });
  const id = crypto.randomUUID();
  db.prepare(
    'INSERT INTO contact_messages (id, user_id, contact_id, sender, text, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(id, req.userId, contact.id, 'user', text, new Date().toISOString());
  logAudit(req.userId, 'contact_message_sent', `contact=${contact.id}`);
  res.status(201).json({ id, sender: 'user', text, createdAt: new Date().toISOString() });
});

module.exports = router;
