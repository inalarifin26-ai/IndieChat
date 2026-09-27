# Personal Agentic Messaging Platform — Product & Technical Specification

## 1. Product Vision

A personal-first mobile messaging platform where the primary product is **Personal Message** and autonomous AI agents operate as personal digital workers.

The platform is intentionally different from a conventional chat app:

- Human contacts and AI agents are visually and functionally separated.
- The user owns the personal workspace and private data domain.
- Workflows are personal assets.
- The platform provides infrastructure, orchestration, agents, tools, storage, and UI.
- Nothing is shared externally unless the user explicitly consents.
- Autonomous agents may operate continuously, but only within permissions and mandates granted by the user.
- External integrations are optional connectors, not the foundation of identity or private storage.
- Platform-owned data is limited to operational necessities such as subscription, payment, account/device/security records, and legally required information.

### Core principle

> The platform provides the infrastructure. The user owns the purpose, private workspace, workflows, memory, and decisions. Agents perform work only within user-granted authority.

---

# 2. Product Principles

## 2.1 Personal-first

Phase 1 is strictly personal.

There is no:
- shared workflow editing
- team workflow access
- workspace collaboration
- agency workspace
- shared agent editing
- workflow marketplace

These may be introduced later as separate Team/Agency domains.

## 2.2 Consent-first

Every meaningful data access or external action must have an explicit consent/mandate model.

Consent is not merely a privacy settings page. It is part of the operational UX.

Examples:
- Read campaign data: consent
- Read calendar: consent
- Run an automation continuously: mandate
- Send a message externally: approval/mandate
- Publish content: approval/mandate
- Share a generated report: explicit user action unless a specific recurring mandate exists

## 2.3 Autonomous does not mean unrestricted

An agent may operate independently only inside the authority granted to it.

> Autonomous = independent execution within a defined user mandate.

## 2.4 Private by architecture

Avoid absolute claims such as "100% private."

The architectural goal is:

> Private by Architecture.

Use:
- data minimization
- scoped permissions
- Personal Vault
- encryption
- consent records
- audit trails
- temporary processing
- controlled connectors
- user-controlled external sharing

---

# 3. Primary Product Structure

```text
PERSONAL MESSAGE
│
├── CONTACTS
│   └── Human conversations
│
├── AGENTS
│   ├── Agent Center
│   ├── Agent Chat
│   └── Agent Dashboard
│
├── WORKFLOWS
│   ├── Workflow Dashboard
│   ├── Workflow Builder
│   ├── Live Execution
│   └── Execution History
│
├── PERSONAL VAULT
│   ├── Files
│   ├── Reports
│   ├── Agent Outputs
│   ├── Memory
│   └── Workflow Records
│
└── SETTINGS
    ├── Account
    ├── Security
    ├── Consent
    ├── Connections
    └── Subscription
```

The **Personal Message** remains the center of gravity.

---

# 4. Mobile Navigation

Recommended primary navigation:

```text
Messages | Agents | Workflows | Vault | More
```

### Messages

Human contacts only.

### Agents

AI workers only.

### Workflows

Personal automation only.

### Vault

Private user-owned storage and generated outputs.

### More

Settings, account, security, consent, integrations, subscription.

---

# 5. Human Contacts vs AI Agents

These must be separated.

## Contacts

Examples:
- Alex
- Sarah
- Family
- Client

## Agents

Examples:
- Personal Assistant
- Marketing Agent
- Research Agent
- Finance Agent

The UI must make the distinction immediately understandable.

> Contact = communicates with me.
>
> Agent = works for me.

---

# 6. Personal Message

The primary communication layer.

Capabilities:
- human-to-human messaging
- agent conversation
- commands
- workflow triggers
- notifications
- approval requests
- consent requests
- task completion messages
- generated output delivery

The message layer should feel familiar to users of modern messenger apps, while adding agentic objects.

---

# 7. Agent Center

Agent Center is the overall control center for the user's agents.

Example:

```text
Agent Center

Needs Attention
- Marketing Agent — Approval Required

Active
- Marketing Agent — Monitoring Campaign
- Research Agent — Researching
- Finance Agent — Processing
- Personal Assistant — Scheduled
```

Agent Center is personal only in Phase 1.

No team/agency access.

---

# 8. Individual Agent Dashboard

Each agent can have a personal dashboard.

Recommended sections:

- Overview
- Tasks
- Activity
- Permissions
- Automation
- Memory
- Settings

