# Personal Agentic Mobile Platform — Development Package

Files in this package:

- `PERSONAL_AGENTIC_PLATFORM_SPEC.md` — Product, UX, privacy, workflow, architecture and MVP specification.
- `DEVELOPER_PROMPT.md` — Main prompt for a developer/AI coding agent.
- `CLAUDE_PROJECT_COMMAND.md` — Project-level command prompt for Claude AI.
- `CLAUDE_PROJECT_SKILL.md` — Reusable Claude skill/instruction set for development.

## Recommended Claude workflow

1. Put `PERSONAL_AGENTIC_PLATFORM_SPEC.md` in the project root.
2. Give Claude `CLAUDE_PROJECT_COMMAND.md` as the project instruction.
3. Load/use `CLAUDE_PROJECT_SKILL.md` as the project development skill.
4. Ask Claude to audit the repository before writing code.
5. Implement in MVP phases.
6. Require tests and security review at every major milestone.

## First command to Claude

Read:
- PERSONAL_AGENTIC_PLATFORM_SPEC.md
- DEVELOPER_PROMPT.md
- CLAUDE_PROJECT_COMMAND.md
- CLAUDE_PROJECT_SKILL.md

Then inspect the existing repository without changing code.

Return:
1. Current architecture
2. Existing stack
3. Missing modules
4. Recommended folder structure
5. Data model proposal
6. Workflow execution architecture
7. Consent/permission architecture
8. Security risks
9. MVP implementation sequence

Do not implement until the architecture audit is complete.

## Product boundary

Phase 1 is personal only.

Workflow sharing does NOT exist.

Only workflow outputs/results can be explicitly shared by the user.

Team and agency features belong to a future product domain.
