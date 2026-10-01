const crypto = require('node:crypto');
const { EventEmitter } = require('node:events');
const db = require('../db');
const { logAudit } = require('./audit');

// One EventEmitter per execution id, so an SSE route can stream live
// node/execution state changes to the client without polling.
// NOTE: in-memory only — fine for a single-process MVP; a multi-instance
// deployment would replace this with a pub/sub channel (Redis, etc).
const emitters = new Map();
// Per-execution in-memory run state (chosen branches, running set, etc).
// Also in-memory only, for the same reason as `emitters`.
const runs = new Map();

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

function orderedNodes(workflowId) {
  // Still used by callers that just want "the nodes" (builder screens etc.) —
  // insertion order there is cosmetic, not an execution order.
  return db.prepare('SELECT * FROM workflow_nodes WHERE workflow_id = ? ORDER BY rowid ASC').all(workflowId);
}

function setNodeState(nodeId, state) {
  db.prepare('UPDATE workflow_nodes SET state = ? WHERE id = ?').run(state, nodeId);
}

/**
 * Real topological walk of workflow_connections (COMMAND 08), replacing the
 * earlier insertion-order simplification:
 *  - A node becomes READY once every one of its incoming edges points at a
 *    node that finished successfully (fan-in), or it has no incoming edges
 *    (a trigger).
 *  - Independent branches run in PARALLEL, each on its own timer.
 *  - A `logic` node with multiple distinct outgoing `branch_label`s picks
 *    ONE branch (first alphabetically, for determinism in this MVP — swap
 *    in real condition evaluation later) and marks sibling branch targets
 *    `skipped`, cascading to anything only reachable through them.
 *  - `approval` nodes pause the whole execution exactly as before.
 */
function buildGraph(workflowId) {
  const nodes = db.prepare('SELECT * FROM workflow_nodes WHERE workflow_id = ?').all(workflowId);
  const edges = db.prepare('SELECT * FROM workflow_connections WHERE workflow_id = ?').all(workflowId);
  const byId = new Map(nodes.map((n) => [n.id, n]));
  const outgoing = new Map(nodes.map((n) => [n.id, []]));
  const incoming = new Map(nodes.map((n) => [n.id, []]));
  for (const e of edges) {
    if (!byId.has(e.from_node_id) || !byId.has(e.to_node_id)) continue;
    outgoing.get(e.from_node_id).push(e);
    incoming.get(e.to_node_id).push(e);
  }
  return { nodes, byId, outgoing, incoming };
}

function descendantsOnlyReachableThrough(graph, startEdge, excludeNodeId) {
  // Nodes reachable from startEdge.to_node_id that are NOT also reachable
  // via any node outside the skipped branch — a safe "cascade the skip"
  // without accidentally starving a node another branch still feeds.
  const skippedRoot = startEdge.to_node_id;
  const reachableFromSkipped = new Set();
  (function walk(id) {
    if (reachableFromSkipped.has(id)) return;
    reachableFromSkipped.add(id);
    for (const e of graph.outgoing.get(id) || []) walk(e.to_node_id);
  })(skippedRoot);

  const stillFed = new Set();
  for (const id of reachableFromSkipped) {
    const ins = graph.incoming.get(id) || [];
    const hasOutsideFeed = ins.some((e) => e.from_node_id !== excludeNodeId && !reachableFromSkipped.has(e.from_node_id));
    if (id !== skippedRoot && hasOutsideFeed) stillFed.add(id);
  }
  return [...reachableFromSkipped].filter((id) => !stillFed.has(id));
}

function startExecution(userId, workflowId) {
  const workflow = db.prepare('SELECT * FROM workflows WHERE id = ? AND user_id = ?').get(workflowId, userId);
  if (!workflow) throw new Error('Workflow not found');

  const graph = buildGraph(workflowId);
  if (graph.nodes.length === 0) throw new Error('Workflow has no nodes');
  for (const n of graph.nodes) setNodeState(n.id, 'idle');

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

  runs.set(executionId, { userId, workflowId, graph, running: new Set(), done: new Set(), skipped: new Set() });
  advance(executionId);
  return executionId;
}

function isTerminal(nodeId, run) {
  return run.done.has(nodeId) || run.skipped.has(nodeId);
}

/** Finds every idle node whose dependencies are already resolved, and starts them. */
function advance(executionId) {
  const run = runs.get(executionId);
  if (!run) return;
  const execution = db.prepare('SELECT * FROM executions WHERE id = ?').get(executionId);
  if (!execution || ['cancelled', 'completed', 'waitingApproval'].includes(execution.state)) return;

  const { graph } = run;
  let startedAny = false;

  for (const node of graph.nodes) {
    if (run.running.has(node.id) || isTerminal(node.id, run)) continue;
    const ins = graph.incoming.get(node.id) || [];
    if (ins.length === 0) {
      runNode(executionId, node);
      startedAny = true;
      continue;
    }
    const allSettled = ins.every((e) => isTerminal(e.from_node_id, run));
    if (!allSettled) continue;
    const anySucceeded = ins.some((e) => run.done.has(e.from_node_id));
    if (anySucceeded) {
      runNode(executionId, node);
    } else {
      // every incoming branch was skipped -> this node is unreachable too
      run.skipped.add(node.id);
      setNodeState(node.id, 'skipped');
      emit(executionId, { type: 'node', nodeId: node.id, state: 'skipped' });
    }
    startedAny = true;
  }

  if (!startedAny && run.running.size === 0) {
    finishIfDone(executionId);
  }
}

