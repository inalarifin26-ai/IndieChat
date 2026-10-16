// Backend support for the redesigned screens: chosen Indie ID, display name,
// group chats, search, vault notes/memories, share format, execution cancel.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-uifeatures.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
delete process.env.ANTHROPIC_API_KEY;

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/contacts', require('../src/routes/contacts'));
app.use('/groups', require('../src/routes/groups'));
app.use('/agents', require('../src/routes/agents'));
app.use('/search', require('../src/routes/search'));
app.use('/vault', require('../src/routes/vault'));
app.use('/workflows', require('../src/routes/workflows'));
app.use('/consent', require('../src/routes/consent'));
app.use('/orchestrator', require('../src/routes/orchestrator'));

let server, base;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(method, url, token, body) {
  const res = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let json = null; try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}
async function seeded() { return (await api('POST', '/auth/register', null, { credential: 'ui-test-' + Math.random(), seedDemo: true })).body; }
let uniq = 0;

test.before(async () => { await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); }); });
test.after(async () => { await new Promise((r) => server.close(r)); for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} } });

// ---------------- Create Your ID ----------------
test('id-available: invalid, reserved, taken and free IDs are told apart (no auth needed)', async () => {
  const bad = (await api('GET', '/auth/id-available?id=a!')).body;
  assert.strictEqual(bad.valid, false);
  const reserved = (await api('GET', '/auth/id-available?id=Admin')).body;
  assert.strictEqual(reserved.available, false); assert.match(reserved.reason, /reserved/);
  const free = (await api('GET', '/auth/id-available?id=free_name_' + (++uniq))).body;
  assert.deepStrictEqual([free.valid, free.available], [true, true]);
});

test('register with a chosen ID: normalized, then reported taken, duplicate rejected (409), invalid rejected (400)', async () => {
  const id = 'Chosen_' + (++uniq) + '.Id';
  const r = await api('POST', '/auth/register', null, { credential: 'secret-123', personalId: id });
  assert.strictEqual(r.status, 201);
  assert.strictEqual(r.body.personalId, id.toLowerCase());
  assert.strictEqual((await api('GET', '/auth/id-available?id=' + id)).body.available, false, 'now taken');
  const dup = await api('POST', '/auth/register', null, { credential: 'secret-123', personalId: id.toUpperCase() });
  assert.strictEqual(dup.status, 409);
  const inv = await api('POST', '/auth/register', null, { credential: 'secret-123', personalId: 'no spaces allowed' });
  assert.strictEqual(inv.status, 400);
  const login = await api('POST', '/auth/login', null, { personalId: id.toLowerCase(), credential: 'secret-123' });
  assert.strictEqual(login.status, 200, 'the chosen ID is the login ID');
});

test('id-suggestions: three distinct, valid, available IDs', async () => {
  const s = (await api('GET', '/auth/id-suggestions')).body.suggestions;
  assert.strictEqual(new Set(s).size, 3);
  for (const id of s) assert.strictEqual((await api('GET', '/auth/id-available?id=' + id)).body.available, true);
});

test('display name: defaults to the Indie ID, can be changed, validated', async () => {
  const u = await seeded();
  const me = (await api('GET', '/auth/me', u.token)).body;
  assert.strictEqual(me.displayName, u.personalId);
  assert.strictEqual((await api('PATCH', '/auth/me', u.token, { displayName: '  ' })).status, 400);
  const upd = await api('PATCH', '/auth/me', u.token, { displayName: 'Clips' });
  assert.strictEqual(upd.body.displayName, 'Clips');
  assert.strictEqual((await api('GET', '/auth/me', u.token)).body.displayName, 'Clips');
});

// ---------------- Groups ----------------
test('seeded account has real groups (kind=group) with members, listed alongside people', async () => {
  const u = await seeded();
  const list = (await api('GET', '/contacts', u.token)).body;
  const team = list.find((c) => c.name === 'Team Marketing');
  assert.strictEqual(team.kind, 'group');
  assert.strictEqual(team.memberCount, 3, '2 members + you');
  assert.deepStrictEqual(team.members.map((m) => m.name).sort(), ['Alex Rahman', 'Sarah Putri']);
  assert.ok(list.filter((c) => c.kind === 'person').length >= 2);
  const msgs = (await api('GET', `/contacts/${team.id}/messages`, u.token)).body;
  assert.ok(msgs.some((m) => m.from === 'Alex Rahman'), 'group messages carry the sender name');
});

