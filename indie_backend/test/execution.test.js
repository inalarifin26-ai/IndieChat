// Execution Engine: parallel fan-out/fan-in and logic-node branch skipping.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-exec.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/workflows', require('../src/routes/workflows'));

let server, base;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(method, url, token, body) {
  const res = await fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}
async function newUser() {
  const r = await api('POST', '/auth/register', null, { credential: 'pass-' + Math.random() });
  return r.body.token;
}
async function addNode(t, wfId, category, title) {
  return (await api('POST', `/workflows/${wfId}/nodes`, t, { category, title })).body;
}
async function connect(t, wfId, from, to, branchLabel) {
  return api('POST', `/workflows/${wfId}/connections`, t, { fromNodeId: from, toNodeId: to, branchLabel });
}
async function nodeStates(t, wfId) {
  const wf = (await api('GET', `/workflows/${wfId}`, t)).body;
  const m = {};
  wf.nodes.forEach((n) => (m[n.title] = n.state));
  return m;
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
});
test.after(async () => {
  await new Promise((r) => server.close(r));
  for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} }
});

test('fan-out + fan-in: independent branches run in parallel, join waits for both', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Fan test' })).body;
  const trigger = wf.nodes[0]; // seeded "Manual trigger"
  const a = await addNode(t, wf.id, 'data', 'Branch A');
  const b = await addNode(t, wf.id, 'data', 'Branch B');
  const join = await addNode(t, wf.id, 'output', 'Join');
  await connect(t, wf.id, trigger.id, a.id);
  await connect(t, wf.id, trigger.id, b.id);
  await connect(t, wf.id, a.id, join.id);
  await connect(t, wf.id, b.id, join.id);

  const valid = await api('POST', `/workflows/${wf.id}/validate`, t);
  assert.strictEqual(valid.body.valid, true);

  const run = await api('POST', `/workflows/${wf.id}/run`, t);
  assert.strictEqual(run.status, 202);

  // The trigger itself runs for ~900ms first; once it completes, BOTH
  // branch A and B should start running in parallel (not one-after-the-other,
  // as the old insertion-order engine would have done).
  await sleep(1050);
  let states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Branch A'], 'running', 'A running in parallel');
  assert.strictEqual(states['Branch B'], 'running', 'B running in parallel');
  assert.strictEqual(states['Join'], 'idle', 'join has not started — still waiting on both branches');

  await sleep(900);
  states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Branch A'], 'success');
  assert.strictEqual(states['Branch B'], 'success');
  assert.strictEqual(states['Join'], 'running', 'join only starts once BOTH branches finished');

  await sleep(900);
  const exec = (await api('GET', `/workflows/${wf.id}/executions`, t)).body[0];
  assert.strictEqual(exec.state, 'completed');
  states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Join'], 'success');
});

test('logic node: picks one branch deterministically, skips the sibling branch and its exclusive descendants', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Branch test' })).body;
  const trigger = wf.nodes[0];
  const cond = await addNode(t, wf.id, 'logic', 'Condition');
  const yesPath = await addNode(t, wf.id, 'action', 'Yes Action');
  const noPath = await addNode(t, wf.id, 'action', 'No Action');
  const noOnly = await addNode(t, wf.id, 'storage', 'No-only follow-up'); // only reachable via the "No" branch
  await connect(t, wf.id, trigger.id, cond.id);
  await connect(t, wf.id, cond.id, yesPath.id, 'Yes');
  await connect(t, wf.id, cond.id, noPath.id, 'No');
  await connect(t, wf.id, noPath.id, noOnly.id);

  await api('POST', `/workflows/${wf.id}/run`, t);
  await sleep(2100); // trigger + condition node both complete (~2 x 900ms)

  const states = await nodeStates(t, wf.id);
  // 'No' sorts before 'Yes' alphabetically, so the engine's deterministic
  // pick takes the "No" branch (see applyBranchSkip's `sort()[0]`).
  assert.strictEqual(states['No Action'], 'running');
  assert.strictEqual(states['Yes Action'], 'skipped');

  await sleep(900);
  const states2 = await nodeStates(t, wf.id);
  assert.strictEqual(states2['No-only follow-up'], 'running', 'downstream-of-chosen-branch node still runs');

  await sleep(900);
  const exec = (await api('GET', `/workflows/${wf.id}/executions`, t)).body[0];
  assert.strictEqual(exec.state, 'completed');
  const timeline = (await api('GET', `/workflows/executions/${exec.id}/timeline`, t)).body;
  assert.ok(timeline.some((e) => e.label.includes('condition took branch "No"')));
  assert.ok(timeline.some((e) => e.label.includes('1 node skipped')));
});

test('a node fed only by a fully-skipped branch is itself skipped (cascade)', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Cascade test' })).body;
  const trigger = wf.nodes[0];
  const cond = await addNode(t, wf.id, 'logic', 'Condition');
  const yesA = await addNode(t, wf.id, 'action', 'Yes A');
  const yesB = await addNode(t, wf.id, 'action', 'Yes B'); // chained only off the skipped branch
  const noA = await addNode(t, wf.id, 'action', 'No A');
  await connect(t, wf.id, trigger.id, cond.id);
  await connect(t, wf.id, cond.id, yesA.id, 'Yes');
  await connect(t, wf.id, cond.id, noA.id, 'No');
  await connect(t, wf.id, yesA.id, yesB.id);

  await api('POST', `/workflows/${wf.id}/run`, t);
  await sleep(2100);
  const states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Yes A'], 'skipped');
  assert.strictEqual(states['Yes B'], 'skipped', 'cascades to a node only reachable through the skipped branch');
  assert.strictEqual(states['No A'], 'running');
});
