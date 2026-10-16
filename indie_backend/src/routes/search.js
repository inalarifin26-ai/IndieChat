const express = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { snippet } = require('../lib/messages');

const router = express.Router();
router.use(requireAuth);

const like = (q) => `%${q.replace(/[%_\\]/g, (c) => '\\' + c)}%`;

/**
 * GET /search?q=report[&scope=messages|contacts|groups|agents]
 * Everything is scoped to the signed-in user. Message hits are matched on
 * the human-readable snippet (so a file named "Weekly Report.pdf" is found
 * by "report", but searching "name" does not match JSON keys), never on raw
 * payload internals.
 */
router.get('/', (req, res) => {
  const q = String(req.query.q || '').trim().toLowerCase();
  const scope = req.query.scope ? String(req.query.scope) : null;
  const out = { messages: [], contacts: [], groups: [], agents: [] };
  if (!q) return res.json(out);
  const want = (s) => !scope || scope === s;

  if (want('messages')) {
    const hit = (row, room) => ({ room, message: { id: row.id, sender: row.sender, from: row.sender_name || null, snippet: snippet(row), createdAt: row.created_at } });
    db.prepare(
      `SELECT m.*, c.name AS room_name, c.kind AS room_kind FROM contact_messages m JOIN contacts c ON c.id = m.contact_id
       WHERE m.user_id = ? AND m.deleted = 0 AND m.kind != 'system' AND (lower(m.text) LIKE ? ESCAPE '\\' OR lower(m.payload_json) LIKE ? ESCAPE '\\')`
    ).all(req.userId, like(q), like(q)).forEach((r) => {
      if (snippet(r).toLowerCase().includes(q)) out.messages.push(hit(r, { type: r.room_kind === 'group' ? 'group' : 'contact', id: r.contact_id, name: r.room_name }));
    });
    db.prepare(
      `SELECT m.*, a.name AS room_name FROM agent_messages m JOIN agents a ON a.id = m.agent_id
       WHERE m.user_id = ? AND m.deleted = 0 AND (lower(m.text) LIKE ? ESCAPE '\\' OR lower(m.payload_json) LIKE ? ESCAPE '\\')`
    ).all(req.userId, like(q), like(q)).forEach((r) => {
      if (snippet(r).toLowerCase().includes(q)) out.messages.push(hit(r, { type: 'agent', id: r.agent_id, name: r.room_name }));
    });
    out.messages.sort((a, b) => (a.message.createdAt < b.message.createdAt ? 1 : -1));
    out.messages = out.messages.slice(0, 30);
  }
  if (want('contacts')) {
    out.contacts = db.prepare("SELECT id, name, initials, info FROM contacts WHERE user_id = ? AND kind = 'person' AND (lower(name) LIKE ? ESCAPE '\\' OR lower(info) LIKE ? ESCAPE '\\') ORDER BY name").all(req.userId, like(q), like(q));
  }
  if (want('groups')) {
    out.groups = db.prepare("SELECT id, name, initials FROM contacts WHERE user_id = ? AND kind = 'group' AND lower(name) LIKE ? ESCAPE '\\' ORDER BY name").all(req.userId, like(q));
  }
  if (want('agents')) {
    out.agents = db.prepare("SELECT id, name, role FROM agents WHERE user_id = ? AND (lower(name) LIKE ? ESCAPE '\\' OR lower(role) LIKE ? ESCAPE '\\') ORDER BY name").all(req.userId, like(q), like(q));
  }
  res.json(out);
});

module.exports = router;
