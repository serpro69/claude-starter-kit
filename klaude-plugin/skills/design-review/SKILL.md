---
name: design-review
description: |
  Review design and implementation docs produced by analysis-process. Evaluates document quality, internal consistency, and technical soundness.
  Use after analysis-process completes and before starting implementation-process.
---

# Design Review

For capy knowledge base conventions, see [capy-knowledge-protocol.md](../_shared/capy-knowledge-protocol.md).

## Overview

Pre-implementation review gate that evaluates design documents produced by `analysis-process` before code is written. Sits between `analysis-process` (creates docs) and `implementation-process` (executes them). Reviews two dimensions: document quality/structure (completeness, internal consistency, clarity, convention adherence) and technical soundness (architectural viability, edge cases, failure modes, trade-off analysis).

## Review Modes

### Standard Mode (`/kk:design-review`)

Reviews design documents in the main conversation context. Fast, single-pass review using the workflow below.

### Isolated Mode (`/kk:design-review:isolated`)

Delegates detection to independent reviewers that did not participate in the analysis-process, then annotates their findings with author context. Two parallel reviewers: a `design-reviewer` sub-agent and `pal codereview` (external model in native format). Produces a report organized by agreement level with corroborated findings highlighted.

- **Cost**: Higher (sub-agent + external model + annotation)
- **Isolation**: True — reviewers have zero authorship bias or session context
- **Degradation**: Graceful — if one reviewer fails, proceeds with the other; if both fail, suggests standard mode fallback
- **Best for**: When extra rigor is worth the cost (before starting implementation of high-stakes features)

See [review-isolated.md](./review-isolated.md) for the isolated workflow.

## Finding Types

| Type | Code | Description |
|------|------|-------------|
| Incomplete Spec | `INCOMPLETE` | Section lacks sufficient detail for implementation |
| Internal Inconsistency | `INCONSISTENT` | Two parts of the docs contradict each other |
| Technical Risk | `TECH_RISK` | Architecture choice has unaddressed failure modes, scalability concerns, or edge cases |
| Missing Concern | `MISSING` | Cross-cutting concern is absent (error handling, migration, backwards compatibility) |
| Ambiguity | `AMBIGUOUS` | Requirements can be interpreted multiple ways, likely to cause implementation divergence |
| Structure Issue | `STRUCTURE` | Document doesn't follow project conventions — missing sections, vague subtasks |

## Severity Levels

| Level | Name | Description | Action |
|-------|------|-------------|--------|
| **P0** | Critical | Fundamental flaw — design will not work as described, or critical requirement is missing | Must fix before implementation |
| **P1** | High | Significant gap — likely to cause rework or wrong implementation | Should fix before implementation |
| **P2** | Medium | Moderate concern — ambiguity or missing detail that could cause confusion | Fix or create follow-up |
| **P3** | Low | Minor — style, structure, or nitpick | Optional |

## Workflow

**Phases:**

1. Load documents — parse scope, locate feature directory, read in-scope docs
2. Capy search — search `kk:arch-decisions` and `kk:review-findings` for prior context
3. Document quality review — completeness, clarity, consistency, convention adherence
4. Technical soundness review — viability, edge cases, trade-offs, scalability, testing strategy
5. Self-check and confidence assessment — re-read, question assumptions, assign confidence
6. Present findings with next steps

See [review-process.md](./review-process.md) for the detailed step-by-step process.

## Invocation

Standard mode — reviews `design.md` + `implementation.md` by default:

```
/kk:design-review [feature-name]
```

Standard mode with scope — review specific documents:

```
/kk:design-review [feature-name] design
/kk:design-review [feature-name] implementation
/kk:design-review [feature-name] tasks
/kk:design-review [feature-name] all
```

| Scope | Documents reviewed |
|-------|-------------------|
| _(none)_ | `design.md` + `implementation.md` (default) |
| `design` | `design.md` only |
| `implementation` | `implementation.md` only |
| `tasks` | `tasks.md` only |
| `all` | `design.md` + `implementation.md` + `tasks.md` |

Isolated mode with independent sub-agents:

```
/kk:design-review:isolated [feature-name]
/kk:design-review:isolated [feature-name] tasks
```
