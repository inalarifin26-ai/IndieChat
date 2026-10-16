const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');

const router = express.Router();
router.use(requireAuth);

function serializeOutput(row) {
  return {
    id: row.id,
    workflowId: row.workflow_id,
    title: row.title,
    kind: row.kind,
    summary: row.summary,
    aiSummary: row.ai_summary,
    rawDataPreview: row.raw_data_preview,
    agentActivity: JSON.parse(row.agent_activity_json || '[]'),
    shared: !!row.shared,
    createdAt: row.created_at,
  };
}

router.get('/outputs', (req, res) => {
  const rows = db.prepare('SELECT * FROM vault_outputs WHERE user_id = ? ORDER BY created_at DESC').all(req.userId);
  res.json(rows.map(serializeOutput));
});

router.get('/outputs/:id', (req, res) => {
  const row = db.prepare('SELECT * FROM vault_outputs WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!row) return res.status(404).json({ error: 'Not found' });
  res.json(serializeOutput(row));
});

/**
 * POST /vault/outputs/:id/share
 * Body: { recipient, include: { report, aiSummary, rawData, agentActivity, privateNotes } }
 *
 * This endpoint is the *only* place output data leaves the Personal Vault.
 * It builds the shared payload from exactly the fields the caller opted
 * into — the workflow definition, credentials, and full private memory are
 * structurally absent from `vault_outputs` in the first place, so there is
 * nothing here that could accidentally leak them (Invariants 3 & 7).
 */
router.post('/outputs/:id/share', (req, res) => {
  const row = db.prepare('SELECT * FROM vault_outputs WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!row) return res.status(404).json({ error: 'Not found' });
  const { recipient, include } = req.body || {};
  const format = String((req.body || {}).format || 'pdf').toLowerCase();
  if (!['pdf', 'link', 'message', 'file'].includes(format)) return res.status(400).json({ error: 'format must be one of: pdf, link, message, file' });
  const opts = { report: false, aiSummary: false, rawData: false, agentActivity: false, ...include };

  const payload = {};
  if (opts.report) payload.summary = row.summary;
  if (opts.aiSummary) payload.aiSummary = row.ai_summary;
  if (opts.rawData) payload.rawDataPreview = row.raw_data_preview;
  if (opts.agentActivity) payload.agentActivity = JSON.parse(row.agent_activity_json || '[]');

  if (Object.keys(payload).length === 0) {
    return res.status(400).json({ error: 'Select at least one item to share' });
  }

  db.prepare('UPDATE vault_outputs SET shared = 1 WHERE id = ?').run(row.id);
  logAudit(req.userId, 'output_shared', `output=${row.id} recipient=${recipient || 'unspecified'} format=${format} fields=${Object.keys(payload).join(',')}`);

  // In production this would hand `payload` to a delivery channel (message,
  // exported file, controlled link) — returned directly here for the MVP.
  res.json({ ok: true, recipient: recipient || null, format, shared: payload });
});

// ---- Notes (Vault > Notes) ----
const noteShape = (n) => ({ id: n.id, title: n.title, body: n.body, createdAt: n.created_at });
router.get('/notes', (req, res) => {
  res.json(db.prepare('SELECT * FROM vault_notes WHERE user_id = ? ORDER BY created_at DESC, rowid DESC').all(req.userId).map(noteShape));
});
router.post('/notes', (req, res) => {
  const title = String((req.body || {}).title || '').trim();
  if (!title) return res.status(400).json({ error: 'Title is required' });
  const id = crypto.randomUUID();
  db.prepare('INSERT INTO vault_notes (id, user_id, title, body, created_at) VALUES (?, ?, ?, ?, ?)').run(id, req.userId, title.slice(0, 120), String((req.body || {}).body || '').slice(0, 5000), new Date().toISOString());
  logAudit(req.userId, 'note_created', `note=${id}`);
  res.status(201).json(noteShape(db.prepare('SELECT * FROM vault_notes WHERE id = ?').get(id)));
});
router.delete('/notes/:id', (req, res) => {
  const r = db.prepare('DELETE FROM vault_notes WHERE id = ? AND user_id = ?').run(req.params.id, req.userId);
  if (!r.changes) return res.status(404).json({ error: 'Not found' });
  res.json({ ok: true });
});

// ---- Memories (Vault > Memories): what agents have noted about the user's preferences ----
router.get('/memories', (req, res) => {
  const rows = db.prepare('SELECT m.id, m.note, m.created_at, a.id AS agent_id, a.name AS agent_name FROM agent_memory m JOIN agents a ON a.id = m.agent_id WHERE m.user_id = ? ORDER BY m.created_at DESC, m.rowid DESC').all(req.userId);
  res.json(rows.map((r) => ({ id: r.id, note: r.note, agentId: r.agent_id, agentName: r.agent_name, createdAt: r.created_at })));
});

module.exports = router;
