const { makeGoogleConnector } = require('./googleOAuthBase');
const { logAudit } = require('../audit');

const LIST_URL = 'https://gmail.googleapis.com/gmail/v1/users/me/messages';
const MSG_URL = (id) => `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}`;

const base = makeGoogleConnector({
  provider: 'gmail',
  // Read-only, and metadata-only scope would be even narrower, but Gmail's
  // metadata scope still requires gmail.readonly for the messages.get call
  // used below — kept to the least-privilege readonly scope regardless.
  scope: 'https://www.googleapis.com/auth/gmail.readonly',
});

function headerValue(headers, name) {
  const h = (headers || []).find((h) => h.name.toLowerCase() === name.toLowerCase());
  return h ? h.value : '';
}

/**
 * The one action specific to this connector: list recent unread messages.
 * Two Gmail API calls are required (list ids, then get each message) — we
 * ask for `format=metadata` with only the headers we need, not the full
 * message body, matching the spec's data-minimization principle even
 * though the OAuth scope itself is the same `gmail.readonly`.
 */
async function listUnread(userId, { maxResults = 5 } = {}) {
  const token = await base.getValidAccessToken(userId);
  const headers = { Authorization: `Bearer ${token}` };

  const listParams = new URLSearchParams({ maxResults: String(maxResults), labelIds: 'UNREAD', q: 'in:inbox' });
  const listRes = await fetch(`${LIST_URL}?${listParams.toString()}`, { headers });
  if (!listRes.ok) {
    const body = await listRes.text().catch(() => '');
    const err = new Error(`Gmail API error (${listRes.status}): ${body.slice(0, 200)}`);
    err.code = 'GMAIL_API_ERROR';
    throw err;
  }
  const listData = await listRes.json();
  const ids = (listData.messages || []).map((m) => m.id);

  const messages = [];
  for (const id of ids) {
    const params = new URLSearchParams({ format: 'metadata' });
    params.append('metadataHeaders', 'Subject');
    params.append('metadataHeaders', 'From');
    const res = await fetch(`${MSG_URL(id)}?${params.toString()}`, { headers });
    if (!res.ok) continue; // skip a single bad message rather than failing the whole list
    const data = await res.json();
    messages.push({
      id: data.id,
      subject: headerValue(data.payload?.headers, 'Subject') || '(no subject)',
      from: headerValue(data.payload?.headers, 'From') || 'Unknown sender',
      snippet: data.snippet || '',
    });
  }
  logAudit(userId, 'connector_action', `provider=${base.PROVIDER} action=list_unread count=${messages.length}`);
  return messages;
}

module.exports = { ...base, listUnread };
