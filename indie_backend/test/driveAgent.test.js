// Finance Agent's "Read invoices" step uses the real Google Drive connector (metadata only), through the
// Permission Gateway. Google is mocked.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-driveagent.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.CONNECTOR_ENC_KEY = 'test-connector-enc-key';
delete process.env.ANTHROPIC_API_KEY;

const app = require('../src/app');
const { escapeQ } = require('../src/lib/connectors/googleDrive');
let server, base;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(method, url, token, body) {
  const res = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let json = null; try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}
async function seeded() { return (await api('POST', '/auth/register', null, { credential: 'drive-agent-' + Math.random(), seedDemo: true })).body; }
const finance = async (u) => (await api('GET', '/agents', u.token)).body.find((a) => a.name === 'Finance Agent');
const lastMsg = async (u, a) => { const m = (await api('GET', `/agents/${a.id}/messages`, u.token)).body; return m[m.length - 1]; };

async function connectDrive(user) {
  process.env.GOOGLE_CLIENT_ID = 'cid'; process.env.GOOGLE_CLIENT_SECRET = 'sec'; process.env.PUBLIC_BASE_URL = 'http://localhost';
  const auth = await api('GET', '/connectors/google_drive/authorize', user.token);
  const state = new URL(auth.body.url).searchParams.get('state');
  const real = global.fetch;
  global.fetch = async (url, opts) => String(url).includes('oauth2.googleapis.com/token') ? { ok: true, json: async () => ({ access_token: 'drive-tok', refresh_token: 'r', expires_in: 3600 }) } : real(url, opts);
  try { assert.strictEqual((await api('GET', `/connectors/google_drive/callback?state=${state}&code=abc`, null)).status, 200); } finally { global.fetch = real; }
}
const cleanEnv = () => { delete process.env.GOOGLE_CLIENT_ID; delete process.env.GOOGLE_CLIENT_SECRET; delete process.env.PUBLIC_BASE_URL; };

test.before(async () => { await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); }); });
test.after(async () => { cleanEnv(); await new Promise((r) => server.close(r)); for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} } });

test('Drive not connected -> friendly message pointing to Connectors', async () => {
  const u = await seeded(), a = await finance(u);
  const sent = await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'please read my invoices' });
  assert.strictEqual(sent.body.scope, 'in_scope');
  await sleep(1100);
  const m = await lastMsg(u, a);
  assert.match(m.text, /can't reach your Google Drive/); assert.match(m.text, /Connectors/);
});

test('connected: the agent lists real invoice files (query is scoped to "invoice", metadata fields only)', async () => {
  const u = await seeded(), a = await finance(u);
  await connectDrive(u);
  const real = global.fetch; let seen;
  global.fetch = async (url, opts) => {
    if (String(url).includes('googleapis.com/drive/v3/files')) {
      seen = { url: new URL(String(url)), auth: opts.headers.Authorization };
      return { ok: true, json: async () => ({ files: [{ id: '1', name: 'Invoice 2026-001.pdf', modifiedTime: '2026-01-05T10:00:00Z' }, { id: '2', name: 'invoice-acme.xlsx', modifiedTime: '2026-01-02T08:00:00Z' }] }) };
    }
    return real(url, opts);
  };
  try {
    await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'read my invoices' });
    await sleep(1100);
  } finally { global.fetch = real; }
  assert.strictEqual(seen.auth, 'Bearer drive-tok');
  assert.match(seen.url.searchParams.get('q'), /name contains 'invoice' and trashed = false/);
  assert.strictEqual(seen.url.searchParams.get('fields'), 'files(id,name,mimeType,modifiedTime,webViewLink)', 'no file contents are ever requested');
  const m = await lastMsg(u, a);
  assert.strictEqual(m.kind, 'card'); assert.strictEqual(m.payload.card.title, 'Invoice files in your Drive');
  assert.ok(m.payload.card.insights[0].includes('Invoice 2026-001.pdf') && m.payload.card.insights[1].includes('invoice-acme.xlsx'));
  cleanEnv();
});

test('connected but nothing matches -> a plain "no files" message', async () => {
  const u = await seeded(), a = await finance(u);
  await connectDrive(u);
  const real = global.fetch;
  global.fetch = async (url, opts) => String(url).includes('googleapis.com/drive/v3/files') ? { ok: true, json: async () => ({ files: [] }) } : real(url, opts);
  try { await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'read invoices' }); await sleep(1100); } finally { global.fetch = real; }
  assert.match((await lastMsg(u, a)).text, /no files with "invoice"/);
  cleanEnv();
});

test('Drive API failure is reported without crashing; scope enforcement and other steps are unchanged', async () => {
  const u = await seeded(), a = await finance(u);
  await connectDrive(u);
  const real = global.fetch;
  global.fetch = async (url, opts) => String(url).includes('googleapis.com/drive/v3/files') ? { ok: false, status: 403, text: async () => 'forbidden' } : real(url, opts);
  try { await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'read invoices' }); await sleep(1100); } finally { global.fetch = real; }
  assert.match((await lastMsg(u, a)).text, /can't reach your Google Drive/);
  cleanEnv();
  // still refuses anything outside the workflow
  assert.strictEqual((await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'book me a flight' })).body.scope, 'out_of_scope');
  // another step of the same agent keeps its ordinary behaviour (no Drive call)
  const fetchCalls = []; const r2 = global.fetch;
  global.fetch = async (url, opts) => { fetchCalls.push(String(url)); return r2(url, opts); };
  try { await api('POST', `/agents/${a.id}/messages`, u.token, { text: 'calculate the weekly cash flow' }); await sleep(1100); } finally { global.fetch = r2; }
  assert.ok(!fetchCalls.some((u2) => u2.includes('googleapis.com')), 'no Google call for a non-invoice step');
  assert.match((await lastMsg(u, a)).text, /part of my workflow/);
});

test('raw endpoint: ?nameContains is applied; quotes and backslashes cannot break out of the Drive query', async () => {
  const u = await seeded();
  await connectDrive(u);
  const real = global.fetch; const qs = [];
  global.fetch = async (url, opts) => { if (String(url).includes('googleapis.com/drive/v3/files')) { qs.push(new URL(String(url)).searchParams.get('q')); return { ok: true, json: async () => ({ files: [] }) }; } return real(url, opts); };
  try {
    await api('GET', `/connectors/google_drive/files?nameContains=${encodeURIComponent("x' or name contains '")}`, u.token);
    await api('GET', '/connectors/google_drive/files', u.token);
  } finally { global.fetch = real; cleanEnv(); }
  assert.strictEqual(qs[0], "name contains 'x\\' or name contains \\'' and trashed = false", 'the injected quotes are escaped: ' + qs[0]);
  assert.strictEqual(qs[1], 'trashed = false', 'no filter when none is given');
  assert.strictEqual(escapeQ("o'brien\\x"), "o\\'brien\\\\x");
});