The dashboard is not the primary communication interface.

The Agent Chat remains the primary conversational interface.

---

# 9. Agent Chat

Agent chat supports:

- natural-language commands
- task creation
- workflow triggering
- progress
- results
- approval requests
- consent requests
- notifications
- autonomous activity messages

Example:

```text
User:
Monitor my campaign every morning.

Agent:
I can monitor Campaign Alpha every day at 09:00.

Permission required:
- Read campaign analytics
- Analyze campaign performance
- Notify you

[Allow]
```

After approval, the agent can operate autonomously inside that mandate.

---

# 10. Consent & Mandate Model

A consent/mandate should define:

```text
User
Agent
Purpose
Data Scope
Actions
Autonomy Level
External Access
Duration/Revocation
Approval Rules
Status
```

Example:

```text
Agent:
Marketing Agent

Purpose:
Campaign monitoring

Data:
Campaign Alpha analytics

Allowed:
READ
ANALYZE
GENERATE REPORT
NOTIFY USER

Not allowed:
PUBLISH
SEND EXTERNAL MESSAGE
CHANGE BUDGET

Autonomy:
Continuous

Status:
ACTIVE
```

## Important

Do not force a fixed short consent timer simply because a task may run for a long time.

For long-running automation, the user can explicitly grant an ongoing mandate.

The platform should provide:
- active mandate status
- review
- pause
- revoke
- change permissions

When an agent reaches an action outside its mandate, it pauses and requests user approval.

---

# 11. Permission Model

Use least privilege.

Permission categories:

### Data permissions
- read
- write
- create
- update
- delete

### Tool permissions
- calendar
- email
- files
- web/API
- project data
- external connectors

### Action permissions
- send
- publish
- share
- schedule
- purchase/transaction where supported

### Autonomy
- manual only
- task-level
- recurring
- continuous within mandate

---

# 12. Personal Vault

The Personal Vault is the user's private storage domain.

Possible contents:

```text
Personal Vault
├── Files
├── Reports
├── Agent Outputs
├── Memory
├── Workflow Definitions
├── Workflow Execution Records
└── User Preferences
```

The platform should minimize what is retained in platform infrastructure.

The architecture should support encryption and clear ownership boundaries.

---

# 13. Identity & Recovery

Phase 1 should not require phone number or email as the primary identity.

Preferred conceptual model:

```text
Registration
    ↓
Personal ID / PIN ID
    ↓
Secure Local Credential
    ↓
Recovery Phrase / Recovery Key
    ↓
Personal Vault
```

The recovery phrase acts as a master recovery mechanism.

Important implementation requirement:

- never store the raw recovery phrase
- use secure derivation
- support secure backup/export
- clearly warn users that losing the recovery mechanism may make recovery impossible
- separate account recovery from normal session authentication

---

# 14. Platform-Owned Minimal Data

The platform may legitimately retain operational data necessary to provide the service.

Examples:
- subscription status
- payment records
- billing information required by payment providers
- platform account identifier
- security/device records where necessary
- abuse/security logs
- legally required records
- service configuration

This does not mean the platform should automatically store all user personal content.

---

# 15. External Connectors

External services are optional.

Examples:
- Google Calendar
- Gmail
- cloud storage
- CRM
- APIs
- social platforms

Connector architecture:

```text
User
 ↓
Consent
 ↓
Permission Gateway
 ↓
Connector
 ↓
Scoped Data
 ↓
Agent
```

External systems are sources/tools, not the user's primary private storage.

---

# 16. Workflow Automation

Workflow is a personal executable object.

It is not merely a diagram.

A workflow contains:

```text
Identity
Trigger
Inputs
Nodes
Connections
Conditions
Agents
Tools
Permissions
Consent/Mandate
Approval Rules
State
Outputs
Storage
Execution History
Versions
```

---

# 17. Workflow Lifecycle

```text
DRAFT
  ↓
VALIDATE
  ↓
TEST
  ↓
READY
  ↓
ACTIVATE
  ↓
TRIGGER
  ↓
EXECUTE
  ↓
OUTPUT
  ↓
SAVE
  ↓
NOTIFY
```

If edited:

```text
ACTIVE v1.3
   ↓
Edit
   ↓
DRAFT v1.4
   ↓
Test
   ↓
Activate
```

Keep previous versions.

---

# 18. Workflow Builder

The builder should use a visual node canvas.

Recommended layout:

