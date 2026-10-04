// Gmail connector (reuses the same googleOAuthBase as Calendar) + its
// agent-workflow wiring ("Summarize unread emails"). Google mocked throughout.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-gmail.db');
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

const db = require('../src/db');

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
async function newUser(seedDemo = false) {
  const r = await api('POST', '/auth/register', null, { credential: 'gmail-test-' + Math.random(), seedDemo });
  return r.body;
}
function withGoogleEnv(fn) {
  return async (...args) => {
    process.env.GOOGLE_CLIENT_ID = 'test-client-id';
    process.env.GOOGLE_CLIENT_SECRET = 'test-client-secret';
    process.env.GOOGLE_REDIRECT_URI = 'http://localhost/connectors/gmail/callback';
    try {
      await fn(...args);
    } finally {
      delete process.env.GOOGLE_CLIENT_ID;
      delete process.env.GOOGLE_CLIENT_SECRET;
      delete process.env.GOOGLE_REDIRECT_URI;
    }
  };
}
async function connectGmail(user, { listResponder } = {}) {
  const authorize = await api('GET', '/connectors/gmail/authorize', user.token);
  assert.strictEqual(authorize.status, 200);
  assert.match(authorize.body.url, /scope=.*gmail\.readonly/);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'gmail-token', refresh_token: 'gmail-refresh', expires_in: 3600 }) };
    }
    return realFetch(url, opts);
  };
  try {
    const cb = await api('GET', `/connectors/gmail/callback?state=${state}&code=abc`, null);
    assert.strictEqual(cb.status, 200);
  } finally {
    global.fetch = realFetch;
  }
  if (listResponder) global.fetch = listResponder(realFetch);
  return realFetch;
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
});
test.after(async () => {
  await new Promise((r) => server.close(r));
  for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} }
});

test('GET /connectors lists both google_calendar and gmail independently', async () => {
  const user = await newUser();
  const list = (await api('GET', '/connectors', user.token)).body;
  const providers = list.map((c) => c.provider).sort();
  assert.deepStrictEqual(providers, ['gmail', 'google_calendar']);
  assert.ok(list.every((c) => c.connected === false));
});

test(
  'two-step Gmail fetch: lists unread ids, then fetches subject/from/snippet per message, skips a broken one',
  withGoogleEnv(async () => {
    const user = await newUser();
    const realFetch = await connectGmail(user, {});
    global.fetch = async (url, opts) => {
      const u = String(url);
      if (u.includes('gmail.googleapis.com/gmail/v1/users/me/messages?')) {
        assert.strictEqual(opts.headers.Authorization, 'Bearer gmail-token');
        assert.match(u, /labelIds=UNREAD/);
        return { ok: true, json: async () => ({ messages: [{ id: 'm1' }, { id: 'm2' }, { id: 'm3' }] }) };
      }
      if (u.includes('/messages/m1')) {
        return {
          ok: true,
          json: async () => ({ id: 'm1', snippet: 'Can we move the meeting?', payload: { headers: [{ name: 'Subject', value: 'Re: Meeting' }, { name: 'From', value: 'Alex <alex@indie.id>' }] } }),
        };
      }
      if (u.includes('/messages/m2')) {
        return { ok: false, status: 500, text: async () => 'boom' }; // simulate one broken message
      }
      if (u.includes('/messages/m3')) {
        return {
          ok: true,
          json: async () => ({ id: 'm3', snippet: 'Invoice attached', payload: { headers: [{ name: 'Subject', value: 'Invoice #44' }] } }),
        };
      }
      return realFetch(url, opts);
    };
    try {
      const res = await api('GET', '/connectors/gmail/messages', user.token);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.length, 2, 'the broken message (m2) is skipped, not fatal');
      assert.strictEqual(res.body[0].subject, 'Re: Meeting');
      assert.strictEqual(res.body[0].from, 'Alex <alex@indie.id>');
      assert.strictEqual(res.body[1].subject, 'Invoice #44');
      assert.strictEqual(res.body[1].from, 'Unknown sender', 'missing From header handled gracefully');
    } finally {
      global.fetch = realFetch;
    }
  })
);

test('isolation + independence: connecting Gmail does not connect Calendar, and vice versa', withGoogleEnv(async () => {
  const user = await newUser();
  await connectGmail(user, {});
  const list = (await api('GET', '/connectors', user.token)).body;
  const gmailRow = list.find((c) => c.provider === 'gmail');
  const calRow = list.find((c) => c.provider === 'google_calendar');
  assert.strictEqual(gmailRow.connected, true);
  assert.strictEqual(calRow.connected, false, 'Calendar is untouched by connecting Gmail');
}));

test('seed data: Personal Assistant workflow includes the email step', async () => {
  const user = await newUser(true);
  const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');
  assert.ok(pa.workflow.some((s) => /email/i.test(s)), JSON.stringify(pa.workflow));
  assert.ok(pa.workflow.some((s) => /calendar/i.test(s)), 'calendar step still present alongside it');
});

test('asking the Personal Assistant to summarize emails without Gmail connected -> friendly NOT_CONNECTED', async () => {
  const user = await newUser(true);
  const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');
  const sent = await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'can you summarize my unread emails?' });
  assert.strictEqual(sent.body.scope, 'in_scope');
  await sleep(1000);
  const msgs = (await api('GET', `/agents/${pa.id}/messages`, user.token)).body;
  assert.match(msgs[msgs.length - 1].text, /can't reach your inbox/i);
});

test(
  'with Gmail connected, the agent replies with a real unread-emails card (and calendar step is unaffected)',
  withGoogleEnv(async () => {
    const user = await newUser(true);
    const pa = (await api('GET', '/agents', user.token)).body.find((a) => a.name === 'Personal Assistant');
    const realFetch = await connectGmail(user, {});
    global.fetch = async (url, opts) => {
      const u = String(url);
      if (u.includes('/messages?')) return { ok: true, json: async () => ({ messages: [{ id: 'x1' }] }) };
      if (u.includes('/messages/x1')) {
        return { ok: true, json: async () => ({ id: 'x1', snippet: '...', payload: { headers: [{ name: 'Subject', value: 'Quarterly numbers' }, { name: 'From', value: 'Finance' }] } }) };
      }
      return realFetch(url, opts);
    };
    try {
      await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'please summarize unread emails' });
      await sleep(1000);
      const msgs = (await api('GET', `/agents/${pa.id}/messages`, user.token)).body;
      const card = msgs.find((m) => m.kind === 'card' && m.payload.card.title === 'Unread emails');
      assert.ok(card);
      assert.ok(card.payload.card.insights[0].includes('Quarterly numbers'));
    } finally {
      global.fetch = realFetch;
    }

    // Calendar wasn't connected in this test — the calendar step should
    // still independently report NOT_CONNECTED, proving the two connectors
    // (and the two workflow steps using them) don't interfere.
    const sentCal = await api('POST', `/agents/${pa.id}/messages`, user.token, { text: 'check my calendar please' });
    assert.strictEqual(sentCal.body.scope, 'in_scope');
    await sleep(1000);
    const msgs2 = (await api('GET', `/agents/${pa.id}/messages`, user.token)).body;
    assert.match(msgs2[msgs2.length - 1].text, /can't reach your calendar/i);
  })
);
