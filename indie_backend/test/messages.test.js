// Message-detail, contacts, agent-scope and Orchestrator tests.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-msg.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/contacts', require('../src/routes/contacts'));
app.use('/agents', require('../src/routes/agents'));
app.use('/workflows', require('../src/routes/workflows'));
app.use('/vault', require('../src/routes/vault'));
app.use('/orchestrator', require('../src/routes/orchestrator'));

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
async function newUser(seed = true) {
  const r = await api('POST', '/auth/register', null, { credential: 'pass-' + Math.random(), seedDemo: seed });
  return r.body.token;
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
});
test.after(async () => {
  await new Promise((r) => server.close(r));
  for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} }
});

test('add contact validates fields; contacts are people only', async () => {
  const t = await newUser(false);
  const bad = await api('POST', '/contacts', t, { name: '', info: '' });
  assert.strictEqual(bad.status, 400);
  assert.ok(bad.body.fields.name && bad.body.fields.info);
  const ok = await api('POST', '/contacts', t, { name: 'John Smith', info: 'john@indie.id', group: 'Work' });
  assert.strictEqual(ok.status, 201);
  assert.strictEqual(ok.body.initials, 'JS');
  assert.strictEqual(ok.body.group, 'Work');
  const patched = await api('PATCH', `/contacts/${ok.body.id}`, t, { muted: true, pinned: true, name: 'Johnny Smith' });
  assert.strictEqual(patched.body.muted, true);
  assert.strictEqual(patched.body.name, 'Johnny Smith');
  const del = await api('DELETE', `/contacts/${ok.body.id}`, t);
  assert.strictEqual(del.status, 200);
  assert.strictEqual((await api('GET', '/contacts', t)).body.length, 0);
});

test('message detail: reply, reaction toggle, delete tombstone, delivery status', async () => {
  const t = await newUser(true);
  const contacts = (await api('GET', '/contacts', t)).body;
  const alex = contacts.find((c) => c.name === 'Alex Rahman');
  const msgs = (await api('GET', `/contacts/${alex.id}/messages`, t)).body;
  assert.ok(msgs.some((m) => m.kind === 'file'), 'seeded file attachment');
  assert.ok(msgs.some((m) => m.replyTo && m.replyTo.snippet.includes('Great!')), 'seeded reply quote');
  const target = msgs.find((m) => m.sender === 'user');

  const sent = (await api('POST', `/contacts/${alex.id}/messages`, t, { text: 'See you there', replyToId: target.id })).body;
  assert.strictEqual(sent.status, 'sent');
  assert.strictEqual(sent.replyTo.id, target.id);

  let r = (await api('PATCH', `/contacts/${alex.id}/messages/${sent.id}/reaction`, t, { emoji: '❤️' })).body;
  assert.deepStrictEqual(r.reactions, { '❤️': 1 });
  assert.strictEqual(r.myReaction, '❤️');
  r = (await api('PATCH', `/contacts/${alex.id}/messages/${sent.id}/reaction`, t, { emoji: '❤️' })).body;
  assert.deepStrictEqual(r.reactions, {}, 'same emoji again removes it');
  assert.strictEqual((await api('PATCH', `/contacts/${alex.id}/messages/${sent.id}/reaction`, t, { emoji: '💩' })).status, 400);

  const foreign = msgs.find((m) => m.sender === 'contact');
  assert.strictEqual((await api('DELETE', `/contacts/${alex.id}/messages/${foreign.id}`, t)).status, 403, 'cannot delete others\' messages');
  const del = (await api('DELETE', `/contacts/${alex.id}/messages/${sent.id}`, t)).body;
  assert.strictEqual(del.deleted, true);
  assert.strictEqual(del.text, '');

  const second = (await api('POST', `/contacts/${alex.id}/messages`, t, { text: 'status check' })).body;
  await sleep(2300);
  const after = (await api('GET', `/contacts/${alex.id}/messages`, t)).body.find((m) => m.id === second.id);
  assert.strictEqual(after.status, 'read', 'sent -> delivered -> read');
});

test('unread resets when the room is opened; clear history works', async () => {
  const t = await newUser(true);
  const sarah = (await api('GET', '/contacts', t)).body.find((c) => c.name === 'Sarah Putri');
  assert.strictEqual(sarah.unread, 1);
  await api('GET', `/contacts/${sarah.id}/messages`, t);
  assert.strictEqual((await api('GET', '/contacts', t)).body.find((c) => c.id === sarah.id).unread, 0);
  await api('DELETE', `/contacts/${sarah.id}/messages`, t);
  assert.strictEqual((await api('GET', `/contacts/${sarah.id}/messages`, t)).body.length, 0);
});

