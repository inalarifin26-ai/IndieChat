// Flags `.member` accesses and named arguments whose name is neither declared in lib/ nor used by the baseline commit.
// Baseline = the pre-redesign Flutter code; everything it used is treated as already-reviewed API surface.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const root = process.argv[2], base = process.argv[3];
const strip = s => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '').replace(/r?'''[\s\S]*?'''|r?"""[\s\S]*?"""/g, '""').replace(/'(?:\\.|[^'\\\n])*'/g, "''").replace(/"(?:\\.|[^"\\\n])*"/g, '""');
const walk = d => fs.readdirSync(d).flatMap(f => { const p = path.join(d, f); return fs.statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') ? [p] : []; });
const accesses = s => { const out = []; for (const m of strip(s).matchAll(/(?:\.|\?\.)\s*([a-z_]\w*)/g)) out.push(m[1]); for (const m of strip(s).matchAll(/[(,]\s*([a-z_]\w*)\s*:(?!:)/g)) out.push(m[1]); return out; };
const declared = s => { const out = new Set(), c = strip(s);
  for (const m of c.matchAll(/\bthis\.([a-zA-Z_]\w*)/g)) out.add(m[1]);
  for (const m of c.matchAll(/\b(?:get|set)\s+([a-zA-Z_]\w*)/g)) out.add(m[1]);
  for (const m of c.matchAll(/(?:^|[;{}\s])(?:static\s+|final\s+|const\s+|late\s+|required\s+)*[A-Za-z_][\w<>?,.\[\]\s]*?\s+([a-zA-Z_]\w*)\s*(?=[=;(,)])/gm)) out.add(m[1]);
  for (const m of c.matchAll(/\b(?:required|final)\s+[\w<>?.,\[\] ]+\s+([a-zA-Z_]\w*)\b/g)) out.add(m[1]);
  for (const m of c.matchAll(/\b([a-zA-Z_]\w*)\s*:\s*(?:[A-Z]|\()/g)) out.add(m[1]);   // enum-ish / map keys; harmless over-approximation
  for (const m of c.matchAll(/^\s*([a-zA-Z_]\w*)\s*[,;]?\s*$/gm)) out.add(m[1]);       // enum values on their own line
  for (const m of c.matchAll(/enum\s+\w+\s*\{([^}]*)\}/g)) m[1].split(',').forEach(x => { const n = x.trim().split(/\s/)[0]; if (n) out.add(n); });
  return out; };
const known = new Set();
for (const f of cp.execSync(`git ls-tree -r --full-name --name-only ${base}`, { encoding: 'utf8', cwd: root }).split('\n').filter(f => f.startsWith('indie_app/lib') && f.endsWith('.dart'))) {
  const s = cp.execSync(`git show ${base}:${f}`, { encoding: 'utf8', cwd: root, maxBuffer: 1e8 }); accesses(s).forEach(x => known.add(x)); declared(s).forEach(x => known.add(x)); }
const where = new Map();
for (const f of walk(path.join(root, 'indie_app/lib'))) { const s = fs.readFileSync(f, 'utf8'); declared(s).forEach(x => known.add(x)); for (const a of accesses(s)) if (!where.has(a)) where.set(a, f.replace(root + '/indie_app/lib/', '')); }
const unknown = [...where.keys()].filter(a => !known.has(a)).sort();
console.log(unknown.length + ' unfamiliar member/argument names:\n' + unknown.map(a => `  ${a}  (${where.get(a)})`).join('\n'));
