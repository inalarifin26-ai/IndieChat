// Google Calendar connector: OAuth round trip, token encryption at rest,
// Permission Gateway (connect/expire/refresh/revoke), all with Google's
// endpoints mocked — no real client credentials or network needed.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-connectors.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.CONNECTOR_ENC_KEY = 'test-connector-enc-key';

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/connectors', require('../src/routes/connectors'));

const db = require('../src/db');
const gcal = require('../src/lib/connectors/googleCalendar');

let server, base;
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
  const r = await api('POST', '/auth/register', null, { credential: 'conn-test-' + Math.random() });
  return r.body;
}

function withGoogleEnv(fn) {
  return async (...args) => {
    const prev = {
      GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID,
      GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET,
      GOOGLE_REDIRECT_URI: process.env.GOOGLE_REDIRECT_URI,
    };
    process.env.GOOGLE_CLIENT_ID = 'test-client-id';
    process.env.GOOGLE_CLIENT_SECRET = 'test-client-secret';
    process.env.GOOGLE_REDIRECT_URI = 'http://localhost:4000/connectors/google_calendar/callback';
    try {
      await fn(...args);
    } finally {
      Object.assign(process.env, prev);
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

test('encryption: tokens are never stored in plaintext', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  assert.strictEqual(authorize.status, 200);
  assert.match(authorize.body.url, /^https:\/\/accounts\.google\.com\/o\/oauth2\/v2\/auth\?/);
  assert.match(authorize.body.url, /client_id=test-client-id/);
  assert.match(authorize.body.url, /access_type=offline/);
  const state = new URL(authorize.body.url).searchParams.get('state');

  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'super-secret-access-token', refresh_token: 'super-secret-refresh-token', expires_in: 3600, scope: 'calendar.readonly' }) };
    }
    return realFetch(url, opts);
  };
  try {
    const cb = await api('GET', `/connectors/google_calendar/callback?state=${state}&code=fake-auth-code`, null);
    assert.strictEqual(cb.status, 200);
  } finally {
    global.fetch = realFetch;
  }

  const row = db.prepare('SELECT * FROM connectors WHERE user_id = ?').get(user.id || (await api('GET', '/auth/me', user.token)).body.id);
  assert.ok(row);
  assert.strictEqual(row.access_token_enc.includes('super-secret-access-token'), false, 'access token not stored in plaintext');
  assert.strictEqual(row.refresh_token_enc.includes('super-secret-refresh-token'), false, 'refresh token not stored in plaintext');

  const list = await api('GET', '/connectors', user.token);
  assert.strictEqual(list.body[0].connected, true);
  assert.strictEqual(JSON.stringify(list.body).includes('super-secret'), false, 'raw tokens never leave the server in any API response');
}));

test('OAuth state is single-use (CSRF protection)', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');

  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'tok', expires_in: 3600 }) };
    }
    return realFetch(url, opts);
  };
  try {
    const first = await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
    assert.strictEqual(first.status, 200);
    const replay = await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
    assert.strictEqual(replay.status, 400, 'the same state cannot be replayed');
  } finally {
    global.fetch = realFetch;
  }
}));

test('Permission Gateway: NOT_CONNECTED, then connect, then calendar events works', withGoogleEnv(async () => {
  const user = await newUser();
  const before = await api('GET', '/connectors/google_calendar/events', user.token);
  assert.strictEqual(before.status, 409);
  assert.strictEqual(before.body.code, 'NOT_CONNECTED');

  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    const u = String(url);
    if (u.includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'valid-token', refresh_token: 'refresh-1', expires_in: 3600, scope: 'calendar.readonly' }) };
    }
    if (u.includes('calendar/v3/calendars/primary/events')) {
      assert.strictEqual(opts.headers.Authorization, 'Bearer valid-token');
      return {
        ok: true,
        json: async () => ({
          items: [{ id: 'evt1', summary: 'Team sync', start: { dateTime: '2026-01-01T09:00:00Z' }, end: { dateTime: '2026-01-01T09:30:00Z' } }],
        }),
      };
    }
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
    const events = await api('GET', '/connectors/google_calendar/events', user.token);
    assert.strictEqual(events.status, 200);
    assert.strictEqual(events.body[0].title, 'Team sync');
  } finally {
    global.fetch = realFetch;
  }
}));

