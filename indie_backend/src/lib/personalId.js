const crypto = require('node:crypto');
const { WORDS } = require('./mnemonic');

function generatePersonalId() {
  const a = WORDS[crypto.randomInt(0, WORDS.length)];
  const b = WORDS[crypto.randomInt(0, WORDS.length)];
  const n = crypto.randomInt(10, 99);
  return `${a}.${b}${n}`;
}

const RESERVED = ['admin', 'administrator', 'indie', 'support', 'root', 'system', 'orchestrator', 'moderator'];
const ID_RE = /^[a-z0-9_.]{3,24}$/;

/** Normalizes (trim + lowercase) and validates a user-chosen Indie ID. */
function validateChosenId(raw) {
  const id = String(raw == null ? '' : raw).trim().toLowerCase();
  if (!ID_RE.test(id)) return { ok: false, id, reason: 'Use 3-24 letters, numbers, dots or underscores' };
  if (RESERVED.includes(id)) return { ok: false, id, reason: 'This ID is reserved' };
  return { ok: true, id };
}

const ADJ = ['creative', 'digital', 'focus', 'bright', 'quiet', 'swift', 'calm', 'bold'];
const NOUN = ['mind', 'nomad', 'life', 'spark', 'river', 'pixel', 'orbit', 'ember'];

/** n distinct readable suggestions; `isTaken(id)` filters ones already in use. */
function suggestIds(n, isTaken) {
  const out = [];
  let guard = 0;
  while (out.length < n && guard++ < 200) {
    const s = `${ADJ[crypto.randomInt(0, ADJ.length)]}_${NOUN[crypto.randomInt(0, NOUN.length)]}`;
    if (!out.includes(s) && !isTaken(s)) out.push(s);
  }
  return out;
}

module.exports = { generatePersonalId, validateChosenId, suggestIds };
