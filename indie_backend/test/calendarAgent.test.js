// Personal Assistant's "Read your calendar" workflow step calls the real
// Google Calendar connector through the Permission Gateway.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-calagent.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.CONNECTOR_ENC_KEY = 'test-connector-enc-key';
delete process.env.ANTHROPIC_API_KEY;

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/agents', require('../src/routes/agents'));
app.use('/connectors', require('../src/routes/connectors'));

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
async function newSeededUser() {
  const r = await api('POST', '/auth/register', null, { credential: 'cal-agent-' + Math.random(), seedDemo: true });
  return r.body;
}
function withGoogleEnv(fn) {
  return async (...args) => {
    process.env.GOOGLE_CLIENT_ID = 'test-client-id';
    process.env.GOOGLE_CLIENT_SECRET = 'test-client-secret';
    process.env.GOOGLE_REDIRECT_URI = 'http://localhost/connectors/google_calendar/callback';
    try {
      await fn(...args);
    } finally {
      delete process.env.GOOGLE_CLIENT_ID;
      delete process.env.GOOGLE_CLIENT_SECRET;
      delete process.env.GOOGLE_REDIRECT_URI;
    }
  };
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
});
test.after(async () => {
  await new Promise((r) => server.close(r));
  for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} }
});

test('seed data includes a Personal Assistant with a calendar workflow step', async () => {
  const user = await newSeededUser();
  const agents = (await api('GET', '/agents', user.token)).body;
  const pa = agents.find((a) => a.name === 'Personal Assistant');
  assert.ok(pa, 'Personal Assistant agent exists');
  assert.ok(pa.workflow.some((s) => /calendar/i.test(s)), 'has a calendar step: ' + JSON.stringify(pa.workflow));
});

test('asking to check the calendar without connecting it first -> friendly NOT_CONNECTED reply', async () => {
  const user = await newSeededUser();
  const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');
  const sent = await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'can you check my calendar for today?' });
  assert.strictEqual(sent.body.scope, 'in_scope');
  await sleep(1000);
  const msgs = (await api('GET', `/agents/${pa.id}/messages`, user.token)).body;
  const reply = msgs[msgs.length - 1];
  assert.match(reply.text, /can't reach your calendar/i);
  assert.match(reply.text, /Connectors/);
});

test(
  'with Google Calendar connected, the agent replies with real events via the Permission Gateway',
  withGoogleEnv(async () => {
    const user = await newSeededUser();
    const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');

    const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
    const state = new URL(authorize.body.url).searchParams.get('state');
    const realFetch = global.fetch;
    global.fetch = async (url, opts) => {
      const u = String(url);
      if (u.includes('oauth2.googleapis.com/token')) {
        return { ok: true, json: async () => ({ access_token: 'cal-token', refresh_token: 'cal-refresh', expires_in: 3600 }) };
      }
      return realFetch(url, opts);
    };
    try {
      const cb = await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
      assert.strictEqual(cb.status, 200);
    } finally {
      global.fetch = realFetch;
    }

    global.fetch = async (url, opts) => {
      const u = String(url);
      if (u.includes('calendar/v3/calendars/primary/events')) {
        assert.strictEqual(opts.headers.Authorization, 'Bearer cal-token');
        return {
          ok: true,
          json: async () => ({
            items: [
              { id: '1', summary: 'Design review', start: { dateTime: '2026-03-01T10:00:00Z' }, end: { dateTime: '2026-03-01T10:30:00Z' } },
              { id: '2', summary: 'Dentist', start: { date: '2026-03-02' }, end: { date: '2026-03-02' } },
            ],
          }),
        };
      }
      return realFetch(url, opts);
    };
    try {
      const sent = await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'please read my calendar for upcoming events' });
      assert.strictEqual(sent.body.scope, 'in_scope');
      await sleep(1000);
      const msgs = (await api('GET', `/agents/${pa.id}/messages`, user.token)).body;
      const card = msgs.find((m) => m.kind === 'card');
      assert.ok(card, 'agent replied with a card of real events');
      assert.strictEqual(card.payload.card.title, 'Upcoming calendar events');
      assert.ok(card.payload.card.insights.some((i) => i.includes('Design review')));
      assert.ok(card.payload.card.insights.some((i) => i.includes('Dentist')));
    } finally {
      global.fetch = realFetch;
    }
  })
);

test('a request outside the Personal Assistant workflow is still refused (scope enforcement unaffected by the connector)', async () => {
  const user = await newSeededUser();
  const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');
  const sent = await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'book me a flight to Tokyo' });
  assert.strictEqual(sent.body.scope, 'out_of_scope');
});
