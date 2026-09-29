# Indie Backend (skeleton)

A real, runnable backend for the Personal Agentic Messaging Platform spec:
auth (Personal ID + recovery phrase), a Permission/Consent Engine, an
Execution Engine with live (SSE) workflow execution, and a Personal Vault
with an explicit Share Result endpoint. Every user-owned table is scoped by
`user_id` and every query filters on it server-side — see "Data isolation"
below.

Built with **zero native dependencies**: Express for HTTP, and Node's
built-in `node:sqlite` for storage (no `better-sqlite3`/`node-gyp` native
compile step to fight with). Tested end-to-end in this sandbox — see
"What was actually tested" below.

## Requirements

- **Node.js ≥ 22.5** (for `node:sqlite`). Check with `node -v`.
  `node:sqlite` is still marked experimental upstream, so every run command
  passes `--experimental-sqlite`; you'll see one harmless warning line on
  startup.

## Setup

```bash
cd indie_backend
npm install
cp .env.example .env      # edit JWT_SECRET before any real deployment
npm start                 # http://localhost:4000
```

`npm run dev` restarts on file changes (`node --watch`).

## Quick smoke test

```bash
curl -X POST http://localhost:4000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"credential":"a-strong-local-credential","seedDemo":true}'
```

`seedDemo: true` populates the new account with the same demo contacts /
agents / workflow / mandates / vault outputs the Flutter app ships with, so
you immediately have something to explore. Save the returned
`recoveryPhrase` — it is never shown again — and use the returned `token` as
`Authorization: Bearer <token>` on every other request.

## Automated tests

```bash
npm test
```

