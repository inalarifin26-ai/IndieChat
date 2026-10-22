const fs = require('fs'), path = require('path');
const { Parser, Language } = require('web-tree-sitter');
(async () => {
  await Parser.init();
  const lang = await Language.load(require.resolve('tree-sitter-wasms/out/tree-sitter-dart.wasm'));
  const parser = new Parser(); parser.setLanguage(lang);
  const files = [];
  (function walk(d){ for (const f of fs.readdirSync(d)) { const p = path.join(d,f); fs.statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') && files.push(p); } })(process.argv[2]);
  let bad = 0;
  for (const f of files) {
    const src = fs.readFileSync(f,'utf8'); const tree = parser.parse(src); const errs = [];
    (function visit(n){ if (n.isError || n.isMissing) errs.push(n); for (const c of n.children) visit(c); })(tree.rootNode);
    if (errs.length) { bad++; const e = errs[0]; console.log(`SYNTAX ERROR ${f}:${e.startPosition.row+1}:${e.startPosition.column+1} near: ${src.split('\n')[e.startPosition.row].trim().slice(0,100)}`); }
  }
  console.log(`${files.length} files checked, ${bad} with syntax errors`);
})();
