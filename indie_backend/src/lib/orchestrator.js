const crypto = require('node:crypto');
const db = require('../db');
const { logAudit } = require('./audit');

const ACCENTS = ['2FE4DB', '5AA9FF', '34D399', 'B48CFF', 'F5B95B', '3A5CFF'];
const APPROVAL_STEP = 'Ask your approval before any external action';
const STOP = new Set(['my', 'the', 'a', 'an', 'to', 'saya', 'ku', 'untuk', 'yang', 'that', 'of', 'and']);
const busy = new Set(); // one orchestration at a time per user

const LIB = {
  travel: { name: 'Travel Agent', glyph: 'T', role: 'Flights & hotels', steps: ['Search flights', 'Compare hotels', 'Report options to you'], result: 'Found 3 flight options and 2 family-friendly hotels within budget.' },
  itinerary: { name: 'Itinerary Agent', glyph: 'I', role: 'Daily itineraries', steps: ['Build day-by-day schedule', 'Balance activities and rest', 'Report plan to you'], result: 'Built a 7-day schedule balancing beach days, culture and rest time.' },
  finance: { existing: 'Finance Agent', result: 'Estimated total budget: Rp 32,600,000 for a family of 4, incl. buffer.' },
  research: { existing: 'Research Agent', result: 'Found 5 relevant options and sources worth reviewing.' },
  marketing: { existing: 'Marketing Agent', result: 'Drafted a performance summary — publishing still needs your approval.' },
};

function uuid() {
  return crypto.randomUUID();
}
function nowIso() {
  return new Date().toISOString();
}

function addMessage(userId, sender, kind, text, payload, agentId) {
  const id = uuid();
  db.prepare(
    `INSERT INTO orchestrator_messages (id, user_id, sender, agent_id, kind, text, payload_json, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(id, userId, sender, agentId || null, kind, text || '', payload ? JSON.stringify(payload) : null, nowIso());
  return id;
}

function serialize(row) {
  return {
    id: row.id,
    sender: row.sender,
    agentId: row.agent_id,
    kind: row.kind,
    text: row.text,
    payload: row.payload_json ? JSON.parse(row.payload_json) : null,
    saved: !!row.saved,
    createdAt: row.created_at,
  };
}

function ensureWelcome(userId) {
  const any = db.prepare('SELECT 1 FROM orchestrator_messages WHERE user_id = ? LIMIT 1').get(userId);
  if (any) return;
  addMessage(userId, 'orchestrator', 'welcome', 'Hi! I define what your agents do.', {
    suggestions: ['Create an agent to monitor my Instagram', 'Plan a 7-day trip to Bali, family-friendly', 'Create an agent to summarize my daily emails'],
  });
}

function deriveAgent(text, existingCount) {
  const m = text.match(/(?:\bto\b|\buntuk\b|\bthat\b|\byang\b)\s+(.+)$/i);
  let topic = (m ? m[1] : text.replace(/.*\bagent\b/i, '')).replace(/[.!?]+$/, '').trim();
  if (!topic) topic = 'general tasks';
  const words = topic.split(/\s+/).filter((w) => w && !STOP.has(w.toLowerCase())).slice(0, 2);
  const name = (words.length ? words.map((w) => w[0].toUpperCase() + w.slice(1)).join(' ') : 'Custom') + ' Agent';
  const short = topic.length > 38 ? topic.slice(0, 38) + '…' : topic;
  const l = topic.toLowerCase();
  const obj = short.replace(/^(monitor|memantau|pantau|watch|track|summari[sz]e|meringkas|ringkas|report|melaporkan|research|find|search|mencari|cari)\s+(on\s+|for\s+)?/i, '');
  let steps;
  if (/monitor|pantau|memantau|watch|track/.test(l)) steps = [`Check ${obj} on a schedule`, 'Detect important changes', 'Notify you'];
  else if (/summar|ringkas|meringkas/.test(l)) steps = [`Collect ${obj}`, 'Summarize key points', 'Save summary to Vault'];
  else if (/report|laporan/.test(l)) steps = [`Gather data for ${obj}`, 'Generate report', 'Save report to Vault'];
  else if (/research|cari|find|search/.test(l)) steps = ['Search public sources', 'Compare findings', 'Report results to you'];
  else steps = ['Receive tasks from Orchestrator', `Execute: ${short}`, 'Report results to you'];
  steps.push(APPROVAL_STEP);
  return { name, glyph: name[0], role: short[0].toUpperCase() + short.slice(1), steps, accent: ACCENTS[existingCount % ACCENTS.length] };
}

function writeSteps(userId, agentId, steps) {
  db.prepare('DELETE FROM agent_workflow_steps WHERE agent_id = ?').run(agentId);
  steps.forEach((s, i) =>
    db.prepare('INSERT INTO agent_workflow_steps (id, user_id, agent_id, position, step) VALUES (?, ?, ?, ?, ?)').run(uuid(), userId, agentId, i, s)
  );
}

function stepsOf(agentId) {
  return db.prepare('SELECT step FROM agent_workflow_steps WHERE agent_id = ? ORDER BY position ASC').all(agentId).map((r) => r.step);
}

function createAgent(userId, d) {
  const id = uuid();
  db.prepare(
    `INSERT INTO agents (id, user_id, name, role, glyph, accent_hex, state, current_activity, created_at)
     VALUES (?, ?, ?, ?, ?, ?, 'ready', 'Ready — waiting for tasks', ?)`
  ).run(id, userId, d.name, d.role, d.glyph, d.accent, nowIso());
  writeSteps(userId, id, d.steps);
  db.prepare(
    `INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, created_at) VALUES (?, ?, ?, 'agent', 'text', ?, ?)`
  ).run(uuid(), userId, id, `Hi! I'm ${d.name}. The Orchestrator set up my workflow — I will follow it exactly.`, nowIso());
  logAudit(userId, 'agent_created', `agent=${id} via=orchestrator`);
  return id;
}

