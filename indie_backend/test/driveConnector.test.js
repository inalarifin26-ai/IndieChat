// Google Drive connector — third connector on the shared googleOAuthBase,
// proving the pattern generalizes cleanly. Google mocked throughout.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-drive.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.CONNECTOR_ENC_KEY = 'test-connector-enc-key';

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/connectors', require('../src/routes/connectors'));

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
  const r = await api('POST', '/auth/register', null, { credential: 'drive-test-' + Math.random() });
  return r.body;
}
function withGoogleEnv(fn) {
  return async (...args) => {
    process.env.GOOGLE_CLIENT_ID = 'test-client-id';
    process.env.GOOGLE_CLIENT_SECRET = 'test-client-secret';
    process.env.PUBLIC_BASE_URL = 'http://localhost';
    try {
      await fn(...args);
    } finally {
      delete process.env.GOOGLE_CLIENT_ID;
      delete process.env.GOOGLE_CLIENT_SECRET;
      delete process.env.PUBLIC_BASE_URL;
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

test('each connector derives its own distinct redirect_uri from PUBLIC_BASE_URL (regression guard — they must never share one)', withGoogleEnv(async () => {
  const user = await newUser();
  const cal = await api('GET', '/connectors/google_calendar/authorize', user.token);
  const gm = await api('GET', '/connectors/gmail/authorize', user.token);
  const dr = await api('GET', '/connectors/google_drive/authorize', user.token);
  const redirect = (url) => new URL(url).searchParams.get('redirect_uri');
  assert.strictEqual(redirect(cal.body.url), 'http://localhost/connectors/google_calendar/callback');
  assert.strictEqual(redirect(gm.body.url), 'http://localhost/connectors/gmail/callback');
  assert.strictEqual(redirect(dr.body.url), 'http://localhost/connectors/google_drive/callback');
  const all = [redirect(cal.body.url), redirect(gm.body.url), redirect(dr.body.url)];
  assert.strictEqual(new Set(all).size, 3, 'all three redirect_uri values must be distinct');
}));

test('GET /connectors lists all three providers independently', async () => {
  const user = await newUser();
  const providers = (await api('GET', '/connectors', user.token)).body.map((c) => c.provider).sort();
  assert.deepStrictEqual(providers, ['gmail', 'google_calendar', 'google_drive']);
});

test('authorize URL requests the metadata-readonly scope (least privilege — no file contents)', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_drive/authorize', user.token);
  assert.match(authorize.body.url, /scope=.*drive\.metadata\.readonly/);
}));

test('lists recent files via the Permission Gateway, mapping Drive\'s response shape', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_drive/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ access_token: 'drive-token', refresh_token: 'drive-refresh', expires_in: 3600 }) };
    }
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_drive/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }

  global.fetch = async (url, opts) => {
    const u = String(url);
    if (u.includes('googleapis.com/drive/v3/files')) {
      assert.strictEqual(opts.headers.Authorization, 'Bearer drive-token');
      assert.match(u, /orderBy=modifiedTime\+desc|orderBy=modifiedTime%20desc/);
      return {
        ok: true,
        json: async () => ({
          files: [
            { id: 'f1', name: 'Q3 Report.pdf', mimeType: 'application/pdf', modifiedTime: '2026-01-05T10:00:00Z', webViewLink: 'https://drive.google.com/f1' },
          ],
        }),
      };
    }
    return realFetch(url, opts);
  };
  try {
    const res = await api('GET', '/connectors/google_drive/files', user.token);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body[0].name, 'Q3 Report.pdf');
    assert.strictEqual(res.body[0].link, 'https://drive.google.com/f1');
  } finally {
    global.fetch = realFetch;
  }
}));

test('not connected -> 409 NOT_CONNECTED, same as the other two connectors', async () => {
  const user = await newUser();
  const res = await api('GET', '/connectors/google_drive/files', user.token);
  assert.strictEqual(res.status, 409);
  assert.strictEqual(res.body.code, 'NOT_CONNECTED');
});

test('three connectors, three independent states: connecting Drive touches neither Calendar nor Gmail', withGoogleEnv(async () => {
  const user = await newUser();
  const authorize = await api('GET', '/connectors/google_drive/authorize', user.token);
  const state = new URL(authorize.body.url).searchParams.get('state');
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('oauth2.googleapis.com/token')) return { ok: true, json: async () => ({ access_token: 'tok', expires_in: 3600 }) };
    return realFetch(url, opts);
  };
  try {
    await api('GET', `/connectors/google_drive/callback?state=${state}&code=abc`, null);
  } finally {
    global.fetch = realFetch;
  }
  const list = (await api('GET', '/connectors', user.token)).body;
  const byProvider = Object.fromEntries(list.map((c) => [c.provider, c.connected]));
  assert.deepStrictEqual(byProvider, { google_calendar: false, gmail: false, google_drive: true });
}));
