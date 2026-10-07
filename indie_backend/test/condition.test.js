// Real condition evaluation for `logic` nodes — replaces the old
// alphabetically-first stand-in with configurable always/probability/random
// branch selection, while keeping the alphabetical fallback for workflows
// that never configure a condition (backward compatible with execution.test.js).
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-condition.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';

const { chooseBranch } = require('../src/lib/executionEngine');

// ---- Pure unit tests for chooseBranch (no server, no timing) ----

test('chooseBranch: no condition -> alphabetically-first (legacy default)', () => {
  assert.strictEqual(chooseBranch(['Yes', 'No'], null), 'No');
  assert.strictEqual(chooseBranch(['Yes', 'No'], undefined), 'No');
  assert.strictEqual(chooseBranch(['Zebra', 'Apple'], 'not valid json {'), 'Apple');
});

test('chooseBranch: "always" picks exactly that branch, every time', () => {
  const cond = JSON.stringify({ type: 'always', branch: 'Yes' });
  for (let i = 0; i < 20; i++) {
    assert.strictEqual(chooseBranch(['Yes', 'No'], cond), 'Yes');
  }
});

test('chooseBranch: "always" naming a branch that is not actually wired falls back to alphabetical', () => {
  const cond = JSON.stringify({ type: 'always', branch: 'Maybe' }); // not in the wired labels
  assert.strictEqual(chooseBranch(['Yes', 'No'], cond), 'No');
});

test('chooseBranch: "probability" 100% always picks the branch, 0% never does', () => {
  const always = JSON.stringify({ type: 'probability', branch: 'Yes', percent: 100 });
  const never = JSON.stringify({ type: 'probability', branch: 'Yes', percent: 0 });
  for (let i = 0; i < 30; i++) {
    assert.strictEqual(chooseBranch(['Yes', 'No'], always), 'Yes');
    assert.strictEqual(chooseBranch(['Yes', 'No'], never), 'No');
  }
});

test('chooseBranch: "probability" 50% produces both outcomes over many trials (statistical, generous margin)', () => {
  const cond = JSON.stringify({ type: 'probability', branch: 'Yes', percent: 50 });
  const seen = new Set();
  for (let i = 0; i < 200; i++) seen.add(chooseBranch(['Yes', 'No'], cond));
  assert.deepStrictEqual([...seen].sort(), ['No', 'Yes'], `expected both outcomes in 200 trials, got: ${[...seen]}`);
});

test('chooseBranch: "probability" with >2 branches picks uniformly among the OTHERS on the miss', () => {
  const cond = JSON.stringify({ type: 'probability', branch: 'A', percent: 0 }); // always misses -> among B, C
  const seen = new Set();
  for (let i = 0; i < 100; i++) seen.add(chooseBranch(['A', 'B', 'C'], cond));
  assert.ok(!seen.has('A'), '0% branch must never be chosen');
  assert.deepStrictEqual([...seen].sort(), ['B', 'C'], `expected both non-A branches to appear, got: ${[...seen]}`);
});

test('chooseBranch: "random" (no branch/percent needed) picks uniformly among all labels', () => {
  const cond = JSON.stringify({ type: 'random' });
  const seen = new Set();
  for (let i = 0; i < 200; i++) seen.add(chooseBranch(['Yes', 'No', 'Maybe'], cond));
  assert.deepStrictEqual([...seen].sort(), ['Maybe', 'No', 'Yes'], `expected all three to appear in 200 trials, got: ${[...seen]}`);
});

// ---- Route + end-to-end execution tests ----

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
  const r = await api('POST', '/auth/register', null, { credential: 'cond-test-' + Math.random() });
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

test('PATCH node: condition is validated (bad type, missing branch, bad percent)', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Cond validate' })).body;
  const cond = await addNode(t, wf.id, 'logic', 'Condition');

  assert.strictEqual((await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'bogus' } })).status, 400);
  assert.strictEqual((await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'always' } })).status, 400, 'missing branch');
  assert.strictEqual((await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'probability', branch: 'Yes', percent: 150 } })).status, 400, 'percent out of range');

  const ok = await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'random' } });
  assert.strictEqual(ok.status, 200);
  assert.deepStrictEqual(ok.body.condition, { type: 'random' });

  const cleared = await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: null });
  assert.strictEqual(cleared.body.condition, null);
});

test('end-to-end: an "always" condition deterministically drives which branch actually executes', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Always Yes' })).body;
  const trigger = wf.nodes[0];
  const cond = await addNode(t, wf.id, 'logic', 'Condition');
  const yesPath = await addNode(t, wf.id, 'action', 'Yes Action');
  const noPath = await addNode(t, wf.id, 'action', 'No Action');
  await connect(t, wf.id, trigger.id, cond.id);
  await connect(t, wf.id, cond.id, yesPath.id, 'Yes');
  await connect(t, wf.id, cond.id, noPath.id, 'No');
  await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'always', branch: 'Yes' } });

  await api('POST', `/workflows/${wf.id}/run`, t);
  await sleep(2100);
  const states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Yes Action'], 'running', 'the configured branch runs — not the alphabetical default ("No")');
  assert.strictEqual(states['No Action'], 'skipped');
});

test('end-to-end: a "probability" condition is visible in the execution timeline', async () => {
  const t = await newUser();
  const wf = (await api('POST', '/workflows', t, { name: 'Prob test' })).body;
  const trigger = wf.nodes[0];
  const cond = await addNode(t, wf.id, 'logic', 'Condition');
  const a = await addNode(t, wf.id, 'action', 'Path A');
  const b = await addNode(t, wf.id, 'action', 'Path B');
  await connect(t, wf.id, trigger.id, cond.id);
  await connect(t, wf.id, cond.id, a.id, 'A');
  await connect(t, wf.id, cond.id, b.id, 'B');
  await api('PATCH', `/workflows/${wf.id}/nodes/${cond.id}`, t, { condition: { type: 'probability', branch: 'A', percent: 100 } });

  const run = await api('POST', `/workflows/${wf.id}/run`, t);
  await sleep(2100);
  const timeline = (await api('GET', `/workflows/executions/${run.body.executionId}/timeline`, t)).body;
  assert.ok(timeline.some((e) => e.label.includes('condition took branch "A"')));
  const states = await nodeStates(t, wf.id);
  assert.strictEqual(states['Path A'], 'running');
  assert.strictEqual(states['Path B'], 'skipped');
});
