const crypto = require('node:crypto');
const { EventEmitter } = require('node:events');
const db = require('../db');
const { logAudit } = require('./audit');

// One EventEmitter per execution id, so an SSE route can stream live
// node/execution state changes to the client without polling.
// NOTE: in-memory only — fine for a single-process MVP; a multi-instance
// deployment would replace this with a pub/sub channel (Redis, etc).
const emitters = new Map();

function emitterFor(executionId) {
  if (!emitters.has(executionId)) emitters.set(executionId, new EventEmitter());
  return emitters.get(executionId);
}

function emit(executionId, event) {
  emitterFor(executionId).emit('event', event);
}

function recordEvent(executionId, label) {
  db.prepare('INSERT INTO execution_events (id, execution_id, label, created_at) VALUES (?, ?, ?, ?)').run(
    crypto.randomUUID(),
    executionId,
    label,
    new Date().toISOString()
  );
  emit(executionId, { type: 'log', label, at: new Date().toISOString() });
}

// Nodes are ordered by SQLite rowid (insertion order) as an MVP
// simplification. A production Execution Engine would instead do a proper
// topological walk of workflow_connections, following condition branches —
// see COMMAND 08 in CLAUDE_PROJECT_COMMAND.md.
function orderedNodes(workflowId) {
  return db.prepare('SELECT * FROM workflow_nodes WHERE workflow_id = ? ORDER BY rowid ASC').all(workflowId);
}

function startExecution(userId, workflowId) {
  const workflow = db.prepare('SELECT * FROM workflows WHERE id = ? AND user_id = ?').get(workflowId, userId);
  if (!workflow) throw new Error('Workflow not found');

  const nodes = orderedNodes(workflowId);
  db.prepare('UPDATE workflow_nodes SET state = ? WHERE workflow_id = ?').run('idle', workflowId);

  const executionId = crypto.randomUUID();
  const now = new Date().toISOString();
  db.prepare('INSERT INTO executions (id, user_id, workflow_id, state, started_at) VALUES (?, ?, ?, ?, ?)').run(
    executionId,
    userId,
    workflowId,
    'running',
    now
  );
  recordEvent(executionId, 'Trigger activated');
  logAudit(userId, 'workflow_execution_started', `workflow=${workflowId} execution=${executionId}`);

  stepNode(userId, executionId, workflowId, nodes, 0);
  return executionId;
}

function stepNode(userId, executionId, workflowId, nodes, index) {
  const execution = db.prepare('SELECT * FROM executions WHERE id = ?').get(executionId);
  if (!execution || execution.state === 'cancelled') return;

  if (index >= nodes.length) {
    db.prepare('UPDATE executions SET state = ?, completed_at = ? WHERE id = ?').run(
      'completed',
      new Date().toISOString(),
      executionId
    );
    recordEvent(executionId, 'Execution completed');
    emit(executionId, { type: 'state', state: 'completed' });
    return;
  }

  const node = nodes[index];
  db.prepare('UPDATE workflow_nodes SET state = ? WHERE id = ?').run('running', node.id);
  recordEvent(executionId, `${node.title} started`);
  emit(executionId, { type: 'node', nodeId: node.id, state: 'running' });

  setTimeout(() => {
    if (node.category === 'approval') {
      db.prepare('UPDATE workflow_nodes SET state = ? WHERE id = ?').run('waiting', node.id);
      db.prepare('UPDATE executions SET state = ? WHERE id = ?').run('waitingApproval', executionId);
      recordEvent(executionId, `${node.title} — waiting for your approval`);
      emit(executionId, { type: 'node', nodeId: node.id, state: 'waiting' });
      emit(executionId, { type: 'state', state: 'waitingApproval' });

      const existing = db
        .prepare('SELECT 1 FROM approval_requests WHERE workflow_id = ? AND resolved = 0')
        .get(workflowId);
      if (!existing) {
        // Demo default: attribute the approval to the workflow's first
        // referenced agent-category node's implied agent, falling back to
        // any agent owned by the user. A real engine would carry the
        // originating agent id on the node itself.
        const agent = db.prepare('SELECT * FROM agents WHERE user_id = ? ORDER BY rowid ASC LIMIT 1').get(userId);
        db.prepare(
          `INSERT INTO approval_requests (id, user_id, agent_id, workflow_id, action, scope, requested_at, resolved)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)`
        ).run(crypto.randomUUID(), userId, agent ? agent.id : null, workflowId, node.title, 'External platform', new Date().toISOString());
      }
      return; // waits for resumeAfterApproval()
    }

    db.prepare('UPDATE workflow_nodes SET state = ? WHERE id = ?').run('success', node.id);
    recordEvent(executionId, `${node.title} completed`);
    emit(executionId, { type: 'node', nodeId: node.id, state: 'success' });
    stepNode(userId, executionId, workflowId, nodes, index + 1);
  }, 900);
}

function resumeAfterApproval(userId, workflowId) {
  const execution = db
    .prepare("SELECT * FROM executions WHERE workflow_id = ? AND state = 'waitingApproval' ORDER BY started_at DESC LIMIT 1")
    .get(workflowId);
  if (!execution) return;

  const nodes = orderedNodes(workflowId);
  const waitingIndex = nodes.findIndex((n) => n.state === 'waiting');
  if (waitingIndex === -1) return;

  db.prepare('UPDATE workflow_nodes SET state = ? WHERE id = ?').run('success', nodes[waitingIndex].id);
  db.prepare('UPDATE executions SET state = ? WHERE id = ?').run('running', execution.id);
  recordEvent(execution.id, `${nodes[waitingIndex].title} approved — resuming`);
  emit(execution.id, { type: 'node', nodeId: nodes[waitingIndex].id, state: 'success' });
  emit(execution.id, { type: 'state', state: 'running' });

  stepNode(userId, execution.id, workflowId, nodes, waitingIndex + 1);
}

module.exports = { startExecution, resumeAfterApproval, emitterFor, orderedNodes };
