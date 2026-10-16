const addChat = c => { CHATS.push(c); (c.kind === 'group' ? GROUPS : PEOPLE).push(c); };
const removeChat = id => { [CHATS, GROUPS, PEOPLE].forEach(a => { const i = a.findIndex(c => c.id === id); if (i > -1) a.splice(i, 1); }); };
const lastTs = o => o.messages.length ? o.messages[o.messages.length - 1].ts : 0;
const chev = () => `<span class="chev">${icon('chev', 18)}</span>`;
function formSheet(title, fields, okLabel, onOk) {
  $('#noteSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:12px">${esc(title)}</h3>${fields.map(f => `<div class="field"><label>${esc(f.label)}</label><div class="in ${f.ta ? 'ta' : ''}">${f.ta ? `<textarea id="ff_${f.id}">${esc(f.value || '')}</textarea>` : `<input id="ff_${f.id}" value="${esc(f.value || '')}">`}</div></div>`).join('')}<div class="btnrow"><button class="btn" onclick="closeSheets()">Cancel</button><button class="btn primary" onclick="window._formOk()">${okLabel}</button></div>`;
  window._formOk = () => { const v = {}; fields.forEach(f => v[f.id] = $('#ff_' + f.id).value.trim()); if (onOk(v) !== false) closeSheets(); };
  openSheet('noteSheet');
}
let msgFilter = 'all';
function renderMessages() {
  $('#msgChips').innerHTML = [['all', 'All'], ['people', 'People'], ['agents', 'Agents'], ['groups', 'Groups']].map(([k, l]) => `<button class="chip ${msgFilter === k ? 'on' : ''}" onclick="msgFilter='${k}';renderMessages()">${l}</button>`).join('');
  const items = [];
  if (msgFilter === 'all' || msgFilter === 'people') PEOPLE.filter(p => p.messages.length).forEach(p => items.push({ t: 'chat', o: p }));
  if (msgFilter === 'all' || msgFilter === 'groups') GROUPS.forEach(g => items.push({ t: 'chat', o: g }));
  if (msgFilter === 'all' || msgFilter === 'agents') AGENTS.filter(a => a.messages.length).forEach(a => items.push({ t: 'agent', o: a }));
  items.sort((a, b) => ((b.o.pinned ? 1 : 0) - (a.o.pinned ? 1 : 0)) || lastTs(b.o) - lastTs(a.o));
  let h = '';
  if (msgFilter === 'all' || msgFilter === 'agents') h += `<div class="row" onclick="openOrch()">${orchAv()}<div class="grow"><div class="nm">Orchestrator</div><div class="sb">Direct your agents. Turn ideas into action.</div><div class="st"><i></i>Active</div></div></div>`;
  h += items.map(({ t, o }) => {
    const last = o.messages[o.messages.length - 1], isA = t === 'agent', g = o.kind === 'group';
    const pre = !last ? '' : (last.me ? 'You: ' : (g && last.from ? last.from + ': ' : '')) + snippetOf(last);
    const av = isA ? agentAv(o) : g ? groupAv() : personAv(o.name, '', o.online), ub = o.unread ? `<span class="ub">${o.unread}</span>` : '';
    return `<div class="row" onclick="${isA ? `openAgentChat('${o.id}')` : `openChat('${o.id}')`}">${av}<div class="grow"><div class="nm">${esc(o.name)}${o.pinned ? icon('pin', 13, 'style="color:var(--faint)"') : ''}${o.muted ? '<span style="font-size:12px">🔕</span>' : ''}<span class="tm">${last ? listTime(last.ts) : ''}</span></div><div class="sb" style="display:flex;gap:6px;align-items:center"><span style="flex:1;overflow:hidden;text-overflow:ellipsis">${esc(pre)}</span>${ub}</div>${isA ? agentStatusHTML(o) : ''}</div></div>`;
  }).join('');
  if (!items.length && msgFilter !== 'all' && msgFilter !== 'agents') h += `<div class="hint center" style="margin-top:40px">No conversations here yet.</div>`;
  $('#chatList').innerHTML = h; updateBadges();
}
function updateBadges() { const u = CHATS.reduce((n, c) => n + (c.unread || 0), 0), a = AGENTS.filter(x => x.approval).length, mb = $('#msgBadge'), ab = $('#agBadge'); mb.style.display = u ? 'flex' : 'none'; mb.textContent = u; ab.style.display = a ? 'flex' : 'none'; ab.textContent = a; }

let ctFilter = 'all';
function renderContactsPage() {
  $('#ctChips').innerHTML = [['all', 'All'], ['people', 'People'], ['groups', 'Groups'], ['agents', 'Agents']].map(([k, l]) => `<button class="chip ${ctFilter === k ? 'on' : ''}" onclick="ctFilter='${k}';renderContactsPage()">${l}</button>`).join('');
  const q = ($('#ctSearch').value || '').toLowerCase(), match = n => !q || n.toLowerCase().includes(q); let h = '';
  if (ctFilter === 'all' || ctFilter === 'people') PEOPLE.filter(p => match(p.name)).forEach(p => { const l = p.messages[p.messages.length - 1]; h += `<div class="row" onclick="openChat('${p.id}')">${personAv(p.name, '', p.online)}<div class="grow"><div class="nm">${esc(p.name)}</div><div class="sb">${esc(p.seen)}${l ? ' · ' + esc(snippetOf(l)) : ''}</div></div>${chev()}</div>`; });
  if (ctFilter === 'all' || ctFilter === 'groups') GROUPS.filter(g => match(g.name)).forEach(g => { h += `<div class="row" onclick="openChat('${g.id}')">${groupAv()}<div class="grow"><div class="nm">${esc(g.name)}</div><div class="sb">${g.members.length + 1} members · <span style="color:var(--green)">Active</span></div></div>${chev()}</div>`; });
  if (ctFilter === 'all' || ctFilter === 'agents') AGENTS.filter(a => match(a.name)).forEach(a => { h += `<div class="row" onclick="openAgentChat('${a.id}')">${agentAv(a)}<div class="grow"><div class="nm">${esc(a.name)}</div>${agentStatusHTML(a)}</div>${chev()}</div>`; });
  $('#ctBody').innerHTML = `<div class="lbl" style="margin:4px 18px 4px">Recent</div>` + (h || `<div class="hint center" style="margin-top:30px">Nothing matches.</div>`);
}
let acEdit = false;
function acTab(v) { $$('#acSeg button').forEach(b => b.classList.toggle('on', b.dataset.v === v)); $('#acPeople').style.display = v === 'people' ? '' : 'none'; $('#acAgent').style.display = v === 'agent' ? '' : 'none'; }
function openAddContact(edit) {
  acEdit = !!edit; const c = edit ? curChat : { name: '', info: '', group: '' };
  $('#acTitle').textContent = edit ? 'Edit Contact' : 'Create New Contact'; $('#acSeg').style.display = edit ? 'none' : ''; acTab('people');
  $('#acName').value = c.name; $('#acInfo').value = c.info;
  $('#acGroup').innerHTML = `<option value="">Select group</option>` + ['Family', 'Work', 'Clients', ...GROUPS.map(g => g.name)].filter((v, i, a) => a.indexOf(v) === i).map(g => `<option ${c.group === g ? 'selected' : ''}>${esc(g)}</option>`).join('');
  $('#fName').classList.remove('bad'); $('#fInfo').classList.remove('bad'); openPage('addcontact');
}
function saveContact() {
  const name = $('#acName').value.trim(), info = $('#acInfo').value.trim(), group = $('#acGroup').value;
  $('#fName').classList.toggle('bad', !name); $('#fInfo').classList.toggle('bad', !info); if (!name || !info) return;
  if (acEdit) { Object.assign(curChat, { name, info, group }); renderChat(); closePage('addcontact'); renderSettings(); toast('Contact updated'); refreshLists(); return; }
  const c = { id: 'p' + NOW(), kind: 'person', name, info, group, online: false, pinned: false, muted: false, unread: 0, seen: 'New contact', messages: [] };
  addChat(c); const g = GROUPS.find(x => x.name === group); if (g) g.members.push(c.id);
  closePage('addcontact'); toast('Contact saved'); renderContactsPage(); refreshLists(); setTimeout(() => openChat(c.id), 250);
}
function renderNewChat() {
  const q = ($('#ncSearch').value || '').toLowerCase(), m = n => !q || n.toLowerCase().includes(q); let h = `<div class="lbl" style="margin:2px 18px 4px">Suggested</div>`;
  if (!q) h += `<div class="row" onclick="closePage('newchat');openPage('creategroup')"><div class="av" style="background:#E5EEFF;color:#2F7BF5">${icon('users', 22)}</div><div class="grow"><div class="nm">New group</div><div class="sb">Chat with several contacts at once</div></div>${chev()}</div><div class="row" onclick="closePage('newchat');openOrch()">${orchAv()}<div class="grow"><div class="nm">Orchestrator</div><div class="sb">Create agents, run tasks, define workflows</div></div>${chev()}</div>`;
  const ags = AGENTS.filter(a => m(a.name));
  if (ags.length) h += `<div class="lbl" style="margin:12px 18px 6px">INDIE Agents</div><div style="margin:0 18px" class="cardlist">${ags.map(a => `<div class="row" onclick="closePage('newchat');openAgentChat('${a.id}')">${agentAv(a)}<div class="grow"><div class="nm">${esc(a.name)}</div><div class="sb">${esc(agentStyle(a).tag)}</div></div>${chev()}</div>`).join('')}</div>`;
  const ps = PEOPLE.filter(p => m(p.name));
  if (ps.length) h += `<div class="lbl" style="margin:14px 18px 4px">Contacts</div>${ps.map(p => `<div class="row" onclick="closePage('newchat');openChat('${p.id}')">${personAv(p.name, '', p.online)}<div class="grow"><div class="nm">${esc(p.name)}</div><div class="sb">${esc(p.seen)}</div></div></div>`).join('')}`;
  $('#ncBody').innerHTML = h;
}
let sqChip = 'messages';
function renderSearch() {
  $('#sqChips').innerHTML = [['messages', 'Messages'], ['contacts', 'Contacts'], ['groups', 'Groups'], ['agents', 'Agents']].map(([k, l]) => `<button class="chip ${sqChip === k ? 'on' : ''}" onclick="sqChip='${k}';renderSearch()">${l}</button>`).join('');
  const q = ($('#sqInput').value || '').trim().toLowerCase(); let h = '';
  const roomAv = (o, t) => t === 'agent' ? agentAv(o) : o.kind === 'group' ? groupAv() : personAv(o.name, '', o.online), open = (o, t, m) => t === 'agent' ? `openAgentChat('${o.id}')` : `openChat('${o.id}'${m ? `,'${m}'` : ''})`;
  const all = [...PEOPLE.map(o => ({ o, t: 'chat' })), ...GROUPS.map(o => ({ o, t: 'chat' })), ...AGENTS.map(o => ({ o, t: 'agent' }))];
  if (!q) h = `<div class="lbl" style="margin:4px 18px 4px">Recent</div>` + all.filter(x => x.o.messages.length).sort((a, b) => lastTs(b.o) - lastTs(a.o)).slice(0, 7).map(({ o, t }) => { const l = o.messages[o.messages.length - 1]; return `<div class="row" onclick="${open(o, t)}">${roomAv(o, t)}<div class="grow"><div class="nm">${esc(o.name)}<span class="tm">${listTime(l.ts)}</span></div><div class="sb">${l.me ? 'You: ' : ''}${esc(snippetOf(l))}</div></div></div>`; }).join('');
  else if (sqChip === 'messages') {
    const res = []; all.forEach(({ o, t }) => o.messages.forEach(m => { if (!m.deleted && !m.sys && snippetOf(m).toLowerCase().includes(q)) res.push({ o, t, m }); })); res.sort((a, b) => b.m.ts - a.m.ts);
    h = `<div class="lbl" style="margin:4px 18px 4px">${res.length} result${res.length === 1 ? '' : 's'}</div>` + res.slice(0, 30).map(({ o, t, m }) => `<div class="row" onclick="${open(o, t, m.id)}">${roomAv(o, t)}<div class="grow"><div class="nm">${esc(o.name)}<span class="tm">${listTime(m.ts)}</span></div><div class="sb">${esc(snippetOf(m))}</div></div></div>`).join('');
  } else {
    const src = sqChip === 'contacts' ? PEOPLE.map(o => ({ o, t: 'chat' })) : sqChip === 'groups' ? GROUPS.map(o => ({ o, t: 'chat' })) : AGENTS.map(o => ({ o, t: 'agent' }));
    h = src.filter(({ o }) => o.name.toLowerCase().includes(q)).map(({ o, t }) => `<div class="row" onclick="${open(o, t)}">${roomAv(o, t)}<div class="grow"><div class="nm">${esc(o.name)}</div><div class="sb">${t === 'agent' ? esc(agentStyle(o).tag) : o.kind === 'group' ? o.members.length + 1 + ' members' : esc(o.seen)}</div></div></div>`).join('');
  }
  $('#sqBody').innerHTML = h || `<div class="hint center" style="margin-top:40px">No results for “${esc(q)}”.</div>`;
}
let agTab = 'mine';
function agentTab(v) { agTab = v; renderAgentCenter(); }
function renderAgentCenter() {
  $$('#agentSeg button').forEach(b => b.classList.toggle('on', b.dataset.v === agTab));
  if (agTab === 'mine') $('#agentsBody').innerHTML = AGENTS.map(a => `<div class="row" onclick="openAgentChat('${a.id}')">${agentAv(a)}<div class="grow"><div class="nm">${esc(a.name)}</div>${agentStatusHTML(a).replace('</div>', ` · <span style="color:var(--text2);font-weight:500">${esc(agentStyle(a).tag)}</span></div>`)}</div>${chev()}</div>`).join('') + `<div style="padding:12px 18px"><button class="btn block" onclick="openOrch('Create an agent to ')">${icon('sparkle', 16)}&nbsp; Create an agent with the Orchestrator</button></div>`;
  else $('#agentsBody').innerHTML = `<div style="padding:0 18px"><p class="hint">Templates start a conversation with the Orchestrator, which builds the agent and defines its workflow.</p></div>` + TEMPLATES.map(t => { const have = AGENTS.some(a => a.name === t.name); return `<div class="row" style="cursor:default">${agentAv({ name: t.name })}<div class="grow"><div class="nm">${esc(t.name)}</div><div class="sb">${esc(agentStyle({ name: t.name }).tag)}</div></div>${have ? '<span class="pill gray">Added</span>' : `<button class="btn sm primary" onclick="openOrch('Create an agent to ${esc(t.desc)}')">Create</button>`}</div>`; }).join('');
}
let vTab = 'files';
function vaultTab(v) { vTab = v; renderVault(); }
const fileWhen = ts => (dayLabel(ts) === 'Today' || dayLabel(ts) === 'Yesterday') ? dayLabel(ts) + ', ' + fmtTime(ts) : Math.max(2, Math.round((NOW() - ts) / 864e5)) + ' days ago';
function renderVault() {
  $$('#vaultChips .chip').forEach(b => b.classList.toggle('on', b.dataset.v === vTab)); let h = '';
  if (vTab === 'files') h = OUTPUTS.map(o => `<div class="row frow" onclick="openOutput('${o.id}')">${fileIc(o.name)}<div class="grow"><div class="nm">${esc(o.name)}</div><div class="sb">${esc(o.kind)} · ${fileWhen(o.ts)}${o.shared ? ' · shared' : ''}</div></div>${chev()}</div>`).join('');
  else if (vTab === 'notes') h = `<div style="padding:0 18px 8px"><button class="btn sm ghost" onclick="addNote()">${icon('plus', 15)}&nbsp; Add note</button></div>` + (NOTES.map(n => `<div class="row" style="cursor:default"><div class="fic" style="background:#60A5FA;width:42px;height:42px;border-radius:12px">${icon('note', 19, 'stroke="#fff"')}</div><div class="grow"><div class="nm">${esc(n.title)}</div><div class="sb">${esc(n.text)}</div></div><button class="ibtn" onclick="NOTES.splice(NOTES.findIndex(x=>x.id==='${n.id}'),1);renderVault();toast('Note deleted')">${icon('trash', 17)}</button></div>`).join('') || `<div class="hint center" style="margin-top:30px">No notes yet.</div>`);
  else h = MEMORIES.map(m => { const a = agentById(m.agent); return `<div class="row" style="cursor:default">${agentAv(a, 'sm')}<div class="grow"><div class="nm" style="font-size:14px;font-weight:600">${esc(m.note)}</div><div class="sb">${esc(a.name)}</div></div></div>`; }).join('');
  $('#vaultBody').innerHTML = h;
}
function addNote() { formSheet('New note', [{ id: 'title', label: 'Title' }, { id: 'text', label: 'Note', ta: true }], 'Save', v => { if (!v.title) { toast('Add a title first'); return false; } NOTES.unshift({ id: 'n' + NOW(), title: v.title, text: v.text, ts: NOW() }); renderVault(); toast('Note saved'); }); }
function openOutputByName(n) { openOutput((OUTPUTS.find(x => x.name === n) || OUTPUTS[0]).id); }
function openOutput(id) {
  const o = OUTPUTS.find(x => x.id === id); $('#opTitle').textContent = o.name;
  $('#opBody').innerHTML = `<div class="card" style="padding:14px;display:flex;gap:12px;align-items:center;margin-bottom:14px">${fileIc(o.name)}<div><b style="font-size:15px">${esc(o.name)}</b><div class="hint" style="margin:2px 0 0">${esc(o.kind)} · ${fileWhen(o.ts)}</div></div></div><div class="lbl">Summary</div><p class="hint" style="font-size:14px;color:var(--text)">${esc(o.summary)}</p><div class="lbl">AI Summary</div><p class="hint" style="font-size:14px">${esc(o.ai)}</p><div class="lbl">Raw data</div><p class="hint">${esc(o.raw)}</p>` + (o.activity.length ? `<div class="lbl">Agent activity</div><ul class="hint" style="padding-left:18px;line-height:1.7">${o.activity.map(a => `<li>${esc(a)}</li>`).join('')}</ul>` : '') + `<button class="btn primary block" style="margin-top:12px" onclick="openShare('${o.id}')">Share result</button>`;
  openPage('output');
}
let SH = null;
function openShare(id) { SH = { id, fmt: 'PDF', to: null, inc: { report: true, ai: true, raw: false, act: false } }; renderShare(); openSheet('shareSheet'); }
function renderShare() {
  const o = OUTPUTS.find(x => x.id === SH.id), to = SH.to ? chatById(SH.to) : null;
  $('#shareSheet').innerHTML = `<div class="handle"></div><div class="center" style="margin-bottom:12px"><h3>Share Result</h3><div class="hint" style="margin:2px 0 0">Share the output, not your workflow.</div></div><div class="card" style="padding:12px;display:flex;gap:12px;align-items:center;margin-bottom:6px">${fileIc(o.name)}<div><b style="font-size:14px">${esc(o.name)}</b><div class="hint" style="margin:1px 0 0">${esc(o.kind)}</div></div></div>
  <div class="lbl">Share as</div><div class="cardlist">${['PDF', 'Link', 'Message', 'File'].map(f => `<div class="row" style="${SH.fmt === f ? 'background:#EEF3FF' : ''}" onclick="SH.fmt='${f}';renderShare()"><span class="rd ${SH.fmt === f ? 'on' : ''}"></span><div class="grow nm" style="font-weight:600">${f}</div></div>`).join('')}</div>
  <div class="lbl">Recipient</div><div class="card"><div class="row" onclick="pickRecipient()">${to ? (to.kind === 'group' ? groupAv('sm') : personAv(to.name, 'sm')) : `<div class="av sm" style="background:var(--soft);color:var(--faint)">${icon('user', 17)}</div>`}<div class="grow nm" style="font-weight:600">${to ? esc(to.name) : 'Choose recipient'}</div>${chev()}</div></div>
  <div class="lbl">Data included</div>${[['report', 'Report'], ['ai', 'AI Summary'], ['raw', 'Raw Data'], ['act', 'Agent Activity']].map(([k, l]) => `<div style="display:flex;align-items:center;gap:11px;padding:7px 2px;cursor:pointer;font-size:14px" onclick="SH.inc.${k}=!SH.inc.${k};renderShare()"><span class="cb ${SH.inc[k] ? 'on' : ''}">${icon('check', 14)}</span>${l}</div>`).join('')}
  <div class="hint" style="margin:8px 0 14px">The workflow definition, credentials and private memory are never included.</div><div class="btnrow"><button class="btn" onclick="closeSheets()">Cancel</button><button class="btn primary" onclick="doShare()">Share</button></div>`;
}
function pickRecipient() { $('#pickSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:8px">Recipient</h3>` + [...PEOPLE, ...GROUPS].map(c => `<div class="row" style="padding-left:2px;padding-right:2px" onclick="SH.to='${c.id}';renderShare();openSheet('shareSheet')">${c.kind === 'group' ? groupAv('sm') : personAv(c.name, 'sm')}<div class="grow nm" style="font-weight:600">${esc(c.name)}</div></div>`).join(''); openSheet('pickSheet'); }
function doShare() {
  if (!Object.values(SH.inc).some(Boolean)) { toast('Select at least one item to share'); return; }
  const o = OUTPUTS.find(x => x.id === SH.id); o.shared = true;
  if (SH.to) { const c = chatById(SH.to); c.messages.push(mk(true, '', { type: 'output', output: { title: o.name.replace(/\.[a-z]+$/, '') }, status: 'delivered' })); toast(`Shared with ${c.name} as ${SH.fmt}`); } else toast(`Shared as ${SH.fmt}`);
  closeSheets(); refreshLists(); if (curTab === 'vault') renderVault();
}
function setRow(ic, t, s, fn) { return `<div class="row" style="padding:13px 14px" onclick="${fn}"><div class="setrow" style="padding:0;pointer-events:none;flex:1"><div class="ic">${icon(ic, 18)}</div><div class="grow"><b>${t}</b><small>${s}</small></div></div>${chev()}</div>`; }
function renderProfile() {
  $('#profileBody').innerHTML = `<div class="prof">${personAv(ME.name, 'lg', true)}<div style="flex:1"><div class="nm">${esc(ME.name)} <span style="cursor:pointer;color:var(--text2)" onclick="editName()">${icon('edit', 16)}</span></div><div class="on"><i></i>Online</div></div></div>
  <div style="padding:0 18px"><div class="cardlist" style="margin-bottom:14px"><div class="kv"><div><small>Indie ID</small><b>${esc(ME.id)}</b></div><span style="color:var(--faint);cursor:pointer" onclick="copyText('${esc(ME.id)}')">${icon('copy', 18)}</span></div>
  <div class="row" style="padding:13px 14px" onclick="toast('Email is not shared')"><div class="grow"><div class="sb" style="margin:0 0 2px">Email</div><div class="nm" style="font-weight:600;color:var(--text2)">Not shared</div></div>${chev()}</div>
  <div class="row" style="padding:13px 14px" onclick="toast('Phone is not shared')"><div class="grow"><div class="sb" style="margin:0 0 2px">Phone</div><div class="nm" style="font-weight:600;color:var(--text2)">Not shared</div></div>${chev()}</div></div>
  <div class="cardlist">${setRow('lock', 'Privacy & Security', 'Manage your data and permissions', "openPage('consent')")}${setRow('link', 'Connectors', 'External services and scoped access', "openPage('connectors')")}${setRow('sliders', 'Account Settings', 'Notification, appearance, language', "toast('Account settings are not part of this preview')")}${setRow('help', 'Help & Support', 'Get help or contact us', "toast('support@indie.id')")}</div>
  <button class="btn danger block" style="margin-top:16px" onclick="logout()">Log out</button></div>`;
}
function editName() { formSheet('Display name', [{ id: 'n', label: 'Name', value: ME.name }], 'Save', v => { if (!v.n) return false; ME.name = v.n; renderProfile(); toast('Name updated'); }); }
function logout() { stack.splice(0).forEach(id => $('#pg-' + id).classList.remove('open')); openPage('welcome'); }
function renderConsent() {
  $('#cnBody').innerHTML = `<p class="hint">Every mandate is attributable to an agent and purpose. Pause or revoke at any time.</p>` + MANDATES.map(m => { const a = agentById(m.agent); return `<div class="card" style="padding:14px;margin-bottom:12px"><div style="display:flex;gap:11px;align-items:center">${agentAv(a, 'sm')}<div style="flex:1"><b>${esc(a.name)}</b><div class="hint" style="margin:1px 0 0">${esc(m.autonomy)}</div></div><span class="pill ${m.status === 'active' ? 'green' : m.status === 'paused' ? 'amber' : 'gray'}">${m.status[0].toUpperCase() + m.status.slice(1)}</span></div><p class="hint" style="margin:10px 0">${esc(m.purpose)}</p>${m.status === 'revoked' ? '' : `<div class="btnrow"><button class="btn sm" onclick="setMandate('${m.id}','${m.status === 'active' ? 'paused' : 'active'}')">${m.status === 'active' ? 'Pause' : 'Resume'}</button><button class="btn sm danger" onclick="setMandate('${m.id}','revoked')">Revoke</button></div>`}</div>`; }).join('');
}
function setMandate(id, s) { MANDATES.find(m => m.id === id).status = s; renderConsent(); toast('Mandate ' + s); }
function renderConnectors() { $('#cxBody').innerHTML = `<p class="hint">External services are optional connectors, scoped and revocable. Approval always happens on the provider's own screen.</p><div class="cardlist">${CONNECTORS.map(c => `<div class="row" style="cursor:default"><div class="setrow" style="padding:0;flex:1"><div class="ic" style="${c.on ? 'background:#E3F6EA;color:var(--green)' : ''}">${icon(c.ic, 18)}</div><div class="grow"><b>${c.name}</b><small>${c.on ? 'Connected · ' : ''}${c.desc}</small></div></div><button class="btn sm ${c.on ? 'danger' : ''}" onclick="toggleConnector('${c.id}')">${c.on ? 'Disconnect' : 'Connect'}</button></div>`).join('')}</div>`; }
function toggleConnector(id) { const c = CONNECTORS.find(x => x.id === id); c.on = !c.on; renderConnectors(); toast(c.on ? c.name + ' connected (simulated)' : c.name + ' disconnected'); }

const ADJ = ['creative', 'digital', 'focus', 'bright', 'quiet', 'swift', 'calm', 'bold'], NOUN = ['mind', 'nomad', 'life', 'spark', 'river', 'pixel', 'orbit', 'ember'];
const WORDLIST = 'ocean mirror bridge forest apple diamond winter melody rocket solar camera galaxy harbor velvet maple quartz signal timber lantern ripple ember cobalt drift fable grove meadow summit tundra violet willow zephyr anchor beacon canyon dolphin eclipse falcon glacier horizon island jasmine kettle lagoon marble nectar orchid prairie'.split(' ');
let pendingId = '', phrase = [], phraseOK = false;
const TAKEN = ['admin', 'indie', 'indie_user', 'clips', 'support'];
function initCreateId() {
  $('#idInput').value = ''; $('#pinInput').value = ''; $('#fId').classList.remove('bad', 'good'); $('#fPin').classList.remove('bad');
  const sugs = []; while (sugs.length < 3) { const s = ADJ[Math.floor(Math.random() * 8)] + '_' + NOUN[Math.floor(Math.random() * 8)]; if (!sugs.includes(s)) sugs.push(s); }
  $('#idSugs').innerHTML = sugs.map(s => `<div class="sug" onclick="$('#idInput').value='${s}';idCheck()"><span>${s}</span>${icon('copy', 17)}</div>`).join('');
}
function idCheck() {
  const v = $('#idInput').value.trim().toLowerCase(), f = $('#fId'); f.classList.remove('bad', 'good'); if (!v) return false;
  if (!/^[a-z0-9_.]{3,24}$/.test(v)) { $('#idErr').textContent = 'Use 3–24 letters, numbers, dots or underscores'; f.classList.add('bad'); return false; }
  if (TAKEN.includes(v)) { $('#idErr').textContent = 'This ID is already taken'; f.classList.add('bad'); return false; }
  f.classList.add('good'); return true;
}
function createIdNext() {
  let ok = idCheck(); if (!$('#idInput').value.trim()) { $('#idErr').textContent = 'Choose an Indie ID first'; $('#fId').classList.add('bad'); ok = false; }
  const pin = $('#pinInput').value; $('#fPin').classList.toggle('bad', pin.length < 6); if (!ok || pin.length < 6) return;
  pendingId = $('#idInput').value.trim().toLowerCase(); phrase = [];
  while (phrase.length < 12) { const w = WORDLIST[Math.floor(Math.random() * WORDLIST.length)]; if (!phrase.includes(w)) phrase.push(w); }
  $('#wordGrid').innerHTML = phrase.map((w, i) => `<div><b>${i + 1}.</b>${w}</div>`).join(''); phraseOK = false; $('#phraseCb').classList.remove('on'); openPage('phrase');
}
function phraseToggle() { phraseOK = !phraseOK; $('#phraseCb').classList.toggle('on', phraseOK); }
function phraseContinue() {
  if (!phraseOK) { const r = $('#phraseRow'); r.style.color = 'var(--red)'; try { r.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'translateX(0)' }], { duration: 280 }); } catch (e) {} setTimeout(() => r.style.color = '', 900); return; }
  ME.id = pendingId; enterApp(); toast('Welcome to Indie, ' + ME.id);
}
function enterApp() { ['phrase', 'createid', 'welcome'].forEach(closePage); go('msg'); }
function signIn() { enterApp(); toast('Signed in (demo)'); }