```text
┌────────────┬──────────────────────────┬──────────────┐
│ Node       │ Workflow Canvas         │ Configuration│
│ Library    │                          │              │
│            │ [Trigger]                │ Node config  │
│ Trigger    │     │                   │              │
│ AI         │ [Get Data]              │ Inputs       │
│ Data       │     │                   │ Outputs      │
│ Logic      │ [AI Agent]              │ Permissions  │
│ Action     │     │                   │              │
│ Output     │ [Save]                  │ Test         │
└────────────┴──────────────────────────┴──────────────┘
```

On mobile, convert these areas into:
- canvas
- bottom node drawer
- configuration bottom sheet/full-screen panel

---

# 19. Workflow Node Types

### Trigger
- manual
- schedule
- message
- webhook
- event
- agent event

### Data
- get data
- search
- read file
- read memory
- database query
- API request

### AI/Agent
- AI Agent
- Analyze
- Generate
- Classify
- Summarize
- Extract
- Decide

### Logic
- condition
- if/else
- switch
- filter
- loop
- wait
- merge
- split

### Action
- create
- update
- delete
- send
- publish
- schedule

### Approval
- user approval
- permission request
- review

### Storage
- save to vault
- save file
- save memory
- create record

### Output
- report
- file
- message
- notification
- dashboard
- action result

---

# 20. Wiring Flow

Connections represent executable data/control flow.

States:

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

Visual behavior:

### Idle

```text
○ ───────── ○ ───────── ○
```

### Running

```text
○ ────●──── ○ ───────── ○
      ↑
   data pulse
```

### Success

```text
● ═════════ ● ═════════ ○
✓           ✓
```

### Error

```text
● ═════════ ✕ ───────── ○
```

### Waiting for approval

```text
● ═════════ 🔐 ───────── ○
```

---

# 21. Live Execution Animation

When a workflow runs, animate the execution graph.

Requirements:
- active node glow
- moving data/control pulse along connections
- completed nodes change to success state
- branch selected by condition becomes active
- skipped branches visually remain inactive
- approval node pauses execution
- after approval, animation resumes from that node
- error node shows failure state
- retries show repeated execution pulse

Do not expose internal chain-of-thought.

Show operational status only:
- current node
- action
- progress
- timing
- success/error
- approval state

---

# 22. Execution Timeline

Example:

```text
09:00:01 Trigger activated
09:00:02 Campaign data requested
09:00:03 Campaign data received
09:00:05 Marketing Agent started
09:00:12 Analysis completed
09:00:13 Condition evaluated
09:00:14 Alert generated
09:00:15 Result saved
09:00:16 User notified
```

This is an operational audit trail, not chain-of-thought.

---

# 23. Human-in-the-loop

Example:

```text
Trigger
 ↓
Research
 ↓
Generate
 ↓
Approval
 ↓
Publish
```

At approval:

```text
APPROVAL REQUIRED

Marketing Agent wants to publish this campaign.

Action:
Publish to external platform

[Reject] [Approve]
```

Workflow pauses until the user decides.

---

# 24. Output System

Workflow output types:

- text
- message
- report
- document
- spreadsheet
- image
- data
- dashboard
- notification
- action result

The user can inspect the result before sharing when the action is not already covered by an explicit mandate.

---

# 25. Saving Model

Three levels:

## Workflow Definition
The blueprint.

## Execution Record
A historical run.

## Output
The result.

Example:

```text
Workflow
└── Daily Marketing Report

Executions
├── Run #1842
├── Run #1841
└── Run #1840

Outputs
├── Report 2026-09-26
├── Report 2026-09-25
└── Report 2026-09-24
```

Use autosave for drafts.

Important distinction:

> Draft workflow != Active automation.

Use explicit **Activate** to make an automation live.

---

# 26. Sharing Model — Personal Phase

There is **NO workflow sharing in Phase 1**.

Do not implement:
- Share Workflow
- Collaborative workflow editing
- Team workflow permissions
- Agency workflow permissions
- Public workflow links
- Shared workflow workspace

### Only outputs can be shared.

```text
Workflow
 ↓
Output
 ↓
User review
 ↓
Share Result
```

Possible output sharing:
- PDF
- file
- message
- controlled link
- exported result

The user chooses the recipient.

The user can also choose which data is included.

Example:

```text
Share Result

☑ Report
☑ AI Summary
☐ Raw Data
☐ Agent Activity
☐ Private Notes

[Cancel] [Share]
```

