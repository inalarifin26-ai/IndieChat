const path = require('node:path');
const fs = require('node:fs');
const { DatabaseSync } = require('node:sqlite');

const DB_PATH = process.env.DB_PATH || './data/indie.db';

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA foreign_keys = ON;');
db.exec('PRAGMA journal_mode = WAL;');

const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
db.exec(schema);

// Lightweight forward-only migrations: add columns introduced after the
// first release so existing local databases keep working.
function ensureColumns(table, cols) {
  const have = db.prepare(`PRAGMA table_info(${table})`).all().map((r) => r.name);
  for (const [name, def] of cols) {
    if (!have.includes(name)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${name} ${def}`);
  }
}

const messageCols = [
  ['reply_to_id', 'TEXT'],
  ['deleted', 'INTEGER DEFAULT 0'],
  ['reactions_json', "TEXT DEFAULT '{}'"],
  ['my_reaction', 'TEXT'],
  ['saved', 'INTEGER DEFAULT 0'],
];
ensureColumns('contact_messages', [
  ['kind', "TEXT DEFAULT 'text'"],
  ['payload_json', 'TEXT'],
  ['status', "TEXT DEFAULT 'sent'"],
  ...messageCols,
]);
ensureColumns('agent_messages', messageCols);
ensureColumns('contacts', [
  ['info', "TEXT DEFAULT ''"],
  ['grp', "TEXT DEFAULT ''"],
  ['muted', 'INTEGER DEFAULT 0'],
  ['unread', 'INTEGER DEFAULT 0'],
]);

ensureColumns('users', [['display_name', "TEXT DEFAULT ''"]]);
ensureColumns('contacts', [
  ['kind', "TEXT DEFAULT 'person'"], // 'person' | 'group'
  ['description', "TEXT DEFAULT ''"],
  ['visibility', "TEXT DEFAULT 'private'"], // groups: 'public' | 'private'
  ['allow_new', 'INTEGER DEFAULT 1'],
]);
ensureColumns('contact_messages', [['sender_name', 'TEXT']]); // which member said it (group chats)

ensureColumns('workflow_nodes', [
  ['condition_json', 'TEXT'], // logic-node branch condition — see lib/executionEngine.js chooseBranch()
]);

// connectors / oauth_states are new tables (added by schema.sql on every
// boot via CREATE TABLE IF NOT EXISTS), so no ALTER TABLE migration is
// needed for them specifically — listed here only as a reminder for future
// column additions to those tables.

module.exports = db;