function finishIfDone(executionId) {
  const run = runs.get(executionId);
  if (!run) return;
  const allSettled = run.graph.nodes.every((n) => isTerminal(n.id, run));
  if (!allSettled) return;
  db.prepare('UPDATE executions SET state = ?, completed_at = ? WHERE id = ?').run('completed', new Date().toISOString(), executionId);
  const skippedCount = run.skipped.size;
  recordEvent(executionId, skippedCount ? `Execution completed (${skippedCount} node${skippedCount === 1 ? '' : 's'} skipped by branching)` : 'Execution completed');
  emit(executionId, { type: 'state', state: 'completed' });
  runs.delete(executionId);
}

function runNode(executionId, node) {
  const run = runs.get(executionId);
  run.running.add(node.id);
  setNodeState(node.id, 'running');
  recordEvent(executionId, `${node.title} started`);
  emit(executionId, { type: 'node', nodeId: node.id, state: 'running' });

  setTimeout(() => {
    if (!runs.has(executionId)) return; // execution was cancelled/gc'd
    if (node.category === 'approval') {
      run.running.delete(node.id);
      setNodeState(node.id, 'waiting');
      db.prepare('UPDATE executions SET state = ? WHERE id = ?').run('waitingApproval', executionId);
      recordEvent(executionId, `${node.title} — waiting for your approval`);
      emit(executionId, { type: 'node', nodeId: node.id, state: 'waiting' });
      emit(executionId, { type: 'state', state: 'waitingApproval' });

      const existing = db.prepare('SELECT 1 FROM approval_requests WHERE workflow_id = ? AND resolved = 0').get(run.workflowId);
      if (!existing) {
        const agent = db.prepare('SELECT * FROM agents WHERE user_id = ? ORDER BY rowid ASC LIMIT 1').get(run.userId);
        db.prepare(
          `INSERT INTO approval_requests (id, user_id, agent_id, workflow_id, action, scope, requested_at, resolved)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)`
        ).run(crypto.randomUUID(), run.userId, agent ? agent.id : null, run.workflowId, node.title, 'External platform', new Date().toISOString());
      }
      return; // waits for resumeAfterApproval()
    }

    completeNode(executionId, node);
  }, 900);
}

function completeNode(executionId, node) {
  const run = runs.get(executionId);
  if (!run) return;
  run.running.delete(node.id);
  run.done.add(node.id);
  setNodeState(node.id, 'success');
  recordEvent(executionId, `${node.title} completed`);
  emit(executionId, { type: 'node', nodeId: node.id, state: 'success' });

  if (node.category === 'logic') {
    applyBranchSkip(executionId, node);
  }

  advance(executionId);
}

/** A `logic` node with >1 distinct branch_label picks one deterministically and skips the rest. */
function applyBranchSkip(executionId, node) {
  const run = runs.get(executionId);
  const { graph } = run;
  const outs = graph.outgoing.get(node.id) || [];
  const labeled = outs.filter((e) => e.branch_label);
  const distinctLabels = [...new Set(labeled.map((e) => e.branch_label))];
  if (distinctLabels.length < 2) return; // nothing to branch on

  const chosen = [...distinctLabels].sort()[0];
  recordEvent(executionId, `${node.title} — condition took branch "${chosen}"`);
  for (const e of labeled) {
    if (e.branch_label === chosen) continue;
    for (const id of descendantsOnlyReachableThrough(graph, e, node.id)) {
      if (isTerminal(id, run) || run.running.has(id)) continue;
      run.skipped.add(id);
      setNodeState(id, 'skipped');
      emit(executionId, { type: 'node', nodeId: id, state: 'skipped' });
    }
  }
}

function resumeAfterApproval(userId, workflowId) {
  const execution = db
    .prepare("SELECT * FROM executions WHERE workflow_id = ? AND state = 'waitingApproval' ORDER BY started_at DESC LIMIT 1")
    .get(workflowId);
  if (!execution) return;
  const run = runs.get(execution.id);
  if (!run) return;

  const waitingNode = run.graph.nodes.find((n) => {
    const row = db.prepare('SELECT state FROM workflow_nodes WHERE id = ?').get(n.id);
    return row && row.state === 'waiting';
  });
  if (!waitingNode) return;

  db.prepare('UPDATE executions SET state = ? WHERE id = ?').run('running', execution.id);
  recordEvent(execution.id, `${waitingNode.title} approved — resuming`);
  emit(execution.id, { type: 'state', state: 'running' });
  completeNode(execution.id, waitingNode);
}

module.exports = { startExecution, resumeAfterApproval, emitterFor, orderedNodes };
