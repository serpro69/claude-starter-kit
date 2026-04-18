---
name: review-code
description: |
  Code review of current git changes with an expert senior-engineer lens. Detects SOLID violations, security risks, and proposes actionable improvements.
  Use when performing code reviews.
---

# SOLID Code Review

## Overview

Perform a structured review of the current git changes with focus on SOLID, architecture, removal candidates, and security risks. Default to review-only output unless the user asks to implement changes.

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection — the set of reference checklists loaded for a given diff — is delegated to the shared procedure at [shared-profile-detection.md](shared-profile-detection.md). The workflow below invokes it in Step 2 and uses the resulting `(profile, checklist)` list to drive Steps 3–4.

## Required Outputs

Before declaring the review complete, verify all outputs are delivered:

- [ ] Review report presented to user
- [ ] P0/P1 systemic findings indexed as `kk:review-findings` (skip if no qualifying findings)
- [ ] Next steps confirmation from user

Indexing is owned by this skill — callers (e.g., `implement`) do NOT duplicate it.

## Review Modes

### Standard Mode (`/kk:review-code`)

Reviews code in the main conversation context. Fast, single-pass review using the workflow below.

### Isolated Mode (`/kk:review-code:isolated`)

Delegates detection to independent reviewers that did not write the code, then annotates their findings with author context. Two parallel reviewers: a `code-reviewer` sub-agent and `pal codereview` (external model in native format). Produces a report organized by agreement level with corroborated findings highlighted.

- **Cost**: Higher (sub-agent + external model + annotation)
- **Isolation**: True — reviewers have zero authorship bias or session context
- **Degradation**: Graceful — if one reviewer fails, proceeds with the other; if both fail, suggests standard mode fallback
- **Best for**: When extra rigor is worth the cost (pre-merge, high-stakes changes)

See [review-isolated.md](./review-isolated.md) for the isolated workflow.

## Severity Levels

| Level  | Name     | Description                                                      | Action                             |
| ------ | -------- | ---------------------------------------------------------------- | ---------------------------------- |
| **P0** | Critical | Security vulnerability, data loss risk, correctness bug          | Must block merge                   |
| **P1** | High     | Logic error, significant SOLID violation, performance regression | Should fix before merge            |
| **P2** | Medium   | Code smell, maintainability concern, minor SOLID violation       | Fix in this PR or create follow-up |
| **P3** | Low      | Style, naming, minor suggestion                                  | Optional improvement               |

## Workflow

**Phases:**

1. Preflight context — scope changes, re-read changed files, search prior findings
2. Detect active profiles — delegate to `shared-profile-detection.md`; produce the list of `(profile, checklist)` records
3. Load profile review indexes — for each active profile, resolve its `review-code/index.md` and collect always-load + matching conditional checklists
4. Apply checklists — iterate the resolved list; emit findings grouped by `(profile, checklist)`
5. Self-check and confidence assessment
6. Index findings — capy index systemic P0/P1 patterns as `kk:review-findings`
7. Present results with next steps

See [review-process.md](./review-process.md) for the detailed step-by-step process.

## Invocation

Standard mode:

```
/kk:review-code
```

Isolated mode with independent sub-agents:

```
/kk:review-code:isolated
```
