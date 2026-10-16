const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ICONS = {
  chat: '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>',
  user: '<circle cx="12" cy="8" r="3.6"/><path d="M5 20c0-3.6 3.1-6 7-6s7 2.4 7 6"/>',
  users: '<circle cx="9" cy="8.5" r="3"/><path d="M3 19c0-3 2.7-5 6-5s6 2 6 5"/><path d="M16 5.6a3 3 0 0 1 0 5.8M18 14.2c2 .6 3.5 2.4 3.5 4.8"/>',
  flow: '<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><circle cx="6" cy="18" r="2.5"/><path d="M8.5 6H14a3 3 0 0 1 3 3v6.5M8.5 18H14"/>',
  shield: '<path d="M12 3l7 3v5.2c0 4.4-3 7.9-7 9.8-4-1.9-7-5.4-7-9.8V6l7-3z"/><path d="M9 12l2.2 2.2L15.5 10"/>',
  grid: '<circle cx="6" cy="6" r="1.4"/><circle cx="12" cy="6" r="1.4"/><circle cx="18" cy="6" r="1.4"/><circle cx="6" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18" cy="12" r="1.4"/><circle cx="6" cy="18" r="1.4"/><circle cx="12" cy="18" r="1.4"/><circle cx="18" cy="18" r="1.4"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  back: '<path d="M15 5l-7 7 7 7"/>',
  send: '<path d="M12 19V5M5.5 11.5L12 5l6.5 6.5"/>',
  plane: '<path d="M4 12l16-8-6 16-3-7z"/>',
  smile: '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.3a4.5 4.5 0 0 0 7 0M9 9.6h.01M15 9.6h.01"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  checks: '<path d="M2.5 12.5l4.5 4.5L15 8.5M10 16l1 1L21 7"/>',
  chev: '<path d="M9 5l7 7-7 7"/>',
  copy: '<rect x="9" y="9" width="11" height="11" rx="2.5"/><path d="M5 15V6.5A2.5 2.5 0 0 1 7.5 4H15"/>',
  camera: '<path d="M4 8.5h3l1.8-2.5h6.4L17 8.5h3V19H4z"/><circle cx="12" cy="13.5" r="3.4"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  bell: '<path d="M6 16v-4.5a6 6 0 0 1 12 0V16l1.6 2H4.4zM10 21h4"/>',
  file: '<path d="M7 3h7l5 5v13H7z"/><path d="M14 3v5h5"/>',
  image: '<rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="M20 16l-5-5-8 8"/>',
  download: '<path d="M12 4v11M7 11l5 5 5-5M5 20h14"/>',
  mega: '<path d="M4 10v4h3.5l7.5 4V6L7.5 10H4zM18 9a4 4 0 0 1 0 6"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M21 20H3"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
  heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
  edit: '<path d="M4 20l1-4.2L16.5 4.3l3.2 3.2L8.2 19z"/><path d="M14.5 6.3l3.2 3.2"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 5v6h-6"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  trash: '<path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/>',
  pin: '<path d="M9 4h6l-1 6 3 3H7l3-3zM12 13v7"/>',
  sliders: '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.6a2.5 2.5 0 1 1 3.4 2.3c-.7.4-1 1-1 1.7M12 17h.01"/>',
  mail: '<rect x="3" y="6" width="18" height="12" rx="2.5"/><path d="M3.5 8l8.5 6 8.5-6"/>',
  phone: '<path d="M6.5 4h3l1.5 4-2 1.5a10 10 0 0 0 5.5 5.5L16 13l4 1.5v3a2 2 0 0 1-2 2A14 14 0 0 1 4.5 6a2 2 0 0 1 2-2z"/>',
  kebab: '<circle cx="12" cy="5.5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="18.5" r="1.4"/>',
  sparkle: '<path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z"/>',
  bolt: '<path d="M13 3L5 14h6l-1 7 8-11h-6z"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3A4 4 0 0 0 11 18.7l1-1"/>',
  logout: '<path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4M15 8l4 4-4 4M19 12H9"/>',
  note: '<path d="M6 3h9l4 4v14H6z"/><path d="M9 11h7M9 15h5"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/>',
};
function icon(name, s = 20, extra = '') { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" ${extra}>${ICONS[name] || ''}</svg>`; }
function hydrateIcons(root = document) { $$('[data-i]', root).forEach(el => { const st = el.getAttribute('style'); el.outerHTML = icon(el.dataset.i, +el.dataset.s || 20, st ? `style="${st}"` : ''); }); }
let toastT;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), 2300); }