test('create group: validates name and members (own people contacts only, never agents/foreign ids)', async () => {
  const u = await seeded(), other = await seeded();
  const people = (await api('GET', '/contacts', u.token)).body.filter((c) => c.kind === 'person');
  const foreign = (await api('GET', '/contacts', other.token)).body[0];
  const agent = (await api('GET', '/agents', u.token)).body[0];
  assert.strictEqual((await api('POST', '/groups', u.token, { name: '  ' })).status, 400);
  assert.strictEqual((await api('POST', '/groups', u.token, { name: 'X', memberIds: [foreign.id] })).status, 400, "someone else's contact");
  assert.strictEqual((await api('POST', '/groups', u.token, { name: 'X', memberIds: [agent.id] })).status, 400, 'an agent');
  assert.strictEqual((await api('POST', '/groups', u.token, { name: 'X', visibility: 'secret' })).status, 400);
  const ok = await api('POST', '/groups', u.token, { name: 'QA Squad', description: 'Testing', visibility: 'public', allowNewMembers: false, memberIds: [people[0].id, people[0].id] });
  assert.strictEqual(ok.status, 201);
  assert.deepStrictEqual([ok.body.kind, ok.body.visibility, ok.body.allowNewMembers, ok.body.memberCount], ['group', 'public', false, 2], 'duplicate member id counted once');
  const msgs = (await api('GET', `/contacts/${ok.body.id}/messages`, u.token)).body;
  assert.strictEqual(msgs[0].kind, 'system'); assert.match(msgs[0].text, /QA Squad/);
});

test('members: add (dups skipped, system message), remove, list; isolation from other accounts', async () => {
  const u = await seeded(), other = await seeded();
  const people = (await api('GET', '/contacts', u.token)).body.filter((c) => c.kind === 'person');
  const g = (await api('POST', '/groups', u.token, { name: 'Crew', memberIds: [people[0].id] })).body;
  const add = await api('POST', `/groups/${g.id}/members`, u.token, { contactIds: [people[0].id, people[1].id] });
  assert.strictEqual(add.body.memberCount, 3, 'only the new member was added');
  const msgs = (await api('GET', `/contacts/${g.id}/messages`, u.token)).body;
  assert.strictEqual(msgs.filter((m) => m.kind === 'system' && /joined/.test(m.text)).length, 1);
  assert.strictEqual((await api('GET', `/groups/${g.id}/members`, u.token)).body.length, 2);
  const rm = await api('DELETE', `/groups/${g.id}/members/${people[0].id}`, u.token);
  assert.strictEqual(rm.body.memberCount, 2);
  assert.strictEqual((await api('DELETE', `/groups/${g.id}/members/${people[0].id}`, u.token)).status, 404, 'already removed');
  assert.strictEqual((await api('GET', `/groups/${g.id}/members`, other.token)).status, 404);
  assert.strictEqual((await api('POST', `/groups/${g.id}/members`, other.token, { contactIds: [] })).status, 404);
});

test('group chat: a member replies (simulated) with their name; PATCH edits description/visibility; DELETE = leave', async () => {
  const u = await seeded();
  const g = (await api('GET', '/contacts', u.token)).body.find((c) => c.name === 'Team Marketing');
  await api('POST', `/contacts/${g.id}/messages`, u.token, { text: 'hello team' });
  await sleep(2700);
  const msgs = (await api('GET', `/contacts/${g.id}/messages`, u.token)).body;
  const reply = msgs[msgs.length - 1];
  assert.strictEqual(reply.sender, 'contact');
  assert.ok(['Alex Rahman', 'Sarah Putri'].includes(reply.from), 'reply is attributed to a member: ' + reply.from);
  const p = await api('PATCH', `/contacts/${g.id}`, u.token, { description: 'New desc', visibility: 'public', name: 'Marketing HQ' });
  assert.deepStrictEqual([p.body.description, p.body.visibility, p.body.name], ['New desc', 'public', 'Marketing HQ']);
  assert.strictEqual((await api('PATCH', `/contacts/${g.id}`, u.token, { visibility: 'nope' })).status, 400);
  assert.strictEqual((await api('DELETE', `/contacts/${g.id}`, u.token)).status, 200);
  assert.ok(!(await api('GET', '/contacts', u.token)).body.some((c) => c.id === g.id), 'group gone after leaving');
});

