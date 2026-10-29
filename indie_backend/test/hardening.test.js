// Security hardening: rate limits (forced on for this file), headers, error handling, length caps.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

process.env.DB_PATH = path.join(__dirname, '.tmp-hardening.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';
process.env.RATE_LIMIT_FORCE = '1'; // limiters are normally off inside `node --test`
process.env.RL_LOGIN_MAX = '4';
process.env.RL_RECOVER_MAX = '3';
process.env.RL_REGISTER_MAX = '6';
process.env.RL_LOOKUP_MAX = '5';
delete process.env.ANTHROPIC_API_KEY;

const { createLimiter } = require('../src/middleware/rateLimit');
const { tooLong } = require('../src/middleware/security');
const app = require('../src/app');

let server, base;
async function api(method, url, token, body, raw) {
  const res = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: raw !== undefined ? raw : body ? JSON.stringify(body) : undefined });
  let json = null; try { json = await res.json(); } catch {}
  return { status: res.status, body: json, headers: res.headers };
}
const x = (n) => 'x'.repeat(n);

test.before(async () => { await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); }); });
test.after(async () => { await new Promise((r) => server.close(r)); for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} } });

test('every response carries the security headers; the framework banner is gone', async () => {
  const r = await api('GET', '/health');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.headers.get('x-content-type-options'), 'nosniff');
  assert.strictEqual(r.headers.get('x-frame-options'), 'DENY');
  assert.strictEqual(r.headers.get('referrer-policy'), 'no-referrer');
  assert.strictEqual(r.headers.get('cache-control'), 'no-store');
  assert.strictEqual(r.headers.get('x-powered-by'), null);
});

test('malformed JSON is a 400 and an oversized body a 413 (not a 500)', async () => {
  const bad = await api('POST', '/auth/login', null, null, '{not json');
  assert.strictEqual(bad.status, 400); assert.match(bad.body.error, /Malformed/);
  const big = await api('POST', '/auth/login', null, null, JSON.stringify({ personalId: 'a', credential: x(300_000) }));
  assert.strictEqual(big.status, 413);
});

test('login: failed attempts are throttled per account, a correct login still works before the limit, others are unaffected', async () => {
  const reg = await api('POST', '/auth/register', null, { credential: 'right-password' });
  const id = reg.body.personalId;
  // a successful login does not use up the allowance
  for (let i = 0; i < 6; i++) assert.strictEqual((await api('POST', '/auth/login', null, { personalId: id, credential: 'right-password' })).status, 200);
  // 4 failures allowed, the 5th is throttled
  for (let i = 0; i < 4; i++) assert.strictEqual((await api('POST', '/auth/login', null, { personalId: id, credential: 'wrong' + i })).status, 401);
  const blocked = await api('POST', '/auth/login', null, { personalId: id, credential: 'wrong-again' });
  assert.strictEqual(blocked.status, 429);
  assert.ok(Number(blocked.headers.get('retry-after')) >= 1, 'Retry-After header');
  assert.ok(blocked.body.retryAfterSeconds >= 1);
  assert.strictEqual((await api('POST', '/auth/login', null, { personalId: id, credential: 'right-password' })).status, 429, 'blocked even with the right password until the window passes');
  // a different account from the same client has its own allowance
  const other = await api('POST', '/auth/register', null, { credential: 'other-password' });
  assert.strictEqual((await api('POST', '/auth/login', null, { personalId: other.body.personalId, credential: 'wrong' })).status, 401);
  assert.strictEqual((await api('POST', '/auth/login', null, { personalId: other.body.personalId, credential: 'other-password' })).status, 200);
});

test('recovery attempts are throttled too (guessing a recovery phrase is the sharper attack)', async () => {
  const reg = await api('POST', '/auth/register', null, { credential: 'recover-test-1' });
  const id = reg.body.personalId;
  const guess = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  for (let i = 0; i < 3; i++) assert.strictEqual((await api('POST', '/auth/recover', null, { personalId: id, recoveryPhrase: guess, newCredential: 'new-credential' })).status, 401);
  assert.strictEqual((await api('POST', '/auth/recover', null, { personalId: id, recoveryPhrase: reg.body.recoveryPhrase, newCredential: 'new-credential' })).status, 429, 'even the real phrase is refused during the lockout');
});

test('registration is limited per client; ID lookups are limited to curb enumeration', async () => {
  const results = [];
  for (let i = 0; i < 6; i++) results.push((await api('POST', '/auth/register', null, { credential: 'bulk-password-' + i })).status);
  assert.ok(results.includes(429), 'a burst of registrations is stopped: ' + results.join(','));
  const lookups = [];
  for (let i = 0; i < 8; i++) lookups.push((await api('GET', '/auth/id-available?id=probe_' + i)).status);
  assert.deepStrictEqual(lookups.slice(0, 5), [200, 200, 200, 200, 200]);
  assert.ok(lookups.slice(5).every((s) => s === 429), 'lookups beyond the limit are refused: ' + lookups.join(','));
});

test('createLimiter: window resets, skipSuccessful, and an explicit enabled flag overrides the test-run heuristic', async () => {
  const express = require('express');
  const a = express(); a.use(express.json());
  const lim = createLimiter({ windowMs: 400, max: 2, keyFn: () => 'k', enabled: true });
  a.get('/x', lim, (_q, r) => r.json({ ok: true }));
  const s = await new Promise((r) => { const sv = a.listen(0, () => r(sv)); });
  const url = `http://localhost:${s.address().port}/x`;
  assert.deepStrictEqual([(await fetch(url)).status, (await fetch(url)).status, (await fetch(url)).status], [200, 200, 429]);
  await new Promise((r) => setTimeout(r, 450));
  assert.strictEqual((await fetch(url)).status, 200, 'allowance returns after the window');
  lim.reset(); assert.strictEqual((await fetch(url)).status, 200);
  await new Promise((r) => s.close(r));
});

test('tooLong helper and credential cap', async () => {
  assert.strictEqual(tooLong('abc', 5, 'x'), null);
  assert.match(tooLong('abcdef', 5, 'Name'), /Name is too long \(max 5 characters\)/);
  assert.strictEqual(tooLong(undefined, 5, 'x'), null);
  const r = await api('POST', '/auth/login', null, { personalId: 'a', credential: x(201) });
  assert.strictEqual(r.status, 400, 'an over-long credential is rejected before any hashing work');
});
