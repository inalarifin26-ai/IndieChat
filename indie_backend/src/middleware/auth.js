const jwt = require('jsonwebtoken');
const db = require('../db');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });

  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }

  const session = db
    .prepare('SELECT * FROM sessions WHERE id = ? AND user_id = ?')
    .get(payload.jti, payload.sub);
  if (!session || session.revoked_at) {
    return res.status(401).json({ error: 'Session revoked' });
  }
  if (new Date(session.expires_at).getTime() < Date.now()) {
    return res.status(401).json({ error: 'Session expired' });
  }

  req.userId = payload.sub;
  req.sessionId = payload.jti;
  next();
}

module.exports = { requireAuth, JWT_SECRET };
