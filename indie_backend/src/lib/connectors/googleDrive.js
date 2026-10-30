const { makeGoogleConnector } = require('./googleOAuthBase');
const { logAudit } = require('../audit');

const FILES_URL = 'https://www.googleapis.com/drive/v3/files';

const base = makeGoogleConnector({
  provider: 'google_drive',
  // Readonly + metadata-only: file names/links/timestamps, never file
  // contents — least privilege for "what have I got" style questions.
  scope: 'https://www.googleapis.com/auth/drive.metadata.readonly',
});

/** Escapes a value for use inside a single-quoted Drive `q` string. */
function escapeQ(v) {
  return String(v).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

/**
 * The one action specific to this connector: list recently modified files
 * (metadata only). `nameContains` narrows it to files whose name contains
 * that text — e.g. "invoice" for the Finance Agent's "Read invoices" step.
 */
async function listRecentFiles(userId, { maxResults = 10, nameContains } = {}) {
  const token = await base.getValidAccessToken(userId);
  const q = nameContains ? `name contains '${escapeQ(String(nameContains).slice(0, 80))}' and trashed = false` : 'trashed = false';
  const params = new URLSearchParams({
    q,
    pageSize: String(maxResults),
    orderBy: 'modifiedTime desc',
    fields: 'files(id,name,mimeType,modifiedTime,webViewLink)',
    spaces: 'drive',
  });
  const res = await fetch(`${FILES_URL}?${params.toString()}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    const err = new Error(`Google Drive API error (${res.status}): ${body.slice(0, 200)}`);
    err.code = 'DRIVE_API_ERROR';
    throw err;
  }
  const data = await res.json();
  logAudit(userId, 'connector_action', `provider=${base.PROVIDER} action=list_files count=${(data.files || []).length}`);
  return (data.files || []).map((f) => ({
    id: f.id,
    name: f.name,
    mimeType: f.mimeType,
    modifiedAt: f.modifiedTime,
    link: f.webViewLink,
  }));
}

module.exports = { ...base, listRecentFiles, escapeQ };