function agentCount(userId) {
  return db.prepare('SELECT COUNT(*) AS n FROM agents WHERE user_id = ?').get(userId).n;
}

function agentByName(userId, name) {
  return db.prepare('SELECT * FROM agents WHERE user_id = ? AND lower(name) = lower(?)').get(userId, name);
}

function handleCreateAgent(userId, text) {
  const d = deriveAgent(text, agentCount(userId));
  const dup = agentByName(userId, d.name);
  if (dup) {
    addMessage(userId, 'orchestrator', 'text', `${dup.name} already exists. You can chat with it, or tell me how to change its workflow.`, { agentId: dup.id, name: dup.name });
    return;
  }
  const id = createAgent(userId, d);
  addMessage(userId, 'orchestrator', 'agent_created', `Created ${d.name}.`, { agentId: id, name: d.name, workflow: d.steps });
}

function handleUpdateWorkflow(userId, text) {
  const lower = text.toLowerCase();
  const agents = db.prepare('SELECT * FROM agents WHERE user_id = ?').all(userId);
  const a = agents.find((x) => {
    const n = x.name.toLowerCase();
    return lower.includes(n) || lower.includes(n.replace(' agent', ''));
  });
  if (!a) {
    addMessage(userId, 'orchestrator', 'text', 'Which agent? Try: Update workflow of Research Agent: compare prices.');
    return;
  }
  const idx = text.indexOf(':');
  const step = (idx > -1 ? text.slice(idx + 1) : text).trim();
  if (step.length < 3) {
    addMessage(userId, 'orchestrator', 'text', `What should ${a.name} do? Add the new step after a colon.`);
    return;
  }
  const steps = stepsOf(a.id);
  steps.splice(Math.max(0, steps.length - 1), 0, step[0].toUpperCase() + step.slice(1));
  writeSteps(userId, a.id, steps);
  db.prepare(
    `INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, created_at) VALUES (?, ?, ?, 'system', 'text', ?, ?)`
  ).run(uuid(), userId, a.id, `Orchestrator updated your workflow: + ${step}`, nowIso());
  logAudit(userId, 'agent_workflow_updated', `agent=${a.id}`);
  addMessage(userId, 'orchestrator', 'workflow_updated', `Updated ${a.name}.`, { agentId: a.id, name: a.name, workflow: steps });
}

function pickPlan(text) {
  const l = text.toLowerCase();
  if (/trip|bali|travel|liburan|flight|hotel/.test(l)) return ['travel', 'itinerary', 'finance', 'research'];
  if (/campaign|marketing|instagram|ads|iklan/.test(l)) return ['research', 'marketing'];
  return ['research', 'finance'];
}

