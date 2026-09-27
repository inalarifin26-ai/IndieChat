const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');

const router = express.Router();
router.use(requireAuth);

function serializeAgent(row) {
  const permissions = db.prepare('SELECT label FROM agent_permissions WHERE agent_id = ?').all(row.id).map((p) => p.label);
  const pendingApproval = db
    .prepare("SELECT 1 FROM approval_requests WHERE agent_id = ? AND resolved = 0 LIMIT 1")
    .get(row.id);
  return {
    id: row.id,
    name: row.name,
    role: row.role,
    glyph: row.glyph,
    accentHex: row.accent_hex,
    state: row.state,
    currentActivity: row.current_activity,
    permissions,
    needsAttention: !!pendingApproval || row.state === 'error',
  };
}

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM agents WHERE user_id = ? ORDER BY name ASC').all(req.userId);
  res.json(rows.map(serializeAgent));
});

router.get('/:id', (req, res) => {
  const agent = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!agent) return res.status(404).json({ error: 'Not found' });
  res.json(serializeAgent(agent));
});

router.get('/:id/messages', (req, res) => {
  const agent = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!agent) return res.status(404).json({ error: 'Not found' });
  const rows = db.prepare('SELECT * FROM agent_messages WHERE agent_id = ? ORDER BY created_at ASC').all(agent.id);
  res.json(
    rows.map((m) => ({
      id: m.id,
      sender: m.sender,
      kind: m.kind,
      text: m.text,
      payload: m.payload_json ? JSON.parse(m.payload_json) : null,
      createdAt: m.created_at,
    }))
  );
});

// A command is only ever accepted or scripted-acknowledged here — wiring a
// real model call in is the "Next implementation steps" item in the README.
router.post('/:id/messages', (req, res) => {
  const agent = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!agent) return res.status(404).json({ error: 'Not found' });
  const { text } = req.body || {};
  if (!text) return res.status(400).json({ error: 'text is required' });

  const now = new Date().toISOString();
  const userMsgId = crypto.randomUUID();
  db.prepare(
    'INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(userMsgId, req.userId, agent.id, 'user', 'text', text, now);
  logAudit(req.userId, 'agent_command_sent', `agent=${agent.id}`);

  // Scripted acknowledgement, inserted after a short delay so the client's
  // next poll/GET picks it up — mirrors the Flutter mock's timing.
  setTimeout(() => {
    db.prepare(
      'INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).run(
      crypto.randomUUID(),
      req.userId,
      agent.id,
      'agent',
      'text',
      "Got it. I'll work within my current permissions and let you know if I need anything more.",
      new Date().toISOString()
    );
  }, 700);

  res.status(201).json({ id: userMsgId, sender: 'user', text, createdAt: now });
});

router.get('/:id/activity', (req, res) => {
  const agent = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!agent) return res.status(404).json({ error: 'Not found' });
  const rows = db
    .prepare('SELECT label, created_at FROM agent_activity_log WHERE agent_id = ? ORDER BY created_at ASC')
    .all(agent.id);
  res.json(rows);
});

router.get('/:id/memory', (req, res) => {
  const agent = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!agent) return res.status(404).json({ error: 'Not found' });
  const rows = db.prepare('SELECT note, created_at FROM agent_memory WHERE agent_id = ? ORDER BY created_at ASC').all(agent.id);
  res.json(rows);
});

module.exports = router;
