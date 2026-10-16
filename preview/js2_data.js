let mid = 0;
const mk = (me, t, extra) => Object.assign({ id: 'm' + (++mid), me, t, ts: NOW(), status: me ? 'sent' : undefined }, extra || {});
const ME = { name: 'Clips', id: 'clips_indie' };
const PEOPLE = [
  { id: 'p1', kind: 'person', name: 'Alex Johnson', info: 'alex@indie.id', group: 'Work', online: true, pinned: true, muted: false, unread: 0, seen: 'Online',
    messages: [{ me: false, t: "Hey, let's discuss the report", ts: ago(75) }, { me: true, t: 'Sure! I just sent the latest numbers.', ts: ago(70), status: 'read' }, { me: false, type: 'file', file: { name: 'Campaign-Report.pdf', size: '2.4 MB' }, ts: ago(41) }, { id: 'sd4', me: true, t: "Great! Let's review it in the next meeting.", ts: ago(38), status: 'read', rx: { '👍': 1 } }, { me: false, t: 'Sounds good, see you at 3', ts: ago(35), replyTo: { id: 'sd4', who: 'You', t: "Great! Let's review it in the next meeting." } }] },
  { id: 'p2', kind: 'person', name: 'Sarah Wilson', info: 'sarah@indie.id', group: 'Clients', online: true, pinned: false, muted: false, unread: 1, seen: 'Online', messages: [{ me: false, t: "Sounds good! Let's proceed with the plan.", ts: ago(190) }] },
  { id: 'p3', kind: 'person', name: 'Michael Tan', info: 'michael@indie.id', group: '', online: false, pinned: false, muted: false, unread: 0, seen: 'Last seen 10m ago', messages: [{ me: false, t: 'Thanks for the update.', ts: ago(400) }] },
  { id: 'p4', kind: 'person', name: 'Emma Davis', info: 'emma@indie.id', group: 'Work', online: true, pinned: false, muted: false, unread: 0, seen: 'Online', messages: [{ me: false, t: 'Great!', ts: ago(520) }] },
  { id: 'p5', kind: 'person', name: 'Lisa Chen', info: 'lisa@indie.id', group: '', online: false, pinned: false, muted: false, unread: 0, seen: 'Offline', messages: [] },
  { id: 'p6', kind: 'person', name: 'David Kim', info: 'david@indie.id', group: 'Work', online: false, pinned: false, muted: false, unread: 0, seen: 'Offline', messages: [{ me: false, t: 'Project update', ts: ago(1500) }] },
  { id: 'p7', kind: 'person', name: 'Mom', info: '+62 812-0000-1111', group: 'Family', online: false, pinned: false, muted: false, unread: 0, seen: 'Offline', messages: [{ me: false, t: 'See you later! ❤️', ts: ago(1700) }] },
  { id: 'p8', kind: 'person', name: 'Rudi Santoso', info: 'rudi@indie.id', group: 'Clients', online: false, pinned: false, muted: false, unread: 0, seen: 'Offline', messages: [] },
];
const GROUPS = [
  { id: 'g1', kind: 'group', name: 'Team Marketing', desc: 'Campaign planning and weekly syncs.', vis: 'private', allowNew: true, members: ['p1', 'p2', 'p4', 'p6'], muted: false, pinned: false, unread: 0,
    messages: [{ me: false, from: 'Alex Johnson', type: 'file', file: { name: 'Campaign Report.pdf', size: '2.4 MB' }, ts: ago(300) }, { me: false, from: 'Alex Johnson', t: "Here's the latest campaign update.", ts: ago(299) }, { me: true, t: "Great! Let's review it in the next meeting.", ts: ago(290), status: 'read' }, { me: false, from: 'Sarah Wilson', t: "I'll also share the creative brief shortly.", ts: ago(120), rx: { '👍': 1 } }, { me: false, from: 'Emma Davis', t: 'Campaign update meeting at 10 AM.', ts: ago(30) }] },
  { id: 'g2', kind: 'group', name: 'Family', desc: 'Family chat', vis: 'private', allowNew: false, members: ['p7'], muted: false, pinned: false, unread: 0, messages: [{ me: false, from: 'Mom', t: 'Dinner at 7?', ts: ago(1900) }] },
];
const CHATS = [...PEOPLE, ...GROUPS];
const chatById = id => CHATS.find(c => c.id === id);
const personById = id => PEOPLE.find(p => p.id === id);
const AGENTS = [
  { id: 'a1', name: 'Marketing Agent', role: 'Campaign monitoring & reporting', state: 'approval', activity: 'Wants to publish Campaign Alpha update', approval: true,
    workflow: ['Read campaign analytics', 'Generate report', 'Notify you', 'Ask your approval before publishing'],
    messages: [{ me: true, t: "Can you create a summary of last week's campaign performance?", ts: ago(34), status: undefined },
      { me: false, t: "I've analyzed the data and here's your weekly campaign summary:", ts: ago(33) },
      { me: false, type: 'card', ts: ago(32), card: { title: 'Campaign Performance', metrics: [['Total Reach', '124.5K', '↑ 12.4%'], ['Engagement Rate', '4.8%', '↑ 2.1%'], ['Conversions', '2.3K', '↑ 8.7%'], ['Spend', 'Rp 8.2jt', '']], insights: ['Instagram performed best (CTR 5.2%)', 'Audience engagement increased by 12.4%', 'Conversion rate improved by 8.7%'] } },
      { me: false, type: 'file', file: { name: 'Weekly Report.pdf', size: '2.4 MB' }, ts: ago(31) }] },
  { id: 'a2', name: 'Research Agent', role: 'Market & competitor research', state: 'working', activity: 'Researching competitor pricing', workflow: ['Search public web data', 'Summarize findings', 'Report results to you'], messages: [{ me: false, t: 'Found 5 new insights for your project.', ts: ago(55) }] },
  { id: 'a3', name: 'Finance Agent', role: 'Invoices & cash flow', state: 'scheduled', activity: 'Next run tomorrow 08:00', workflow: ['Read invoices', 'Calculate weekly cash flow', 'Save report to Vault'], messages: [{ me: false, t: 'Your expense summary is ready.', ts: ago(300) }] },
  { id: 'a4', name: 'Personal Assistant', role: 'Scheduling & daily brief', state: 'idle', activity: 'Idle', workflow: ['Read your calendar', 'Summarize unread emails', 'Prepare daily brief', 'Send reminders'], messages: [] },
  { id: 'a5', name: 'Health Coach', role: 'Fitness, nutrition, wellness', state: 'scheduled', activity: 'Morning workout reminder', workflow: ['Plan workouts', 'Track habits', 'Send reminders'], messages: [{ me: false, t: 'Time for your morning workout! 💪', ts: ago(1440) }] },
  { id: 'a6', name: 'Content Creator', role: 'Content & social media', state: 'ready', activity: 'Ready — waiting for tasks', workflow: ['Draft posts', 'Suggest hashtags', 'Ask your approval before publishing'], messages: [] },
];
const agentById = id => AGENTS.find(a => a.id === id);
const TEMPLATES = [
  { name: 'Marketing Agent', desc: 'monitor campaigns and report performance weekly' }, { name: 'Research Agent', desc: 'research competitors and summarize findings' },
  { name: 'Finance Agent', desc: 'track invoices and summarize cash flow' }, { name: 'Personal Assistant', desc: 'read my calendar and prepare a daily brief' },
  { name: 'Health Coach', desc: 'plan workouts and remind me every morning' }, { name: 'Content Creator', desc: 'draft social media posts for my brand' },
];
const OUTPUTS = [
  { id: 'o1', name: 'Weekly Marketing Report.pdf', ext: 'pdf', kind: 'Report', ts: ago(30), summary: 'Reach up 12.4%, engagement 4.8%, conversions 2.3K this week.', ai: 'Instagram performed best; no action needed today.', raw: 'campaign_alpha_metrics.json · updated this morning', activity: ['Fetched campaign analytics', 'Compared to 7-day average', 'Drafted summary'] },
  { id: 'o2', name: 'Project Plan.docx', ext: 'docx', kind: 'Document', ts: ago(1500), summary: 'Draft project plan for Q4 launch.', ai: 'Milestones look realistic; two dependencies flagged.', raw: 'plan_v3.docx', activity: ['Read brief', 'Structured milestones'] },
  { id: 'o3', name: 'Meeting Notes.txt', ext: 'txt', kind: 'Note', ts: ago(1560), summary: 'Notes from the weekly sync.', ai: 'Three action items identified.', raw: 'notes.txt', activity: ['Transcribed notes'] },
  { id: 'o4', name: 'Personal Photo.jpg', ext: 'jpg', kind: 'Image', ts: ago(2900), summary: 'Photo stored in your vault.', ai: 'No analysis available for images.', raw: 'IMG_2041.jpg', activity: [] },
  { id: 'o5', name: 'Bank Statement.pdf', ext: 'pdf', kind: 'Report', ts: ago(4400), summary: 'Monthly bank statement.', ai: 'Spending is 6% below last month.', raw: 'statement.pdf', activity: ['Read statement', 'Categorized spending'] },
  { id: 'o6', name: 'Travel Plan.pdf', ext: 'pdf', kind: 'Report', ts: ago(5800), summary: '7-day family trip plan.', ai: 'Budget estimate Rp 32.6jt.', raw: 'travel.pdf', activity: ['Combined agent results'] },
];
const EXT = { pdf: ['#EF4444', 'file'], docx: ['#3B82F6', 'file'], txt: ['#60A5FA', 'note'], jpg: ['#22C55E', 'image'] };
const NOTES = [{ id: 'n1', title: 'Campaign ideas', text: 'Short videos for Instagram, collab with two creators.', ts: ago(900) }, { id: 'n2', title: 'Reminders', text: 'Renew domain before Friday.', ts: ago(3000) }];
const MEMORIES = [{ agent: 'a1', note: 'Prefers concise report tone' }, { agent: 'a1', note: 'Campaign Alpha runs through Oct 30' }, { agent: 'a2', note: 'Focus: SME SaaS pricing in the ID market' }, { agent: 'a4', note: 'Prefers Bahasa Indonesia in the morning brief' }];
const MANDATES = [{ id: 'mm1', agent: 'a1', purpose: 'Campaign monitoring — read analytics, generate report', autonomy: 'Daily at 09:00', status: 'active' }, { id: 'mm2', agent: 'a2', purpose: 'Competitor research — public web only', autonomy: 'Manual only', status: 'paused' }];
const CONNECTORS = [{ id: 'google_calendar', name: 'Google Calendar', desc: 'Read-only — Personal Assistant reads your calendar', ic: 'clock', on: false }, { id: 'gmail', name: 'Gmail', desc: 'Read-only — summarize unread emails', ic: 'mail', on: false }, { id: 'google_drive', name: 'Google Drive', desc: 'Read-only — list your recent files', ic: 'file', on: false }];
