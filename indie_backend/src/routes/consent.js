const express = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const { resumeAfterApproval } = require('../lib/executionEngine');

const router = express.Router();
router.use(requireAuth);

function serializeMandate(row) {
  return {
    id: row.id,
    agentId: row.agent_id,
    purpose: row.purpose,
    dataScope: row.data_scope,
    allowedActions: JSON.parse(row.allowed_actions_json || '[]'),
    deniedActions: JSON.parse(row.denied_actions_json || '[]'),
    autonomy: row.autonomy,
    externalTarget: row.external_target,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    revokedAt: row.revoked_at,
  };
}

router.get('/mandates', (req, res) => {
  const rows = db.prepare('SELECT * FROM consent_mandates WHERE user_id = ? ORDER BY created_at ASC').all(req.userId);
  res.json(rows.map(serializeMandate));
});

// Every permission change is attributable and revocable at any time —
// spec §10 Consent & Mandate Model.
router.patch('/mandates/:id', (req, res) => {
  const mandate = db.prepare('SELECT * FROM consent_mandates WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!mandate) return res.status(404).json({ error: 'Not found' });
  const { status } = req.body || {};
  if (!['active', 'paused', 'revoked'].includes(status)) {
    return res.status(400).json({ error: 'status must be active | paused | revoked' });
  }
  const now = new Date().toISOString();
  db.prepare('UPDATE consent_mandates SET status = ?, updated_at = ?, revoked_at = ? WHERE id = ?').run(
    status,
    now,
    status === 'revoked' ? now : mandate.revoked_at,
    mandate.id
  );
  logAudit(req.userId, 'mandate_status_changed', `mandate=${mandate.id} status=${status}`);
  res.json(serializeMandate(db.prepare('SELECT * FROM consent_mandates WHERE id = ?').get(mandate.id)));
});

router.get('/approvals', (req, res) => {
  const rows = db.prepare('SELECT * FROM approval_requests WHERE user_id = ? ORDER BY requested_at DESC').all(req.userId);
  res.json(
    rows.map((r) => ({
      id: r.id,
      agentId: r.agent_id,
      workflowId: r.workflow_id,
      action: r.action,
      scope: r.scope,
      requestedAt: r.requested_at,
      resolved: !!r.resolved,
      approved: r.approved === null ? null : !!r.approved,
    }))
  );
});

// PAUSE -> CREATE APPROVAL REQUEST -> NOTIFY -> WAIT -> APPROVE/REJECT
// (spec §11 Approval Engine). Approving resumes the paused execution.
router.post('/approvals/:id/resolve', (req, res) => {
  const approval = db.prepare('SELECT * FROM approval_requests WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!approval) return res.status(404).json({ error: 'Not found' });
  if (approval.resolved) return res.status(409).json({ error: 'Already resolved' });
  const { approve } = req.body || {};
  db.prepare('UPDATE approval_requests SET resolved = 1, approved = ? WHERE id = ?').run(approve ? 1 : 0, approval.id);
  logAudit(req.userId, 'approval_resolved', `approval=${approval.id} approved=${!!approve}`);

  const agent = db.prepare('SELECT * FROM agents WHERE id = ?').get(approval.agent_id);
  if (agent) {
    db.prepare('UPDATE agents SET state = ?, current_activity = ? WHERE id = ?').run(
      approve ? 'working' : 'idle',
      approve ? 'Publishing update' : 'Update cancelled by user',
      agent.id
    );
  }

  if (approve) {
    resumeAfterApproval(req.userId, approval.workflow_id);
  }

  res.json({ ok: true });
});

module.exports = router;
