const crypto = require('node:crypto');
const db = require('../db');

function uuid() {
  return crypto.randomUUID();
}


function minsAgo(m) {
  return new Date(Date.now() - m * 60000).toISOString();
}

function cMsg(userId, contactId, sender, text, minutes, extra = {}) {
  const id = extra.id || uuid();
  db.prepare(
    `INSERT INTO contact_messages (id, user_id, contact_id, sender, text, created_at, kind, payload_json, status, reply_to_id, reactions_json, my_reaction)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    id, userId, contactId, sender, text, minsAgo(minutes), extra.kind || 'text',
    extra.payload ? JSON.stringify(extra.payload) : null,
    sender === 'user' ? extra.status || 'read' : null,
    extra.replyTo || null, JSON.stringify(extra.reactions || {}), extra.myReaction || null
  );
  return id;
}

function aMsg(userId, agentId, sender, kind, text, minutes, payload) {
  db.prepare(
    `INSERT INTO agent_messages (id, user_id, agent_id, sender, kind, text, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(uuid(), userId, agentId, sender, kind, text, payload ? JSON.stringify(payload) : null, minsAgo(minutes));
}

function setSteps(userId, agentId, steps) {
  steps.forEach((step, i) =>
    db.prepare('INSERT INTO agent_workflow_steps (id, user_id, agent_id, position, step) VALUES (?, ?, ?, ?, ?)').run(uuid(), userId, agentId, i, step)
  );
}

/**
 * Populates a new account with the same demo content as the Flutter app's
 * MockData (mock_data.dart), so a fresh Personal ID has something to look
 * at immediately — contacts, agents, one active workflow with a live
 * approval node, a paused mandate, and two vault outputs.
 */
function seedDemoData(userId) {
  const now = new Date().toISOString();

  // Contacts (info/group/pinned/unread + rich messages: file, reply, reaction, shared result)
  const alexId = uuid();
  db.prepare(
    "INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at, info, grp) VALUES (?, ?, 'Alex Rahman', 'AR', 'Online', 1, ?, 'alex@indie.id', 'Work')"
  ).run(alexId, userId, now);
  cMsg(userId, alexId, 'contact', 'Did the campaign report go out?', 58);
  cMsg(userId, alexId, 'user', 'Yep, agent sent it this morning ✅', 55);
  cMsg(userId, alexId, 'contact', '', 41, { kind: 'file', payload: { file: { name: 'Campaign-Report.pdf', size: '2.4 MB' } } });
  const greatId = cMsg(userId, alexId, 'user', "Great! Let's review it in the next meeting.", 38, { reactions: { '👍': 1 } });
  cMsg(userId, alexId, 'contact', 'Sure, see you at 3', 35, { replyTo: greatId });

  const sarahId = uuid();
  db.prepare(
    "INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at, info, grp, unread) VALUES (?, ?, 'Sarah Putri', 'SP', 'Last seen 2h ago', 0, ?, 'sarah@indie.id', '', 1)"
  ).run(sarahId, userId, now);
  cMsg(userId, sarahId, 'contact', 'Send me the vault link when ready', 190);

  const familyId = uuid();
  db.prepare(
    "INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at, info, grp) VALUES (?, ?, 'Family', 'FM', '4 members', 0, ?, 'Group · 4 members', 'Family')"
  ).run(familyId, userId, now);
  cMsg(userId, familyId, 'contact', 'Dinner at 7?', 360);

  // Agents
  const marketingId = uuid();
  db.prepare(
    `INSERT INTO agents (id, user_id, name, role, glyph, accent_hex, state, current_activity, created_at)
     VALUES (?, ?, 'Marketing Agent', 'Campaign monitoring & reporting', 'M', '2FE4DB', 'waitingApproval', 'Wants to publish Campaign Alpha update', ?)`
  ).run(marketingId, userId, now);
  ['Read campaign analytics', 'Generate report', 'Notify user'].forEach((label) =>
    db.prepare('INSERT INTO agent_permissions (id, user_id, agent_id, label) VALUES (?, ?, ?, ?)').run(uuid(), userId, marketingId, label)
  );
  ['09:00 — Trigger activated', '09:00 — Campaign data requested', '09:03 — Analysis completed', '09:04 — Approval requested: publish update'].forEach(
    (label) => db.prepare('INSERT INTO agent_activity_log (id, user_id, agent_id, label, created_at) VALUES (?, ?, ?, ?, ?)').run(uuid(), userId, marketingId, label, now)
  );
  db.prepare('INSERT INTO agent_memory (id, user_id, agent_id, note, created_at) VALUES (?, ?, ?, ?, ?)').run(
    uuid(), userId, marketingId, 'Prefers concise report tone', now
  );
  setSteps(userId, marketingId, ['Read campaign analytics', 'Generate report', 'Notify you', 'Ask your approval before publishing']);
  aMsg(userId, marketingId, 'agent', 'text', 'Analysis of Campaign Alpha is done. Summary below:', 22);
  aMsg(userId, marketingId, 'agent', 'card', '', 21, {
    card: {
      title: 'Campaign Performance',
      metrics: [['Total reach', '124.5K', '↑ 12.4%'], ['Engagement rate', '4.8%', '↑ 2.1%']],
      insights: ['Instagram performed best (CTR 5.2%)', 'Audience engagement increased by 12.4%', 'Conversion rate improved by 8.7%'],
    },
  });
  aMsg(userId, marketingId, 'agent', 'approvalRequest', 'Marketing Agent wants to publish an update for Campaign Alpha.', 6, { workflow: 'Daily Marketing Report' });

  const researchId = uuid();
  db.prepare(
    `INSERT INTO agents (id, user_id, name, role, glyph, accent_hex, state, current_activity, created_at)
     VALUES (?, ?, 'Research Agent', 'Market & competitor research', 'R', '5AA9FF', 'working', 'Researching competitor pricing', ?)`
  ).run(researchId, userId, now);
  ['Read public web data', 'Summarize findings'].forEach((label) =>
    db.prepare('INSERT INTO agent_permissions (id, user_id, agent_id, label) VALUES (?, ?, ?, ?)').run(uuid(), userId, researchId, label)
  );
  setSteps(userId, researchId, ['Search public web data', 'Summarize findings', 'Report results to you']);
  aMsg(userId, researchId, 'agent', 'text', 'Started researching competitor pricing, back to you shortly.', 20);

  const financeId = uuid();
  db.prepare(
    `INSERT INTO agents (id, user_id, name, role, glyph, accent_hex, state, current_activity, created_at)
     VALUES (?, ?, 'Finance Agent', 'Invoices & cash flow', 'F', '34D399', 'scheduled', 'Next run tomorrow 08:00', ?)`
  ).run(financeId, userId, now);
  ['Read invoices', 'Generate report'].forEach((label) =>
    db.prepare('INSERT INTO agent_permissions (id, user_id, agent_id, label) VALUES (?, ?, ?, ?)').run(uuid(), userId, financeId, label)
  );
  setSteps(userId, financeId, ['Read invoices', 'Calculate weekly cash flow', 'Save report to Vault']);
  aMsg(userId, financeId, 'agent', 'text', 'Weekly cash flow summary is ready in your Vault.', 2900);
  aMsg(userId, financeId, 'agent', 'card', '', 2899, {
    card: { title: 'Cash Flow Report — Week 39', metrics: [['Net cash flow', 'Rp 18.4jt', '↑ 6%'], ['Outstanding', '3 invoices', '']], insights: ['3 invoices still outstanding', 'Cash position improved week-over-week'] },
  });

  // Workflow: Daily Marketing Report (active, with an approval node)
  const wfId = uuid();
  db.prepare(
    `INSERT INTO workflows (id, user_id, name, description, version, lifecycle, trigger_summary, created_at, updated_at)
     VALUES (?, ?, 'Daily Marketing Report', 'Monitors Campaign Alpha, analyzes performance and drafts an update.', 'v1.3', 'active', 'Every day at 09:00', ?, ?)`
  ).run(wfId, userId, now, now);

  const nodeDefs = [
    ['Daily schedule', 'trigger', '09:00 every day', 40, 40],
    ['Get campaign data', 'data', 'Campaign Alpha analytics', 40, 150],
    ['Marketing Agent', 'ai', 'Analyze performance', 40, 260],
    ['Threshold check', 'logic', 'CTR dropped > 10%?', 40, 370],
    ['Publish update', 'approval', 'Requires approval', 40, 480],
    ['Save to Vault', 'storage', 'Report + summary', 40, 590],
  ];
  const nodeIds = nodeDefs.map(([title, category, subtitle, x, y]) => {
    const id = uuid();
    db.prepare(
      'INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(id, userId, wfId, title, category, subtitle, x, y);
    return id;
  });
  for (let i = 0; i < nodeIds.length - 1; i++) {
    db.prepare(
      'INSERT INTO workflow_connections (id, user_id, workflow_id, from_node_id, to_node_id) VALUES (?, ?, ?, ?, ?)'
    ).run(uuid(), userId, wfId, nodeIds[i], nodeIds[i + 1]);
  }

  // Second workflow: Weekly Cash Flow Summary
  const wf2Id = uuid();
  db.prepare(
    `INSERT INTO workflows (id, user_id, name, description, version, lifecycle, trigger_summary, created_at, updated_at)
     VALUES (?, ?, 'Weekly Cash Flow Summary', 'Reads invoices, calculates cash flow, saves a report.', 'v1.0', 'active', 'Every Monday at 08:00', ?, ?)`
  ).run(wf2Id, userId, now, now);
  const wf2NodeDefs = [
    ['Weekly schedule', 'trigger', 'Mondays 08:00', 40, 40],
    ['Read invoices', 'data', 'Vault: Finance', 40, 150],
    ['Finance Agent', 'ai', 'Summarize cash flow', 40, 260],
    ['Save report', 'storage', 'Vault: Reports', 40, 370],
  ];
  const wf2NodeIds = wf2NodeDefs.map(([title, category, subtitle, x, y]) => {
    const id = uuid();
    db.prepare(
      'INSERT INTO workflow_nodes (id, user_id, workflow_id, title, category, subtitle, pos_x, pos_y) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(id, userId, wf2Id, title, category, subtitle, x, y);
    return id;
  });
  for (let i = 0; i < wf2NodeIds.length - 1; i++) {
    db.prepare(
      'INSERT INTO workflow_connections (id, user_id, workflow_id, from_node_id, to_node_id) VALUES (?, ?, ?, ?, ?)'
    ).run(uuid(), userId, wf2Id, wf2NodeIds[i], wf2NodeIds[i + 1]);
  }

  // Consent mandates
  db.prepare(
    `INSERT INTO consent_mandates (id, user_id, agent_id, purpose, data_scope, allowed_actions_json, denied_actions_json, autonomy, external_target, status, created_at, updated_at)
     VALUES (?, ?, ?, 'Campaign monitoring', 'Campaign Alpha analytics', ?, ?, 'Continuous — daily at 09:00', 'Instagram (read analytics only)', 'active', ?, ?)`
  ).run(
    uuid(), userId, marketingId,
    JSON.stringify(['Read', 'Analyze', 'Generate report', 'Notify user']),
    JSON.stringify(['Publish', 'Change budget', 'Send external message']),
    now, now
  );
  db.prepare(
    `INSERT INTO consent_mandates (id, user_id, agent_id, purpose, data_scope, allowed_actions_json, denied_actions_json, autonomy, status, created_at, updated_at)
     VALUES (?, ?, ?, 'Competitor research', 'Public web data only', ?, ?, 'Manual only', 'paused', ?, ?)`
  ).run(
    uuid(), userId, researchId,
    JSON.stringify(['Read', 'Summarize']),
    JSON.stringify(['Store personal data', 'Contact competitors']),
    now, now
  );

  // Pending approval matching the Marketing Agent message above
  db.prepare(
    `INSERT INTO approval_requests (id, user_id, agent_id, workflow_id, action, scope, requested_at, resolved)
     VALUES (?, ?, ?, ?, 'Publish performance update', 'External platform: Instagram', ?, 0)`
  ).run(uuid(), userId, marketingId, wfId, now);

  // Vault outputs
  db.prepare(
    `INSERT INTO vault_outputs (id, user_id, workflow_id, title, kind, summary, ai_summary, raw_data_preview, agent_activity_json, shared, created_at)
     VALUES (?, ?, ?, 'Cash Flow Report — Week 39', 'report', ?, ?, ?, ?, 0, ?)`
  ).run(
    uuid(), userId, wf2Id,
    'Net positive cash flow of Rp 18.4jt this week, 3 invoices still outstanding.',
    'Cash position improved week-over-week; recommend following up on 3 overdue invoices.',
    'invoices.csv · 42 rows · updated 2 days ago',
    JSON.stringify(['Read 42 invoice records', 'Computed weekly delta', 'Drafted summary']),
    now
  );
  db.prepare(
    `INSERT INTO vault_outputs (id, user_id, workflow_id, title, kind, summary, ai_summary, raw_data_preview, agent_activity_json, shared, created_at)
     VALUES (?, ?, ?, 'Campaign Alpha — Daily Snapshot', 'dashboard', ?, ?, ?, ?, 0, ?)`
  ).run(
    uuid(), userId, wfId,
    'CTR steady at 3.2%, spend on track, no anomalies detected.',
    'Performance stable; no action required today.',
    'campaign_alpha_metrics.json · updated this morning',
    JSON.stringify(['Fetched campaign analytics', 'Compared to 7-day average']),
    now
  );
}

module.exports = { seedDemoData };
