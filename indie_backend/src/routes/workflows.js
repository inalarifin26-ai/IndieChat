const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const { startExecution, emitterFor, orderedNodes } = require('../lib/executionEngine');

const router = express.Router();
router.use(requireAuth);

function serializeNode(n) {
  return {
    id: n.id,
    title: n.title,
    category: n.category,
    subtitle: n.subtitle,
    position: { x: n.pos_x, y: n.pos_y },
    state: n.state,
    disabled: !!n.disabled,
    permissionRequirements: JSON.parse(n.permission_requirements_json || '[]'),
  };
}

function serializeWorkflow(wf, includeGraph = true) {
  const base = {
    id: wf.id,
    name: wf.name,
    description: wf.description,
    version: wf.version,
    lifecycle: wf.lifecycle,
    triggerSummary: wf.trigger_summary,
    updatedAt: wf.updated_at,
  };
  if (!includeGraph) return base;
  const nodes = orderedNodes(wf.id).map(serializeNode);
  const connections = db
    .prepare('SELECT * FROM workflow_connections WHERE workflow_id = ?')
    .all(wf.id)
    .map((c) => ({ id: c.id, fromNodeId: c.from_node_id, toNodeId: c.to_node_id, branchLabel: c.branch_label }));
  return { ...base, nodes, connections };
}

function loadOwnedWorkflow(req, res) {
  const wf = db.prepare('SELECT * FROM workflows WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!wf) {
    res.status(404).json({ error: 'Not found' });
    return null;
  }
  return wf;
}

function touchWorkflow(id) {
  db.prepare('UPDATE workflows SET updated_at = ? WHERE id = ?').run(new Date().toISOString(), id);
}

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM workflows WHERE user_id = ? ORDER BY updated_at DESC').all(req.userId);
  res.json(rows.map((w) => serializeWorkflow(w, false)));
});

