# Design: design-review Skill

> Issue: [#52](https://github.com/serpro69/claude-toolbox/issues/52)
> Status: design-complete

## Overview

The `design-review` skill is a pre-implementation review gate that evaluates design documents produced by `analysis-process` before code is written. It sits between `analysis-process` (creates docs) and `implementation-process` (executes them).

The skill evaluates two dimensions:

1. **Document quality/structure** — completeness, internal consistency, clarity, adherence to project conventions, sufficient detail for a first-time contributor
2. **Technical soundness** — architectural viability, edge cases, failure modes, trade-off analysis, simpler alternatives not considered

## Document Scope

Default scope is `design.md` + `implementation.md` from `/docs/wip/[feature]/`. Scope is configurable via argument:

| Argument | Documents reviewed |
|----------|-------------------|
| _(none)_ | `design.md` + `implementation.md` (default) |
| `design` | `design.md` only |
| `implementation` | `implementation.md` only |
| `tasks` | `tasks.md` only |
| `all` | `design.md` + `implementation.md` + `tasks.md` |

If a requested doc is missing, inform the user and proceed with what's available (unlike `implementation-review` which stops — reviewing a single doc is a valid use case here).

## Invocation

| Mode | Command |
|------|---------|
| Standard | `/kk:design-review [feature-name]` |
| Standard scoped | `/kk:design-review [feature-name] design` |
| Isolated | `/kk:design-review:isolated [feature-name]` |
| Isolated scoped | `/kk:design-review:isolated [feature-name] tasks` |

## Finding Types

A taxonomy tailored to design document review, distinct from the code-oriented findings in `solid-code-review` and the spec-conformance types in `implementation-review`:

| Type | Code | Description |
|------|------|-------------|
| Incomplete Spec | `INCOMPLETE` | Section lacks sufficient detail for implementation — e.g., "handle errors appropriately" without specifying how |
| Internal Inconsistency | `INCONSISTENT` | Two parts of the docs contradict each other — e.g., design.md says REST, implementation.md describes gRPC endpoints |
| Technical Risk | `TECH_RISK` | Architecture choice has unaddressed failure modes, scalability concerns, or edge cases |
| Missing Concern | `MISSING` | Cross-cutting concern is absent — e.g., no error handling strategy, no migration plan, no backwards compatibility consideration |
| Ambiguity | `AMBIGUOUS` | Requirements can be interpreted multiple ways, likely to cause implementation divergence |
| Structure Issue | `STRUCTURE` | Document doesn't follow project conventions — missing sections, vague subtasks, no file/function names in tasks |

## Severity Levels

Same P0-P3 scale as other review skills, adapted for design review context:

| Level | Name | Meaning |
|-------|------|---------|
| **P0** | Critical | Fundamental flaw — design will not work as described, or critical requirement is missing |
| **P1** | High | Significant gap — likely to cause rework or wrong implementation |
| **P2** | Medium | Moderate concern — ambiguity or missing detail that could cause confusion |
| **P3** | Low | Minor — style, structure, or nitpick |

## Confidence Levels

Each finding gets a confidence score (1-10) with mandatory reasoning, same scale as `implementation-review`:

| Score | Meaning |
|-------|---------|
| 9-10 | Certain — direct, unambiguous flaw or gap |
| 7-8 | Strong — clear evidence but minor room for interpretation |
| 5-6 | Moderate — likely issue but docs have plausible alternative reading |
| 3-4 | Uncertain — possible issue, needs human judgment |
| 1-2 | Speculative — gut feeling, very ambiguous context |

## Review Modes

### Standard Mode

Single-pass review in the main conversation context. Fast, low-cost.

### Isolated Mode

Delegates detection to independent reviewers that did not participate in the analysis-process, then annotates their findings with author context. Two parallel reviewers:

1. **`design-reviewer` sub-agent** — Claude sub-agent applying the full finding taxonomy with structured output
2. **`pal codereview`** — external model providing an independent second opinion in native format

Produces a report organized by agreement level with corroborated findings highlighted.

- **Cost**: Higher (sub-agent + external model + annotation)
- **Isolation**: True — reviewers have zero authorship bias or session context
- **Degradation**: Graceful — if one reviewer fails, proceeds with the other; if both fail, suggests standard mode fallback
- **Best for**: When extra rigor is worth the cost (before starting implementation of high-stakes features)

## The `design-reviewer` Agent

A new dedicated sub-agent (separate from `code-reviewer` and `spec-reviewer`) purpose-built for evaluating design documents pre-implementation.

**Identity**: Independent design reviewer with no authorship attachment. Did not participate in the analysis-process that produced the documents.

**Tool access** (restricted via frontmatter allowlist): `Read`, `Grep`, `Glob`, `capy_search` — same set as other review agents. Uses Read for design docs, Grep/Glob to cross-reference against actual codebase when designs reference existing code, and `capy_search` for architecture decisions and prior findings.

**What it receives**: Document paths (reads them itself), review scope, finding taxonomy and severity definitions.

**What it does NOT have**: Conversation history, design rationale discussions from analysis-process Step 3, knowledge of alternatives considered and rejected.

**Review workflow**:
1. Read provided documents
2. Capy search for prior arch decisions and review findings
3. Document quality pass — completeness, clarity, structure, internal consistency, convention adherence
4. Technical soundness pass — architectural viability, edge cases, failure modes, trade-off analysis, simpler alternatives
5. Cross-document consistency (when multiple docs in scope)
6. Self-check and confidence assessment
7. Output structured findings

**Output contract**: Structured markdown with findings grouped by P0-P3, each with finding type code, section reference, confidence with reasoning, description, evidence, and recommendation. Overall assessment is one of: SOUND, CONCERNS_FOUND, or MAJOR_GAPS. Use `(none)` under empty severity sections. The agent omits a "next steps" section — the orchestrating workflow (standard mode or isolated mode annotation phase) handles user interaction.
