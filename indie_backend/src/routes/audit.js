const express = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

router.get('/', (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 100, 500);
  const rows = db
    .prepare('SELECT event_type, detail, created_at FROM audit_log WHERE user_id = ? ORDER BY created_at DESC LIMIT ?')
    .all(req.userId, limit);
  res.json(rows.map((r) => ({ eventType: r.event_type, detail: r.detail, at: r.created_at })));
});

module.exports = router;