test('deleting a person removes them from every group', async () => {
  const u = await seeded();
  const list = (await api('GET', '/contacts', u.token)).body;
  const alex = list.find((c) => c.name === 'Alex Rahman'), team = list.find((c) => c.name === 'Team Marketing');
  await api('DELETE', `/contacts/${alex.id}`, u.token);
  assert.deepStrictEqual((await api('GET', `/groups/${team.id}/members`, u.token)).body.map((m) => m.name), ['Sarah Putri']);
});

// ---------------- Agents, search ----------------
test('agents list carries lastMessage for the unified Messages list', async () => {
  const u = await seeded();
  const agents = (await api('GET', '/agents', u.token)).body;
  const research = agents.find((a) => a.name === 'Research Agent');
  assert.ok(research.lastMessage && research.lastMessage.text.length > 0);
  assert.ok(agents.find((a) => a.name === 'Personal Assistant'));
});

test('search: scoped to the account, matches snippets (not JSON keys), case-insensitive, filterable by scope', async () => {
  const u = await seeded(), other = await seeded();
  const r = (await api('GET', '/search?q=REPORT', u.token)).body;
  assert.ok(r.messages.some((m) => /Campaign-Report/.test(m.message.snippet) && m.room.type === 'contact'), 'file name in a person chat');
  assert.ok(r.messages.some((m) => m.room.type === 'agent'), 'agent card/result');
  assert.ok(r.messages.some((m) => m.room.type === 'group'), 'file name in a group chat');
  assert.strictEqual((await api('GET', '/search?q=payload_json', u.token)).body.messages.length, 0, 'JSON internals are not searchable');
  const k = (await api('GET', '/search?q=alex&scope=contacts', u.token)).body;
  assert.deepStrictEqual([k.contacts.length, k.messages.length, k.groups.length], [1, 0, 0]);
  assert.strictEqual((await api('GET', '/search?q=marketing&scope=groups', u.token)).body.groups[0].name, 'Team Marketing');
  assert.ok((await api('GET', '/search?q=research&scope=agents', u.token)).body.agents.length >= 1);
  const empty = (await api('GET', '/search?q=', u.token)).body;
  assert.deepStrictEqual(Object.values(empty).map((a) => a.length), [0, 0, 0, 0]);
  const unseeded = await api('POST', '/auth/register', null, { credential: 'secret-123' });
  assert.strictEqual((await api('GET', '/search?q=report', unseeded.body.token)).body.messages.length, 0, 'nothing leaks across accounts');
  assert.ok(other.token);
  assert.strictEqual((await api('GET', '/search?q=x')).status, 401);
});

test('search: deleted messages are never returned', async () => {
  const u = await seeded();
  const alex = (await api('GET', '/contacts', u.token)).body.find((c) => c.name === 'Alex Rahman');
  const sent = (await api('POST', `/contacts/${alex.id}/messages`, u.token, { text: 'zebra-unique-token' })).body;
  assert.strictEqual((await api('GET', '/search?q=zebra-unique', u.token)).body.messages.length, 1);
  await api('DELETE', `/contacts/${alex.id}/messages/${sent.id}`, u.token);
  assert.strictEqual((await api('GET', '/search?q=zebra-unique', u.token)).body.messages.length, 0);
});

// ---------------- Vault ----------------
test('vault notes: create/list/delete with validation and isolation; memories come from agents', async () => {
  const u = await seeded(), other = await seeded();
  assert.strictEqual((await api('POST', '/vault/notes', u.token, { title: ' ' })).status, 400);
  const n = (await api('POST', '/vault/notes', u.token, { title: 'Campaign ideas', body: 'short videos' })).body;
  assert.strictEqual((await api('GET', '/vault/notes', u.token)).body[0].title, 'Campaign ideas');
  assert.strictEqual((await api('GET', '/vault/notes', other.token)).body.length, 0);
  assert.strictEqual((await api('DELETE', `/vault/notes/${n.id}`, other.token)).status, 404);
  assert.strictEqual((await api('DELETE', `/vault/notes/${n.id}`, u.token)).status, 200);
  const mem = (await api('GET', '/vault/memories', u.token)).body;
  assert.ok(mem.length >= 1 && mem[0].agentName && mem[0].note);
});

