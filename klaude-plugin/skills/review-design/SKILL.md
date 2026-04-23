---
name: review-design
description: |
  Review design and implementation docs produced by design. Evaluates document quality, internal consistency, and technical soundness.
  Use after design completes and before starting implement.
---

# Design Review

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Overview

Pre-implementation review gate that evaluates design documents produced by `design` before code is written. Sits between `design` (creates docs) and `implement` (executes them). Reviews two dimensions: document quality/structure (completeness, internal consistency, clarity, convention adherence) and technical soundness (architectural viability, edge cases, failure modes, trade-off analysis).

## Review Modes

### Standard Mode (`/kk:review-design`)

Reviews design documents in the main conversation context. Fast, single-pass review using the workflow below.

### Isolated Mode (`/kk:review-design:isolated`)

Delegates detection to independent reviewers that did not participate in the design, then annotates their findings with author context. Two parallel reviewers: a `design-reviewer` sub-agent and `pal codereview` (external model in native format). Produces a report organized by agreement level with corroborated findings highlighted.

- **Cost**: Higher (sub-agent + external model + annotation)
- **Isolation**: True — reviewers have zero authorship bias or session context
- **Degradation**: Graceful — if one reviewer fails, proceeds with the other; if both fail, suggests standard mode fallback
- **Best for**: When extra rigor is worth the cost (before starting implementation of high-stakes features)

See [review-isolated.md](./review-isolated.md) for the isolated workflow.

## Finding Types

| Type                   | Code           | Description                                                                              |
| ---------------------- | -------------- | ---------------------------------------------------------------------------------------- |
| Incomplete Spec        | `INCOMPLETE`   | Section lacks sufficient detail for implementation                                       |
| Internal Inconsistency | `INCONSISTENT` | Two parts of the docs contradict each other                                              |
| Technical Risk         | `TECH_RISK`    | Architecture choice has unaddressed failure modes, scalability concerns, or edge cases   |
| Missing Concern        | `MISSING`      | Cross-cutting concern is absent (error handling, migration, backwards compatibility)     |
| Ambiguity              | `AMBIGUOUS`    | Requirements can be interpreted multiple ways, likely to cause implementation divergence |
| Structure Issue        | `STRUCTURE`    | Document doesn't follow project conventions — missing sections, vague subtasks           |

## Severity Levels

| Level  | Name     | Description                                                                              | Action                           |
| ------ | -------- | ---------------------------------------------------------------------------------------- | -------------------------------- |
| **P0** | Critical | Fundamental flaw — design will not work as described, or critical requirement is missing | Must fix before implementation   |
| **P1** | High     | Significant gap — likely to cause rework or wrong implementation                         | Should fix before implementation |
| **P2** | Medium   | Moderate concern — ambiguity or missing detail that could cause confusion                | Fix or create follow-up          |
| **P3** | Low      | Minor — style, structure, or nitpick                                                     | Optional                         |

## Workflow

**Mandatory order — methodology before evaluation.** The flow below is strictly sequential. Do not evaluate document quality, assess technical soundness, or form findings until this SKILL.md and the process file are fully loaded. The design documents are both instruction context (they define what the feature is) and subject matter (they are what you evaluate) — but the review methodology and rubric must be loaded first. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

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
/kk:review-design [feature-name]
```

Standard mode with scope — review specific documents:

```
/kk:review-design [feature-name] design
/kk:review-design [feature-name] implementation
/kk:review-design [feature-name] tasks
/kk:review-design [feature-name] all
```

| Scope            | Documents reviewed                             |
| ---------------- | ---------------------------------------------- |
| _(none)_         | `design.md` + `implementation.md` (default)    |
| `design`         | `design.md` only                               |
| `implementation` | `implementation.md` only                       |
| `tasks`          | `tasks.md` only                                |
| `all`            | `design.md` + `implementation.md` + `tasks.md` |

Isolated mode with independent sub-agents:

```
/kk:review-design:isolated [feature-name]
/kk:review-design:isolated [feature-name] tasks
```
