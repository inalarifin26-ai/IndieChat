// Input length caps. Separate from hardening.test.js on purpose: that file forces the rate limiters on,
// and its registration burst would otherwise leave this client without an account to test with.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-caps.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
delete process.env.ANTHROPIC_API_KEY;

const app = require('../src/app');
let server, base, token, person, agent;
const x = (n) => 'x'.repeat(n);
async function api(method, url, body) {
  const res = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let json = null; try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
  const reg = await api('POST', '/auth/register', { credential: 'caps-password', seedDemo: true });
  assert.strictEqual(reg.status, 201, 'setup must succeed — no early exits in this file: ' + JSON.stringify(reg.body));
  token = reg.body.token;
  person = (await api('GET', '/contacts')).body.find((c) => c.kind === 'person');
  agent = (await api('GET', '/agents')).body[0];
});
test.after(async () => { await new Promise((r) => server.close(r)); for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} } });

test('chat messages: 4000 characters is fine, 4001 is rejected — in person chats and agent chats', async () => {
  assert.strictEqual((await api('POST', `/contacts/${person.id}/messages`, { text: x(4000) })).status, 201);
  const over = await api('POST', `/contacts/${person.id}/messages`, { text: x(4001) });
  assert.strictEqual(over.status, 400); assert.match(JSON.stringify(over.body), /too long/);
  assert.strictEqual((await api('POST', `/agents/${agent.id}/messages`, { text: x(4001) })).status, 400);
  assert.strictEqual((await api('POST', `/contacts/${person.id}/messages`, { kind: 'file', payload: { file: { name: x(201), size: '1 KB' } } })).status, 400, 'file names are capped too');
});

test('contacts and groups: names, info, descriptions and member lists are capped', async () => {
  assert.strictEqual((await api('POST', '/contacts', { name: x(81), info: 'a@b.c' })).status, 400);
  assert.strictEqual((await api('POST', '/contacts', { name: 'Ok', info: x(121) })).status, 400);
  assert.strictEqual((await api('POST', '/contacts', { name: x(80), info: x(120) })).status, 201, 'the limits themselves are allowed');
  assert.strictEqual((await api('PATCH', `/contacts/${person.id}`, { name: x(81) })).status, 400);
  assert.strictEqual((await api('POST', '/groups', { name: x(81) })).status, 400);
  assert.strictEqual((await api('POST', '/groups', { name: 'Ok', description: x(501) })).status, 400);
  assert.strictEqual((await api('POST', '/groups', { name: 'Ok', memberIds: Array(201).fill(person.id) })).status, 400);
  assert.strictEqual((await api('POST', '/groups', { name: x(80), description: x(500) })).status, 201);
});

test('orchestrator instructions are capped at 1000 characters', async () => {
  assert.strictEqual((await api('POST', '/orchestrator/messages', { text: x(1001) })).status, 400);
  assert.ok((await api('POST', '/orchestrator/messages', { text: 'Create an agent to ' + x(900) })).status < 300);
});

test('credentials: over-long ones are refused at registration and login', async () => {
  assert.strictEqual((await api('POST', '/auth/register', { credential: x(201) })).status, 400);
  assert.strictEqual((await api('POST', '/auth/login', { personalId: 'someone', credential: x(201) })).status, 400);
});
