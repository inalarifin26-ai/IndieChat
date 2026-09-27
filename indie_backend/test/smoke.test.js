// Minimal smoke tests using Node's built-in test runner + fetch.
// Run with: npm test  (starts nothing — assumes the server is NOT running;
// this file spins up the app in-process against a throwaway DB file).
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-test.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.PORT = '0'; // ephemeral port

const express = require('express');
const cors = require('cors');
const authRoutes = require('../src/routes/auth');
const workflowsRoutes = require('../src/routes/workflows');
const consentRoutes = require('../src/routes/consent');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/auth', authRoutes);
app.use('/workflows', workflowsRoutes);
app.use('/consent', consentRoutes);

let server;
let baseUrl;

test.before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      baseUrl = `http://localhost:${server.address().port}`;
      resolve();
    });
  });
});

test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
  if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
});

test('register -> returns personalId, recoveryPhrase, token', async () => {
  const res = await fetch(`${baseUrl}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ credential: 'a-valid-credential' }),
  });
  assert.strictEqual(res.status, 201);
  const body = await res.json();
  assert.ok(body.personalId);
  assert.strictEqual(body.recoveryPhrase.split(' ').length, 12);
  assert.ok(body.token);
});

test('workflow isolation: a second user cannot read the first user\'s workflow', async () => {
  const reg1 = await (
    await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential: 'user-one-credential' }),
    })
  ).json();

  const wf = await (
    await fetch(`${baseUrl}/workflows`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${reg1.token}` },
      body: JSON.stringify({ name: 'Private flow' }),
    })
  ).json();

  const reg2 = await (
    await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential: 'user-two-credential' }),
    })
  ).json();

  const res = await fetch(`${baseUrl}/workflows/${wf.id}`, {
    headers: { Authorization: `Bearer ${reg2.token}` },
  });
  assert.strictEqual(res.status, 404);
});

test('validate flags a node with no incoming connection', async () => {
  const reg = await (
    await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential: 'validate-flow-credential' }),
    })
  ).json();
  const auth = { Authorization: `Bearer ${reg.token}`, 'Content-Type': 'application/json' };

  const wf = await (
    await fetch(`${baseUrl}/workflows`, { method: 'POST', headers: auth, body: JSON.stringify({ name: 'V' }) })
  ).json();

  await fetch(`${baseUrl}/workflows/${wf.id}/nodes`, {
    method: 'POST',
    headers: auth,
    body: JSON.stringify({ category: 'ai', title: 'Orphan node' }),
  });

  const validation = await (
    await fetch(`${baseUrl}/workflows/${wf.id}/validate`, { method: 'POST', headers: auth })
  ).json();
  assert.strictEqual(validation.valid, false);
  assert.ok(validation.issues.some((i) => i.includes('Orphan node')));
});