test('share: format is validated and echoed; nothing but selected fields leaves', async () => {
  const u = await seeded();
  const out = (await api('GET', '/vault/outputs', u.token)).body[0];
  assert.strictEqual((await api('POST', `/vault/outputs/${out.id}/share`, u.token, { include: { report: true }, format: 'carrier-pigeon' })).status, 400);
  const ok = await api('POST', `/vault/outputs/${out.id}/share`, u.token, { recipient: 'Sarah', format: 'LINK', include: { report: true } });
  assert.strictEqual(ok.body.format, 'link');
  assert.deepStrictEqual(Object.keys(ok.body.shared), ['summary']);
  const dflt = await api('POST', `/vault/outputs/${out.id}/share`, u.token, { include: { aiSummary: true } });
  assert.strictEqual(dflt.body.format, 'pdf', 'default format');
});

// ---------------- Cancel a running workflow ----------------
test('cancel execution: stops a run paused at approval, cancels open nodes, closes the approval; guards apply', async () => {
  const u = await seeded(), other = await seeded();
  const wf = (await api('GET', '/workflows', u.token)).body.find((w) => /Marketing/i.test(w.name)) || (await api('GET', '/workflows', u.token)).body[0];
  const run = await api('POST', `/workflows/${wf.id}/run`, u.token);
  assert.ok(run.body.executionId, JSON.stringify(run.body));
  const exId = run.body.executionId;
  // not cancellable by someone else
  assert.strictEqual((await api('POST', `/workflows/executions/${exId}/cancel`, other.token)).status, 404);
  let state = '';
  for (let i = 0; i < 40 && state !== 'waitingApproval'; i++) { await sleep(300); state = (await api('GET', `/workflows/${wf.id}/executions`, u.token)).body.find((e) => e.id === exId).state; }
  assert.strictEqual(state, 'waitingApproval');
  assert.strictEqual((await api('GET', '/consent/approvals', u.token)).body.some((a) => a.workflowId === wf.id || a.workflow_id === wf.id), true, 'an approval is open');
  const c = await api('POST', `/workflows/executions/${exId}/cancel`, u.token);
  assert.strictEqual(c.status, 200);
  const after = (await api('GET', `/workflows/${wf.id}/executions`, u.token)).body.find((e) => e.id === exId);
  assert.strictEqual(after.state, 'cancelled');
  const nodes = (await api('GET', `/workflows/${wf.id}`, u.token)).body.nodes;
  assert.ok(nodes.some((n) => n.state === 'cancelled'), 'unfinished nodes cancelled');
  assert.ok(nodes.some((n) => n.state === 'success'), 'finished nodes keep their result');
  assert.strictEqual((await api('GET', '/consent/approvals', u.token)).body.filter((a) => (a.workflowId || a.workflow_id) === wf.id && !a.resolved).length, 0, 'approval closed');
  assert.strictEqual((await api('POST', `/workflows/executions/${exId}/cancel`, u.token)).status, 409, 'cannot cancel twice');
  await sleep(1200);
  assert.strictEqual((await api('GET', `/workflows/${wf.id}/executions`, u.token)).body.find((e) => e.id === exId).state, 'cancelled', 'stays cancelled — no zombie timers resume it');
});

test('orchestrator: "plan my day" is handled by the Personal Assistant, not the generic research+finance plan', async () => {
  const u = await seeded();
  const sent = await api('POST', '/orchestrator/messages', u.token, { text: 'Plan my day from my calendar' });
  assert.ok(sent.status < 300, JSON.stringify(sent.body));
  await sleep(4500);
  const thread = JSON.stringify((await api('GET', '/orchestrator/messages', u.token)).body);
  assert.match(thread, /Personal Assistant/);
  assert.match(thread, /Prepared your day/);
  assert.doesNotMatch(thread, /Finance Agent/, 'no generic finance step');
});
