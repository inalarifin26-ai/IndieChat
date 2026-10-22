/* ================= voice input / voice commands =================
   Dictation into any composer (chat, agent chat, Orchestrator). Nothing is sent
   unless the user taps Send — or has turned on "hands-free send" and ends the
   utterance with "kirim" / "send". Mirrors lib/core/voice_command.dart. */
const VOICE = {
  chat: { inp: 'chInput', snd: 'chSnd', mic: 'chMic', box: 'chComposer', send: () => sendChat() },
  agent: { inp: 'agInput', snd: 'agSnd', mic: 'agMic', box: 'agComposer', send: () => sendAgent() },
  orch: { inp: 'orInput', snd: 'orSnd', mic: 'orMic', box: 'orComposer', send: () => sendOrch() },
};
const VS = (() => { let o = {}; try { o = JSON.parse(localStorage.getItem('indie.voice') || '{}'); } catch (e) {} return Object.assign({ consented: false, handsFree: false, lang: 'id-ID' }, o); })();
const vSave = () => { try { localStorage.setItem('indie.voice', JSON.stringify(VS)); } catch (e) {} };
let vrec = null, vroom = null, vPrefix = '', vText = '', vFinal = false, vErr = null, vHeld = false, vTimer = null;

/** Pure: turns a transcript into text + optional command. `handsFree` enables the trailing send keyword. */
function parseVoiceCommand(raw, handsFree) {
  const t = String(raw == null ? '' : raw).replace(/\s+/g, ' ').trim();
  const low = t.toLowerCase().replace(/[.!?,;:\s]+$/, '');
  if (['batal', 'cancel', 'hapus', 'hapus semua', 'clear', 'clear all'].includes(low)) return { text: '', send: false, clear: true };
  if (handsFree) {
    const m = t.match(/^(.*?)[\s,.;:!?]*\b(kirim(?: pesan| sekarang)?|send(?: it| message| now)?)[\s.!?]*$/i);
    if (m) {
      const rest = m[1].replace(/[\s,.;:!?]+$/, '').trim();
      if (rest.split(/\s+/).filter(Boolean).length >= 2) return { text: rest, send: true, clear: false };
    }
  }
  return { text: t, send: false, clear: false };
}

const voiceSupported = () => !!(window.SpeechRecognition || window.webkitSpeechRecognition);
function voiceSync(room) {
  const c = VOICE[room], inp = $('#' + c.inp), box = $('#' + c.box); if (!inp || !box) return;
  const listening = vrec && vroom === room;
  box.classList.toggle('has', inp.value.trim().length > 0 || !!listening);
  box.classList.toggle('listening', !!listening);
  $('#' + c.mic).classList.toggle('rec', !!listening);
  inp.classList.toggle('live', !!listening);
  inp.placeholder = listening ? 'Listening…' : (room === 'orch' ? 'Type your request...' : 'Type a message...');
}
function vDown(room) { clearTimeout(vTimer); vHeld = false; vTimer = setTimeout(() => { vHeld = true; openVoiceSheet(room, false); }, 600); }
function vUp() { clearTimeout(vTimer); }

