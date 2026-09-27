const express = require('express');
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
  logAudit(req.userId, 'output_shared', `output=${row.id} recipient=${recipient || 'unspecified'} fields=${Object.keys(payload).join(',')}`);

  // In production this would hand `payload` to a delivery channel (message,
  // exported file, controlled link) — returned directly here for the MVP.
  res.json({ ok: true, recipient: recipient || null, shared: payload });
});

module.exports = router;