let armed = {};
function confirmTwice(k, msg, fn) { if (!armed[k]) { armed[k] = true; toast(msg); setTimeout(() => armed[k] = false, 3000); return; } armed[k] = false; fn(); }
function openSettings() { renderSettings(); openPage('settings'); }
function renderSettings() {
  const c = curChat; if (!c) return; const g = c.kind === 'group';
  const sw = (on, fn) => `<span class="sw ${on ? 'on' : ''}" onclick="event.stopPropagation();${fn}"></span>`;
  const row = (ic, t, s, fn, right) => `<div class="setrow" onclick="${fn}"><div class="ic">${icon(ic, 18)}</div><div class="grow"><b>${t}</b><small>${s}</small></div>${right || `<span class="chev">${icon('chev', 18)}</span>`}</div>`;
  $('#stBody').innerHTML = `<div class="center" style="margin:4px 0 14px"><div class="cen">${g ? groupAv('lg') : personAv(c.name, 'lg')}</div><h3 style="margin-top:10px">${esc(c.name)}</h3><div class="hint" style="margin:0">${g ? c.members.length + 1 + ' members' : esc(c.info || c.seen)}</div></div>` +
    (g ? row('user', 'Group Info', 'Name, description, icon', 'editGroupInfo()') + row('users', 'Members', 'View and manage members', 'openMembers()') : row('user', 'Contact Info', esc(c.info || 'Not shared'), 'openAddContact(true)')) +
    row('bell', 'Notifications', g ? 'Message, mention, and call' : 'Mute message and call alerts', "togg('muted')", sw(c.muted, "togg('muted')")) + (g ? '' : row('pin', 'Pin chat', 'Keep at the top of Messages', "togg('pinned')", sw(c.pinned, "togg('pinned')"))) +
    row('image', 'Media & Files', 'Shared media and documents', `toast('${c.messages.filter(m => m.type === 'file').length} files shared')`) + row('trash', 'Clear Chat History', 'Remove all messages', 'clearHistory()') +
    `<div class="setrow danger" style="margin-top:10px" onclick="${g ? 'leaveGroup()' : 'deleteContact()'}"><div class="ic">${icon(g ? 'logout' : 'trash', 18)}</div><div class="grow"><b>${g ? 'Leave Group' : 'Delete Contact'}</b></div></div>`;
}
function togg(k) { curChat[k] = !curChat[k]; renderSettings(); refreshLists(); toast(k === 'muted' ? (curChat.muted ? 'Notifications muted' : 'Notifications on') : (curChat.pinned ? 'Chat pinned' : 'Chat unpinned')); }
function clearHistory() { confirmTwice('clr', 'Tap "Clear Chat History" again to confirm', () => { curChat.messages = []; renderChat(); renderSettings(); refreshLists(); toast('Chat history cleared'); }); }
function deleteContact() { confirmTwice('del', 'Tap "Delete Contact" again to confirm', () => { const id = curChat.id; GROUPS.forEach(g => g.members = g.members.filter(m => m !== id)); removeChat(id); closePage('settings'); closePage('chat'); refreshLists(); toast('Contact deleted'); }); }
function leaveGroup() { confirmTwice('leave', 'Tap "Leave Group" again to confirm', () => { removeChat(curChat.id); closePage('settings'); closePage('chat'); refreshLists(); toast('You left the group'); }); }
function editGroupInfo() { formSheet('Group info', [{ id: 'n', label: 'Group name', value: curChat.name }, { id: 'd', label: 'Description', value: curChat.desc, ta: true }], 'Save', v => { if (!v.n) return false; curChat.name = v.n; curChat.desc = v.d; renderChat(); renderSettings(); refreshLists(); toast('Group updated'); }); }
function openMembers() {
  const g = curChat; $('#membersSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:6px">Members · ${g.members.length + 1}</h3><div class="row" style="padding-left:2px;cursor:default">${personAv(ME.name, 'sm')}<div class="grow nm">${esc(ME.name)} <span class="pill gray">You</span></div></div>` + g.members.map(id => { const p = personById(id); return p ? `<div class="row" style="padding-left:2px;cursor:default">${personAv(p.name, 'sm', p.online)}<div class="grow"><div class="nm">${esc(p.name)}</div><div class="sb">${esc(p.info)}</div></div><button class="ibtn" onclick="removeMember('${id}')">${icon('x', 18)}</button></div>` : ''; }).join('') + `<button class="btn primary block" style="margin-top:12px" onclick="closeSheets();openInvite('add')">Invite more</button>`; openSheet('membersSheet');
}
function removeMember(id) { const g = curChat; g.members = g.members.filter(m => m !== id); g.messages.push(mk(false, `${(personById(id) || {}).name} was removed`, { sys: true })); renderChat(); renderSettings(); openMembers(); toast('Member removed'); }
let GD = { members: [], vis: 'private' }, ivMode = 'create', ivSel = new Set();
function initCreateGroup() { GD = { members: [], vis: 'private' }; $('#gName').value = ''; $('#gDesc').value = ''; $('#fGName').classList.remove('bad'); $('#gAllow').classList.add('on'); renderGroupDraft(); }
function renderGroupDraft() {
  $('#gMembers').innerHTML = GD.members.slice(0, 5).map(id => personAv(personById(id).name, 'sm')).join('') + `<button class="chip" style="display:flex;align-items:center;gap:5px;padding:7px 12px" onclick="openInvite('create')">${icon('plus', 14)} Add</button>`;
  $('#gVis').innerHTML = [['public', 'globe', 'Public Group', 'Anyone with the link can join.'], ['private', 'lock', 'Private Group', 'Only invited members can join.']].map(([k, ic, t, s]) => `<div class="row" onclick="GD.vis='${k}';renderGroupDraft()" style="${GD.vis === k ? 'background:#EEF3FF' : ''}"><div class="setrow" style="padding:0;pointer-events:none;flex:1"><div class="ic">${icon(ic, 18)}</div><div class="grow"><b>${t}</b><small>${s}</small></div></div><span class="rd ${GD.vis === k ? 'on' : ''}"></span></div>`).join('');
}
function createGroup() {
  const name = $('#gName').value.trim(); $('#fGName').classList.toggle('bad', !name); if (!name) return;
  const g = { id: 'g' + NOW(), kind: 'group', name, desc: $('#gDesc').value.trim(), vis: GD.vis, allowNew: $('#gAllow').classList.contains('on'), members: [...GD.members], muted: false, pinned: false, unread: 0, messages: [mk(false, `You created “${name}”`, { sys: true })] };
  addChat(g); closePage('creategroup'); refreshLists(); toast('Group created'); setTimeout(() => openChat(g.id), 250);
}
function openInvite(mode) { ivMode = mode; ivSel = new Set(mode === 'create' ? GD.members : []); $('#ivTitle').textContent = mode === 'create' ? 'Add Members' : 'Invite to Group'; $('#ivSearch').value = ''; renderInvite(); openPage('invite'); }
function renderInvite() {
  const q = ($('#ivSearch').value || '').toLowerCase(), have = ivMode === 'add' ? curChat.members : [];
  $('#ivBody').innerHTML = PEOPLE.filter(p => !have.includes(p.id) && (!q || p.name.toLowerCase().includes(q))).map(p => `<div class="row" onclick="ivToggle('${p.id}')"><span class="cb ${ivSel.has(p.id) ? 'on' : ''}">${icon('check', 14)}</span>${personAv(p.name, '', p.online)}<div class="grow"><div class="nm">${esc(p.name)}</div><div class="sb">${esc(p.info)}</div></div></div>`).join('');
  $('#ivCount').textContent = ivSel.size + ' selected'; $('#ivBtn').textContent = ivMode === 'create' ? 'Done' : 'Invite';
}
function ivToggle(id) { ivSel.has(id) ? ivSel.delete(id) : ivSel.add(id); renderInvite(); }
function inviteDone() {
  if (ivMode === 'create') { GD.members = [...ivSel]; back(); renderGroupDraft(); return; }
  if (!ivSel.size) { toast('Select at least one contact'); return; }
  const g = curChat, n = ivSel.size; [...ivSel].forEach(id => { g.members.push(id); g.messages.push(mk(false, `${personById(id).name} joined the group`, { sys: true })); });
  back(); renderChat(); renderSettings(); refreshLists(); toast(n + ' member' + (n > 1 ? 's' : '') + ' invited');
}
