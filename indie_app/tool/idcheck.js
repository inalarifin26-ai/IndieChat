// Flags capitalized identifiers that are neither defined in lib/ nor already used by the baseline (git HEAD) code.
// Catches typos / renamed-but-not-updated class names that a syntax-only check cannot see.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const root = process.argv[2];
const strip = s => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '').replace(/r?'''[\s\S]*?'''|r?"""[\s\S]*?"""/g, '""').replace(/'(?:\\.|[^'\\\n])*'/g, "''").replace(/"(?:\\.|[^"\\\n])*"/g, '""');
const idsOf = s => new Set((strip(s).match(/\b[A-Z][A-Za-z0-9_]*\b/g) || []));
const defsOf = s => new Set([...strip(s).matchAll(/\b(?:class|enum|mixin|typedef|extension)\s+([A-Za-z_][A-Za-z0-9_]*)/g)].map(m => m[1]));
const walk = d => fs.readdirSync(d).flatMap(f => { const p = path.join(d, f); return fs.statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') ? [p] : []; });
const files = walk(root);
const defined = new Set(); const used = new Map();
for (const f of files) { const s = fs.readFileSync(f, 'utf8'); defsOf(s).forEach(d => defined.add(d)); idsOf(s).forEach(i => { if (!used.has(i)) used.set(i, []); used.get(i).push(f.replace(root + '/', '')); }); }
const baseline = new Set();
try {
  const list = cp.execSync(`git -C ${root} ls-tree -r --full-name --name-only HEAD`, { encoding: 'utf8' }).split('\n').filter(f => f.endsWith('.dart') && f.includes('indie_app/lib'));
  for (const f of list) { const s = cp.execSync(`git -C ${root} show HEAD:${f}`, { encoding: 'utf8', maxBuffer: 1e8 }); idsOf(s).forEach(i => baseline.add(i)); defsOf(s).forEach(i => baseline.add(i)); }
} catch (e) { console.log('no baseline:', String(e).slice(0, 100)); }
const consts = /^[A-Z][A-Z0-9_]+$/; // SCREAMING_CASE constants
const unknown = [...used.keys()].filter(i => !defined.has(i) && !baseline.has(i) && !consts.test(i)).sort();
console.log(unknown.length ? 'NEW external identifiers to verify by hand:\n' + unknown.map(i => `  ${i}  (${used.get(i).slice(0, 2).join(', ')})`).join('\n') : 'all identifiers are defined or baseline-known');
