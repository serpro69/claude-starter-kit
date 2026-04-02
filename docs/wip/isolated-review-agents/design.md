# Design: Isolated Review Agents

> Status: draft
> Created: 2026-04-02

## Problem

All review skills (`solid-code-review`, `implementation-review`) run in the main conversation context. The agent that wrote the code also reviews it. This introduces confirmation bias — not from knowledge of the rationale (which is valuable context), but from **authorship**: ownership, sunk cost, and narrative momentum from living through the implementation session.

Research backing: Huang et al. (ICLR 2024, "Large Language Models Cannot Self-Correct Reasoning Yet") demonstrates that LLMs cannot reliably self-correct without external grounding.

## Solution

Introduce **isolated variants** of the review skills that delegate detection to sub-agents, following the pattern established by `cove-isolated`. Existing skills remain unchanged — isolated variants are opt-in alternatives.

## Core Principle: Isolated Detection

The sub-agent achieves isolation through **structural separation**, not prompt instructions:

- It is a fresh agent that did not write the code — no ownership, no sunk cost, no narrative momentum
- It receives full context about **what** was decided and **why** (spec, task description, design decisions, rationale)
- It does **not** receive the implementation session context (conversation history, debugging, false starts, retries, alternatives considered and rejected)

The isolation boundary is **authorship and session context**, not knowledge. The sub-agent reviews with full understanding but zero attachment.

## Isolation Boundary

| Given to sub-agent | Excluded from sub-agent |
|---|---|
| Git diff / source files | Conversation history |
| Spec (design.md, implementation.md) | Implementation session debugging |
| Task description from tasks.md | False starts and retries |
| Documented design decisions and rationale | Alternatives considered but not taken |
| Language-specific checklists | "I tried X but it didn't work" narratives |
| Capy read access (search only) | Capy write access (no indexing) |

## Architecture

### New Components

1. **`klaude-plugin/agents/code-reviewer.md`** — Agent definition for independent code review
2. **`klaude-plugin/agents/spec-reviewer.md`** — Agent definition for independent spec conformance review
3. **`klaude-plugin/skills/_shared/review-reconciliation-protocol.md`** — Shared reconciliation rules and report format
4. **`klaude-plugin/skills/solid-code-review/review-isolated.md`** — Isolated code review workflow
5. **`klaude-plugin/skills/implementation-review/review-isolated.md`** — Isolated spec conformance workflow

### Modified Components

6. **`klaude-plugin/skills/solid-code-review/SKILL.md`** — Updated to route between standard and isolated variants
7. **`klaude-plugin/skills/implementation-review/SKILL.md`** — Updated to route between standard and isolated variants
8. **`klaude-plugin/skills/implementation-process/SKILL.md`** — Updated Step 3 to support isolated review mode

## Skill Invocation Pattern

Follows the `cove` / `cove:cove-isolated` convention:

| Invocation | Behavior |
|---|---|
| `/kk:solid-code-review` | Existing behavior, unchanged |
| `/kk:solid-code-review:isolated` | Spawns sub-agents, reconciles, consolidated report |
| `/kk:implementation-review` | Existing behavior, unchanged |
| `/kk:implementation-review:isolated` | Spawns sub-agent, reconciles, consolidated report |

## Detailed Flows

### Isolated Code Review (`solid-code-review:isolated`)

**Three-phase pipeline:**

#### Phase 1 — Isolated Detection (parallel)

Two independent reviewers spawn simultaneously:

- **Sub-agent A** (`code-reviewer` agent): Receives git diff, spec context (design.md section, task description, documented rationale), language-specific checklists. Has capy read access. Produces findings in P0-P3 format with confidence scores.
- **Sub-agent B** (`pal` codereview with gemini): External model, naturally isolated. Receives git diff. Produces findings in its own format.

Both run in parallel.

#### Phase 2 — Main Agent Reconciliation

The main agent receives both finding sets and reconciles using the shared reconciliation protocol:

- Cross-references findings (agreement strengthens confidence, disagreement flags for closer look)
- Verifies each finding against session context — this is where the main agent's context is an advantage: it can filter false positives from reviewers lacking session-specific knowledge
- Assigns disposition to every finding: **Confirmed**, **Disputed — Intentional** (with reason), **Disputed — False Positive** (with evidence), or **Duplicate**

Rule: the main agent **cannot silently drop findings**. Every finding appears in the report.

#### Phase 3 — Consolidated Report

Single report to user in existing `solid-code-review` format, extended with:
- Reviewer attribution (which reviewer(s) flagged each issue)
- Main agent disposition and reasoning
- Agreement indicator (both reviewers, single reviewer, or main-agent-only finding)

### Isolated Spec Conformance Review (`implementation-review:isolated`)

**Two-phase pipeline:**

#### Phase 1 — Isolated Spec Conformance Check

A single `spec-reviewer` sub-agent spawns with:
- Design docs (design.md, implementation.md)
- tasks.md (to determine scope — which tasks are done)
- Read/Grep access to source files
- Capy read access
- Finding type taxonomy (MISSING_IMPL, EXTRA_IMPL, SPEC_DEV, DOC_INCON, OUTDATED_DOC, AMBIGUOUS) and severity levels from existing skill

