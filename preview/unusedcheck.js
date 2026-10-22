// Heuristic for two common `flutter analyze` warnings: unused_import and unused private members.
const fs = require('fs'), path = require('path');
const strip = s => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '').replace(/\s\/\/.*$/gm, '');
const walk = d => fs.readdirSync(d).flatMap(f => { const p = path.join(d, f); return fs.statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') ? [p] : []; });
const root = process.argv[2], files = walk(root);
const declsOf = src => { const out = new Set(); const s = strip(src);
  for (const m of s.matchAll(/^(?:abstract\s+|final\s+|base\s+|sealed\s+)*(?:class|enum|mixin|typedef|extension)\s+([A-Za-z_]\w*)/gm)) out.add(m[1]);
  for (const m of s.matchAll(/^(?:const\s+|final\s+|late\s+)?(?:[A-Za-z_][\w<>?,\s]*?\s+)?([a-zA-Z_]\w*)\s*(?:=|\()/gm)) if (!/^(if|for|while|switch|return|import|export|part|void|class)$/.test(m[1])) out.add(m[1]);
  return out; };
const PKG = { 'package:provider/provider.dart': /\b(Provider|ChangeNotifierProvider|MultiProvider|Consumer|context\.(read|watch|select)|\.read<|\.watch<)/, 'package:intl/intl.dart': /\b(DateFormat|NumberFormat|Intl)\b/, 'package:flutter/services.dart': /\b(Clipboard|ClipboardData|SystemUiOverlayStyle|SystemChrome|HapticFeedback|TextInputFormatter|FilteringTextInputFormatter|SystemMouseCursors)\b/,
  'dart:async': /\b(Timer|StreamSubscription|Completer|StreamController|unawaited|Stream)\b/, 'dart:convert': /\b(jsonEncode|jsonDecode|utf8|base64|JsonEncoder|LineSplitter)\b/, 'dart:math': /\b(Random|pi|min|max|sqrt|pow|sin|cos)\b/, 'package:url_launcher/url_launcher.dart': /\b(launchUrl|canLaunchUrl|LaunchMode)\b/,
  'package:shared_preferences/shared_preferences.dart': /\bSharedPreferences\b/, 'package:http/http.dart': /\bhttp\.|\bClient\b/, 'package:flutter/foundation.dart': /\b(ChangeNotifier|kDebugMode|debugPrint|ValueNotifier|VoidCallback|immutable|listEquals|kIsWeb)\b/,
  'package:speech_to_text/speech_to_text.dart': /\bSpeechToText\b/, 'package:speech_to_text/speech_recognition_result.dart': /\bSpeechRecognitionResult\b/, 'package:speech_to_text/speech_recognition_error.dart': /\bSpeechRecognitionError\b/ };
let issues = 0;
for (const f of files) {
  const raw = fs.readFileSync(f, 'utf8'), code = strip(raw), body = code.replace(/^\s*(import|export|part)\s.*$/gm, '');
  for (const m of code.matchAll(/^import\s+'([^']+)'(?:\s+as\s+\w+)?(?:\s+show\s+([^;]+))?(?:\s+hide\s+[^;]+)?;/gm)) {
    const spec = m[1], show = m[2] ? m[2].split(',').map(x => x.trim()) : null;
    if (spec.startsWith('.') || spec.startsWith('../')) {
      const t = path.resolve(path.dirname(f), spec); if (!fs.existsSync(t)) { console.log(`${f}: import of missing file ${spec}`); issues++; continue; }
      const names = show || [...declsOf(fs.readFileSync(t, 'utf8'))];
      if (!names.some(n => new RegExp('\\b' + n + '\\b').test(body))) { console.log(`${path.relative(root, f)}: unused import '${spec}'`); issues++; }
    } else if (PKG[spec] && !PKG[spec].test(body)) { console.log(`${path.relative(root, f)}: unused import '${spec}'`); issues++; }
  }
  const priv = new Map();
  for (const m of body.matchAll(/\b(_[a-zA-Z]\w*)\b/g)) priv.set(m[1], (priv.get(m[1]) || 0) + 1);
  for (const [n, c] of priv) if (c === 1) { console.log(`${path.relative(root, f)}: private '${n}' appears only once (unused?)`); issues++; }
}
console.log(issues ? `${issues} possible issue(s)` : 'no unused imports / private members found');
