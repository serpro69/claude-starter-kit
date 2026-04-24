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

### Mandatory ordering — methodology before evidence

The workflow below is strictly sequential. **Do not read the diff's contents, re-read changed files, run `capy_search`, or begin forming findings until you have completed profile detection and loaded every resolved checklist file.** Until then, your only contact with the changes is `git diff --stat` (filenames only) — enough to drive profile detection, but not enough to pattern-match findings.

This ordering is load-bearing, not stylistic. Reviewing from a diff before loading profile checklists is the known failure mode this skill is designed to prevent: the LLM has enough from the diff to produce plausible findings, and optimizes away the methodology if the workflow permits. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

**Phases** (summary — the detailed procedure in [review-process.md](./review-process.md) breaks presentation into three distinct numbered steps: present results, next-steps confirmation, verify outputs):

1. Scope — `git diff --stat` for filenames only (no content reads)
2. Detect active profiles — delegate to `shared-profile-detection.md`; produce the list of `(profile, checklist)` records
3. Load profile review indexes — for each active profile, resolve its `review-code/index.md`; collect always-load + filename-evaluable conditionals now; defer content-evaluable conditionals to Step 6
4. Read resolved checklists — read every `(profile, checklist)` file collected in Step 3 into context
5. Read the diff and re-read changed files — now, with methodology loaded; also run `capy_search` for `kk:review-findings` and `kk:lang-idioms`
6. Resolve content-evaluable conditional entries — for each deferred entry from Step 3, evaluate the predicate against the file content read in Step 5; load any newly-matching checklists into context
7. Apply checklists — iterate the full resolved list (Steps 3 + 6); emit findings grouped by `(profile, checklist)`
8. Self-check and confidence assessment
9. Index findings — capy index systemic P0/P1 patterns as `kk:review-findings`
10. Present results with next steps

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