function handleTask(userId, text, done) {
  const plan = pickPlan(text);
  const created = [];
  const agents = plan.map((key) => {
    const L = LIB[key];
    let a = agentByName(userId, L.existing || L.name);
    if (!a) {
      const d = L.existing
        ? { name: L.existing, glyph: L.existing[0], role: 'Created by Orchestrator', steps: ['Receive tasks from Orchestrator', 'Report results to you', APPROVAL_STEP], accent: ACCENTS[agentCount(userId) % ACCENTS.length] }
        : { name: L.name, glyph: L.glyph, role: L.role, steps: [...L.steps, APPROVAL_STEP], accent: ACCENTS[agentCount(userId) % ACCENTS.length] };
      const id = createAgent(userId, d);
      a = db.prepare('SELECT * FROM agents WHERE id = ?').get(id);
      created.push(a.name);
    }
    return { a, result: L.result };
  });

  const short = text.length > 44 ? text.slice(0, 44) + '…' : text;

  // The Orchestrator defines the workflow: a real, runnable workflow whose
  // nodes are the chosen agents (visible under the Workflows tab).
  const wfId = uuid();
  const ts = nowIso();
  db.prepare(
    `INSERT INTO workflows (id, user_id, name, description, version, lifecycle, trigger_summary, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'v1.0', 'ready', 'Manual run', ?, ?)`
  ).run(wfId, userId, short, `Created by Orchestrator for: ${text}`, ts, ts);
  const nodeIds = [];
  const addNode = (title, category, subtitle, y) => {
    const nid = uuid();
    db.prepare('INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y) VALUES (?, ?, ?, ?, ?, ?, 40, ?)').run(nid, userId, wfId, title, category, subtitle, y);
    nodeIds.push(nid);
  };
  addNode('Manual trigger', 'trigger', 'Run on demand', 40);
  agents.forEach((x, i) => addNode(x.a.name, 'ai', stepsOf(x.a.id)[0] || '', 150 + i * 110));
  addNode('Save to Vault', 'storage', 'Combined result', 150 + agents.length * 110);
  for (let i = 0; i < nodeIds.length - 1; i++) {
    db.prepare('INSERT INTO workflow_connections (id, user_id, workflow_id, from_node_id, to_node_id) VALUES (?, ?, ?, ?, ?)').run(uuid(), userId, wfId, nodeIds[i], nodeIds[i + 1]);
  }
  logAudit(userId, 'workflow_created', `workflow=${wfId} via=orchestrator`);

  addMessage(userId, 'orchestrator', 'plan', `I will coordinate ${agents.length} agents for this task.`, {
    workflowId: wfId,
    created,
    agents: agents.map((x) => ({ id: x.a.id, name: x.a.name, firstStep: stepsOf(x.a.id)[0] || '' })),
  });

  agents.forEach((x, i) => {
    setTimeout(() => {
      try {
        addMessage(userId, 'agent', 'agent_result', x.result, null, x.a.id);
        db.prepare(
          `INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, created_at) VALUES (?, ?, ?, 'agent', 'text', ?, ?)`
        ).run(uuid(), userId, x.a.id, `Task done for "${short}": ${x.result}`, nowIso());
        db.prepare("UPDATE agents SET current_activity = ? WHERE id = ? AND state = 'ready'").run(`Last task: ${short}`, x.a.id);
      } catch {}
    }, (i + 1) * 1000).unref();
  });
  setTimeout(() => {
    try {
      addMessage(userId, 'orchestrator', 'result', `All ${agents.length} agents finished — combined result.`, {
        title: short,
        workflowId: wfId,
        rows: agents.map((x) => ({ agent: x.a.name, result: x.result })),
        agentIds: agents.map((x) => x.a.id),
      });
    } finally {
      done();
    }
  }, (agents.length + 1) * 1000).unref();
}

function intentOf(text) {
  const lower = text.toLowerCase();
  if (/\b(update|ubah|change|edit)\b[^.]*\bworkflow\b/.test(lower)) return 'update_workflow';
  if (/\b(create|buat|bikin|make|add|tambah)\w*\b[^.]*\bagent\b/.test(lower)) return 'create_agent';
  return 'task';
}

/** Returns {intent} or {busy:true}. Replies are written to the thread asynchronously. */
function handle(userId, text) {
  if (busy.has(userId)) return { busy: true };
  const intent = intentOf(text);
  busy.add(userId);
  const done = () => busy.delete(userId);
  logAudit(userId, 'orchestrator_instruction', `intent=${intent}`);
  try {
    if (intent === 'task') {
      handleTask(userId, text, done);
    } else {
      setTimeout(() => {
        try {
          if (intent === 'create_agent') handleCreateAgent(userId, text);
          else handleUpdateWorkflow(userId, text);
        } finally {
          done();
        }
      }, 800).unref();
    }
  } catch (e) {
    done();
    throw e;
  }
  return { intent };
}

function isBusy(userId) {
  return busy.has(userId);
}

module.exports = { handle, isBusy, addMessage, serialize, ensureWelcome, deriveAgent, intentOf };
