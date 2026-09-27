const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const WORDS = fs
  .readFileSync(path.join(__dirname, 'bip39-english.txt'), 'utf8')
  .split('\n')
  .map((w) => w.trim())
  .filter(Boolean);

/**
 * Generates a 12-word recovery phrase drawn uniformly at random from the
 * standard BIP-39 English wordlist (2048 words -> ~11 bits/word, 132 bits
 * total). This is a simplified generator for the MVP: it does NOT implement
 * full BIP-39 (no checksum word derived from entropy), so phrases here are
 * not interchangeable with a real BIP-39/HD-wallet implementation. Swap in
 * a proper `bip39` library before using this for anything beyond the demo.
 */
function generateRecoveryPhrase(wordCount = 12) {
  const words = [];
  for (let i = 0; i < wordCount; i++) {
    const idx = crypto.randomInt(0, WORDS.length);
    words.push(WORDS[idx]);
  }
  return words.join(' ');
}

function normalizePhrase(phrase) {
  return phrase.trim().toLowerCase().split(/\s+/).join(' ');
}

module.exports = { generateRecoveryPhrase, normalizePhrase, WORDS };
