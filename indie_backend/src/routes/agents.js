const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { logAudit } = require('../lib/audit');
const { serializeMessage, setReaction, buildAttachment } = require('../lib/messages');
const { evaluate, resultCard } = require('../lib/agentScope');
const aiModel = require('../lib/aiModel');

const router = express.Router();
router.use(requireAuth);

const T = 'agent_messages';

function stepsOf(agentId) {
  return db.prepare('SELECT step FROM agent_workflow_steps WHERE agent_id = ? ORDER BY position ASC').all(agentId).map((r) => r.step);
}

function serializeAgent(row) {
  const permissions = db.prepare('SELECT label FROM agent_permissions WHERE agent_id = ?').all(row.id).map((p) => p.label);
  const pendingApproval = db.prepare('SELECT 1 FROM approval_requests WHERE agent_id = ? AND resolved = 0 LIMIT 1').get(row.id);
  return {
    id: row.id,
    name: row.name,
    role: row.role,
    glyph: row.glyph,
    accentHex: row.accent_hex,
    state: row.state,
    currentActivity: row.current_activity,
    permissions,
    workflow: stepsOf(row.id), // defined by the Orchestrator — read-only here
    needsAttention: !!pendingApproval || row.state === 'error',
  };
}

function ownedAgent(req, res) {
  const a = db.prepare('SELECT * FROM agents WHERE id = ? AND user_id = ?').get(req.params.id, req.userId);
  if (!a) res.status(404).json({ error: 'Not found' });
  return a;
}

function insertAgentMessage(userId, agentId, sender, kind, text, payload, extra = {}) {
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO ${T} (id, user_id, agent_id, sender, kind, text, payload_json, created_at, reply_to_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(id, userId, agentId, sender, kind, text, payload ? JSON.stringify(payload) : null, new Date().toISOString(), extra.replyToId || null);
  return id;
}

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM agents WHERE user_id = ? ORDER BY name ASC').all(req.userId);
  res.json(rows.map(serializeAgent));
});

// NOTE: there is intentionally no POST /agents. Agents are created only by
// the Orchestrator so every agent has a workflow scope from day one.

router.get('/:id', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  res.json(serializeAgent(a));
});

router.get('/:id/messages', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  const rows = db.prepare(`SELECT * FROM ${T} WHERE agent_id = ? ORDER BY created_at ASC, rowid ASC`).all(a.id);
  res.json(rows.map((r) => serializeMessage(T, r)));
});

router.post('/:id/messages', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  const att = buildAttachment(req.userId, req.body || {});
  if (att.error) return res.status(400).json({ error: att.error });

  let replyToId = null;
  if (req.body.replyToId) {
    const orig = db.prepare(`SELECT id FROM ${T} WHERE id = ? AND agent_id = ?`).get(req.body.replyToId, a.id);
    if (!orig) return res.status(400).json({ error: 'replyToId must be a message in this chat' });
    replyToId = orig.id;
  }

  const userMsgId = insertAgentMessage(req.userId, a.id, 'user', att.kind, att.text, att.payload, { replyToId });
  if (att.output) {
    db.prepare('UPDATE vault_outputs SET shared = 1 WHERE id = ?').run(att.output.id);
    logAudit(req.userId, 'output_shared', `output=${att.output.id} recipient=agent:${a.id} via=chat`);
  }
  logAudit(req.userId, 'agent_command_sent', `agent=${a.id} kind=${att.kind}`);

  // Scope check always runs server-side: the text (or attachment name) is
  // matched against the workflow the Orchestrator defined for this agent.
  // This is the deterministic source of truth for `scope` in the response
  // and for the audit log, regardless of whether a real model is used.
  const subject = att.kind === 'file' ? att.payload.file.name : att.kind === 'output' ? att.payload.output.title : att.text;
  const steps = stepsOf(a.id);
  const verdict = evaluate(a, steps, subject);
  logAudit(req.userId, 'agent_scope_check', `agent=${a.id} result=${verdict.kind} model=${aiModel.isConfigured() ? 'live' : 'scripted'}`);

  setTimeout(async () => {
    try {
      if (aiModel.isConfigured()) {
        try {
          const history = db.prepare(`SELECT * FROM ${T} WHERE agent_id = ? ORDER BY created_at ASC, rowid ASC`).all(a.id);
          const text = await aiModel.generateReply({ agent: a, steps, history });
          insertAgentMessage(req.userId, a.id, 'agent', 'text', text, verdict.kind === 'out_of_scope' ? { cta: 'ask_orchestrator' } : null);
          return;
        } catch (err) {
          logAudit(req.userId, 'agent_model_error', `agent=${a.id} error=${String(err.message || err).slice(0, 200)}`);
          // fall through to the scripted reply below
        }
      }
      insertAgentMessage(req.userId, a.id, 'agent', 'text', verdict.text, verdict.payload || null);
      if (verdict.kind === 'in_scope') {
        setTimeout(() => {
          try {
            insertAgentMessage(req.userId, a.id, 'agent', 'card', '', { card: resultCard(verdict.hit) });
          } catch {}
        }, 1500).unref();
      }
    } catch {}
  }, 800).unref();

  res.status(201).json({ message: serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(userMsgId)), scope: verdict.kind });
});

function ownedMessage(req, res, a) {
  const m = db.prepare(`SELECT * FROM ${T} WHERE id = ? AND agent_id = ?`).get(req.params.mid, a.id);
  if (!m) res.status(404).json({ error: 'Message not found' });
  return m;
}

router.patch('/:id/messages/:mid/reaction', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  const m = ownedMessage(req, res, a);
  if (!m) return;
  if (m.deleted) return res.status(409).json({ error: 'Message was deleted' });
  const r = setReaction(T, m, req.body && req.body.emoji !== undefined ? req.body.emoji : null);
  if (r.error) return res.status(400).json({ error: r.error });
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

router.post('/:id/messages/:mid/save', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  const m = ownedMessage(req, res, a);
  if (!m) return;
  if (!['card', 'file', 'output'].includes(m.kind)) return res.status(400).json({ error: 'Only results and files can be saved' });
  db.prepare(`UPDATE ${T} SET saved = 1 WHERE id = ?`).run(m.id);
  logAudit(req.userId, 'chat_item_saved', `message=${m.id}`);
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

router.delete('/:id/messages/:mid', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  const m = ownedMessage(req, res, a);
  if (!m) return;
  if (m.sender !== 'user') return res.status(403).json({ error: 'You can only delete your own messages' });
  db.prepare(`UPDATE ${T} SET deleted = 1, text = '', payload_json = NULL, reactions_json = '{}', my_reaction = NULL WHERE id = ?`).run(m.id);
  logAudit(req.userId, 'agent_message_deleted', `message=${m.id}`);
  res.json(serializeMessage(T, db.prepare(`SELECT * FROM ${T} WHERE id = ?`).get(m.id)));
});

router.get('/:id/activity', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  res.json(db.prepare('SELECT label, created_at FROM agent_activity_log WHERE agent_id = ? ORDER BY created_at ASC').all(a.id));
});

router.get('/:id/memory', (req, res) => {
  const a = ownedAgent(req, res);
  if (!a) return;
  res.json(db.prepare('SELECT note, created_at FROM agent_memory WHERE agent_id = ? ORDER BY created_at ASC').all(a.id));
});

module.exports = router;