Runs `test/smoke.test.js` (Node's built-in test runner) against an
in-process app instance and a throwaway SQLite file: registration shape,
cross-user data isolation (a second account gets a 404 on the first
account's workflow), and workflow validation. All three pass as of this
writing.

## What was actually tested in the build sandbox (not just written)

Every one of these was exercised with `curl` against a running instance
before this package was handed off:

- register (with `seedDemo`) → `/auth/me` → `/agents` → `/workflows`
- `/workflows/:id/validate` before and after connecting nodes
- `/workflows/:id/run` → live `/workflows/executions/:id/stream` (SSE) →
  observed node-by-node events, pausing at the Approval node exactly as
  designed
- `/consent/approvals/:id/resolve` with `approve:true` → execution resumed
  and completed → confirmed via `/workflows/executions/:id/timeline`
- `/vault/outputs/:id/share` with only `report` + `aiSummary` selected →
  confirmed `rawData`/`agentActivity` are structurally absent from the
  response, not just hidden
- a second registered account requesting the first account's workflow → 404
  (data isolation enforced server-side, not just client-side filtering)
- `/consent/mandates/:id` → `revoked`
- bad login credential → 401
- `/auth/recover` with the recovery phrase → new token issued, **and** the
  old token instantly stops working (`Session revoked`) — confirms
  recovery revokes prior sessions as documented in the spec


## Chat rooms, Orchestrator & workflow-scoped agents (new)

- **Contacts** are people only (`POST/PATCH/DELETE /contacts`) — reply quotes,
  emoji reactions, delete (tombstoned), save-to-Vault on attachments, and
  simulated delivery ticks (sent → delivered → read).
- **Agents can only be created by the Orchestrator** (`/orchestrator/messages`)
  — there is intentionally no `POST /agents`. Each agent gets a `workflow`
  (an ordered list of steps) that a **server-side scope check**
  (`lib/agentScope.js`) enforces on every message sent to that agent: in
  scope → it works the step and posts a result card; out of scope → it
  refuses and points back to the Orchestrator.
- Giving the Orchestrator a task (e.g. "Plan a 7-day trip to Bali") creates
  any missing agents, **a real workflow** (visible under `/workflows`, with
  real nodes and connections), runs each agent, and posts a combined result
  you can save to the Vault.
- See the updated API reference table below for the new endpoints
  (`/contacts/:id/messages/*`, `/agents/:id/messages/*`, `/orchestrator/*`).

## API reference

All routes except `/health` and `/auth/*` require `Authorization: Bearer <token>`.

### Auth
| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/auth/register` | `{ credential, seedDemo? }` | Returns `{ personalId, recoveryPhrase, token }` — phrase shown once |
| POST | `/auth/login` | `{ personalId, credential }` | Returns `{ token }` |
| POST | `/auth/recover` | `{ personalId, recoveryPhrase, newCredential }` | Resets credential, revokes old sessions |
| POST | `/auth/logout` | — | Revokes current session |
| GET | `/auth/me` | — | Current account |

### Contacts / Agents
| Method | Path |
|---|---|
| GET | `/contacts` |
| POST | `/contacts` `{ name, initials?, status? }` |
| GET/POST | `/contacts/:id/messages` |
| GET | `/agents`, `/agents/:id` |
| GET/POST | `/agents/:id/messages` (POST = send a command) |
| GET | `/agents/:id/activity`, `/agents/:id/memory` |

### Workflows (builder + execution)
| Method | Path |
|---|---|
| GET/POST | `/workflows` |
| GET/PATCH/DELETE | `/workflows/:id` (`PATCH` for `lifecycle`/`name`/`description`) |
| POST | `/workflows/:id/nodes` `{ category, title?, subtitle?, position? }` |
| PATCH/DELETE | `/workflows/:id/nodes/:nodeId` |
| POST | `/workflows/:id/nodes/:nodeId/duplicate` |
| POST/DELETE | `/workflows/:id/connections` / `/workflows/:id/connections/:connectionId` |
| POST | `/workflows/:id/validate` → `{ valid, issues[] }` |
| POST | `/workflows/:id/run` → `{ executionId }` (202) |
| GET | `/workflows/:id/executions`, `/workflows/executions/:executionId/timeline` |
| GET | `/workflows/executions/:executionId/stream` — **SSE**, `event: update` frames shaped `{type:'node'|'log'|'state', ...}` |

### Consent / Vault / Audit
| Method | Path |
|---|---|
| GET | `/consent/mandates` |
| PATCH | `/consent/mandates/:id` `{ status: active\|paused\|revoked }` |
| GET | `/consent/approvals` |
| POST | `/consent/approvals/:id/resolve` `{ approve: bool }` — resumes the paused execution if approved |
| GET | `/vault/outputs`, `/vault/outputs/:id` |
| POST | `/vault/outputs/:id/share` `{ recipient?, include: { report, aiSummary, rawData, agentActivity } }` |
| GET | `/audit?limit=100` |

## Data isolation

Every user-owned table (`contacts`, `agents`, `workflows`, …) carries a
`user_id` column, and every route does `WHERE ... AND user_id = ?` — never
just a client-supplied filter. Cross-account access returns a flat `404`,
not a `403` (so a workflow ID leaking to the wrong account doesn't even
confirm the row exists) — see COMMAND 19 "Security Review" /
Invariant 2 in the skill file.

## Simplifications called out on purpose (read before treating this as final)

- **Recovery phrase generation is NOT full BIP-39.** It draws 12 words
  uniformly at random from the real BIP-39 English wordlist (so the words
  look and feel standard), but it skips the checksum-word derivation from
  entropy that real BIP-39/HD-wallet tooling relies on. Swap in the `bip39`
  npm package before treating these phrases as interoperable with wallet
  software.
- **The local "device credential" is taken as a plain request-body field**
  for MVP simplicity. A production client should derive this from a
  device-bound secret/biometric unlock rather than a typed password sent
  over the wire on every login.
- **Node execution order is insertion order** (SQLite `rowid`), not a real
  graph traversal of `workflow_connections` with condition-branch
  evaluation. Fine for the seeded linear demo workflows; a real Execution
  Engine needs topological execution — see COMMAND 08.
- **The approval flow doesn't yet know which node "belongs" to which
  agent** — it attributes a pending approval to the user's first agent as a
  demo shortcut. A real node needs an explicit `agent_id` column.
- **SSE, not WebSockets** — simpler and one-directional, which is all the
  live execution feed needs. Fine for single-instance deployment; a
  multi-instance deployment needs a shared pub/sub (Redis, etc.) instead of
  the in-memory `EventEmitter` map in `lib/executionEngine.js`.
- **No rate limiting, no HTTPS termination, no connector OAuth** yet — this
  is a skeleton, not a hardened deployment. See COMMAND 19 before shipping.

## Project structure

```
src/
  index.js               # Express app wiring
  db.js                  # node:sqlite bootstrap + schema load
  schema.sql              # every table, one user_id column each
  middleware/auth.js      # JWT bearer verification + session revocation check
  lib/
    secret.js              # scrypt hash/verify — credentials & recovery phrase
    mnemonic.js             # BIP-39 wordlist -> recovery phrase
    personalId.js           # human-friendly Personal ID generator
    audit.js                # append-only operational audit log helper
    executionEngine.js      # step-through workflow runner + SSE emitter
    seedDemoData.js          # optional demo content on register
  routes/
    auth.js  contacts.js  agents.js  workflows.js  consent.js  vault.js  audit.js
test/
  smoke.test.js            # node:test — isolation, validation, register shape
```

## Next steps (in priority order)

1. Point the Flutter app at this backend instead of its in-memory mock data
   (see the Flutter package's updated README for the API client wiring).
2. Real `bip39` package for the recovery phrase.
3. A proper topological Execution Engine that follows `workflow_connections`
   and evaluates `logic`/condition nodes, instead of insertion-order.
4. One real external connector (e.g. Google Calendar) behind a Permission
   Gateway, with OAuth and scoped, revocable tokens.
5. Move `JWT_SECRET` and friends to a real secrets manager before any
   non-local deployment.
