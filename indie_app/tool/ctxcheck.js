// Crude scan for `use_build_context_synchronously`: BuildContext used within a few lines after an `await`
// without an intervening `mounted` / `ctx.mounted` / `context.mounted` check.
const fs = require('fs'), path = require('path');
const walk = d => fs.readdirSync(d).flatMap(f => { const p = path.join(d, f); return fs.statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') ? [p] : []; });
let n = 0;
for (const f of walk(process.argv[2])) { const L = fs.readFileSync(f, 'utf8').split('\n');
  for (let i = 0; i < L.length; i++) { if (!/\bawait\b/.test(L[i]) || /^\s*\/\//.test(L[i])) continue;
    for (let j = i + 1; j < Math.min(L.length, i + 7); j++) {
      if (/mounted/.test(L[j])) break; if (/^\s*}\s*$/.test(L[j]) && /^\s{0,4}}/.test(L[j])) { }
      if (/\b(context|ctx)\b\s*[.,)]|\(context\)|Navigator\.of\(|ScaffoldMessenger\.of\(|context\.(read|watch)/.test(L[j]) && !/\(BuildContext|builder:|\(context\)\s*=>\s*$|Future<|showModal|showDialog/.test(L[j])) { console.log(`${path.relative(process.argv[2], f)}:${j + 1}: ${L[j].trim().slice(0, 100)}   (await at ${i + 1})`); n++; break; } } } }
console.log(n + ' candidate(s)');