Follows the existing review-process steps (load docs, determine scope, per-task verification, cross-cutting concerns, self-check). Produces structured findings.

#### Phase 2 — Main Agent Reconciliation

Reconciliation with type-specific trust levels:

| Finding Type | Main Agent Trust Level | Reasoning |
|---|---|---|
| MISSING_IMPL | High trust in sub-agent | "I forgot" is a real possibility for the implementer |
| AMBIGUOUS | High trust in sub-agent | If the isolated reviewer found it ambiguous, that's a real signal |
| SPEC_DEV | Medium trust | May be an intentional decision — main agent must state why |
| EXTRA_IMPL | Medium trust | May be a legitimate discovery — main agent must state why |
| DOC_INCON | High trust in sub-agent | Contradictions are objective |
| OUTDATED_DOC | High trust in sub-agent | Staleness is objective |

For disputed SPEC_DEV and EXTRA_IMPL findings, the main agent suggests updating the spec to reflect the intentional deviation.

Produces consolidated report with finding, reviewer attribution, disposition, and recommendation.

## Shared Review Reconciliation Protocol

Defined in `_shared/review-reconciliation-protocol.md`, referenced by both isolated workflows.

### Disposition Categories

| Disposition | Meaning | Requirement |
|---|---|---|
| **Confirmed** | Finding is valid regardless of session context | None — finding stands |
| **Disputed — Intentional** | Deviation was a deliberate decision during implementation | Must state the specific reason |
| **Disputed — False Positive** | Finding is incorrect given broader context | Must cite specific evidence |
| **Duplicate** | Same issue flagged by multiple reviewers | Merge findings, note agreement |

### Invariants

1. Every sub-agent finding must appear in the consolidated report with a disposition
2. The main agent cannot add new findings that weren't flagged by any reviewer (it already had its chance during implementation)
3. "Disputed" findings still appear in the report — the user makes the final call
4. Agreement between independent reviewers increases effective severity by one level (e.g., P2 flagged by both becomes recommended-P1)

### Consolidated Report Format

```markdown
## Review Summary (Isolated Mode)

**Reviewers**: [list of reviewers with types]
**Files reviewed**: X files, Y lines changed
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical

- **[file:line]** Brief title
  - Flagged by: [reviewer A, reviewer B]
  - Disposition: Confirmed
  - Description and suggested fix

### P1 - High

- **[file:line]** Brief title
  - Flagged by: [reviewer A]
  - Disposition: Disputed — Intentional (reason: ...)
  - Description and suggested fix

...

---

## Reconciliation Summary

| # | Finding | Reviewers | Disposition | Action |
|---|---------|-----------|-------------|--------|
| 1 | [title] | A, B | Confirmed | Fix |
| 2 | [title] | A | Disputed — Intentional | User decides |
| 3 | [title] | A, B | Duplicate (merged) | Fix |

## Reviewer Disagreements

(If reviewers contradicted each other on the same code, surface both perspectives)
```

## Agent Definitions

### code-reviewer agent

- **Location**: `klaude-plugin/agents/code-reviewer.md`
- **Role**: Independent code reviewer with no authorship attachment
- **Receives**: Git diff, spec context, language-specific checklists, capy read access
- **Excluded**: Conversation history, session context
- **Output**: Structured findings in P0-P3 format with confidence and evidence
- **Capy restriction**: `capy_search` only — no `capy_index`, no `capy_fetch_and_index`

### spec-reviewer agent

- **Location**: `klaude-plugin/agents/spec-reviewer.md`
- **Role**: Independent spec conformance reviewer with no authorship attachment
- **Receives**: Design docs, tasks.md, source file access, capy read access
- **Excluded**: Conversation history, session context
- **Output**: Structured findings using finding type taxonomy (MISSING_IMPL, etc.) with severity and confidence
- **Capy restriction**: `capy_search` only — no `capy_index`, no `capy_fetch_and_index`

## Integration with implementation-process

`implementation-process` Step 3 (Report) gains an optional isolated review mode:

- If the user invokes isolated review (via flag or explicit request), Step 3 uses `solid-code-review:isolated` and/or `implementation-review:isolated` instead of their standard variants
- The `pal` codereview call moves inside the isolated code review flow (Phase 1, Sub-agent B) rather than being a separate step
- The main agent's reconciliation phase replaces the current "consolidate findings" step

The standard flow remains the default. No behavioral change unless the user opts in.

## Design Decisions

1. **Opt-in, not default**: Isolated review costs more (sub-agent spawning, parallel execution, reconciliation). Users choose when the extra rigor is worth it.
2. **Two reviewers for code, one for spec**: Code quality is subjective and benefits from multiple independent perspectives. Spec conformance is more binary — a single independent reviewer is sufficient.
3. **Rationale is context, not contamination**: Sub-agents receive full design rationale. The bias comes from authorship (living through the implementation), not from knowing why decisions were made.
4. **Main agent reconciles, doesn't review**: The main agent's role shifts from reviewer to reconciler. It uses its session context to filter false positives, not to find new issues.
5. **No silent drops**: Every finding reaches the user. The main agent can dispute but not suppress.
