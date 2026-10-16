let orchBusy = false, orchRun = 0, orchStarted = false;
const ORCH_CHIPS = [['Create a report', 'file', 'Create an agent to report weekly campaign performance'], ['Plan my day', 'clock', 'Plan my day from my calendar and emails'], ['Analyze data', 'chart', 'Analyze my latest campaign performance'], ['Build a workflow', 'flow', 'Build a workflow to monitor my campaign every morning']];
const oTag = () => `<div class="otag"><span class="mk">in</span>ORCHESTRATOR<time>${fmtTime(NOW())}</time></div>`;
function oAdd(html) { const b = $('#orBody'); b.insertAdjacentHTML('beforeend', html); b.scrollTop = b.scrollHeight; return b.lastElementChild; }
function openOrch(prefill) {
  $('#orbChips').innerHTML = ORCH_CHIPS.map(([l, ic], i) => `<button onclick="orchChip(${i})">${icon(ic, 18)}${l}</button>`).join('');
  $('#orbWrap').style.display = orchStarted ? 'none' : ''; $('#orBody').style.display = orchStarted ? '' : 'none'; openPage('orch');
  if (typeof prefill === 'string') { const i = $('#orInput'); i.value = prefill; i.focus(); }
}
function orchChip(i) { $('#orInput').value = ORCH_CHIPS[i][2]; sendOrch(); }
function startOrchThread() { if (orchStarted) return; orchStarted = true; $('#orbWrap').style.display = 'none'; $('#orBody').style.display = ''; oAdd(`<div class="omsg">${oTag()}<div>Hi! I define <b>what your agents do</b>. Create an agent, give me a task, or update an agent's workflow — agents only ever work inside the workflow I give them.</div></div>`); }
function sendOrch() {
  const inp = $('#orInput'), text = inp.value.trim(); if (!text) return;
  if (orchBusy) { toast('Orchestrator is still working…'); return; }
  inp.value = ''; startOrchThread();
  oAdd(`<div class="msg me"><div class="bub" style="cursor:default">${esc(text)}</div><div class="mt">${fmtTime(NOW())} <span class="tk read">${icon('checks', 15)}</span></div></div>`);
  const l = text.toLowerCase();
  if (/\b(update|ubah|change|edit)\b[^.]*\bworkflow\b/.test(l)) updateWorkflowFlow(text);
  else if (/\b(create|buat|bikin|make|add|tambah)\w*\b[^.]*\bagent\b/.test(l)) createAgentFlow(text); else taskFlow(text);
}
const STOP = { my: 1, the: 1, a: 1, an: 1, to: 1, saya: 1, ku: 1, untuk: 1, yang: 1, that: 1, of: 1, and: 1 };
function deriveAgent(text) {
  const m = text.match(/(?:\bto\b|\buntuk\b|\bthat\b|\byang\b)\s+(.+)$/i);
  const topic = (m ? m[1] : text.replace(/.*\bagent\b/i, '')).replace(/[.!?]+$/, '').trim() || 'general tasks';
  const words = topic.split(/\s+/).filter(w => w && !STOP[w.toLowerCase()]).slice(0, 2);
  const name = (words.length ? words.map(w => w[0].toUpperCase() + w.slice(1)).join(' ') : 'Custom') + ' Agent';
  const short = topic.length > 38 ? topic.slice(0, 38) + '…' : topic, l = topic.toLowerCase();
  const obj = short.replace(/^(monitor|memantau|pantau|watch|track|summari[sz]e|meringkas|ringkas|report|melaporkan|research|find|search|mencari|cari)\s+(on\s+|for\s+)?/i, ''); let steps;
  if (/monitor|pantau|memantau|watch|track/.test(l)) steps = [`Check ${obj} on a schedule`, 'Detect important changes', 'Notify you'];
  else if (/summar|ringkas|meringkas/.test(l)) steps = [`Collect ${obj}`, 'Summarize key points', 'Save summary to Vault'];
  else if (/report|laporan/.test(l)) steps = [`Gather data for ${obj}`, 'Generate report', 'Save report to Vault'];
  else if (/research|cari|find|search/.test(l)) steps = ['Search public sources', 'Compare findings', 'Report results to you'];
  else steps = ['Receive tasks from Orchestrator', 'Execute: ' + short, 'Report results to you'];
  steps.push('Ask your approval before any external action');
  return { name, role: short[0].toUpperCase() + short.slice(1), steps };
}
function makeAgent(d) { const a = { id: 'a' + NOW() + Math.floor(Math.random() * 99), name: d.name, role: d.role, state: 'ready', activity: 'Ready — waiting for tasks', workflow: d.steps, messages: [mk(false, `Hi! I'm ${d.name}. The Orchestrator set up my workflow — I will follow it exactly.`)] }; AGENTS.push(a); refreshLists(); return a; }
const chatBtn = a => `<button class="btn sm" style="margin-top:8px" onclick="openAgentChat('${a.id}')">💬 Chat with ${esc(a.name)}</button>`;
const olist = arr => `<ol>${arr.map(s => `<li>${esc(s)}</li>`).join('')}</ol>`;
function createAgentFlow(text) {
  orchBusy = true; const t = oAdd('<div class="hint" style="margin:0 4px 10px">Orchestrator is defining the workflow…</div>');
  setTimeout(() => {
    t.remove(); const d = deriveAgent(text), dup = AGENTS.find(x => x.name.toLowerCase() === d.name.toLowerCase());
    if (dup) oAdd(`<div class="omsg">${oTag()}<div>${esc(dup.name)} already exists. You can chat with it, or tell me how to change its workflow.</div>${chatBtn(dup)}</div>`);
    else { const a = makeAgent(d); oAdd(`<div class="omsg">${oTag()}<div>✅ Created <b>${esc(a.name)}</b>. Workflow I defined:</div>${olist(a.workflow)}<div class="hint" style="margin:6px 0 0">You can now chat with it directly — it will only do these steps.</div>${chatBtn(a)}</div>`); }
    orchBusy = false;
  }, 1000);
}
function updateWorkflowFlow(text) {
  const l = text.toLowerCase(), a = AGENTS.find(x => { const n = x.name.toLowerCase(); return l.includes(n) || l.includes(n.replace(' agent', '')); }), say = h => oAdd(`<div class="omsg">${oTag()}${h}</div>`);
  if (!a) return say('<div>Which agent? Try: <i>Update workflow of Research Agent: compare prices</i>.</div>');
  const i = text.indexOf(':'), step = (i > -1 ? text.slice(i + 1) : text).trim();
  if (step.length < 3) return say(`<div>What should ${esc(a.name)} do? Add the new step after a colon.</div>`);
  a.workflow.splice(Math.max(0, a.workflow.length - 1), 0, step[0].toUpperCase() + step.slice(1)); a.messages.push(mk(false, 'Orchestrator updated your workflow: + ' + step, { sys: true }));
  say(`<div>✅ Updated <b>${esc(a.name)}</b>. Its workflow is now:</div>${olist(a.workflow)}${chatBtn(a)}`);
}
const LIB = {
  travel: { name: 'Travel Agent', role: 'Flights & hotels', wf: ['Search flights', 'Compare hotels', 'Report options to you'], res: 'Found 3 flight options and 2 family-friendly hotels within budget.' },
  itinerary: { name: 'Itinerary Agent', role: 'Daily itineraries', wf: ['Build day-by-day schedule', 'Balance activities and rest', 'Report plan to you'], res: 'Built a 7-day schedule balancing beach days, culture and rest time.' },
  finance: { ex: 'Finance Agent', res: 'Estimated total budget: Rp 32,600,000 for a family of 4, incl. buffer.' }, research: { ex: 'Research Agent', res: 'Found 5 relevant options and sources worth reviewing.' },
  marketing: { ex: 'Marketing Agent', res: 'Drafted a performance summary — publishing still needs your approval.' }, assistant: { ex: 'Personal Assistant', res: 'Prepared your day from your calendar and inbox.' },
};
function pickPlan(t) { const l = t.toLowerCase(); if (/trip|bali|travel|liburan|flight|hotel/.test(l)) return ['travel', 'itinerary', 'finance', 'research']; if (/campaign|marketing|instagram|ads|iklan/.test(l)) return ['research', 'marketing']; if (/\bday\b|schedule|agenda|hari|calendar/.test(l)) return ['assistant']; return ['research', 'finance']; }
const orchOut = {};
function saveOrchOut(rid, share) { const o = orchOut[rid]; if (!o.saved) { OUTPUTS.unshift(o); o.saved = true; } const b = $('#sv' + rid); if (b) { b.disabled = true; b.textContent = 'Saved ✓'; } if (share) openShare(o.id); else toast('Saved to Vault'); }
function taskFlow(text) {
  orchBusy = true; const rid = ++orchRun, created = [], stages = ['Research', 'Planning', 'Processing', 'Complete'];
  const items = pickPlan(text).map(k => { const L = LIB[k]; let a = AGENTS.find(x => x.name === (L.ex || L.name)); if (!a) { a = makeAgent({ name: L.name, role: L.role, steps: [...L.wf, 'Ask your approval before any external action'] }); created.push(a); } return { a, res: L.res }; }), N = items.length;
  const short = text.length > 44 ? text.slice(0, 44) + '…' : text;
  oAdd(`<div class="omsg">${oTag()}<div>I will coordinate ${N} agent${N > 1 ? 's' : ''} for this task:</div>${olist(items.map(x => x.a.name + ' → ' + x.a.workflow[0]))}${created.length ? `<div style="font-size:12px;color:var(--indigo);margin-top:8px">＋ Created ${created.length} new agent${created.length > 1 ? 's' : ''} with their own workflow: ${created.map(c => esc(c.name)).join(', ')}</div>` : ''}<div class="achips">${items.map((x, i) => `<div class="achip"><div class="cen">${agentAv(x.a, 'sm')}</div><p>${esc(x.a.name.replace(' Agent', ''))}</p><span id="st${rid}_${i}">Queued</span></div>`).join('')}</div><div class="pipe">${stages.map((s, i) => `<div class="st ${i === 0 ? 'act' : ''}" id="pl${rid}_${i}"><i>${i + 1}</i>${s}</div>`).join('')}</div></div>`);
  let k = 0;
  const stage = (s, fin) => stages.forEach((_, i) => { const e = $(`#pl${rid}_${i}`); if (!e) return; e.classList.remove('act', 'done'); if (fin || i < s) e.classList.add('done'); else if (i === s) e.classList.add('act'); });
  const tick = () => {
    stage(k === N ? 3 : Math.min(2, Math.floor(k * 3 / N)));
    if (k >= 1) { const d = items[k - 1], st = $(`#st${rid}_${k - 1}`); if (st) st.textContent = 'Done ✓'; oAdd(`<div class="amsg">${agentAv(d.a, 'xs')}<div class="bd"><b>${esc(d.a.name)} · ${fmtTime(NOW())}</b><p>${esc(d.res)}</p></div></div>`); }
    if (k < N) { const s2 = $(`#st${rid}_${k}`); if (s2) s2.textContent = 'Working…'; }
    k++; k <= N ? setTimeout(tick, 1000) : setTimeout(finish, 1000);
  };
  const finish = () => {
    stage(3, true); items.forEach(x => { x.a.messages.push(mk(false, `Task done for "${short}": ${x.res}`)); if (x.a.state === 'ready') x.a.activity = 'Last task: ' + short; });
    orchOut[rid] = { id: 'o' + NOW(), name: (short.replace(/[^\w ]/g, '').trim().slice(0, 30) || 'Result') + '.pdf', ext: 'pdf', kind: 'Report', ts: NOW(), summary: items.map(x => x.res).join(' '), ai: `Combined result from ${N} agent${N > 1 ? 's' : ''}.`, raw: 'orchestrator run', activity: items.map(x => x.a.name + ' completed') };
    oAdd(`<div class="omsg">${oTag()}<div>All ${N} agent${N > 1 ? 's' : ''} finished — combined result:</div><div class="tcard"><h4>${esc(short)}</h4>${items.map(x => `<div class="trow"><span>${esc(x.a.name)}</span><b>${esc(x.res)}</b></div>`).join('')}</div><div class="btnrow" style="margin-top:10px"><button class="btn sm" id="sv${rid}" onclick="saveOrchOut(${rid},false)">Save to Vault</button><button class="btn primary sm" onclick="saveOrchOut(${rid},true)">Share</button></div><div class="hint" style="margin:10px 0 4px">Workflow saved. Chat directly with an agent — it only works inside its workflow:</div><div style="display:flex;gap:8px;flex-wrap:wrap">${items.map(x => `<button class="chip" onclick="openAgentChat('${x.a.id}')">💬 ${esc(x.a.name)}</button>`).join('')}</div></div>`);
    refreshLists(); orchBusy = false;
  };
  tick();
}

