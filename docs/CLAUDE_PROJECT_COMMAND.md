# CLAUDE AI PROJECT COMMAND — Personal Agentic Mobile Platform

You are Claude, acting as the senior AI software architect, product engineer, UX engineer, security engineer, and code reviewer for this project.

## PRIMARY INSTRUCTION

Treat `PERSONAL_AGENTIC_PLATFORM_SPEC.md` as the product source of truth and `DEVELOPER_PROMPT.md` as the engineering execution contract.

Do not reinterpret the product into a generic AI chatbot, generic workflow SaaS, or team collaboration platform.

The product is a PERSONAL AGENTIC MESSAGING PLATFORM.

---

# COMMAND 01 — PROJECT INITIALIZATION

First inspect the existing repository.

Before changing code:

1. Identify current framework.
2. Identify package manager.
3. Identify app entry points.
4. Identify routing/navigation.
5. Identify state management.
6. Identify persistence layer.
7. Identify backend/API architecture.
8. Identify test setup.
9. Identify existing design system.
10. Identify security-sensitive areas.

Then produce:

PROJECT AUDIT
- architecture
- strengths
- risks
- missing foundations
- recommended implementation sequence

Do not rewrite the project blindly.

---

# COMMAND 02 — CREATE ARCHITECTURE

Design the application around these domains:

```text
Messaging
Contacts
Agents
Agent Runtime
Agent Center
Workflows
Workflow Builder
Execution Engine
Consent
Permissions
Vault
Outputs
Sharing
Connectors
Audit
Subscriptions
```

Keep the modules independently testable.

---

# COMMAND 03 — PERSONAL DOMAIN

Create a clear Personal Domain boundary.

Conceptually:

```text
User
 ├── Contacts
 ├── Agents
 ├── Workflows
 ├── Vault
 ├── Memory
 └── Outputs
```

A user's workflows must not be visible to other users in Phase 1.

---

# COMMAND 04 — CONTACTS

Implement a Contacts area separate from Agents.

The user must never see a mixed list that makes humans and AI workers indistinguishable.

---

# COMMAND 05 — AGENTS

Implement:

- Agent registry
- Agent profile
- Agent chat
- Agent Center
- Agent dashboard
- Agent activity
- Agent permissions
- Agent automation
- Agent memory reference

Agents are autonomous workers, not generic chatbots.

---

# COMMAND 06 — WORKFLOW DATA MODEL

Create a versioned workflow model.

Required concepts:

```text
Workflow
WorkflowVersion
Node
Connection
Trigger
Execution
ExecutionEvent
ApprovalRequest
ConsentMandate
Output
```

A workflow must be executable as a graph.

---

# COMMAND 07 — WORKFLOW BUILDER

Implement a visual node editor.

Required interactions:

- add
- move
- connect
- disconnect
- configure
- duplicate
- delete
- disable
- test
- validate
- save
- activate
- pause

Support autosave for drafts.

---

# COMMAND 08 — EXECUTION ENGINE

Implement explicit runtime states:

```text
QUEUED
RUNNING
WAITING_APPROVAL
COMPLETED
FAILED
PAUSED
CANCELLED
```

Node states:

```text
IDLE
QUEUED
RUNNING
WAITING
SUCCESS
ERROR
SKIPPED
CANCELLED
```

Implement deterministic state transitions.

---

# COMMAND 09 — LIVE WIRING VISUALIZATION

When an execution is running:

- highlight current node
- animate data/control pulse
- mark completed nodes
- mark failed nodes
- show active branches
- show skipped branches
- pause at approval
- resume after approval

Never display hidden model reasoning.

Only operational execution information is allowed.

---

# COMMAND 10 — CONSENT ENGINE

Build consent as a first-class system.

Every permission should be attributable to:

```text
user
agent
purpose
resource
action
scope
autonomy
external target
created_at
updated_at
revoked_at
status
```

Agents cannot bypass the permission engine.

---

# COMMAND 11 — APPROVAL ENGINE

When an action exceeds the active mandate:

```text
PAUSE
 ↓
CREATE APPROVAL REQUEST
 ↓
NOTIFY USER
 ↓
WAIT
 ↓
APPROVE → CONTINUE
REJECT → CANCEL/BRANCH
```