Workflow definition, credentials, private memory, and execution internals must never be implicitly shared with an output.

---

# 27. Future Team/Agency Mode

This is a future product domain, not part of Phase 1.

Later:

```text
PERSONAL MODE
My Data
My Agents
My Workflows
My Vault

TEAM MODE
Shared Projects
Shared Agents
Shared Workflows
Team Permissions

AGENCY MODE
Client Spaces
Reusable Workflows
Team Operations
Client Deliverables
```

Do not pollute Phase 1 UX with Team/Agency concepts.

---

# 28. Error Handling

Workflow node error strategies:
- stop workflow
- retry
- retry with delay
- skip
- agent recovery
- notify user

Agents may attempt recovery only within their mandate.

---

# 29. Technical Architecture

Recommended logical architecture:

```text
Mobile Client
    │
    ├── Messaging UI
    ├── Agent UI
    ├── Workflow Builder
    ├── Vault UI
    └── Consent UI
          │
          ▼
API / Application Layer
          │
    ┌─────┼──────────────┐
    ▼     ▼              ▼
Orchestrator  Permission Engine  Execution Engine
    │              │              │
    └──────────────┼──────────────┘
                   │
          ┌────────┴────────┐
          ▼                 ▼
       Agents           Connectors
          │                 │
          └────────┬────────┘
                   ▼
             Personal Vault
```

The exact technology stack should be chosen by the development team after architecture validation. Do not hard-code a stack prematurely.

---

# 30. Security Requirements

Minimum requirements:
- encryption in transit
- encryption at rest
- secure secret storage
- least privilege
- scoped access tokens
- short-lived external connector credentials where possible
- consent/mandate audit trail
- workflow execution audit trail
- revocation
- device/session management
- secure recovery flow
- no raw recovery phrase storage
- no credential leakage into workflow exports
- no implicit data sharing
- clear data deletion controls

---

# 31. UX Design Language

Visual direction:

- premium
- clean
- personal
- calm
- technical without looking cyberpunk
- messenger-first
- subtle motion
- consistent component language

Avoid:
- generic AI robot imagery
- excessive neon
- overly complex dashboards
- enterprise ERP appearance
- mixing contacts and agents
- team collaboration UI in personal phase

---

# 32. Core Mobile Screens

MVP screens:

1. Onboarding / Personal ID
2. Recovery Setup
3. Messages — Contacts
4. Agents
5. Agent Center
6. Agent Chat
7. Agent Dashboard
8. Workflows
9. Workflow Builder
10. Workflow Configuration
11. Live Workflow Execution
12. Approval/Consent
13. Execution History
14. Output Viewer
15. Share Result
16. Personal Vault
17. Settings
18. Consent Manager
19. Connector Manager
20. Subscription

---

# 33. MVP Development Priority

## Phase A — Foundation
- Personal identity
- local secure session
- recovery mechanism
- messaging foundation
- Personal Vault foundation

## Phase B — Agents
- Agent registry
- Agent Chat
- Agent Center
- Agent permissions
- activity

## Phase C — Workflow
- workflow data model
- builder
- node system
- wiring
- validation
- execution engine
- state machine

## Phase D — Consent
- permission engine
- mandate model
- approval nodes
- consent UI
- audit trail

## Phase E — Output
- output objects
- Vault storage
- result viewer
- explicit sharing

## Phase F — External Connectors
- connector framework
- scoped authorization
- external action approval
- revocation

---

# 34. Acceptance Criteria

The MVP is successful when:

1. A user can create an agent.
2. A user can chat with an agent.
3. A user can create a workflow.
4. A workflow can contain multiple nodes.
5. Nodes can be connected visually.
6. The workflow can be saved as a private personal asset.
7. The workflow can be tested.
8. The workflow can be activated.
9. The workflow can execute automatically.
10. Live execution shows operational animation.
11. The workflow can pause for user approval.
12. Approval resumes execution.
13. Results are saved to the Personal Vault.
14. The user can view execution history.
15. The user can edit/version the workflow.
16. No other user can access the workflow in Phase 1.
17. Only the result can be explicitly shared.
18. External actions require appropriate consent/mandate.
19. User can revoke permissions.
20. No raw recovery phrase is stored by the platform.

---

# 35. Product Mantra

> Personal by default.
>
> Consent by design.
>
> Autonomous within authority.
>
> Private by architecture.
>
> User-owned workflows.
>
> Explicit sharing of results.
>
> The platform provides the infrastructure; the user controls the work.
