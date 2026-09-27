const crypto = require('node:crypto');

const KEY_LEN = 64;

function hashSecret(secret) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(secret, salt, KEY_LEN).toString('hex');
  return { hash, salt };
}

function verifySecret(secret, hash, salt) {
  const candidate = crypto.scryptSync(secret, salt, KEY_LEN);
  const stored = Buffer.from(hash, 'hex');
  if (candidate.length !== stored.length) return false;
  return crypto.timingSafeEqual(candidate, stored);
}

module.exports = { hashSecret, verifySecret };
