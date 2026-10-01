const bip39 = require('bip39');

/**
 * Generates a real BIP-39 recovery phrase: 12 words, 128 bits of entropy,
 * with the standard checksum word baked in (bip39.generateMnemonic checks
 * entropy via crypto.randomBytes under the hood). Interoperable with any
 * other BIP-39 implementation — unlike the earlier uniform-random-word MVP
 * version, a phrase from here can be validated independently.
 */
function generateRecoveryPhrase(wordCount = 12) {
  const bitsPerWord = 11;
  const checksumBits = wordCount / 3;
  const entropyBits = wordCount * bitsPerWord - checksumBits;
  return bip39.generateMnemonic(entropyBits);
}

function normalizePhrase(phrase) {
  return bip39.default ? phrase : phrase.trim().toLowerCase().split(/\s+/).join(' ');
}

function isValidPhrase(phrase) {
  return bip39.validateMnemonic(normalizePhrase(phrase));
}

const WORDS = bip39.wordlists.english;

module.exports = { generateRecoveryPhrase, normalizePhrase, isValidPhrase, WORDS };
