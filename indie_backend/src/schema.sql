-- Indie backend schema (SQLite via node:sqlite).
-- Every user-owned table carries user_id so authorization can be enforced
-- with a WHERE clause at the data layer, never left to client-side
-- filtering alone (see PERSONAL_AGENTIC_PLATFORM_SPEC.md §"Data Isolation").

CREATE TABLE IF NOT EXISTS users (
  id                TEXT PRIMARY KEY,
  personal_id       TEXT UNIQUE NOT NULL,
  credential_hash   TEXT NOT NULL,   -- scrypt(local device credential)
  credential_salt   TEXT NOT NULL,
  recovery_hash     TEXT NOT NULL,   -- scrypt(recovery phrase) — raw phrase is NEVER stored
  recovery_salt     TEXT NOT NULL,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id                TEXT PRIMARY KEY,   -- jti embedded in the JWT
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at        TEXT NOT NULL,
  expires_at        TEXT NOT NULL,
  revoked_at        TEXT
);

CREATE TABLE IF NOT EXISTS contacts (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  initials          TEXT NOT NULL,
  status            TEXT DEFAULT '',
  pinned            INTEGER DEFAULT 0,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS contact_messages (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_id        TEXT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  sender            TEXT NOT NULL,     -- 'user' | 'contact'
  text              TEXT NOT NULL,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agents (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  role              TEXT DEFAULT '',
  glyph             TEXT DEFAULT 'A',
  accent_hex        TEXT DEFAULT '2FE4DB',
  state             TEXT DEFAULT 'idle',       -- idle|monitoring|working|waitingApproval|scheduled|error
  current_activity  TEXT DEFAULT 'No active task',
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_messages (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  sender            TEXT NOT NULL,     -- 'user' | 'agent' | 'system'
  kind              TEXT DEFAULT 'text', -- text|approvalRequest|notification
  text              TEXT NOT NULL,
  payload_json      TEXT,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_permissions (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  label             TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_activity_log (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  label             TEXT NOT NULL,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_memory (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  note              TEXT NOT NULL,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workflows (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  description       TEXT DEFAULT '',
  version           TEXT DEFAULT 'v0.1 draft',
  lifecycle         TEXT DEFAULT 'draft',    -- draft|validating|ready|active|paused
  trigger_summary   TEXT DEFAULT 'Not configured',
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workflow_nodes (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workflow_id           TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  category              TEXT NOT NULL,   -- trigger|data|ai|logic|action|approval|storage|output
  subtitle              TEXT DEFAULT '',
  pos_x                 REAL DEFAULT 0,
  pos_y                 REAL DEFAULT 0,
  state                 TEXT DEFAULT 'idle',
  disabled              INTEGER DEFAULT 0,
  permission_requirements_json TEXT DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS workflow_connections (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workflow_id       TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  from_node_id      TEXT NOT NULL,
  to_node_id        TEXT NOT NULL,
  branch_label      TEXT
);

CREATE TABLE IF NOT EXISTS executions (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workflow_id       TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  state             TEXT DEFAULT 'queued',  -- queued|running|waitingApproval|completed|failed|paused|cancelled
  started_at        TEXT NOT NULL,
  completed_at      TEXT
);

CREATE TABLE IF NOT EXISTS execution_events (
  id                TEXT PRIMARY KEY,
  execution_id      TEXT NOT NULL REFERENCES executions(id) ON DELETE CASCADE,
  label             TEXT NOT NULL,
  created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS consent_mandates (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id              TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  purpose               TEXT NOT NULL,
  data_scope            TEXT NOT NULL,
  allowed_actions_json  TEXT NOT NULL DEFAULT '[]',
  denied_actions_json   TEXT NOT NULL DEFAULT '[]',
  autonomy              TEXT NOT NULL,
  external_target       TEXT,
  status                TEXT DEFAULT 'active',  -- active|paused|revoked|expired
  created_at            TEXT NOT NULL,
  updated_at            TEXT NOT NULL,
  revoked_at            TEXT
);

CREATE TABLE IF NOT EXISTS approval_requests (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  workflow_id       TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  action            TEXT NOT NULL,
  scope             TEXT NOT NULL,
  requested_at      TEXT NOT NULL,
  resolved          INTEGER DEFAULT 0,
  approved          INTEGER
);

CREATE TABLE IF NOT EXISTS vault_outputs (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workflow_id           TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  kind                  TEXT DEFAULT 'report',
  summary               TEXT DEFAULT '',
  ai_summary            TEXT DEFAULT '',
  raw_data_preview      TEXT DEFAULT '',
  agent_activity_json   TEXT DEFAULT '[]',
  shared                INTEGER DEFAULT 0,
  created_at            TEXT NOT NULL
);

-- Operational audit trail only — never hidden model reasoning
-- (spec §21 "Live Execution Animation" / §22 "Execution Timeline").
CREATE TABLE IF NOT EXISTS audit_log (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type        TEXT NOT NULL,
  detail            TEXT DEFAULT '',
  created_at        TEXT NOT NULL
);

-- Workflow scope of an agent, defined by the Orchestrator. An agent's chat
-- may only act within these steps (enforced server-side in routes/agents.js).
CREATE TABLE IF NOT EXISTS agent_workflow_steps (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  position          INTEGER NOT NULL,
  step              TEXT NOT NULL
);

-- The Orchestrator chat thread (user <-> orchestrator, plus agent result bubbles).
CREATE TABLE IF NOT EXISTS orchestrator_messages (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender            TEXT NOT NULL,      -- 'user' | 'orchestrator' | 'agent'
  agent_id          TEXT,
  kind              TEXT DEFAULT 'text', -- text|welcome|plan|agent_result|result|agent_created|workflow_updated
  text              TEXT DEFAULT '',
  payload_json      TEXT,
  saved             INTEGER DEFAULT 0,
  created_at        TEXT NOT NULL
);

-- External connectors (COMMAND 14): Agent -> Permission Gateway -> Connector
-- -> Scoped External Access -> Result. One row per user+provider; tokens are
-- encrypted at rest (see lib/encryption.js) and every connector supports
-- revocation (DELETE /connectors/:provider).
CREATE TABLE IF NOT EXISTS connectors (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider              TEXT NOT NULL,         -- 'google_calendar'
  scope                 TEXT NOT NULL,
  access_token_enc      TEXT NOT NULL,
  refresh_token_enc     TEXT,
  expires_at            TEXT,
  connected_at          TEXT NOT NULL,
  revoked_at            TEXT,
  UNIQUE(user_id, provider)
);

-- Short-lived CSRF-protection state for the OAuth redirect round trip.
CREATE TABLE IF NOT EXISTS oauth_states (
  state                 TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider              TEXT NOT NULL,
  created_at            TEXT NOT NULL
);
