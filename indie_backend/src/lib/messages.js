const db = require('../db');

const ALLOWED_REACTIONS = ['👍', '❤️', '😂', '🙏', '✅'];

function snippet(row) {
  if (row.deleted) return 'Message deleted';
  const payload = row.payload_json ? JSON.parse(row.payload_json) : null;
  if (row.kind === 'file' && payload && payload.file) return `📎 ${payload.file.name}`;
  if (row.kind === 'output' && payload && payload.output) return `📄 ${payload.output.title}`;
  if (row.kind === 'card' && payload && payload.card) return `📊 ${payload.card.title}`;
  return row.text || '';
}

/**
 * Serializes a row from contact_messages or agent_messages into the shape
 * the clients render (bubble, quote, reactions, status, deleted tombstone).
 */
function serializeMessage(table, row) {
  let replyTo = null;
  if (row.reply_to_id) {
    const orig = db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(row.reply_to_id);
    if (orig) replyTo = { id: orig.id, sender: orig.sender, snippet: snippet(orig) };
  }
  return {
    id: row.id,
    sender: row.sender,
    kind: row.kind || 'text',
    text: row.deleted ? '' : row.text,
    payload: row.deleted || !row.payload_json ? null : JSON.parse(row.payload_json),
    replyTo,
    status: row.status || null,
    reactions: row.deleted ? {} : JSON.parse(row.reactions_json || '{}'),
    myReaction: row.deleted ? null : row.my_reaction || null,
    deleted: !!row.deleted,
    saved: !!row.saved,
    createdAt: row.created_at,
  };
}

function setReaction(table, row, emoji) {
  if (emoji !== null && !ALLOWED_REACTIONS.includes(emoji)) return { error: 'unsupported reaction' };
  const counts = JSON.parse(row.reactions_json || '{}');
  const drop = (e) => {
    counts[e] = (counts[e] || 1) - 1;
    if (counts[e] <= 0) delete counts[e];
  };
  let mine = row.my_reaction || null;
  if (mine === emoji) {
    drop(mine);
    mine = null; // tapping the same emoji again removes it
  } else {
    if (mine) drop(mine);
    if (emoji) {
      counts[emoji] = (counts[emoji] || 0) + 1;
      mine = emoji;
    } else {
      mine = null;
    }
  }
  db.prepare(`UPDATE ${table} SET reactions_json = ?, my_reaction = ? WHERE id = ?`).run(
    JSON.stringify(counts),
    mine,
    row.id
  );
  return { ok: true };
}

/**
 * Validates an outgoing attachment. Files are described by name/size only.
 * Vault outputs are NEVER trusted from the client body: the server loads the
 * output the user owns and builds a result-only payload (no workflow
 * definition, credentials or private memory) — Invariants 3 & 7.
 */
function buildAttachment(userId, body) {
  const kind = body.kind || 'text';
  if (kind === 'text') {
    if (!body.text || !String(body.text).trim()) return { error: 'text is required' };
    return { kind, text: String(body.text).trim(), payload: null };
  }
  if (kind === 'file') {
    const f = body.payload && body.payload.file;
    if (!f || !f.name) return { error: 'payload.file.name is required' };
    return { kind, text: '', payload: { file: { name: String(f.name), size: String(f.size || '') } } };
  }
  if (kind === 'output') {
    const out = body.outputId
      ? db.prepare('SELECT * FROM vault_outputs WHERE id = ? AND user_id = ?').get(body.outputId, userId)
      : null;
    if (!out) return { error: 'outputId must reference one of your Vault outputs' };
    return {
      kind,
      text: '',
      payload: { output: { id: out.id, title: out.title, note: 'Shared result — report + AI summary only' } },
      output: out,
    };
  }
  return { error: 'unsupported kind' };
}

module.exports = { serializeMessage, setReaction, buildAttachment, snippet, ALLOWED_REACTIONS };
