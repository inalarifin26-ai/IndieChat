const express = require('express');
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { hashSecret, verifySecret } = require('../lib/secret');
const { generateRecoveryPhrase, normalizePhrase, isValidPhrase } = require('../lib/mnemonic');
const { generatePersonalId } = require('../lib/personalId');
const { JWT_SECRET, requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const { seedDemoData } = require('../lib/seedDemoData');

const router = express.Router();

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

function issueSession(userId) {
  const jti = crypto.randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
  db.prepare(
    'INSERT INTO sessions (id, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)'
  ).run(jti, userId, now.toISOString(), expiresAt.toISOString());
  const token = jwt.sign({ sub: userId, jti }, JWT_SECRET, { expiresIn: '30d' });
  return token;
}

/**
 * POST /auth/register
 * Creates a new Personal ID. A local device credential is set by the
 * client (never sent as a traditional "password" over the wire long-term —
 * this MVP still takes it as a request body field for simplicity; a real
 * client should derive it from a device-bound secret / biometric unlock).
 * The recovery phrase is generated server-side, returned exactly ONCE, and
 * only its scrypt hash is ever persisted — see spec §13 & §15.
 */
router.post('/register', (req, res) => {
  const { credential, seedDemo } = req.body || {};
  if (!credential || String(credential).length < 6) {
    return res.status(400).json({ error: 'credential must be at least 6 characters' });
  }

  let personalId = generatePersonalId();
  let attempts = 0;
  while (db.prepare('SELECT 1 FROM users WHERE personal_id = ?').get(personalId) && attempts < 5) {
    personalId = generatePersonalId();
    attempts++;
  }

  const recoveryPhrase = generateRecoveryPhrase(12);
  const { hash: credentialHash, salt: credentialSalt } = hashSecret(credential);
  const { hash: recoveryHash, salt: recoverySalt } = hashSecret(normalizePhrase(recoveryPhrase));

  const userId = crypto.randomUUID();
  db.prepare(
    `INSERT INTO users (id, personal_id, credential_hash, credential_salt, recovery_hash, recovery_salt, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(userId, personalId, credentialHash, credentialSalt, recoveryHash, recoverySalt, new Date().toISOString());

  logAudit(userId, 'account_registered', `personal_id=${personalId}`);

  if (seedDemo) {
    seedDemoData(userId);
    logAudit(userId, 'demo_data_seeded');
  }

  const token = issueSession(userId);

  // recoveryPhrase is returned exactly once — the server never stores or
  // logs the raw phrase again after this response.
  res.status(201).json({
    personalId,
    recoveryPhrase,
    token,
    warning:
      'Save this recovery phrase now — it will not be shown again and losing it may make account recovery impossible.',
  });
});

/**
 * POST /auth/login  { personalId, credential }
 */
router.post('/login', (req, res) => {
  const { personalId, credential } = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE personal_id = ?').get(personalId);
  if (!user || !verifySecret(credential || '', user.credential_hash, user.credential_salt)) {
    return res.status(401).json({ error: 'Invalid Personal ID or credential' });
  }
  const token = issueSession(user.id);
  logAudit(user.id, 'session_login', 'via local credential');
  res.json({ token, personalId: user.personal_id });
});

/**
 * POST /auth/recover  { personalId, recoveryPhrase, newCredential }
 * Separate from normal session auth, per spec §13/§15: proving the recovery
 * phrase lets the user set a new local credential without ever exposing or
 * re-deriving the stored one.
 */
router.post('/recover', (req, res) => {
  const { personalId, recoveryPhrase, newCredential } = req.body || {};
  if (!newCredential || String(newCredential).length < 6) {
    return res.status(400).json({ error: 'newCredential must be at least 6 characters' });
  }
  // Reject a malformed phrase before even touching the DB (defense in
  // depth — the scrypt hash comparison below is the real check).
  if (!recoveryPhrase || !isValidPhrase(String(recoveryPhrase))) {
    return res.status(401).json({ error: 'Invalid Personal ID or recovery phrase' });
  }
  const user = db.prepare('SELECT * FROM users WHERE personal_id = ?').get(personalId);
  if (!user || !verifySecret(normalizePhrase(recoveryPhrase || ''), user.recovery_hash, user.recovery_salt)) {
    return res.status(401).json({ error: 'Invalid Personal ID or recovery phrase' });
  }
  const { hash, salt } = hashSecret(newCredential);
  db.prepare('UPDATE users SET credential_hash = ?, credential_salt = ? WHERE id = ?').run(hash, salt, user.id);
  // Revoke all existing sessions on recovery — a stolen device shouldn't
  // stay logged in after the owner recovers the account.
  db.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').run(
    new Date().toISOString(),
    user.id
  );
  logAudit(user.id, 'account_recovered', 'credential reset via recovery phrase; prior sessions revoked');
  const token = issueSession(user.id);
  res.json({ token, personalId: user.personal_id });
});

router.post('/logout', requireAuth, (req, res) => {
  db.prepare('UPDATE sessions SET revoked_at = ? WHERE id = ?').run(new Date().toISOString(), req.sessionId);
  logAudit(req.userId, 'session_logout');
  res.json({ ok: true });
});

router.get('/me', requireAuth, (req, res) => {
  const user = db.prepare('SELECT id, personal_id, created_at FROM users WHERE id = ?').get(req.userId);
  res.json({ id: user.id, personalId: user.personal_id, createdAt: user.created_at });
});

module.exports = router;
