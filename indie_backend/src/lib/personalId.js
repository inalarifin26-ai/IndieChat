const crypto = require('node:crypto');
const { WORDS } = require('./mnemonic');

function generatePersonalId() {
  const a = WORDS[crypto.randomInt(0, WORDS.length)];
  const b = WORDS[crypto.randomInt(0, WORDS.length)];
  const n = crypto.randomInt(10, 99);
  return `${a}.${b}${n}`;
}

module.exports = { generatePersonalId };
