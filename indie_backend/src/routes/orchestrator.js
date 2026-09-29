const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const orch = require('../lib/orchestrator');

const router = express.Router();
router.use(requireAuth);

// Thread messages, optionally only those after a given message id (polling).
router.get('/messages', (req, res) => {
  orch.ensureWelcome(req.userId);
  let rows;
  if (req.query.after) {
    const ref = db.prepare('SELECT rowid AS r FROM orchestrator_messages WHERE id = ? AND user_id = ?').get(req.query.after, req.userId);
    rows = ref
      ? db.prepare('SELECT * FROM orchestrator_messages WHERE user_id = ? AND rowid > ? ORDER BY rowid ASC').all(req.userId, ref.r)
      : db.prepare('SELECT * FROM orchestrator_messages WHERE user_id = ? ORDER BY rowid ASC').all(req.userId);
  } else {
    rows = db.prepare('SELECT * FROM orchestrator_messages WHERE user_id = ? ORDER BY rowid ASC').all(req.userId);
  }
  res.json(rows.map(orch.serialize));
});

// Give the Orchestrator an instruction: create an agent, run a task, or
// change an agent's workflow. The reply arrives in the thread shortly after.
router.post('/messages', (req, res) => {
  const text = String((req.body && req.body.text) || '').trim();
  if (!text) return res.status(400).json({ error: 'text is required' });
  orch.ensureWelcome(req.userId);
  if (orch.isBusy(req.userId)) {
    return res.status(409).json({ error: 'Orchestrator is still working on your previous instruction' });
  }
  // Store the user's message first so the thread order is user -> orchestrator.
  const id = orch.addMessage(req.userId, 'user', 'text', text);
  const result = orch.handle(req.userId, text);
  const row = db.prepare('SELECT * FROM orchestrator_messages WHERE id = ?').get(id);
  res.status(202).json({ message: orch.serialize(row), intent: result.intent });
});

// "Save to Vault" on a combined result — stores the result only.
router.post('/messages/:id/save', (req, res) => {
  const m = db.prepare('SELECT * FROM orchestrator_messages WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!m) return res.status(404).json({ error: 'Not found' });
  if (m.kind !== 'result') return res.status(400).json({ error: 'Only combined results can be saved' });
  if (m.saved) return res.status(409).json({ error: 'Already saved' });
  const p = JSON.parse(m.payload_json);
  const outId = crypto.randomUUID();
  db.prepare(
    `INSERT INTO vault_outputs (id, user_id, workflow_id, title, kind, summary, ai_summary, raw_data_preview, agent_activity_json, shared, created_at)
     VALUES (?, ?, ?, ?, 'report', ?, ?, ?, ?, 0, ?)`
  ).run(
    outId, req.userId, p.workflowId, p.title,
    p.rows.map((r) => `${r.agent}: ${r.result}`).join(' '),
    `Combined result from ${p.rows.length} agents.`,
    'orchestrator run',
    JSON.stringify(p.rows.map((r) => `${r.agent} completed`)),
    new Date().toISOString()
  );
  db.prepare('UPDATE orchestrator_messages SET saved = 1 WHERE id = ?').run(m.id);
  logAudit(req.userId, 'output_saved', `output=${outId} via=orchestrator`);
  res.status(201).json({ outputId: outId, message: orch.serialize(db.prepare('SELECT * FROM orchestrator_messages WHERE id = ?').get(m.id)) });
});

module.exports = router;