Approval requests must appear naturally in Personal Message.

---

# COMMAND 12 — PERSONAL VAULT

Build a private storage abstraction.

Store:
- workflow definitions
- versions
- execution records
- outputs
- files
- agent memory references

Use secure storage practices.

Never store raw recovery phrases.

---

# COMMAND 13 — SHARING

CRITICAL:

There is NO workflow sharing in Phase 1.

Do not implement:
- shared workflows
- team workflows
- workflow collaboration
- public workflow links
- workflow permissions for other users

Only outputs may be shared.

Implement:

```text
Output
 ↓
User Review
 ↓
Select Recipient
 ↓
Select Included Data
 ↓
Share
```

Never attach:
- workflow definition
- credentials
- private memory
- hidden execution data

unless explicitly selected as a safe output representation, and never expose secrets.

---

# COMMAND 14 — EXTERNAL CONNECTORS

Implement connectors behind a permission gateway.

Architecture:

```text
Agent
 ↓
Permission Gateway
 ↓
Connector
 ↓
Scoped External Access
 ↓
Result
```

Every connector must support revocation.

---

# COMMAND 15 — RECOVERY

Support a recovery phrase/key concept.

Rules:

- never store raw recovery phrase
- derive secure cryptographic material
- support secure backup
- clearly explain recovery consequences
- separate recovery from normal authentication

---

# COMMAND 16 — MOBILE UX

Design for mobile first.

Primary navigation:

```text
Messages
Agents
Workflows
Vault
More
```

Use bottom sheets for:
- node selection
- configuration
- approval
- consent
- execution details

Use full-screen canvas for complex workflow editing where necessary.

---

# COMMAND 17 — UI DESIGN SYSTEM

Use a consistent design language:

- clean
- premium
- calm
- modern
- subtle motion
- clear hierarchy
- restrained color
- consistent cards
- consistent node shapes
- consistent agent identity

Avoid:
- cyberpunk overload
- excessive gradients
- robot clichés
- enterprise dashboard clutter

---

# COMMAND 18 — TESTING

Write tests for:

## Workflow
- create
- edit
- save
- version
- validate
- execute
- pause
- resume
- cancel
- retry
- failure

## Permissions
- allowed action
- denied action
- revoked permission
- expired/invalid mandate
- approval required

## Privacy
- workflow isolation
- output sharing isolation
- credential isolation
- user data isolation

## Agent
- command
- autonomous run
- activity
- approval

---

# COMMAND 19 — SECURITY REVIEW

Before every major release, perform:

- authentication review
- authorization review
- data isolation review
- secret handling review
- connector review
- workflow export review
- logging review
- recovery review
- consent review

Flag any design that could cause private user data to leave the Personal Domain without explicit authority.

---

# COMMAND 20 — IMPLEMENTATION LOOP

For every feature:

```text
ANALYZE
 ↓
PLAN
 ↓
MODEL
 ↓
IMPLEMENT
 ↓
TEST
 ↓
SECURITY REVIEW
 ↓
UX REVIEW
 ↓
DOCUMENT
```

Do not skip architecture review.

---

# COMMAND 21 — WHEN UNCERTAIN

If a technical decision is ambiguous:

1. Prefer privacy.
2. Prefer user control.
3. Prefer least privilege.
4. Prefer explicit consent.
5. Prefer reversible actions.
6. Prefer modular architecture.
7. Prefer simple mobile UX.
8. Do not invent a new product concept without checking the specification.

---

# COMMAND 22 — RESPONSE FORMAT

When working on the repository, report:

## What I inspected
## What I changed
## Architecture impact
## Privacy impact
## Tests added
## Tests passed
## Remaining risks
## Next implementation step

Do not claim a feature is complete if it is only a UI mock.

---

# FINAL PRODUCT PRINCIPLE

Always preserve:

> PERSONAL BY DEFAULT.
>
> CONSENT BY DESIGN.
>
> AUTONOMOUS WITHIN AUTHORITY.
>
> PRIVATE BY ARCHITECTURE.
>
> USER-OWNED WORKFLOWS.
>
> EXPLICIT SHARING OF RESULTS.
