const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const contacts = require('./contacts');

const router = express.Router();
router.use(requireAuth);

const initialsOf = (name) => {
  const p = name.trim().split(/\s+/);
  return ((p[0] || '?')[0] + (p[1] ? p[1][0] : p[0][1] || '')).toUpperCase();
};
const now = () => new Date().toISOString();

function ownedGroup(req, res) {
  const g = db.prepare("SELECT * FROM contacts WHERE id = ? AND user_id = ? AND kind = 'group'").get(req.params.id, req.userId);
  if (!g) res.status(404).json({ error: 'Group not found' });
  return g;
}
/** Only the caller's own person-contacts can be members — never agents, never other users' contacts. */
function validMemberIds(userId, ids) {
  if (!Array.isArray(ids)) return null;
  const out = [];
  for (const id of ids) {
    const c = db.prepare("SELECT id, name FROM contacts WHERE id = ? AND user_id = ? AND kind = 'person'").get(id, userId);
    if (!c) return null;
    if (!out.some((x) => x.id === c.id)) out.push(c);
  }
  return out;
}
function systemMessage(userId, groupId, text) {
  db.prepare(
    "INSERT INTO contact_messages (id, user_id, contact_id, sender, text, created_at, kind, status) VALUES (?, ?, ?, 'contact', ?, ?, 'system', NULL)"
  ).run(crypto.randomUUID(), userId, groupId, text, now());
}

// POST /groups { name, description?, visibility?, allowNewMembers?, memberIds? }
router.post('/', (req, res) => {
  const { name, description, visibility, allowNewMembers, memberIds } = req.body || {};
  if (!name || !String(name).trim()) return res.status(400).json({ error: 'Validation failed', fields: { name: 'Group name is required' } });
  if (String(name).length > 80) return res.status(400).json({ error: 'Group name is too long (max 80 characters)' });
  if (description && String(description).length > 500) return res.status(400).json({ error: 'Description is too long (max 500 characters)' });
  if (Array.isArray(memberIds) && memberIds.length > 200) return res.status(400).json({ error: 'Too many members (max 200)' });
  if (visibility !== undefined && !['public', 'private'].includes(visibility)) return res.status(400).json({ error: 'visibility must be public or private' });
  const members = validMemberIds(req.userId, memberIds === undefined ? [] : memberIds);
  if (!members) return res.status(400).json({ error: 'memberIds must be your own contacts (people only)' });

  const id = crypto.randomUUID(), clean = String(name).trim();
  db.prepare(
    `INSERT INTO contacts (id, user_id, name, initials, status, pinned, created_at, info, grp, kind, description, visibility, allow_new)
     VALUES (?, ?, ?, ?, 'Group', 0, ?, '', '', 'group', ?, ?, ?)`
  ).run(id, req.userId, clean, initialsOf(clean), now(), String(description || '').trim(), visibility || 'private', allowNewMembers === false ? 0 : 1);
  members.forEach((m) => db.prepare('INSERT INTO group_members (group_id, contact_id, added_at) VALUES (?, ?, ?)').run(id, m.id, now()));
  systemMessage(req.userId, id, `You created “${clean}”`);
  logAudit(req.userId, 'group_created', `group=${id} members=${members.length}`);
  res.status(201).json(contacts.serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(id)));
});

router.get('/:id/members', (req, res) => {
  const g = ownedGroup(req, res);
  if (g) res.json(contacts.groupMembers(g.id));
});

// POST /groups/:id/members { contactIds }
router.post('/:id/members', (req, res) => {
  const g = ownedGroup(req, res);
  if (!g) return;
  const picked = validMemberIds(req.userId, (req.body || {}).contactIds);
  if (!picked || !picked.length) return res.status(400).json({ error: 'contactIds must be a non-empty list of your own contacts' });
  let added = 0;
  for (const m of picked) {
    if (db.prepare('SELECT 1 FROM group_members WHERE group_id = ? AND contact_id = ?').get(g.id, m.id)) continue;
    db.prepare('INSERT INTO group_members (group_id, contact_id, added_at) VALUES (?, ?, ?)').run(g.id, m.id, now());
    systemMessage(req.userId, g.id, `${m.name} joined the group`);
    added++;
  }
  logAudit(req.userId, 'group_members_added', `group=${g.id} count=${added}`);
  res.status(201).json(contacts.serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(g.id)));
});

router.delete('/:id/members/:contactId', (req, res) => {
  const g = ownedGroup(req, res);
  if (!g) return;
  const m = db.prepare('SELECT c.name FROM group_members gm JOIN contacts c ON c.id = gm.contact_id WHERE gm.group_id = ? AND gm.contact_id = ?').get(g.id, req.params.contactId);
  if (!m) return res.status(404).json({ error: 'Not a member' });
  db.prepare('DELETE FROM group_members WHERE group_id = ? AND contact_id = ?').run(g.id, req.params.contactId);
  systemMessage(req.userId, g.id, `${m.name} was removed`);
  logAudit(req.userId, 'group_member_removed', `group=${g.id} contact=${req.params.contactId}`);
  res.json(contacts.serializeContact(db.prepare('SELECT * FROM contacts WHERE id = ?').get(g.id)));
});

module.exports = router;
