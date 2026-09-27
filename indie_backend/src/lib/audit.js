const crypto = require('node:crypto');
const db = require('../db');

function logAudit(userId, eventType, detail = '') {
  db.prepare(
    'INSERT INTO audit_log (id, user_id, event_type, detail, created_at) VALUES (?, ?, ?, ?, ?)'
  ).run(crypto.randomUUID(), userId, eventType, detail, new Date().toISOString());
}

module.exports = { logAudit };