test('attachments: Vault outputs are validated server-side and share the result only', async () => {
  const t = await newUser(true);
  const other = await newUser(true);
  const contact = (await api('GET', '/contacts', t)).body[0];
  const out = (await api('GET', '/vault/outputs', t)).body[0];
  const foreignOut = (await api('GET', '/vault/outputs', other)).body[0];

  const stolen = await api('POST', `/contacts/${contact.id}/messages`, t, { kind: 'output', outputId: foreignOut.id });
  assert.strictEqual(stolen.status, 400, 'cannot attach someone else\'s output');
  const forged = await api('POST', `/contacts/${contact.id}/messages`, t, { kind: 'output', outputId: out.id, payload: { output: { title: 'FORGED', workflow: { secret: 1 } } } });
  assert.strictEqual(forged.status, 201);
  assert.strictEqual(forged.body.payload.output.title, out.title, 'title comes from the Vault, not the client');
  assert.strictEqual(JSON.stringify(forged.body).includes('secret'), false, 'client-supplied fields are ignored');
  assert.ok(forged.body.payload.output.note.includes('report + AI summary only'));
  assert.strictEqual((await api('GET', `/vault/outputs/${out.id}`, t)).body.shared, true);

  const file = await api('POST', `/contacts/${contact.id}/messages`, t, { kind: 'file', payload: { file: { name: 'IMG_2041.jpg', size: '1.1 MB' } } });
  assert.strictEqual(file.body.kind, 'file');
  assert.strictEqual((await api('POST', `/contacts/${contact.id}/messages`, t, { kind: 'file', payload: {} })).status, 400);
  const saved = await api('POST', `/contacts/${contact.id}/messages/${file.body.id}/save`, t);
  assert.strictEqual(saved.body.saved, true);
});

test('agent chat is scoped to the workflow; agents cannot be created directly', async () => {
  const t = await newUser(true);
  assert.strictEqual((await api('POST', '/agents', t, { name: 'Sneaky Agent' })).status, 404, 'no direct agent creation');
  const mkt = (await api('GET', '/agents', t)).body.find((a) => a.name === 'Marketing Agent');
  assert.ok(mkt.workflow.includes('Generate report'));

  const out = await api('POST', `/agents/${mkt.id}/messages`, t, { text: 'order me a pizza' });
  assert.strictEqual(out.body.scope, 'out_of_scope');
  const inn = await api('POST', `/agents/${mkt.id}/messages`, t, { text: 'please read campaign analytics' });
  assert.strictEqual(inn.body.scope, 'in_scope');
  await sleep(2700);
  const msgs = (await api('GET', `/agents/${mkt.id}/messages`, t)).body;
  const refusal = msgs.find((m) => m.text.includes('outside my workflow'));
  assert.ok(refusal && refusal.payload.cta === 'ask_orchestrator');
  assert.ok(msgs.some((m) => m.kind === 'card' && m.payload.card.title.includes('Read campaign analytics')), 'follow-up result card');
  const card = msgs.find((m) => m.kind === 'card');
  const saved = await api('POST', `/agents/${mkt.id}/messages/${card.id}/save`, t);
  assert.strictEqual(saved.body.saved, true);
});

test('Orchestrator: create agent, update its workflow, chat stays inside scope', async () => {
  const t = await newUser(true);
  const first = (await api('GET', '/orchestrator/messages', t)).body;
  assert.strictEqual(first[0].kind, 'welcome');

  const post = await api('POST', '/orchestrator/messages', t, { text: 'Create an agent to monitor my Instagram' });
  assert.strictEqual(post.status, 202);
  assert.strictEqual(post.body.intent, 'create_agent');
  assert.strictEqual((await api('POST', '/orchestrator/messages', t, { text: 'another' })).status, 409, 'busy while working');
  await sleep(1100);
  const thread = (await api('GET', `/orchestrator/messages?after=${post.body.message.id}`, t)).body;
  const created = thread.find((m) => m.kind === 'agent_created');
  assert.ok(created, 'agent_created reply');
  assert.strictEqual(created.payload.name, 'Monitor Instagram Agent');
  assert.ok(created.payload.workflow.includes('Notify you'));

  const agent = (await api('GET', `/agents/${created.payload.agentId}`, t)).body;
  assert.strictEqual(agent.workflow.length, 4);
  const greeting = (await api('GET', `/agents/${agent.id}/messages`, t)).body;
  assert.ok(greeting[0].text.includes('Orchestrator set up my workflow'));

  const upd = await api('POST', '/orchestrator/messages', t, { text: 'Update workflow of Monitor Instagram Agent: also track follower growth' });
  assert.strictEqual(upd.body.intent, 'update_workflow');
  await sleep(1100);
  const agent2 = (await api('GET', `/agents/${agent.id}`, t)).body;
  assert.strictEqual(agent2.workflow.length, 5);
  assert.ok(agent2.workflow.includes('Also track follower growth'));
  assert.strictEqual(agent2.workflow[agent2.workflow.length - 1], 'Ask your approval before any external action', 'approval step stays last');

  const inScope = await api('POST', `/agents/${agent.id}/messages`, t, { text: 'track follower growth please' });
  assert.strictEqual(inScope.body.scope, 'in_scope', 'new step is now in scope');
});

