const express = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const gcal = require('../lib/connectors/googleCalendar');

const router = express.Router();
// requireAuth is applied per-route (not router-wide): the OAuth callback is
// a plain browser redirect from Google with no bearer token — it resolves
// the user from the one-time `state` row instead (see handleCallback).

const REGISTRY = { [gcal.PROVIDER]: gcal };

function errStatus(err) {
  switch (err.code) {
    case 'NOT_CONFIGURED':
      return 501; // Not Implemented — server hasn't set this connector up
    case 'NOT_CONNECTED':
    case 'NEEDS_RECONNECT':
      return 409;
    case 'INVALID_STATE':
      return 400;
    default:
      return 502; // upstream (Google) failure
  }
}

// List every known connector and whether this account has connected it.
// External services are optional and never the primary identity/storage —
// spec §15.
router.get('/', requireAuth, (req, res) => {
  res.json(
    Object.values(REGISTRY).map((c) => c.serialize(c.getRow(req.userId)))
  );
});

// Step 1 of the OAuth dance: returns the Google consent URL for the client
// to open. Never auto-redirects server-side — the person must see and
// approve the Google consent screen themselves.
router.get('/:provider/authorize', requireAuth, (req, res) => {
  const connector = REGISTRY[req.params.provider];
  if (!connector) return res.status(404).json({ error: 'Unknown connector' });
  try {
    const { url } = connector.startAuthorize(req.userId);
    res.json({ url });
  } catch (err) {
    res.status(errStatus(err)).json({ error: err.message, code: err.code });
  }
});

// Step 2: Google redirects the browser here with ?code&state. No auth
// middleware applies cleanly to a browser redirect, so this route resolves
// the user from the one-time `state` row instead of a bearer token.
router.get('/:provider/callback', async (req, res) => {
  const connector = REGISTRY[req.params.provider];
  if (!connector) return res.status(404).send('Unknown connector');
  const { state, code, error } = req.query;
  if (error) return res.status(400).send(`Google denied access: ${error}`);
  if (!state || !code) return res.status(400).send('Missing state or code');
  try {
    await connector.handleCallback(String(state), String(code));
    res.send('Google Calendar connected — you can close this window and return to Indie.');
  } catch (err) {
    res.status(errStatus(err)).send(`Could not connect: ${err.message}`);
  }
});

router.delete('/:provider', requireAuth, async (req, res) => {
  const connector = REGISTRY[req.params.provider];
  if (!connector) return res.status(404).json({ error: 'Unknown connector' });
  await connector.revoke(req.userId);
  res.json({ ok: true });
});

// Example scoped action behind the Permission Gateway — list upcoming
// events. A real deployment would call this from an agent's workflow step
// ("Read your calendar") rather than directly from the client.
router.get('/google_calendar/events', requireAuth, async (req, res) => {
  try {
    const events = await gcal.listUpcomingEvents(req.userId, { maxResults: Number(req.query.maxResults) || 10 });
    res.json(events);
  } catch (err) {
    res.status(errStatus(err)).json({ error: err.message, code: err.code });
  }
});

module.exports = router;
