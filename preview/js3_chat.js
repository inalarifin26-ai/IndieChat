let curChat = null, curAgent = null, reply = null, typingIn = null, actRoom = null, actId = null, attachRoom = null, scopeOpen = false;
const listOf = room => room === 'chat' ? curChat.messages : curAgent.messages;
const findMsg = (room, id) => listOf(room).find(m => m.id === id);
const ensureIds = l => l.forEach(m => { if (!m.id) m.id = 'm' + (++mid); if (!m.ts) m.ts = NOW(); });
const snippetOf = m => m.deleted ? 'Message deleted' : m.type === 'file' ? '📎 ' + m.file.name : m.type === 'output' ? '📄 ' + m.output.title : m.type === 'card' ? '📊 ' + m.card.title : (m.t || '');
const tickHTML = m => (!m.me || !m.status) ? '' : `<span class="tk ${m.status === 'read' ? 'read' : ''}">${m.status === 'sent' ? icon('check', 13) : icon('checks', 15)}</span>`;
function fileIc(name) { const ext = (name.split('.').pop() || '').toLowerCase(), e = EXT[ext] || ['#8B93AD', 'file']; return `<div class="fic" style="background:${e[0]}">${icon(e[1], 20, 'stroke="#fff"')}</div>`; }
function cardHTML(m, room) {
  const c = m.card;
  return `<div class="rcard" onclick="openMsg('${room}','${m.id}')"><h5>${esc(c.title)}</h5>` +
    (c.metrics ? `<div class="mets">${c.metrics.map(x => `<div class="met"><small>${esc(x[0])}</small><b>${esc(x[1])}</b>${x[2] ? `<i>${esc(x[2])}</i>` : ''}</div>`).join('')}</div>` : '') +
    (c.insights ? `<div class="ins">Key Insights</div><ul>${c.insights.map(i => `<li>${esc(i)}</li>`).join('')}</ul>` : '') +
    `<div class="acts"><button class="btn" onclick="event.stopPropagation();openOutputByName('Weekly Marketing Report.pdf')">View Full Report</button><button class="btn ${m.saved ? '' : 'ghost'}" ${m.saved ? 'disabled' : ''} onclick="event.stopPropagation();saveMsg('${room}','${m.id}')">${m.saved ? 'Saved ✓' : 'Save to Vault'}</button></div></div>`;
}
function msgHTML(m, room, group) {
  if (m.sys) return `<div class="sysmsg">${esc(m.t)}</div>`;
  const cls = m.me ? 'me' : 'them', open = `openMsg('${room}','${m.id}')`; let body;
  if (m.deleted) body = `<div class="bub" style="opacity:.55;font-style:italic;cursor:default;background:#fff;color:var(--text2)">🚫 Message deleted</div>`;
  else {
    const q = m.replyTo ? `<div class="quote" onclick="event.stopPropagation();jumpTo('${m.replyTo.id}')"><b>${esc(m.replyTo.who)}</b>${esc(m.replyTo.t)}</div>` : '';
    if (m.type === 'card') body = cardHTML(m, room);
    else if (m.type === 'output') body = `<div class="filec" onclick="${open}">${fileIc(m.output.title + '.pdf')}<div><b>${esc(m.output.title)}</b><small>Shared result · report + AI summary only</small></div></div>`;
    else if (m.type === 'file') body = `<div class="filec" onclick="${open}">${fileIc(m.file.name)}<div style="flex:1"><b>${esc(m.file.name)}</b><small>${esc(m.file.size)}</small></div><span style="color:var(--blue)">${icon('download', 18)}</span></div>`;
    else body = `<div class="bub" onclick="${open}">${q}${esc(m.t)}</div>`;
  }
  const rx = (!m.deleted && m.rx && Object.keys(m.rx).length) ? `<div class="rx">${Object.keys(m.rx).map(e => `<span class="${m.myrx === e ? 'mine' : ''}" onclick="event.stopPropagation();react('${room}','${m.id}','${e}')">${e} ${m.rx[e]}</span>`).join('')}</div>` : '';
  const grp = group && !m.me && m.from;
  const who = grp ? `<div class="who"><b>${esc(m.from)}</b> ${dayLabel(m.ts)} ${fmtTime(m.ts)}</div>` : '';
  const time = grp ? '' : `<div class="mt">${fmtTime(m.ts)} ${room === 'chat' ? tickHTML(m) : ''}</div>`;
  const cta = m.cta ? `<div style="margin-top:6px"><button class="chip" onclick="askOrchAbout()">Ask Orchestrator to change my workflow</button></div>` : '';
  return `<div class="msg ${cls}" data-mid="${m.id}">${who}${body}${rx}${time}${cta}</div>`;
}
function renderMsgs(list, room, group) { let last = '', h = ''; list.forEach(m => { const k = dayKey(m.ts); if (k !== last && !m.sys) { h += `<div class="dsep"><span>${dayLabel(m.ts)}</span></div>`; last = k; } h += msgHTML(m, room, group); }); return h; }
const TYPING = '<div class="typing"><i></i><i></i><i></i></div>';
function jumpTo(id) { const el = $(`#chBody .msg[data-mid="${id}"], #agBody .msg[data-mid="${id}"]`); if (el) { el.scrollIntoView({ block: 'center', behavior: 'smooth' }); el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash'); } }

function openChat(id, msgId) { curChat = chatById(id); curChat.unread = 0; clearReply(); renderChat(); openPage('chat'); refreshLists(); if (msgId) setTimeout(() => jumpTo(msgId), 320); }
function renderChat() {
  const c = curChat; if (!c) return; const g = c.kind === 'group', typ = typingIn === c.id;
  $('#chAv').innerHTML = g ? groupAv('sm') : personAv(c.name, 'sm', c.online); $('#chName').textContent = c.name;
  $('#chSub').innerHTML = g ? `${c.members.length + 1} members${typ ? ' · <span style="color:var(--blue)">typing…</span>' : ''}` : (typ ? '<span style="color:var(--blue)">typing…</span>' : (c.online ? '<span style="color:var(--green)">● Online</span>' : esc(c.seen)));
  const body = $('#chBody'); body.innerHTML = (c.messages.length ? renderMsgs(c.messages, 'chat', g) : `<div class="hint center" style="margin-top:50px">No messages yet — say hi 👋</div>`) + (typ ? TYPING : ''); body.scrollTop = body.scrollHeight;
}
const REPLIES = ['Noted 👍', 'Thanks!', 'Okay, got it', 'Will check 🙌', 'Sounds good'];
function sendChat(extra) {
  const c = curChat, inp = $('#chInput'); let m;
  if (extra) m = mk(true, '', extra); else { const t = inp.value.trim(); if (!t) return; m = mk(true, t); inp.value = ''; }
  attachReply(m, 'chat'); c.messages.push(m); renderChat(); refreshLists(); const id = c.id;
  setTimeout(() => { m.status = 'delivered'; if (curChat && curChat.id === id) renderChat(); }, 500);
  setTimeout(() => { typingIn = id; if (curChat && curChat.id === id) renderChat(); }, 900);
  setTimeout(() => {
    typingIn = null; m.status = 'read';
    const who = c.kind === 'group' && c.members.length ? personById(c.members[Math.floor(Math.random() * c.members.length)]) : null;
    c.messages.push(mk(false, extra ? 'Received, thanks! 🙏' : REPLIES[Math.floor(Math.random() * REPLIES.length)], who ? { from: who.name } : {}));
    if (!(curChat && curChat.id === id && $('#pg-chat').classList.contains('open'))) c.unread = (c.unread || 0) + 1;
    if (curChat && curChat.id === id) renderChat(); refreshLists();
  }, 2300);
}
function openAgentChat(id) { curAgent = agentById(id); clearReply(); renderAgentChat(); openPage('agentchat'); }
function renderAgentChat() {
  const a = curAgent; if (!a) return; $('#agAv').innerHTML = agentAv(a, 'sm'); $('#agName').textContent = a.name;
  const typ = typingIn === a.id, [c, l] = AGENT_STATE[a.state] || ['idle', 'Idle'];
  $('#agSub').innerHTML = typ ? '<span style="color:var(--blue)">typing…</span>' : `<span style="color:${c === 'idle' ? 'var(--faint)' : c === 'warn' ? 'var(--amber)' : c === 'appr' ? 'var(--purple)' : 'var(--green)'}">● ${l}</span> · AI Agent`;
  let h = `<div class="scope ${scopeOpen ? 'open' : ''}"><div class="top" onclick="scopeOpen=!scopeOpen;renderAgentChat()">${icon('lock', 15)}<span style="flex:1">Workflow set by Orchestrator · ${a.workflow.length} steps</span>${icon('chev', 14)}</div><ul>${a.workflow.map(s => `<li>${esc(s)}</li>`).join('')}</ul><span class="lk" onclick="askOrchAbout()">Change workflow → ask Orchestrator</span></div>`;
  h += renderMsgs(a.messages, 'agent', false);
  if (a.approval) h += `<div class="apprc"><div class="tg">${icon('lock', 15)} Approval required</div><div style="font-size:14px">Marketing Agent wants to publish an update for Campaign Alpha.</div><div class="btnrow" style="margin-top:10px"><button class="btn sm" onclick="openSheet('apprSheet')">Review</button><button class="btn primary sm" onclick="apprDecide(true)">Approve</button></div></div>`;
  if (typ) h += TYPING; const body = $('#agBody'); body.innerHTML = h; body.scrollTop = body.scrollHeight;
}
function agentReply(a, text) {
  const l = text.toLowerCase(); if (/status|progress|update|kabar/.test(l)) return { t: 'Current status: ' + a.activity + '.' };
  const words = l.split(/[^a-z0-9]+/).filter(w => w.length > 3); let hit = null;
  a.workflow.forEach(s => { const sl = s.toLowerCase(); words.forEach(w => { if (!hit && sl.includes(w)) hit = s; }); });
  if (hit) return { t: `On it — that is part of my workflow ("${hit}"). I will report back here when it is done.`, hit };
  return { t: "That is outside my workflow, so I can't do it. I can only: " + a.workflow.join('; ') + '. To change what I do, ask the Orchestrator.', cta: true };
}
function connectorReply(hit) {
  const inv = /invoice/i.test(hit), cal = /calendar/i.test(hit), cx = CONNECTORS.find(c => c.id === (inv ? 'google_drive' : cal ? 'google_calendar' : 'gmail'));
  if (!cx.on) return { t: `I can't reach your ${inv ? 'Google Drive' : cal ? 'calendar' : 'inbox'} right now (${cx.name} is not connected for this account). Connect it under More → Connectors, then ask me again.` };
  if (inv) return { card: { title: 'Invoice files in your Drive', insights: ['Invoice 2026-001.pdf — modified 05/01/2026', 'invoice-acme.xlsx — modified 02/01/2026'] } };
  return { card: cal ? { title: 'Upcoming calendar events', insights: ['Design review — 10:00', 'Dentist — tomorrow', 'Team sync — Fri 09:00'] } : { title: 'Unread emails', insights: ['Quarterly numbers — Finance', 'Re: Meeting — Alex Johnson'] } };
}
function sendAgent(extra) {
  const a = curAgent, inp = $('#agInput'); let m, text;
  if (extra) { m = mk(true, '', extra); text = extra.file ? extra.file.name : extra.output.title; } else { text = inp.value.trim(); if (!text) return; m = mk(true, text); inp.value = ''; }
  delete m.status; attachReply(m, 'agent'); a.messages.push(m); renderAgentChat(); refreshLists(); const id = a.id;
  setTimeout(() => { typingIn = id; if (curAgent && curAgent.id === id) renderAgentChat(); }, 300);
  setTimeout(() => {
    typingIn = null; const ag = agentById(id), r = agentReply(ag, text);
    if (r.hit && /calendar|email|invoice/i.test(r.hit)) { const cr = connectorReply(r.hit); ag.messages.push(cr.card ? mk(false, '', { type: 'card', card: cr.card }) : mk(false, cr.t)); }
    else {
      ag.messages.push(mk(false, r.t, { cta: r.cta }));
      if (r.hit) setTimeout(() => { ag.messages.push(mk(false, '', { type: 'card', card: { title: 'Task update — ' + r.hit, metrics: [['Workflow step', 'Completed'], ['Saved to', 'Vault']], insights: ['Result stored in your Personal Vault', 'Nothing outside my workflow was touched'] } })); if (curAgent && curAgent.id === id) renderAgentChat(); refreshLists(); }, 1500);
    }
    if (curAgent && curAgent.id === id) renderAgentChat(); refreshLists();
  }, 1100);
}
function askOrchAbout() { const a = curAgent; closeSheets(); openOrch('Update workflow of ' + a.name + ': '); }
function openAgentInfo() { const a = curAgent; $('#msgSheet').innerHTML = `<div class="handle"></div><div class="center" style="margin-bottom:12px"><div class="cen">${agentAv(a, 'lg')}</div><h3 style="margin-top:10px">${esc(a.name)}</h3><div class="hint">${esc(a.role)}</div></div><div class="lbl faint">Workflow defined by Orchestrator</div><div class="cardlist">${a.workflow.map((s, i) => `<div class="row" style="cursor:default"><span class="pill gray">${i + 1}</span><div class="grow nm" style="font-weight:600;font-size:14px">${esc(s)}</div></div>`).join('')}</div><button class="btn block" style="margin-top:14px" onclick="askOrchAbout()">Change workflow</button>`; openSheet('msgSheet'); }

function attachReply(m, room) { if (reply && reply.room === room) { m.replyTo = { id: reply.id, who: reply.who, t: reply.t }; clearReply(); } }
function showReply() { [['chat', 'chReply'], ['agent', 'agReply']].forEach(([r, id]) => { const b = $('#' + id); if (reply && reply.room === r) { b.classList.add('show'); b.innerHTML = `<div class="q"><b>Replying to ${esc(reply.who)}</b>${esc(reply.t)}</div><span onclick="clearReply()" style="cursor:pointer;padding:4px">${icon('x', 16)}</span>`; } else { b.classList.remove('show'); b.innerHTML = ''; } }); }
function clearReply() { reply = null; showReply(); }
function startReply() { const m = findMsg(actRoom, actId); if (!m) return; reply = { room: actRoom, id: m.id, who: m.me ? 'You' : (m.from || (actRoom === 'chat' ? curChat.name : curAgent.name)), t: snippetOf(m) }; showReply(); closeSheets(); $(actRoom === 'chat' ? '#chInput' : '#agInput').focus(); }
function openMsg(room, id) {
  const m = findMsg(room, id); if (!m || m.deleted) return; actRoom = room; actId = id;
  const info = 'Sent ' + fmtTime(m.ts) + (m.me && m.status && room === 'chat' ? ' · ' + ({ read: 'Read', delivered: 'Delivered', sent: 'Sent' })[m.status] : '');
  const row = (t, ic, fn, sub) => `<div class="setrow" onclick="${fn}"><div class="ic">${icon(ic, 18)}</div><div class="grow"><b>${t}</b>${sub ? `<small>${sub}</small>` : ''}</div></div>`;
  let rows = row('Reply', 'chat', 'startReply()');
  if (!m.type && m.t) rows += row('Copy text', 'copy', 'copyText(findMsg(actRoom,actId).t);closeSheets()');
  if (m.type) rows += row('Save to Vault', 'shield', 'saveMsg(actRoom,actId);closeSheets()', 'Only this item — never workflow data');
  rows += row('Message info', 'help', `toast('${info}');closeSheets()`, info);
  if (m.me) rows += `<div class="setrow danger" onclick="deleteMsg()"><div class="ic">${icon('trash', 18)}</div><div class="grow"><b>Delete message</b></div></div>`;
  $('#msgSheet').innerHTML = `<div class="handle"></div><div style="display:flex;justify-content:space-around;margin:0 0 8px">${['👍', '❤️', '😂', '🙏', '✅'].map(e => `<span style="font-size:26px;cursor:pointer;padding:5px 9px;background:var(--soft);border-radius:14px" onclick="react('${room}','${id}','${e}');closeSheets()">${e}</span>`).join('')}</div>${rows}`; openSheet('msgSheet');
}
function copyText(t) { try { if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(t).then(() => toast('Copied'), () => fbCopy(t)); return; } } catch (e) {} fbCopy(t); }
function fbCopy(t) { try { const ta = document.createElement('textarea'); ta.value = t; ta.style.cssText = 'position:fixed;opacity:0'; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); ta.remove(); toast('Copied'); } catch (e) { toast('Copy is not available in this preview'); } }
function rerender(room) { room === 'chat' ? renderChat() : renderAgentChat(); refreshLists(); }
function react(room, id, e) { const m = findMsg(room, id); if (!m) return; m.rx = m.rx || {}; if (m.myrx === e) { m.rx[e]--; if (m.rx[e] <= 0) delete m.rx[e]; m.myrx = null; } else { if (m.myrx) { m.rx[m.myrx]--; if (m.rx[m.myrx] <= 0) delete m.rx[m.myrx]; } m.rx[e] = (m.rx[e] || 0) + 1; m.myrx = e; } rerender(room); }
function deleteMsg() { const m = findMsg(actRoom, actId); if (!m) return; m.deleted = true; m.rx = null; closeSheets(); rerender(actRoom); toast('Message deleted'); }
function saveMsg(room, id) { const m = findMsg(room, id); if (m) { m.saved = true; rerender(room); toast('Saved to Vault'); } }
function openAttach(room) {
  attachRoom = room;
  $('#attachSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:6px">Attach</h3>` + [['File', 'file', "attachPick('file')", 'Campaign-Report.pdf · 2.4 MB (sample)'], ['Photo', 'image', "attachPick('photo')", 'IMG_2041.jpg · 1.1 MB (sample)'], ...OUTPUTS.slice(0, 2).map(o => [o.name, 'shield', `attachPick('${o.id}')`, 'From Vault · shares the result only'])].map(([t, ic, fn, sub]) => `<div class="setrow" onclick="${fn}"><div class="ic">${icon(ic, 18)}</div><div class="grow"><b>${esc(t)}</b><small>${sub}</small></div></div>`).join('');
  openSheet('attachSheet');
}
function attachPick(k) {
  closeSheets(); let x;
  if (k === 'file') x = { type: 'file', file: { name: 'Campaign-Report.pdf', size: '2.4 MB' } }; else if (k === 'photo') x = { type: 'file', file: { name: 'IMG_2041.jpg', size: '1.1 MB' } };
  else x = { type: 'output', output: { title: OUTPUTS.find(o => o.id === k).name.replace(/\.[a-z]+$/, '') } };
  attachRoom === 'chat' ? sendChat(x) : sendAgent(x);
}
