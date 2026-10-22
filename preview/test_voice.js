// Voice input in the preview: parser unit cases + end-to-end flows against a fake SpeechRecognition.
const chromium = require('@sparticuz/chromium').default || require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
let pass = 0, fail = 0; const ok = (c, m) => { if (c) pass++; else { fail++; console.log('FAIL:', m); } };
const FAKE = `
  window.__srs = [];
  class FakeSR { constructor(){ __srs.push(this); this.started = false; this.stopped = false; }
    start(){ this.started = true; } stop(){ this.stopped = true; this.onend && this.onend(); } abort(){ this.onend && this.onend(); }
    emit(list){ this.onresult && this.onresult({ resultIndex: 0, results: list.map(x => Object.assign([{ transcript: x.t }], { isFinal: !!x.final })) }); }
    fail(err){ this.onerror && this.onerror({ error: err }); this.onend && this.onend(); } end(){ this.onend && this.onend(); } }
  window.SpeechRecognition = FakeSR; window.webkitSpeechRecognition = FakeSR;`;
(async () => {
  const browser = await puppeteer.launch({ args: [...chromium.args, '--no-sandbox'], executablePath: await chromium.executablePath(), headless: 'shell' });
  const open = async (init) => { const p = await browser.newPage(); await p.setViewport({ width: 390, height: 844 }); p._errs = []; p.on('pageerror', e => p._errs.push(String(e).slice(0, 160))); if (init) await p.evaluateOnNewDocument(init); await p.goto('file:///home/claude/work/indie/indie_preview.html', { waitUntil: 'load' }); await p.evaluate('signIn()'); return p; };
  const wait = ms => new Promise(r => setTimeout(r, ms));

  // ---- 1. pure parser ----
  let p = await open('');
  const parse = (t, hf) => p.evaluate((t, hf) => parseVoiceCommand(t, hf), t, hf);
  const cases = [
    ['buat laporan mingguan kirim', true, { text: 'buat laporan mingguan', send: true, clear: false }],
    ['Buat laporan mingguan, kirim.', true, { text: 'Buat laporan mingguan', send: true, clear: false }],
    ['create a weekly report send it', true, { text: 'create a weekly report', send: true, clear: false }],
    ['summarize my inbox send message', true, { text: 'summarize my inbox', send: true, clear: false }],
    ['kirim laporan ke Sarah', true, { text: 'kirim laporan ke Sarah', send: false, clear: false }],          // keyword not at the end
    ['tolong kirim', true, { text: 'tolong kirim', send: false, clear: false }],                           // too short to auto-send
    ['kirim', true, { text: 'kirim', send: false, clear: false }],
    ['I want to resend', true, { text: 'I want to resend', send: false, clear: false }],                   // "resend" is not "send"
    ['buat laporan mingguan kirim', false, { text: 'buat laporan mingguan kirim', send: false, clear: false }], // hands-free off: keyword is just text
    ['  batal. ', false, { text: '', send: false, clear: true }], ['Cancel', true, { text: '', send: false, clear: true }], ['hapus semua', false, { text: '', send: false, clear: true }],
    ['batalkan pesanan', false, { text: 'batalkan pesanan', send: false, clear: false }],
    ['', true, { text: '', send: false, clear: false }],
  ];
  for (const [t, hf, want] of cases) { const got = await parse(t, hf); ok(JSON.stringify(got) === JSON.stringify(want), `parse(${JSON.stringify(t)}, ${hf}) -> ${JSON.stringify(got)}`); }
  await p.close();

  // ---- 2. unsupported browser ----
  p = await open('delete window.SpeechRecognition; delete window.webkitSpeechRecognition;');
  await p.evaluate("openChat('p1')"); await wait(350);
  ok(await p.evaluate("$('#chComposer').classList.contains('has')") === false, 'empty composer shows the mic, not send');
  await p.click('#chMic'); await wait(150);
  ok((await p.evaluate("$('#toast').textContent")).includes('not supported'), 'unsupported browser explains itself'); ok(await p.evaluate("!$('#voiceSheet').classList.contains('open')"), 'no consent sheet when unsupported');
  await p.close();

  // ---- 3. consent first, then dictation (chat) ----
  p = await open(FAKE);
  await p.evaluate("openChat('p1')"); await wait(350);
  await p.click('#chMic'); await wait(200);
  ok(await p.evaluate("$('#voiceSheet').classList.contains('open')"), 'first use shows the consent sheet'); ok(await p.evaluate("__srs.length") === 0, 'nothing listens before consent');
  ok((await p.evaluate("$('#voiceSheet').textContent")).includes('never receives or stores audio'), 'sheet states the privacy facts');
  await p.click('#vOk'); await wait(200);
  ok(await p.evaluate("__srs.length") === 1 && await p.evaluate("__srs[0].started"), 'Allow microphone starts listening'); ok(await p.evaluate("__srs[0].lang") === 'id-ID', 'default language is Bahasa Indonesia');
  ok(await p.evaluate("$('#chMic').classList.contains('rec')"), 'mic shows the recording state'); ok(await p.evaluate("$('#chInput').placeholder") === 'Listening…', 'placeholder says Listening');
  await p.evaluate("__srs[0].emit([{t:'halo sarah'}])"); ok(await p.evaluate("$('#chInput').value") === 'halo sarah', 'interim words appear live');
  await p.evaluate("__srs[0].emit([{t:'halo sarah apa kabar kirim', final:true}])"); await wait(100);
  ok(await p.evaluate("$('#chInput').value") === 'halo sarah apa kabar kirim', 'hands-free OFF: the keyword is plain text');
  ok(await p.evaluate("!curChat.messages.some(m=>m.t==='halo sarah apa kabar kirim')"), 'nothing is sent without a tap'); ok(await p.evaluate("!$('#chMic').classList.contains('rec')"), 'recording state clears after the final result');
  await p.evaluate("$('#chInput').value='';voiceSync('chat')");

  // ---- 4. hands-free send via long-press settings ----
  await p.evaluate("vDown('chat')"); await wait(750); await p.evaluate("vUp()");
  ok(await p.evaluate("$('#voiceSheet').classList.contains('open')"), 'long-press opens voice settings');
  await p.evaluate("vDraft('handsFree', true); vDraft('lang','en-US')"); await p.click('#vOk'); await wait(150);
  ok(await p.evaluate("VS.handsFree===true && VS.lang==='en-US'"), 'settings saved'); ok(await p.evaluate("__srs.length") === 1, 'saving settings does not start listening');
  await p.evaluate("voiceToggle('chat')"); await wait(80); // (long-press click suppressed once, then real tap)
  await p.evaluate("voiceToggle('chat')"); await wait(80);
  const n = await p.evaluate("__srs.length"); ok(n === 2 && await p.evaluate("__srs[1].lang") === 'en-US', 'next dictation uses the chosen language');
  await p.evaluate("__srs[1].emit([{t:'see you at three', final:true}])"); await wait(100); ok(await p.evaluate("$('#chInput').value") === 'see you at three', 'plain dictation stays in the box');
  await p.evaluate("$('#chInput').value='';voiceSync('chat')");
  await p.evaluate("voiceToggle('chat')"); await wait(80);
  await p.evaluate("__srs[2].emit([{t:'meet me at the station send it', final:true}])"); await wait(150);
  ok(await p.evaluate("curChat.messages.some(m=>m.me && m.t==='meet me at the station')"), 'hands-free ON: "send it" sends the cleaned text'); ok(await p.evaluate("$('#chInput').value") === '', 'input cleared after the voice send');

  // ---- 5. appending, cancel command, stop by second tap, errors ----
  await p.evaluate("$('#chInput').value='draft:';voiceSync('chat');voiceToggle('chat')"); await wait(80);
  await p.evaluate("__srs.at(-1).emit([{t:'buy milk', final:true}])"); await wait(80); ok(await p.evaluate("$('#chInput').value") === 'draft: buy milk', 'dictation appends to existing text');
  await p.evaluate("voiceToggle('chat')"); await wait(80); await p.evaluate("__srs.at(-1).emit([{t:'batal', final:true}])"); await wait(80);
  ok(await p.evaluate("$('#chInput').value") === 'draft: buy milk', 'cancel command undoes only the latest dictation');
  await p.evaluate("voiceToggle('chat')"); await wait(80); await p.evaluate("__srs.at(-1).emit([{t:'and eggs'}])"); await p.evaluate("voiceToggle('chat')"); await wait(80);
  ok(await p.evaluate("__srs.at(-1).stopped"), 'second tap stops listening'); ok(await p.evaluate("$('#chInput').value") === 'draft: buy milk and eggs', 'stopping keeps what was heard so far');
  await p.evaluate("$('#chInput').value='';voiceSync('chat');voiceToggle('chat')"); await wait(80);
  await p.evaluate("__srs.at(-1).fail('not-allowed')"); await wait(80);
  ok((await p.evaluate("$('#toast').textContent")).includes('permission was denied'), 'denied microphone gets a clear message'); ok(await p.evaluate("!$('#chMic').classList.contains('rec')"), 'error resets the mic');
  await p.evaluate("voiceToggle('chat')"); await wait(80); await p.evaluate("__srs.at(-1).fail('no-speech')"); await wait(80);
  ok((await p.evaluate("$('#toast').textContent")).includes("Didn't catch that"), 'silence is reported gently');

  // ---- 6. the other two chat surfaces ----
  await p.evaluate("back();openAgentChat('a2')"); await wait(350);
  await p.evaluate("voiceToggle('agent')"); await wait(80); await p.evaluate("__srs.at(-1).emit([{t:'please summarize findings send now', final:true}])"); await wait(1700);
  ok(await p.evaluate("curAgent.messages.some(m=>m.me && m.t==='please summarize findings')"), 'agent chat: voice command is sent'); ok(await p.evaluate("curAgent.messages.at(-1).t.includes('part of my workflow')"), 'and the agent answers within its workflow');
  await p.evaluate("back();openOrch()"); await wait(350);
  await p.evaluate("voiceToggle('orch')"); await wait(80); await p.evaluate("__srs.at(-1).emit([{t:'create an agent to monitor my inbox send', final:true}])"); await wait(1800);
  ok(await p.evaluate("AGENTS.some(a=>a.name==='Monitor Inbox Agent')"), 'Orchestrator: a spoken command creates the agent');
  ok(p._errs.length === 0, 'no page errors: ' + p._errs.join(' | '));
  await p.close(); await browser.close();
  console.log(`\n${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0);
})();