const NODE_STYLE = { trigger: ['#F59E0B', 'bolt'], data: ['#3B82F6', 'file'], ai: ['#8B5CF6', 'sparkle'], logic: ['#6366F1', 'flow'], action: ['#0EA5E9', 'plane'], approval: ['#7C5CFF', 'lock'], storage: ['#22C55E', 'shield'], output: ['#8B93AD', 'file'] };
ICONS.plane = '<path d="M4 12l16-8-6 16-3-7z"/>';
const WFS = [
  { id: 'w1', name: 'Daily Marketing Report', desc: 'Monitors Campaign Alpha, analyzes performance and drafts an update.', life: 'active', trigger: 'Every day at 09:00',
    nodes: [{ id: 'n1', t: 'Parse request', c: 'trigger', s: 'Daily at 09:00', x: 30, y: 30 }, { id: 'n2', t: 'Collect data', c: 'data', s: 'Campaign analytics', x: 30, y: 140 }, { id: 'n3', t: 'Analyze', c: 'ai', s: 'Marketing Agent', x: 30, y: 250 }, { id: 'n4', t: 'Generate report', c: 'output', s: 'Weekly report', x: 30, y: 360 }, { id: 'n5', t: 'Publish update', c: 'approval', s: 'Requires approval', x: 30, y: 470 }, { id: 'n6', t: 'Save to Vault', c: 'storage', s: 'Report + summary', x: 30, y: 580 }], edges: [['n1', 'n2'], ['n2', 'n3'], ['n3', 'n4'], ['n4', 'n5'], ['n5', 'n6']] },
  { id: 'w2', name: 'Weekly Cash Flow Summary', desc: 'Reads invoices, calculates cash flow, saves a report.', life: 'active', trigger: 'Mondays at 08:00',
    nodes: [{ id: 'n1', t: 'Weekly schedule', c: 'trigger', s: 'Mondays 08:00', x: 30, y: 30 }, { id: 'n2', t: 'Read invoices', c: 'data', s: 'Vault: Finance', x: 30, y: 140 }, { id: 'n3', t: 'Finance Agent', c: 'ai', s: 'Summarize cash flow', x: 30, y: 250 }, { id: 'n4', t: 'Save report', c: 'storage', s: 'Vault: Reports', x: 30, y: 360 }], edges: [['n1', 'n2'], ['n2', 'n3'], ['n3', 'n4']] },
  { id: 'w3', name: 'Competitor Price Watch', desc: 'Draft automation — not yet activated.', life: 'draft', trigger: 'Manual run',
    nodes: [{ id: 'n1', t: 'Manual trigger', c: 'trigger', s: 'Run on demand', x: 30, y: 30 }, { id: 'n2', t: 'Research Agent', c: 'ai', s: 'Scan competitor sites', x: 30, y: 140 }, { id: 'n3', t: 'Generate report', c: 'output', s: 'Draft summary', x: 30, y: 250 }], edges: [['n1', 'n2'], ['n2', 'n3']] },
];
let FR = null;
function renderFlowList() {
  $('#flowList').innerHTML = `<p class="hint">Personal automations. Private to you — only outputs can ever be shared.</p>` + WFS.map(w => `<div class="card" style="padding:14px;margin-bottom:12px;cursor:pointer" onclick="openFlow('${w.id}')"><div style="display:flex;align-items:center;gap:8px"><b style="font-size:15.5px;flex:1">${esc(w.name)}</b><span class="pill ${w.life === 'active' ? 'green' : 'gray'}">${w.life === 'active' ? 'Active' : 'Draft'}</span></div><div class="hint" style="margin:6px 0 10px">${esc(w.desc)}</div><div style="display:flex;align-items:center;gap:6px;color:var(--text2);font-size:12px"><span style="color:var(--amber)">${icon('bolt', 14)}</span>${esc(w.trigger)}<span style="margin-left:10px">${icon('flow', 14)}</span>${w.nodes.length} steps<button class="btn sm primary" style="margin-left:auto" onclick="event.stopPropagation();openFlow('${w.id}',true)">Run</button></div></div>`).join('') + `<button class="btn block" onclick="newWorkflow()">${icon('plus', 16)}&nbsp; New workflow</button>`;
}
function newWorkflow() { const w = { id: 'w' + NOW(), name: 'Untitled workflow', desc: 'New draft — add steps in the builder.', life: 'draft', trigger: 'Manual run', nodes: [{ id: 'n1', t: 'Manual trigger', c: 'trigger', s: 'Run on demand', x: 30, y: 30 }], edges: [] }; WFS.unshift(w); renderFlowList(); openFlow(w.id); openBuilder(); }
function openFlow(id, run) { const w = WFS.find(x => x.id === id); stopFlow(); FR = { wf: w, st: {}, status: 'idle', tok: 0, t: {} }; w.nodes.forEach(n => FR.st[n.id] = 'idle'); $('#frLiveT').textContent = 'Ready to run'; liveText('Tap Run to start this workflow.'); chart(0); renderFlow(); openPage('flowrun'); if (run) setTimeout(runFlow, 350); }
function stopFlow() { if (FR) FR.tok++; }
function leaveFlow() { stopFlow(); back(); }
function liveText(s) { $('#frLive').textContent = s; }
function chart(p) { const all = [0, .12, .1, .3, .22, .5, .42, .7, .62, .9, .8, 1], pts = all.slice(0, 2 + Math.round(p * 10)), d = pts.map((v, i) => `${i === 0 ? 'M' : 'L'}${(i / 11 * 300).toFixed(0)} ${(60 - v * 46).toFixed(0)}`).join(' '), last = pts.length - 1; $('#frPath').setAttribute('d', d); $('#frArea').setAttribute('d', d + ` L${(last / 11 * 300).toFixed(0)} 66 L0 66 Z`); }
function renderFlow() {
  const w = FR.wf; $('#frSub').textContent = { idle: w.name, running: 'Running your workflow...', waiting: 'Paused — waiting for your approval', done: 'Completed', cancelled: 'Cancelled' }[FR.status];
  $('#frSteps').innerHTML = w.nodes.map(n => { const s = FR.st[n.id], ic = (NODE_STYLE[n.c] || NODE_STYLE.action)[1], cls = { idle: 'wait', run: 'run', done: 'done', wait: 'appr', cancel: 'skip', skip: 'skip' }[s], sub = { idle: 'Waiting...', run: 'In progress · ' + (FR.t[n.id] || ''), done: 'Completed · ' + (FR.t[n.id] || ''), wait: 'Waiting for your approval', cancel: 'Cancelled', skip: 'Skipped' }[s];
    return `<div class="step ${cls}"><div class="dot">${s === 'done' ? icon('check', 16) : s === 'wait' ? icon('lock', 14) : icon(ic, 14)}</div><div><b>${esc(n.t)}</b><small>${sub}</small></div></div>`; }).join('');
  $('#frBanner').style.display = FR.status === 'waiting' ? 'flex' : 'none';
  const b = $('#frBtn'), live = FR.status === 'running' || FR.status === 'waiting'; b.textContent = live ? 'Cancel' : (FR.status === 'idle' ? 'Run now' : 'Run again'); b.className = 'btn block' + (live ? '' : ' primary');
}
function flowBtn() { (FR.status === 'running' || FR.status === 'waiting') ? cancelFlow() : runFlow(); }
const STEP_TXT = { trigger: 'Parsing your request...', data: 'Collecting campaign data...', ai: 'Analyzing campaign performance data...', output: 'Generating report...', approval: 'Waiting for your approval to publish...', storage: 'Saving to your Vault...', logic: 'Evaluating condition...', action: 'Running action...' };
async function runFrom(start, tok) {
  const w = FR.wf;
  for (let i = start; i < w.nodes.length; i++) {
    const n = w.nodes[i]; if (tok !== FR.tok) return; FR.st[n.id] = 'run'; FR.t[n.id] = fmtTime(NOW()); liveText(STEP_TXT[n.c] || 'Working...'); $('#frLiveT').textContent = n.t; chart(i / w.nodes.length); renderFlow(); await sleep(1000); if (tok !== FR.tok) return;
    if (n.c === 'approval') { FR.st[n.id] = 'wait'; FR.status = 'waiting'; FR.pending = i; liveText('Waiting for your approval to publish...'); renderFlow(); return; }
    FR.st[n.id] = 'done'; FR.t[n.id] = fmtTime(NOW());
  }
  finishFlow();
}
function runFlow() { stopFlow(); const tok = ++FR.tok; FR.t = {}; FR.wf.nodes.forEach(n => FR.st[n.id] = 'idle'); FR.status = 'running'; renderFlow(); chart(0); runFrom(0, tok); }
function resumeFlow() { const tok = ++FR.tok, i = FR.pending, n = FR.wf.nodes[i]; FR.st[n.id] = 'done'; FR.t[n.id] = fmtTime(NOW()); FR.status = 'running'; renderFlow(); runFrom(i + 1, tok); }
function finishFlow() { FR.status = 'done'; chart(1); $('#frLiveT').textContent = 'Completed'; liveText('All steps completed. The result was saved to your Vault.'); if (FR.wf.id === 'w1') OUTPUTS[0].ts = NOW(); renderFlow(); toast('Workflow completed'); }
function cancelFlow() { stopFlow(); FR.wf.nodes.forEach(n => { if (['run', 'idle', 'wait'].includes(FR.st[n.id])) FR.st[n.id] = 'cancel'; }); FR.status = 'cancelled'; $('#frLiveT').textContent = 'Cancelled'; liveText('This run was cancelled. Nothing was published.'); renderFlow(); toast('Run cancelled'); }
function apprDecide(ok) {
  closeSheets(); const a = agentById('a1');
  if (a.approval) { a.approval = false; a.state = ok ? 'working' : 'idle'; a.activity = ok ? 'Publishing update' : 'Update cancelled by user'; a.messages.push(mk(false, ok ? 'You approved: Publish performance update. Resuming workflow…' : 'You rejected: Publish performance update. The workflow was cancelled.', { sys: true })); if (ok) a.messages.push(mk(false, "Got it — publishing now. I'll notify you once it's live.")); if (curAgent === a) renderAgentChat(); refreshLists(); }
  if (FR && FR.status === 'waiting') { if (ok) resumeFlow(); else { const n = FR.wf.nodes[FR.pending]; FR.st[n.id] = 'cancel'; FR.wf.nodes.slice(FR.pending + 1).forEach(x => FR.st[x.id] = 'skip'); FR.status = 'cancelled'; $('#frLiveT').textContent = 'Rejected'; liveText('You rejected the approval. Nothing was published.'); renderFlow(); } }
  toast(ok ? 'Approved' : 'Rejected');
}

