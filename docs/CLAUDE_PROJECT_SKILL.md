# CLAUDE PROJECT SKILL — Personal Agentic Platform Development

## Skill Name

`personal-agentic-platform-engineering`

## Purpose

This skill instructs Claude to develop a privacy-first, personal agentic messaging platform with autonomous workflows, explicit consent, private storage, and controlled external actions.

---

## Core Mental Model

Think of the product as:

```text
PERSONAL MESSAGE
       ↓
ORCHESTRATOR
       ↓
AGENTS
       ↓
WORKFLOWS
       ↓
EXECUTION ENGINE
       ↓
PERSONAL VAULT
```

Consent and permission are cross-cutting controls:

```text
           CONSENT / PERMISSION
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
    Agents       Workflows     Connectors
```

---

## Product Invariants

Never violate these:

### Invariant 1 — Personal ownership

A workflow belongs to its user.

### Invariant 2 — No Phase 1 workflow sharing

Other users cannot access, edit, execute, or inspect another user's workflow.

### Invariant 3 — Result sharing only

The user may explicitly share generated outputs.

### Invariant 4 — Consent before authority

No agent gets authority merely because it exists.

### Invariant 5 — Autonomous within mandate

An autonomous agent cannot perform actions outside its current authority.

### Invariant 6 — External actions are controlled

External systems are accessed through permission-controlled connectors.

### Invariant 7 — No secret leakage

Credentials, recovery secrets, and private memory must not appear in outputs or workflow exports.

### Invariant 8 — Operational transparency

Show what the system is doing without exposing hidden model reasoning.

---

# WORKFLOW IMPLEMENTATION PATTERN

Represent a workflow as a directed graph.

```text
Trigger
  ↓
Node
  ↓
Node
  ├── Success
  ├── Error
  └── Approval
```

Each node must have:
- stable ID
- type
- configuration
- input
- output
- permission requirements
- runtime state

---

# EXECUTION PATTERN

```text
createExecution()
      ↓
validateWorkflow()
      ↓
resolvePermissions()
      ↓
runNode()
      ↓
recordEvent()
      ↓
advanceGraph()
      ↓
repeat
```

At approval:

```text
createApprovalRequest()
      ↓
persistExecutionState()
      ↓
notifyUser()
      ↓
WAITING_APPROVAL
      ↓
resumeExecution()
```

---

# DATA ISOLATION PATTERN

All user-owned entities should be scoped to the authenticated user.

Conceptually:

```text
user_id
 ├── workflows
 ├── agents
 ├── messages
 ├── vault
 ├── outputs
 └── executions
```

Never rely solely on client-side filtering.

Enforce authorization at the server/data layer as well.

---

# OUTPUT SHARING PATTERN

```text
workflow execution
       ↓
output
       ↓
user review
       ↓
share request
       ↓
selected recipient
       ↓
selected fields/data
       ↓
share
```

Never treat "workflow sharing" as a side effect of output sharing.

They are different security domains.

---

# MOBILE WORKFLOW UX PATTERN

Desktop-like workflow canvas can be adapted for mobile with:

- pinch zoom
- pan
- node tap
- bottom node drawer
- bottom configuration sheet
- execution overlay
- compact minimap where useful

Primary mobile interaction:

```text
Tap Node
 ↓
Bottom Sheet
 ↓
Configure
 ↓
Save
```

For connecting nodes:

```text
Drag output handle
 ↓
Move to target
 ↓
Drop
 ↓
Validate connection
 ↓
Create edge
```

---

# LIVE EXECUTION VISUALIZATION

Use visual states rather than text-heavy logs.

Example:

```text
[Trigger ✓]
     │
     ●───────>
[Get Data ✓]
     │
     ●───────>
[AI Agent ◉]
     │
     │
     ▼
[Approval 🔐]
```

When approved:

```text
[Approval ✓]
     │
     ●───────>
[Publish ◉]
```

---

# CONSENT UI PATTERN

Always explain:

1. What is being accessed?
2. Why?
3. What action is requested?
4. What is the scope?
5. Is it one-time or recurring?
6. Can the user revoke it?

Example:

```text
Marketing Agent

Wants to:
Read campaign analytics

Purpose:
Monitor Campaign Alpha

Access:
Read only

Autonomy:
Daily at 09:00

[Allow] [Deny]
```

---

# ERROR RECOVERY PATTERN

An agent may recover only within authority.

```text
ERROR
 ↓
Can retry?
 ├── yes → retry
 └── no
       ↓
Can agent recover?
 ├── yes → recover
 └── no → notify user
```

Never let "AI recovery" silently bypass permissions.

---

# AUDIT PATTERN

Record operational events:

- workflow started
- node started
- node completed
- node failed
- approval requested
- approval granted
- approval rejected
- output created
- external action executed
- workflow paused
- workflow resumed
- workflow cancelled

Do not record hidden chain-of-thought.

---

# CODE QUALITY RULES

Prefer:
- typed domain models
- explicit interfaces
- pure state transitions where possible
- deterministic execution
- unit tests
- integration tests
- clear error types
- immutable execution history
- versioned workflow definitions

Avoid:
- global mutable state
- implicit permissions
- UI-only authorization
- hidden side effects
- hard-coded credentials
- unversioned workflow mutation

---

# REVIEW CHECKLIST

Before accepting a feature:

### Product
- Does it preserve personal-first architecture?
- Does it preserve message-first UX?

### Privacy
- Can another user access private workflow data?
- Can an output accidentally include private data?
- Can credentials leak?

### Consent
- Is authority explicit?
- Can it be revoked?
- Does the agent stop when authority is missing?

### Workflow
- Is state persisted?
- Can it recover after interruption?
- Is execution observable?

### Mobile
- Is the interaction usable on a small screen?
- Are controls reachable?
- Is the workflow understandable without a desktop canvas?

### Security
- Is authorization enforced server-side?
- Are secrets protected?
- Are connector scopes minimized?

---

# DEVELOPMENT STYLE

Claude should act as:
- senior engineer
- architect
- security reviewer
- UX reviewer
- test engineer

Claude should not:
- invent team features in Phase 1
- add workflow sharing
- bypass consent
- assume unrestricted autonomy
- store raw recovery secrets
- claim privacy guarantees that the architecture cannot support

---

# Success Definition

The platform should feel like:

> A personal messenger that contains autonomous digital workers, where the user owns the private workspace and can visually build, run, monitor, and control workflows.

It should NOT feel like:

> An enterprise automation dashboard with a chatbot attached.