test('Orchestrator task: creates missing agents + a real workflow, then saves result to Vault', async () => {
  const t = await newUser(true);
  const before = (await api('GET', '/agents', t)).body.length;
  const wfBefore = (await api('GET', '/workflows', t)).body.length;
  const post = await api('POST', '/orchestrator/messages', t, { text: 'Plan a 7-day trip to Bali' });
  assert.strictEqual(post.body.intent, 'task');
  await sleep(6300);
  const thread = (await api('GET', `/orchestrator/messages?after=${post.body.message.id}`, t)).body;
  const plan = thread.find((m) => m.kind === 'plan');
  assert.deepStrictEqual(plan.payload.created.sort(), ['Itinerary Agent', 'Travel Agent']);
  assert.strictEqual(thread.filter((m) => m.kind === 'agent_result').length, 4);
  const result = thread.find((m) => m.kind === 'result');
  assert.ok(result, 'combined result');

  assert.strictEqual((await api('GET', '/agents', t)).body.length, before + 2);
  const wfs = (await api('GET', '/workflows', t)).body;
  assert.strictEqual(wfs.length, wfBefore + 1);
  const wf = (await api('GET', `/workflows/${plan.payload.workflowId}`, t)).body;
  assert.strictEqual(wf.nodes.length, 6, 'trigger + 4 agents + save');
  assert.strictEqual(wf.connections.length, 5);
  assert.strictEqual(wf.lifecycle, 'ready');
  assert.strictEqual((await api('POST', `/workflows/${wf.id}/validate`, t)).body.valid, true);

  const travel = (await api('GET', '/agents', t)).body.find((a) => a.name === 'Travel Agent');
  const room = (await api('GET', `/agents/${travel.id}/messages`, t)).body;
  assert.ok(room.some((m) => m.text.startsWith('Task done for')), 'agent room got its own result');

  const saved = await api('POST', `/orchestrator/messages/${result.id}/save`, t);
  assert.strictEqual(saved.status, 201);
  assert.strictEqual((await api('POST', `/orchestrator/messages/${result.id}/save`, t)).status, 409);
  const outputs = (await api('GET', '/vault/outputs', t)).body;
  assert.ok(outputs.some((o) => o.id === saved.body.outputId));
});

test('isolation: another account cannot touch messages or orchestrator results', async () => {
  const a = await newUser(true);
  const b = await newUser(true);
  const contact = (await api('GET', '/contacts', a)).body[0];
  assert.strictEqual((await api('GET', `/contacts/${contact.id}/messages`, b)).status, 404);
  assert.strictEqual((await api('POST', `/contacts/${contact.id}/messages`, b, { text: 'hi' })).status, 404);
  const agent = (await api('GET', '/agents', a)).body[0];
  assert.strictEqual((await api('POST', `/agents/${agent.id}/messages`, b, { text: 'hi' })).status, 404);
  await api('GET', '/orchestrator/messages', a);
  const m = (await api('GET', '/orchestrator/messages', a)).body[0];
  assert.strictEqual((await api('POST', `/orchestrator/messages/${m.id}/save`, b)).status, 404);
});

test('recovery phrase is real BIP-39 (interoperable checksum, not just 12 random words)', async () => {
  const bip39 = require('bip39');
  const reg = await api('POST', '/auth/register', null, { credential: 'checksum-test-cred' });
  const phrase = reg.body.recoveryPhrase;
  assert.strictEqual(phrase.split(' ').length, 12);
  assert.strictEqual(bip39.validateMnemonic(phrase), true, 'phrase must pass independent BIP-39 validation');

  // Recovery rejects a phrase with a broken checksum before even touching the DB.
  const words = phrase.split(' ');
  words[0] = words[0] === 'zoo' ? 'abandon' : 'zoo'; // corrupt one word
  const bad = await api('POST', '/auth/recover', null, { personalId: reg.body.personalId, recoveryPhrase: words.join(' '), newCredential: 'new-credential-1' });
  assert.strictEqual(bad.status, 401);

  // The real phrase still works.
  const good = await api('POST', '/auth/recover', null, { personalId: reg.body.personalId, recoveryPhrase: phrase, newCredential: 'new-credential-2' });
  assert.strictEqual(good.status, 200);
});