function voiceToggle(room) {
  if (vHeld) { vHeld = false; return; } // a long-press opened the settings sheet; don't also toggle
  if (vrec) { vStop(); return; }
  if (!voiceSupported()) { toast('Voice input is not supported in this browser — try Chrome or Edge.'); return; }
  if (!VS.consented) { openVoiceSheet(room, true); return; }
  vStart(room);
}
function vStart(room) {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition; if (!SR) return;
  const c = VOICE[room], inp = $('#' + c.inp), rec = new SR();
  vrec = rec; vroom = room; vFinal = false; vErr = null; vText = ''; vPrefix = inp.value.trim() ? inp.value.trim() + ' ' : '';
  rec.lang = VS.lang; rec.interimResults = true; rec.continuous = false; rec.maxAlternatives = 1;
  rec.onresult = ev => {
    const parts = Array.from(ev.results); vText = parts.map(r => r[0].transcript).join(' ').trim();
    inp.value = vPrefix + vText; voiceSync(room);
    if (parts.length && parts[parts.length - 1].isFinal) vFinalize();
  };
  rec.onerror = ev => {
    vErr = ev && ev.error; const msg = ({
      'not-allowed': 'Microphone permission was denied — allow it in your browser settings.', 'service-not-allowed': 'Microphone permission was denied — allow it in your browser settings.',
      'no-speech': "Didn't catch that — try again.", 'audio-capture': 'No microphone was found.', 'network': 'Speech recognition needs an internet connection.',
      'language-not-supported': 'This language is not supported for voice input.',
    })[vErr]; if (msg) toast(msg); else if (vErr && vErr !== 'aborted') toast('Voice input failed (' + vErr + ').');
  };
  rec.onend = () => { if (!vFinal && !vErr && vText) vFinalize(); const r = vroom; vrec = null; vroom = null; if (r) voiceSync(r); };
  try { rec.start(); voiceSync(room); } catch (e) { vrec = null; vroom = null; toast('Could not start voice input.'); voiceSync(room); }
}
function vStop() { try { vrec && vrec.stop(); } catch (e) {} }
function vFinalize() {
  if (vFinal) return; vFinal = true;
  const room = vroom, c = VOICE[room], inp = $('#' + c.inp), cmd = parseVoiceCommand(vText, VS.handsFree);
  if (cmd.clear) { inp.value = vPrefix.trim(); toast('Dictation cancelled'); }
  else { inp.value = vPrefix + cmd.text; if (cmd.send) { voiceSync(room); c.send(); } }
  // Close the session explicitly: some engines never fire `end` after a final result, and a stale
  // session would turn the next mic tap into a "stop" instead of a new dictation.
  const rec = vrec; vrec = null; vroom = null;
  try { rec && rec.stop(); } catch (e) {}
  voiceSync(room);
}
function openVoiceSheet(room, first) {
  const draft = { lang: VS.lang, handsFree: VS.handsFree };
  const paint = () => {
    $('#voiceSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:6px">Voice input</h3>
    <p class="hint">Your device's speech recognition turns your voice into text. Depending on your device and language it may use an online service — Indie itself never receives or stores audio, only the text you send.</p>
    <div class="lbl faint" style="margin-top:4px">Language</div>
    <div class="lang">${[['id-ID', 'Bahasa Indonesia'], ['en-US', 'English']].map(([k, l]) => `<button class="chip ${draft.lang === k ? 'on' : ''}" onclick="vDraft('lang','${k}')">${l}</button>`).join('')}</div>
    <div class="card" style="padding:12px 14px;display:flex;align-items:center;gap:12px;margin:12px 0 6px"><div style="flex:1"><b style="font-size:14.5px">Hands-free send</b><div class="hint" style="margin:2px 0 0">End a command with “kirim” or “send” to send it without tapping. Off by default.</div></div><span class="sw ${draft.handsFree ? 'on' : ''}" id="vHF" onclick="vDraft('handsFree',!${draft.handsFree})"></span></div>
    <div class="hint" style="margin:0 0 14px">Say “batal” or “cancel” to discard what you just dictated.</div>
    <div class="btnrow"><button class="btn" onclick="closeSheets()">Cancel</button><button class="btn primary" id="vOk" onclick="vConfirm('${room}',${first})">${first ? 'Allow microphone' : 'Save'}</button></div>`;
  };
  window.vDraft = (k, v) => { draft[k] = v; paint(); }; window.vConfirm = (r, f) => { VS.consented = true; VS.lang = draft.lang; VS.handsFree = draft.handsFree; vSave(); closeSheets(); if (f) setTimeout(() => vStart(r), 50); else toast('Voice settings saved'); };
  paint(); openSheet('voiceSheet');
}
