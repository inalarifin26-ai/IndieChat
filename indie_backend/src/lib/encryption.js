const crypto = require('node:crypto');

/**
 * Reversible encryption for connector tokens at rest (distinct from
 * lib/secret.js's one-way scrypt hashing, which is for credentials that are
 * only ever *verified*, never read back). AES-256-GCM: random IV per value,
 * auth tag checked on decrypt so tampering is detected, not silently
 * accepted.
 *
 * The key comes from CONNECTOR_ENC_KEY (any string; it's stretched to 32
 * bytes via scrypt with a fixed, non-secret salt — the secrecy lives in the
 * env var, not the salt). Falls back to a clearly-labeled insecure dev key
 * so the server still boots without extra setup, loudly warning once.
 */
let warned = false;
function keyBytes() {
  const secret = process.env.CONNECTOR_ENC_KEY;
  if (!secret) {
    if (!warned) {
      warned = true;
      console.warn(
        '[indie-backend] CONNECTOR_ENC_KEY is not set — using an insecure default to encrypt connector tokens. ' +
          'Set CONNECTOR_ENC_KEY in .env before storing any real connector credentials.'
      );
    }
  }
  return crypto.scryptSync(secret || 'insecure-dev-only-key-change-me', 'indie-connector-enc', 32);
}

function encrypt(plaintext) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', keyBytes(), iv);
  const enc = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString('base64');
}

function decrypt(blob) {
  const buf = Buffer.from(blob, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const enc = buf.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', keyBytes(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString('utf8');
}

module.exports = { encrypt, decrypt };