let bSel = null, bDrag = null, bConn = null;
const bW = () => FR.wf;
function openBuilder() { buildCanvas(); openPage('builder'); }
function buildCanvas() {
  const c = $('#bCanvas'); $$('.bnode', c).forEach(n => n.remove());
  bW().nodes.forEach(n => { const [col, ic] = NODE_STYLE[n.c] || NODE_STYLE.action, el = document.createElement('div'); el.className = 'bnode'; el.id = 'bn_' + n.id; el.style.left = n.x + 'px'; el.style.top = n.y + 'px';
    el.innerHTML = `<div class="bi" style="background:${col}">${icon(ic, 16, 'stroke="#fff"')}</div><div><p>${esc(n.t)}</p><span>${esc(n.s)}${n.cond ? ' · ' + n.cond.type : ''}</span></div><div class="bhandle" data-h="${n.id}">${icon('plus', 12)}</div>`; c.appendChild(el); });
  if (!c._wired) { c._wired = true; c.addEventListener('pointerdown', bDown); c.addEventListener('pointermove', bMove); c.addEventListener('pointerup', bUp); }
  bSel = null; bToolUpdate(); drawEdges();
}
const bCenter = (id, bottom) => { const e = $('#bn_' + id); return { x: e.offsetLeft + e.offsetWidth / 2, y: bottom ? e.offsetTop + e.offsetHeight : e.offsetTop }; };
function drawEdges() { let h = ''; bW().edges.forEach(([a, b]) => { if (!$('#bn_' + a) || !$('#bn_' + b)) return; const p = bCenter(a, true), q = bCenter(b, false), m = (p.y + q.y) / 2; h += `<path d="M${p.x} ${p.y} C ${p.x} ${m} ${q.x} ${m} ${q.x} ${q.y}" stroke="#B9C3E0" stroke-width="2" fill="none"/>`; }); if (bConn && bConn.to) h += `<path d="M${bConn.x} ${bConn.y} L ${bConn.to.x} ${bConn.to.y}" stroke="#2F7BF5" stroke-width="2.4" fill="none"/>`; $('#wireSvg').innerHTML = h; }
function bDown(ev) { const hd = ev.target.closest('.bhandle'), nd = ev.target.closest('.bnode'); if (hd) { const id = hd.dataset.h, c = bCenter(id, true); bConn = { id, x: c.x, y: c.y, to: { x: c.x, y: c.y } }; ev.stopPropagation(); return; } if (nd) { const id = nd.id.slice(3); bSelect(id); bDrag = { id, sx: ev.clientX, sy: ev.clientY, ox: nd.offsetLeft, oy: nd.offsetTop }; } else bSelect(null); }
function bMove(ev) { const c = $('#bCanvas'), r = c.getBoundingClientRect(); if (bConn) { bConn.to = { x: ev.clientX - r.left + c.scrollLeft, y: ev.clientY - r.top + c.scrollTop }; drawEdges(); return; } if (bDrag) { const el = $('#bn_' + bDrag.id), n = bW().nodes.find(x => x.id === bDrag.id); n.x = Math.max(0, bDrag.ox + ev.clientX - bDrag.sx); n.y = Math.max(0, bDrag.oy + ev.clientY - bDrag.sy); el.style.left = n.x + 'px'; el.style.top = n.y + 'px'; drawEdges(); } }
function bUp(ev) { if (bConn) { const t = ev.target.closest('.bnode'); if (t && t.id.slice(3) !== bConn.id) { const to = t.id.slice(3); if (!bW().edges.some(e => e[0] === bConn.id && e[1] === to)) bW().edges.push([bConn.id, to]); } bConn = null; drawEdges(); } bDrag = null; }
function bSelect(id) { bSel = id; $$('.bnode').forEach(n => n.classList.toggle('sel', n.id === 'bn_' + id)); bToolUpdate(); }
function bToolUpdate() { const n = bSel && bW().nodes.find(x => x.id === bSel); $('#bTool').style.display = n ? 'flex' : 'none'; if (n) { $('#bSel').textContent = n.t; $('#bCondBtn').style.display = n.c === 'logic' ? '' : 'none'; } }
function bDelete() { if (!bSel) return; const w = bW(); w.nodes = w.nodes.filter(n => n.id !== bSel); w.edges = w.edges.filter(e => e[0] !== bSel && e[1] !== bSel); delete FR.st[bSel]; buildCanvas(); }
function bAdd() { $('#pickSheet').innerHTML = `<div class="handle"></div><h3 style="margin-bottom:6px">Add node</h3>` + Object.keys(NODE_STYLE).map(k => `<div class="setrow" onclick="bAddType('${k}')"><div class="ic" style="background:${NODE_STYLE[k][0]};color:#fff">${icon(NODE_STYLE[k][1], 17, 'stroke="#fff"')}</div><div class="grow"><b style="text-transform:capitalize">${k}</b></div></div>`).join(''); openSheet('pickSheet'); }
function bAddType(k) { closeSheets(); const w = bW(), id = 'n' + NOW(), y = Math.max(0, ...w.nodes.map(n => n.y)) + 110; w.nodes.push({ id, t: 'New ' + k, c: k, s: 'Tap to configure', x: 30, y }); FR.st[id] = 'idle'; buildCanvas(); }
function bValidate() { const w = bW(), tr = w.nodes.filter(n => n.c === 'trigger').length, iss = []; if (tr === 0) iss.push('No trigger node'); if (tr > 1) iss.push('More than one trigger'); w.nodes.forEach(n => { if (n.c !== 'trigger' && !w.edges.some(e => e[1] === n.id)) iss.push(`"${n.t}" has no incoming connection`); }); toast(iss.length ? 'Validation: ' + iss.join('; ') : 'Looks good — every node is connected from the trigger.'); }
function bCondition() {
  const n = bW().nodes.find(x => x.id === bSel), c = n.cond || { type: 'none', branch: 'Yes', percent: 50 };
  $('#condSheet').innerHTML = `<div class="handle"></div><h3>Branch condition</h3><div class="hint">How should “${esc(n.t)}” choose between its labeled branches?</div><div class="cardlist" id="cdOpts">${[['none', 'Alphabetical (default)', 'First label alphabetically'], ['always', 'Always', 'Always take one branch'], ['probability', 'Probability', 'Take a branch X% of the time'], ['random', 'Random', 'Uniform pick among branches']].map(([k, t, s]) => `<div class="row" onclick="cdPick('${k}')"><span class="rd ${c.type === k ? 'on' : ''}" data-k="${k}"></span><div class="grow"><div class="nm">${t}</div><div class="sb">${s}</div></div></div>`).join('')}</div><div class="field" style="margin-top:12px"><label>Branch label (for Always / Probability)</label><div class="in"><input id="cdBranch" value="${esc(c.branch || 'Yes')}"></div></div><div class="field"><label>Percent (Probability)</label><div class="in"><input id="cdPct" type="number" min="0" max="100" value="${c.percent ?? 50}"></div></div><div class="btnrow"><button class="btn" onclick="closeSheets()">Cancel</button><button class="btn primary" onclick="cdSave()">Save</button></div>`;
  window._cd = c.type; openSheet('condSheet');
}
function cdPick(k) { window._cd = k; $$('#cdOpts .rd').forEach(r => r.classList.toggle('on', r.dataset.k === k)); }
function cdSave() { const n = bW().nodes.find(x => x.id === bSel), t = window._cd; if (t === 'none') delete n.cond; else n.cond = { type: t, branch: $('#cdBranch').value.trim(), percent: Math.min(100, Math.max(0, +$('#cdPct').value || 0)) }; closeSheets(); buildCanvas(); toast(t === 'none' ? 'Condition cleared' : 'Condition saved'); }

[...PEOPLE, ...GROUPS, ...AGENTS].forEach(o => ensureIds(o.messages));
hydrateIcons(); $('#apprAv').innerHTML = agentAv(agentById('a1'), 'sm');
stack.push('welcome'); updateNav(); renderMessages();