router.post('/', (req, res) => {
  const { name, description } = req.body || {};
  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO workflows (id, user_id, name, description, version, lifecycle, trigger_summary, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'v0.1 draft', 'draft', 'Not configured', ?, ?)`
  ).run(id, req.userId, name || 'Untitled workflow', description || '', now, now);
  // Seed with a starting trigger node, same as the Flutter builder's "new workflow" default.
  db.prepare(
    `INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y)
     VALUES (?, ?, ?, 'Manual trigger', 'trigger', 'Run on demand', 40, 40)`
  ).run(crypto.randomUUID(), req.userId, id);
  logAudit(req.userId, 'workflow_created', `workflow=${id}`);
  res.status(201).json(serializeWorkflow(db.prepare('SELECT * FROM workflows WHERE id = ?').get(id)));
});

router.get('/:id', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  res.json(serializeWorkflow(wf));
});

router.patch('/:id', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const { lifecycle, name, description } = req.body || {};
  if (lifecycle && !['draft', 'validating', 'ready', 'active', 'paused'].includes(lifecycle)) {
    return res.status(400).json({ error: 'invalid lifecycle' });
  }
  db.prepare('UPDATE workflows SET lifecycle = COALESCE(?, lifecycle), name = COALESCE(?, name), description = COALESCE(?, description), updated_at = ? WHERE id = ?').run(
    lifecycle || null,
    name || null,
    description || null,
    new Date().toISOString(),
    wf.id
  );
  if (lifecycle) logAudit(req.userId, 'workflow_lifecycle_changed', `workflow=${wf.id} lifecycle=${lifecycle}`);
  res.json(serializeWorkflow(db.prepare('SELECT * FROM workflows WHERE id = ?').get(wf.id)));
});

router.delete('/:id', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  db.prepare('DELETE FROM workflows WHERE id = ?').run(wf.id);
  logAudit(req.userId, 'workflow_deleted', `workflow=${wf.id}`);
  res.json({ ok: true });
});

// ---- Builder: nodes ----

router.post('/:id/nodes', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const { title, category, subtitle, position } = req.body || {};
  const validCategories = ['trigger', 'data', 'ai', 'logic', 'action', 'approval', 'storage', 'output'];
  if (!validCategories.includes(category)) return res.status(400).json({ error: 'invalid category' });
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(id, req.userId, wf.id, title || `New ${category}`, category, subtitle || 'Tap to configure', position?.x || 0, position?.y || 0);
  touchWorkflow(wf.id);
  res.status(201).json(serializeNode(db.prepare('SELECT * FROM workflow_nodes WHERE id = ?').get(id)));
});

router.patch('/:id/nodes/:nodeId', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const node = db.prepare('SELECT * FROM workflow_nodes WHERE id = ? AND workflow_id = ?').get(req.params.nodeId, wf.id);
  if (!node) return res.status(404).json({ error: 'Node not found' });
  const { title, subtitle, position, disabled } = req.body || {};
  db.prepare(
    `UPDATE workflow_nodes SET
       title = COALESCE(?, title),
       subtitle = COALESCE(?, subtitle),
       pos_x = COALESCE(?, pos_x),
       pos_y = COALESCE(?, pos_y),
       disabled = COALESCE(?, disabled)
     WHERE id = ?`
  ).run(title ?? null, subtitle ?? null, position?.x ?? null, position?.y ?? null, disabled === undefined ? null : disabled ? 1 : 0, node.id);
  touchWorkflow(wf.id);
  res.json(serializeNode(db.prepare('SELECT * FROM workflow_nodes WHERE id = ?').get(node.id)));
});

router.delete('/:id/nodes/:nodeId', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  db.prepare('DELETE FROM workflow_nodes WHERE id = ? AND workflow_id = ?').run(req.params.nodeId, wf.id);
  db.prepare('DELETE FROM workflow_connections WHERE workflow_id = ? AND (from_node_id = ? OR to_node_id = ?)').run(
    wf.id,
    req.params.nodeId,
    req.params.nodeId
  );
  touchWorkflow(wf.id);
  res.json({ ok: true });
});

router.post('/:id/nodes/:nodeId/duplicate', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const src = db.prepare('SELECT * FROM workflow_nodes WHERE id = ? AND workflow_id = ?').get(req.params.nodeId, wf.id);
  if (!src) return res.status(404).json({ error: 'Node not found' });
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y, permission_requirements_json)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(id, req.userId, wf.id, `${src.title} copy`, src.category, src.subtitle, src.pos_x + 28, src.pos_y + 28, src.permission_requirements_json);
  touchWorkflow(wf.id);
  res.status(201).json(serializeNode(db.prepare('SELECT * FROM workflow_nodes WHERE id = ?').get(id)));
});

// ---- Builder: connections ----

router.post('/:id/connections', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const { fromNodeId, toNodeId, branchLabel } = req.body || {};
  if (!fromNodeId || !toNodeId || fromNodeId === toNodeId) {
    return res.status(400).json({ error: 'fromNodeId and toNodeId are required and must differ' });
  }
  const nodesExist = db
    .prepare('SELECT COUNT(*) AS n FROM workflow_nodes WHERE workflow_id = ? AND id IN (?, ?)')
    .get(wf.id, fromNodeId, toNodeId);
  if (nodesExist.n !== 2) return res.status(400).json({ error: 'Both nodes must belong to this workflow' });
  const exists = db
    .prepare('SELECT 1 FROM workflow_connections WHERE workflow_id = ? AND from_node_id = ? AND to_node_id = ?')
    .get(wf.id, fromNodeId, toNodeId);
  if (exists) return res.status(409).json({ error: 'Connection already exists' });
  const id = crypto.randomUUID();
  db.prepare(
    'INSERT INTO workflow_connections (id, user_id, workflow_id, from_node_id, to_node_id, branch_label) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(id, req.userId, wf.id, fromNodeId, toNodeId, branchLabel || null);
  touchWorkflow(wf.id);
  res.status(201).json({ id, fromNodeId, toNodeId, branchLabel: branchLabel || null });
});

router.delete('/:id/connections/:connectionId', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  db.prepare('DELETE FROM workflow_connections WHERE id = ? AND workflow_id = ?').run(req.params.connectionId, wf.id);
  touchWorkflow(wf.id);
  res.json({ ok: true });
});

// ---- Validate (COMMAND 07) ----

router.post('/:id/validate', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const nodes = orderedNodes(wf.id);
  const connections = db.prepare('SELECT * FROM workflow_connections WHERE workflow_id = ?').all(wf.id);
  const issues = [];
  const triggers = nodes.filter((n) => n.category === 'trigger');
  if (triggers.length === 0) issues.push('No trigger node — add one to start the workflow.');
  if (triggers.length > 1) issues.push('More than one trigger node found.');
  for (const n of nodes) {
    if (n.category === 'trigger') continue;
    const hasIncoming = connections.some((c) => c.to_node_id === n.id);
    if (!hasIncoming) issues.push(`"${n.title}" has no incoming connection.`);
  }
  res.json({ valid: issues.length === 0, issues });
});

// ---- Execution ----

router.post('/:id/run', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  try {
    const executionId = startExecution(req.userId, wf.id);
    res.status(202).json({ executionId });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/:id/executions', (req, res) => {
  const wf = loadOwnedWorkflow(req, res);
  if (!wf) return;
  const rows = db.prepare('SELECT * FROM executions WHERE workflow_id = ? ORDER BY started_at DESC').all(wf.id);
  res.json(rows.map((e) => ({ id: e.id, state: e.state, startedAt: e.started_at, completedAt: e.completed_at })));
});

router.get('/executions/:executionId/timeline', (req, res) => {
  const execution = db.prepare('SELECT * FROM executions WHERE id = ? AND user_id = ?').get(req.params.executionId, req.userId);
  if (!execution) return res.status(404).json({ error: 'Not found' });
  const rows = db
    .prepare('SELECT label, created_at FROM execution_events WHERE execution_id = ? ORDER BY created_at ASC')
    .all(execution.id);
  res.json(rows.map((r) => ({ label: r.label, at: r.created_at })));
});

// Live execution stream (Server-Sent Events) — the operational "live wiring
// visualization" feed. Never carries hidden model reasoning, only node/state
// transitions (spec §21).
router.get('/executions/:executionId/stream', (req, res) => {
  const execution = db.prepare('SELECT * FROM executions WHERE id = ? AND user_id = ?').get(req.params.executionId, req.userId);
  if (!execution) return res.status(404).json({ error: 'Not found' });

  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.flushHeaders();
  res.write(`event: hello\ndata: ${JSON.stringify({ executionId: execution.id, state: execution.state })}\n\n`);

  const emitter = emitterFor(execution.id);
  const onEvent = (payload) => {
    res.write(`event: update\ndata: ${JSON.stringify(payload)}\n\n`);
  };
  emitter.on('event', onEvent);

  req.on('close', () => emitter.off('event', onEvent));
});

module.exports = router;
