const crypto = require('node:crypto');
const db = require('../../db');
const { encrypt, decrypt } = require('../encryption');
const { logAudit } = require('../audit');

const AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const REVOKE_URL = 'https://oauth2.googleapis.com/revoke';

/**
 * Shared Google OAuth 2.0 plumbing (authorize URL, code exchange, refresh,
 * revoke, encrypted token storage) factored out so every Google-backed
 * connector (Calendar, Gmail, Drive, ...) is just this base wired to a
 * provider name, a scope, and its own API calls — not a copy-paste of the
 * whole OAuth dance. Non-Google connectors (a future Slack/Notion/etc.)
 * would get their own base module with the same shape, not this one.
 */
function makeGoogleConnector({ provider, scope }) {
  function isConfigured() {
    return !!(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET && process.env.GOOGLE_REDIRECT_URI);
  }

  function buildAuthorizeUrl(state) {
    const params = new URLSearchParams({
      client_id: process.env.GOOGLE_CLIENT_ID,
      redirect_uri: process.env.GOOGLE_REDIRECT_URI,
      response_type: 'code',
      scope,
      access_type: 'offline',
      prompt: 'consent',
      state,
    });
    return `${AUTH_URL}?${params.toString()}`;
  }

  function startAuthorize(userId) {
    if (!isConfigured()) {
      const err = new Error(`${provider} connector is not configured (missing GOOGLE_CLIENT_ID/SECRET/REDIRECT_URI)`);
      err.code = 'NOT_CONFIGURED';
      throw err;
    }
    const state = crypto.randomUUID();
    db.prepare('INSERT INTO oauth_states (state, user_id, provider, created_at) VALUES (?, ?, ?, ?)').run(state, userId, provider, new Date().toISOString());
    return { url: buildAuthorizeUrl(state), state };
  }

  async function exchangeCode(code) {
    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
        redirect_uri: process.env.GOOGLE_REDIRECT_URI,
        grant_type: 'authorization_code',
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      const err = new Error(`Google token exchange failed (${res.status}): ${body.slice(0, 200)}`);
      err.code = 'TOKEN_EXCHANGE_FAILED';
      throw err;
    }
    return res.json();
  }

  async function refreshAccessToken(refreshToken) {
    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        refresh_token: refreshToken,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
        grant_type: 'refresh_token',
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      const err = new Error(`Google token refresh failed (${res.status}): ${body.slice(0, 200)}`);
      err.code = 'TOKEN_REFRESH_FAILED';
      throw err;
    }
    return res.json();
  }

  async function handleCallback(state, code) {
    const row = db.prepare('SELECT * FROM oauth_states WHERE state = ? AND provider = ?').get(state, provider);
    if (!row) {
      const err = new Error('Invalid or expired OAuth state');
      err.code = 'INVALID_STATE';
      throw err;
    }
    db.prepare('DELETE FROM oauth_states WHERE state = ?').run(state);

    const tokens = await exchangeCode(code);
    const now = new Date();
    const expiresAt = tokens.expires_in ? new Date(now.getTime() + tokens.expires_in * 1000).toISOString() : null;
    const existing = db.prepare('SELECT * FROM connectors WHERE user_id = ? AND provider = ?').get(row.user_id, provider);
    const refreshEnc = tokens.refresh_token ? encrypt(tokens.refresh_token) : existing ? existing.refresh_token_enc : null;

    if (existing) {
      db.prepare(
        'UPDATE connectors SET scope = ?, access_token_enc = ?, refresh_token_enc = ?, expires_at = ?, connected_at = ?, revoked_at = NULL WHERE id = ?'
      ).run(tokens.scope || scope, encrypt(tokens.access_token), refreshEnc, expiresAt, now.toISOString(), existing.id);
    } else {
      db.prepare(
        `INSERT INTO connectors (id, user_id, provider, scope, access_token_enc, refresh_token_enc, expires_at, connected_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(crypto.randomUUID(), row.user_id, provider, tokens.scope || scope, encrypt(tokens.access_token), refreshEnc, expiresAt, now.toISOString());
    }
    logAudit(row.user_id, 'connector_connected', `provider=${provider}`);
    return row.user_id;
  }

  function getRow(userId) {
    return db.prepare('SELECT * FROM connectors WHERE user_id = ? AND provider = ? AND revoked_at IS NULL').get(userId, provider);
  }

  function serialize(row) {
    if (!row) return { provider, connected: false, configured: isConfigured() };
    return { provider, connected: true, scope: row.scope, connectedAt: row.connected_at, expiresAt: row.expires_at, hasRefreshToken: !!row.refresh_token_enc };
  }

  async function getValidAccessToken(userId) {
    const row = getRow(userId);
    if (!row) {
      const err = new Error(`${provider} is not connected for this account`);
      err.code = 'NOT_CONNECTED';
      throw err;
    }
    const stillValid = !row.expires_at || new Date(row.expires_at).getTime() - Date.now() > 60_000;
    if (stillValid) return decrypt(row.access_token_enc);
    if (!row.refresh_token_enc) {
      const err = new Error(`${provider} access expired and cannot be refreshed — please reconnect`);
      err.code = 'NEEDS_RECONNECT';
      throw err;
    }
    const refreshed = await refreshAccessToken(decrypt(row.refresh_token_enc));
    const expiresAt = refreshed.expires_in ? new Date(Date.now() + refreshed.expires_in * 1000).toISOString() : null;
    db.prepare('UPDATE connectors SET access_token_enc = ?, expires_at = ? WHERE id = ?').run(encrypt(refreshed.access_token), expiresAt, row.id);
    return refreshed.access_token;
  }

  async function revoke(userId) {
    const row = getRow(userId);
    if (!row) return;
    try {
      const token = decrypt(row.access_token_enc);
      await fetch(`${REVOKE_URL}?token=${encodeURIComponent(token)}`, { method: 'POST' });
    } catch {
      // best-effort — still revoke locally even if Google's endpoint is unreachable
    }
    db.prepare('UPDATE connectors SET revoked_at = ? WHERE id = ?').run(new Date().toISOString(), row.id);
    logAudit(userId, 'connector_revoked', `provider=${provider}`);
  }

  return { PROVIDER: provider, isConfigured, buildAuthorizeUrl, startAuthorize, handleCallback, getRow, serialize, getValidAccessToken, revoke };
}

module.exports = { makeGoogleConnector };