const stack = [];
let curTab = 'msg';
function updateNav() {
  const top = stack.length ? $('#pg-' + stack[stack.length - 1]) : null;
  const welcome = ['welcome', 'createid', 'phrase'].some(p => stack.includes(p));
  $('#tabbar').classList.toggle('hide', welcome || (!!top && !top.classList.contains('withnav')));
}
function go(tab) {
  curTab = tab; stack.splice(0).forEach(id => $('#pg-' + id).classList.remove('open'));
  $$('.root').forEach(r => r.classList.toggle('active', r.id === 'root-' + tab));
  $$('#tabbar button').forEach(b => b.classList.toggle('on', b.dataset.t === tab));
  ({ msg: renderMessages, agents: renderAgentCenter, flow: renderFlowList, vault: renderVault, more: renderProfile }[tab])();
  updateNav();
}
function openPage(id) {
  const el = $('#pg-' + id); if (!el) return;
  if (stack[stack.length - 1] === id) return;
  if (stack.includes(id)) stack.splice(stack.indexOf(id), 1);
  const init = { contacts: renderContactsPage, newchat: renderNewChat, search: renderSearch, consent: renderConsent, connectors: renderConnectors, createid: initCreateId, creategroup: initCreateGroup }[id];
  if (init) init();
  el.classList.add('open'); stack.push(id); updateNav();
}
function back() { closeSheets(); const id = stack.pop(); if (!id) return; $('#pg-' + id).classList.remove('open'); updateNav(); refreshLists(); }
function closePage(id) { const i = stack.indexOf(id); if (i > -1) { stack.splice(i, 1); $('#pg-' + id).classList.remove('open'); updateNav(); } }
function refreshLists() { renderMessages(); if ($('#pg-contacts').classList.contains('open')) renderContactsPage(); if (curTab === 'agents') renderAgentCenter(); }
function openSheet(id) { closeSheets(); $('#bd').classList.add('open'); $('#' + id).classList.add('open'); }
function closeSheets() { $('#bd').classList.remove('open'); $$('.sheet').forEach(s => s.classList.remove('open')); }

const NOW = () => Date.now();
const ago = m => NOW() - m * 60000;
const p2 = n => ('0' + n).slice(-2);
const fmtTime = ts => { const d = new Date(ts); return p2(d.getHours()) + ':' + p2(d.getMinutes()); };
const dayKey = ts => { const d = new Date(ts); return d.getFullYear() + '-' + d.getMonth() + '-' + d.getDate(); };
const dayLabel = ts => dayKey(ts) === dayKey(NOW()) ? 'Today' : dayKey(ts) === dayKey(NOW() - 864e5) ? 'Yesterday' : new Date(ts).toLocaleDateString([], { day: 'numeric', month: 'short' });
const listTime = ts => dayKey(ts) === dayKey(NOW()) ? fmtTime(ts) : dayLabel(ts);
const sleep = ms => new Promise(r => setTimeout(r, ms));

const PASTELS = [['#E6E9FF', '#4B5CF0'], ['#E0F5EA', '#16A34A'], ['#FFEBD6', '#D9730D'], ['#FBE4F0', '#C2327D'], ['#DDF3FA', '#0E8AA8'], ['#EFE7FF', '#7C5CFF']];
const hash = s => [...String(s)].reduce((a, c) => (a * 31 + c.charCodeAt(0)) >>> 0, 7);
const initialsOf = n => { const p = String(n).trim().split(/\s+/); return ((p[0] || '?')[0] + (p[1] ? p[1][0] : (p[0][1] || ''))).toUpperCase(); };
const personAv = (name, size = '', presence = false) => { const [bg, fg] = PASTELS[hash(name) % PASTELS.length]; return `<div class="av ${size}" style="background:${bg};color:${fg}">${esc(initialsOf(name))}${presence ? '<i class="pres"></i>' : ''}</div>`; };
const groupAv = (size = '') => `<div class="av ${size}" style="background:#E5EEFF;color:#2F7BF5">${icon('users', size === 'lg' ? 32 : size === 'sm' ? 18 : 22)}</div>`;
const AGENT_STYLE = {
  'Marketing Agent': ['#8B5CF6', 'mega', 'Marketing & Content'], 'Research Agent': ['#3B82F6', 'search', 'Research & Analysis'],
  'Finance Agent': ['#22C55E', 'chart', 'Finance & Accounting'], 'Personal Assistant': ['#F59E0B', 'clock', 'Daily Life & Productivity'],
  'Health Coach': ['#F43F5E', 'heart', 'Fitness, nutrition, wellness'], 'Content Creator': ['#14B8A6', 'edit', 'Content & Social Media'],
  'Travel Agent': ['#0EA5E9', 'globe', 'Flights & hotels'], 'Itinerary Agent': ['#6366F1', 'clock', 'Daily itineraries'],
};
const AGENT_COLORS = ['#8B5CF6', '#3B82F6', '#22C55E', '#F59E0B', '#F43F5E', '#14B8A6', '#6366F1', '#0EA5E9'];
const agentStyle = a => { const s = AGENT_STYLE[a.name]; return s ? { color: s[0], ic: s[1], tag: s[2] } : { color: AGENT_COLORS[hash(a.name) % AGENT_COLORS.length], ic: 'sparkle', tag: a.role || 'Custom agent' }; };
const agentAv = (a, size = '') => { const st = agentStyle(a), px = size === 'sm' ? 34 : size === 'xs' ? 30 : size === 'lg' ? 72 : 46; return `<div class="av ag ${size}" style="background:${st.color}">${icon(st.ic, Math.round(px * .5), 'stroke="#fff"')}</div>`; };
const orchAv = (px = 46) => `<div class="av" style="width:${px}px;height:${px}px;background:var(--grad-msg);color:#fff">${icon('sparkle', Math.round(px * .48))}</div>`;
const AGENT_STATE = { working: ['', 'Active'], ready: ['', 'Active'], approval: ['appr', 'Approval required'], scheduled: ['warn', 'Scheduled'], idle: ['idle', 'Idle'] };
const agentStatusHTML = a => { const [c, l] = AGENT_STATE[a.state] || ['idle', 'Idle']; return `<div class="st ${c}"><i></i>${l}</div>`; };