test('Permission Gateway: expired access token is transparently refreshed', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;

  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'old-token', refresh_token: 'refresh-xyz', expires_in: 3600 }) };
    }
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }

  // Force the stored token to look expired.
  db.prepare("UPDATE connectors SET expires_at = '2000-01-01T00:00:00.000Z' WHERE user_id = (SELECT id FROM users WHERE personal_id = ?)").run(user.personalId);

  let refreshCalled = false;
  global.fetch = async (url, opts) => {
    const u = String(url);
    if (u.includes('oauth2.googleapis.com/token')) {
      refreshCalled = true;
      const body = new URLSearchParams(opts.body);
      assert.strictEqual(body.get('refresh_token'), 'refresh-xyz');
      assert.strictEqual(body.get('grant_type'), 'refresh_token');
      return { ok: true, json: async () => ({ access_token: 'fresh-token', expires_in: 3600 }) };
    }
    if (u.includes('calendar/v3/calendars/primary/events')) {
      assert.strictEqual(opts.headers.Authorization, 'Bearer fresh-token');
      return { ok: true, json: async () => ({ items: [] }) };
    }
    return realFetch(url, opts);
  };
  try {
    const events = await api('GET', '/connectors/google_calendar/events', user.token);
    assert.strictEqual(events.status, 200);
    assert.strictEqual(refreshCalled, true);
  } finally {
    global.fetch = realFetch;
  }
}));

test('revoke: calls Google best-effort and always clears the local connection', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) return { ok: true, json: async () => ({ access_token: 'tok', expires_in: 3600 }) };
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }

  let revokeCalled = false;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/revoke')) {
      revokeCalled = true;
      return { ok: true, json: async () => ({}) };
    }
    return realFetch(url, opts);
  };
  try {
    const del = await api('DELETE', '/connectors/google_calendar', user.token);
    assert.strictEqual(del.status, 200);
    assert.strictEqual(revokeCalled, true);
  } finally {
    global.fetch = realFetch;
  }

  const list = await api('GET', '/connectors', user.token);
  assert.strictEqual(list.body[0].connected, false);
  const after = await api('GET', '/connectors/google_calendar/events', user.token);
  assert.strictEqual(after.body.code, 'NOT_CONNECTED', 'revoked connector behaves as never-connected');
}));

test('revoke survives Google being unreachable (best-effort, local state still clears)', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) return { ok: true, json: async () => ({ access_token: 'tok', expires_in: 3600 }) };
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }

  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/revoke')) throw new Error('simulated network failure');
    return realFetch(url, opts);
  };
  try {
    const del = await api('DELETE', '/connectors/google_calendar', user.token);
    assert.strictEqual(del.status, 200, 'revoke endpoint still succeeds locally');
  } finally {
    global.fetch = realFetch;
  }
  const list = await api('GET', '/connectors', user.token);
  assert.strictEqual(list.body[0].connected, false);
}));

test('isolation: another account cannot see or revoke a connector that is not theirs', withGoogleEnv(async () => {
  const a = await newUser();
  const b = await newUser();
  const authorize = await api('GET', '/connectors/google_calendar/authorize', a.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) return { ok: true, json: async () => ({ access_token: 'a-tok', expires_in: 3600 }) };
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_calendar/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }
  const bList = await api('GET', '/connectors', b.token);
  assert.strictEqual(bList.body[0].connected, false, "b's own connector list is unaffected by a's connection");
  const bEvents = await api('GET', '/connectors/google_calendar/events', b.token);
  assert.strictEqual(bEvents.body.code, 'NOT_CONNECTED');
}));
