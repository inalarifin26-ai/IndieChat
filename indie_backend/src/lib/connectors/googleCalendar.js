const { makeGoogleConnector } = require('./googleOAuthBase');
const { logAudit } = require('../audit');

const EVENTS_URL = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';

const base = makeGoogleConnector({
  provider: 'google_calendar',
  scope: 'https://www.googleapis.com/auth/calendar.readonly',
});

/** The one action specific to this connector: list upcoming events. */
async function listUpcomingEvents(userId, { maxResults = 10 } = {}) {
  const token = await base.getValidAccessToken(userId);
  const params = new URLSearchParams({
    maxResults: String(maxResults),
    orderBy: 'startTime',
    singleEvents: 'true',
    timeMin: new Date().toISOString(),
  });
  const res = await fetch(`${EVENTS_URL}?${params.toString()}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    const err = new Error(`Google Calendar API error (${res.status}): ${body.slice(0, 200)}`);
    err.code = 'CALENDAR_API_ERROR';
    throw err;
  }
  const data = await res.json();
  logAudit(userId, 'connector_action', `provider=${base.PROVIDER} action=list_events count=${(data.items || []).length}`);
  return (data.items || []).map((e) => ({
    id: e.id,
    title: e.summary || '(no title)',
    start: e.start?.dateTime || e.start?.date,
    end: e.end?.dateTime || e.end?.date,
  }));
}

module.exports = { ...base, listUpcomingEvents };
