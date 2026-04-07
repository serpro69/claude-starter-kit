# Design v2: Isolated Review Agents

> Status: done
> Created: 2026-04-02
> Updated: 2026-04-03 (v2 — incorporates review feedback from design-review-v1 and design-review-v2)
> Previous version: [design.md](./design.md)

## Problem

Within the `implementation-process` workflow, a single session handles implement → test → review → fix. The agent that wrote the code is the only one present to review it. Starting a separate session for review means pausing, spawning a new session, reviewing there, passing findings back, and resuming — terrible UX.

Sub-agents are the only mechanism that provides review isolation without breaking the session. Claude Code's Agent tool spawns sub-agents that inherently lack parent conversation history. The design's contribution is choosing to exploit this platform behavior for review quality and curating what context the sub-agent receives.

Supporting evidence: Huang et al. (ICLR 2024, "Large Language Models Cannot Self-Correct Reasoning Yet") demonstrates that LLMs cannot reliably self-correct without external grounding — corroborating why the implementing agent cannot objectively review its own work mid-session.

## Solution

Introduce **isolated variants** of the review skills that delegate detection to sub-agents. Existing skills remain unchanged — isolated variants are opt-in alternatives. The approach was inspired by the `cove-isolated` pattern but adapted significantly: CoVe does per-question factual verification while this does per-domain quality evaluation.

## Core Principle: Isolated Detection

The sub-agent achieves isolation through **structural separation**, not prompt instructions:

- It is a fresh agent that did not write the code — no ownership, no sunk cost, no narrative momentum
- It receives full context about **what** was decided and **why** (spec, task description, design decisions, rationale, curated rejected approaches)
- It does **not** receive the implementation session context (conversation history, debugging, false starts, retries)

The Agent tool platform provides the isolation mechanism (sub-agents inherently lack parent conversation history). The design's contribution is the curation: deciding which artifacts to pass and which to withhold.

The isolation boundary is **authorship and session context**, not knowledge. The sub-agent reviews with full understanding but zero attachment.

## Isolation Boundary

| Given to sub-agent                        | Excluded from sub-agent                   |
| ----------------------------------------- | ----------------------------------------- |
| Git diff / source files                   | Conversation history                      |
| Spec (design.md, implementation.md)       | Implementation session debugging          |
| Task description from tasks.md            | False starts and retries                  |
| Documented design decisions and rationale | Full debugging narrative                  |
| Curated rejected approaches summary       | "I tried X but it didn't work" narratives |
| Language-specific checklists              | Session-specific reasoning context        |
| Capy read access (search only)            | Capy write access (no indexing)           |

**Curated rejected approaches:** Before spawning sub-agents, the main agent prepares a brief summary of approaches that were tried and failed (e.g., "approach X was tried and caused regression Y"). This prevents reviewers from suggesting the exact same broken approach. This is a deliberate, curated summary — not the full debugging narrative.

## Architecture

### New Components

1. **`klaude-plugin/agents/code-reviewer.md`** — Agent definition for independent code review
2. **`klaude-plugin/agents/spec-reviewer.md`** — Agent definition for independent spec conformance review
3. **`klaude-plugin/skills/solid-code-review/review-isolated.md`** — Isolated code review workflow
4. **`klaude-plugin/skills/implementation-review/review-isolated.md`** — Isolated spec conformance workflow

### Modified Components

5. **`klaude-plugin/skills/solid-code-review/SKILL.md`** — Updated to route between standard and isolated variants
6. **`klaude-plugin/skills/implementation-review/SKILL.md`** — Updated to route between standard and isolated variants
7. **`klaude-plugin/skills/implementation-process/SKILL.md`** — Session-level isolated review flag

### Removed Components (from v1)

8. **`klaude-plugin/skills/_shared/review-reconciliation-protocol.md`** — Dissolved. Annotation logic inlined into each workflow.

## Skill Invocation Pattern

| Invocation                           | Behavior                                           |
| ------------------------------------ | -------------------------------------------------- |
| `/kk:solid-code-review`              | Existing behavior, unchanged                       |
| `/kk:solid-code-review:isolated`     | Spawns sub-agents, annotates, presents report      |
| `/kk:implementation-review`          | Existing behavior, unchanged                       |
| `/kk:implementation-review:isolated` | Spawns sub-agent, annotates, presents report       |

## Detailed Flows

### Isolated Code Review (`solid-code-review:isolated`)

**Three-phase pipeline:**

#### Phase 1 — Isolated Detection (parallel)

Two independent reviewers spawn simultaneously:

- **Sub-agent A** (`code-reviewer` agent): Receives git diff, spec context (design.md section, task description, documented rationale), curated rejected approaches summary, language-specific checklists. Has capy read access. Produces findings in P0-P3 format with confidence scores.
- **Sub-agent B** (runs `pal codereview` with the top available pal model): External model, naturally isolated. Receives git diff. Produces findings in its native format (not force-mapped to P0-P3).

Both run in parallel.

#### Phase 2 — Annotation

The main agent receives both finding sets and performs annotation — providing context, not judgment:

1. **Duplicate merging**: When both reviewers flag the same logical issue (matched by file location + issue description), merge into one entry. Tag as **"corroborated"** — independent confirmation. Severity stays as assessed; if reviewers disagree on severity, show both assessments.
2. **Author context annotations**: For any finding where the main agent's session context is relevant, add a clearly-labeled annotation explaining the implementation decision. This is context ("I chose X because Y"), not a disposition ("this finding is invalid").
3. **Author-sourced findings**: If the close re-reading triggers new observations, the main agent MAY add them, clearly tagged as **"author-sourced"**. Distinct from sub-agent findings.
4. **pal follow-up** (optional): If a pal finding is ambiguous, the main agent MAY use pal's follow-up interaction to clarify before presenting to the user.

#### Phase 3 — Presentation

Single report to user, organized by agreement level:

1. **Corroborated findings** (both reviewers flagged) — highest signal
2. **Single-reviewer findings** (code-reviewer only or pal only) — evaluate individually
3. **Author-sourced findings** (main agent added during annotation) — clearly separated

Each finding shows: reviewer attribution, severity, the finding itself, and any author context annotation. The pal section uses pal's native format; the code-reviewer section uses P0-P3.

Then follow the same next-steps flow as existing skill: ask user how to proceed (fix all, fix P0/P1, fix specific, no changes).

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

#### Phase 2 — Annotation

The main agent annotates findings using type-specific annotation guidance:

| Finding Type | Author Context Relevance | Annotation Guidance |
| ------------ | ------------------------ | ------------------- |
| MISSING_IMPL | Low — objective gap | Brief. Point to implementing code if it exists, otherwise acknowledge the gap. |
| DOC_INCON    | Low — contradiction is objective | Brief. Confirm or deny the inconsistency. |
| OUTDATED_DOC | Low — staleness is objective | Brief. Note what changed and when. |
| AMBIGUOUS    | Low — if isolated reviewer found it ambiguous, that's a real signal | Brief. Clarify the intent if known. |
| SPEC_DEV     | High — may be intentional | Explain the decision. Suggest spec update if deviation was deliberate. |
| EXTRA_IMPL   | High — may be a legitimate discovery | Explain why it was added. Suggest spec update if intentional. |

Author-sourced findings allowed here too, tagged distinctly.

Findings organized by type rather than agreement level (single reviewer, so "corroborated" doesn't apply). Each finding shows: type, severity, the finding, and author context annotation where relevant.

## Error Handling

### Code Review (`solid-code-review:isolated`)

| Failure | Behavior |
| ------- | -------- |
| `code-reviewer` sub-agent times out or fails | Present pal findings only. Note the failure. Suggest `/kk:solid-code-review` (standard) as supplement. |
| `pal` unavailable (listmodels returns nothing, or codereview fails) | Present code-reviewer findings only. Note that external model review was unavailable. |
| Both reviewers fail | Abort isolated mode. Suggest fallback to `/kk:solid-code-review` (standard mode). |
| Sub-agent produces malformed output | Attempt best-effort parsing. If completely unparseable, treat as failure (apply rules above). |

### Spec Review (`implementation-review:isolated`)

| Failure | Behavior |
| ------- | -------- |
| `spec-reviewer` sub-agent times out or fails | Abort isolated mode. Suggest fallback to `/kk:implementation-review` (standard mode). |
| Sub-agent produces malformed output | Best-effort parse, then failure fallback. |

### Large Diffs

The sub-agent handles batching internally. If the diff exceeds the sub-agent's context window, the spawning workflow should note the limitation and suggest the user scope the review to specific files or tasks.

## Invariants

1. **No silent drops** — every sub-agent finding must appear in the report with reviewer attribution
2. **Author-sourced findings must be tagged** — if the main agent adds findings during annotation, they are clearly labeled as "author-sourced", distinct from sub-agent findings
3. **Agreement = confidence, not severity** — corroborated findings get a "corroborated" tag, not a severity bump. If reviewers disagree on severity, show both assessments. This rule's validity depends on reviewer independence, which is achieved here via different model providers (Claude sub-agent + external pal model). If the architecture ever changes to same-provider agents, revisit this.

## Report Format

### Code Review Report

```markdown
## Review Summary (Isolated Mode)

**Reviewers**: code-reviewer (Claude sub-agent), pal codereview ([model name])
**Files reviewed**: X files, Y lines changed

---

### Corroborated Findings
(Both reviewers flagged — highest signal)

- **[file:line]** Brief title ⟨corroborated⟩
  - code-reviewer: [severity] — [description]
  - pal: [description in native format]
  - Author context: [optional annotation]

### Code Reviewer Findings
(code-reviewer sub-agent only — P0-P3 format)

- **[file:line]** Brief title
  - Severity: P[0-3] | Confidence: [X]%
  - [description and suggested fix]
  - Author context: [optional annotation]

### External Review Findings
(pal codereview — native format)

- [pal output presented in its native format]
  - Author context: [optional annotation]

### Author-Sourced Findings
(Main agent observations during annotation — weight accordingly)

- **[file:line]** Brief title ⟨author-sourced⟩
  - [description]
```

### Spec Review Report

```markdown
## Spec Conformance Review (Isolated Mode)

**Reviewer**: spec-reviewer (Claude sub-agent)
**Scope**: [tasks reviewed]

---

### Findings by Type

#### MISSING_IMPL
- **[description]** — P[0-3]
  - Evidence: [spec reference vs implementation state]
  - Author context: [optional brief annotation]

#### SPEC_DEV
- **[description]** — P[0-3]
  - Evidence: [spec says X, implementation does Y]
  - Author context: [explain decision, suggest spec update if intentional]

... (other types as applicable)

### Author-Sourced Findings

- **[description]** ⟨author-sourced⟩
  - [description]
```

## Agent Definitions

### code-reviewer agent

- **Location**: `klaude-plugin/agents/code-reviewer.md`
- **Role**: Independent code reviewer with no authorship attachment
- **Receives**: Git diff, spec context, curated rejected approaches, language-specific checklists, capy read access
- **Excluded**: Conversation history, session context
- **Output**: Structured findings in P0-P3 format with confidence and evidence
- **Capy restriction**: `capy_search` only — no `capy_index`, no `capy_fetch_and_index`
- **Status**: Unchanged from v1 — no modifications needed

### spec-reviewer agent

- **Location**: `klaude-plugin/agents/spec-reviewer.md`
- **Role**: Independent spec conformance reviewer with no authorship attachment
- **Receives**: Design docs, tasks.md, source file access, capy read access
- **Excluded**: Conversation history, session context
- **Output**: Structured findings using finding type taxonomy (MISSING_IMPL, etc.) with severity and confidence
- **Capy restriction**: `capy_search` only — no `capy_index`, no `capy_fetch_and_index`
- **Status**: Unchanged from v1 — no modifications needed

## Integration with implementation-process

`implementation-process` gains a **session-level isolated review flag**:

- Chosen once at the start of the implementation session (or specified in `tasks.md` metadata)
- When set, all review checkpoints within that session use isolated mode automatically
- The user can override per-checkpoint if needed ("use standard review for this one")
- The `pal` codereview call moves inside the isolated code review flow (Phase 1, Sub-agent B) rather than being a separate step

The standard flow remains the default. No behavioral change unless the user opts in.

## Validation Plan

After shipping, run both modes (standard and isolated) on 5-10 real task reviews. Compare:

- **Unique findings per mode** — does isolated review surface issues that standard review misses?
- **False positive rate** — what fraction of findings does the user reject? Is it lower for isolated mode?
- **User acceptance rate** — what fraction of findings does the user act on?
- **Corroboration rate** — how often do both reviewers flag the same issue? (Measures reviewer independence)

Not a formal experiment. Evaluate after ~10 uses and decide whether the feature is earning its keep.

## Design Decisions

1. **Opt-in, not default**: Isolated review costs more (sub-agent spawning, parallel execution, annotation). Users choose when the extra rigor is worth it.
2. **Two reviewers for code, one for spec**: Code quality is subjective and benefits from multiple independent perspectives. Spec conformance is more binary — a single independent reviewer is sufficient.
3. **Rationale is context, not contamination**: Sub-agents receive full design rationale. The bias comes from authorship (living through the implementation), not from knowing why decisions were made.
4. **User reconciles, agent annotates**: The main agent provides implementation context as annotations but does not assign dispositions or judge findings. The user is the final arbiter. This avoids presentation bias where plausible-sounding "Disputed" justifications lead users to dismiss valid issues.
5. **No silent drops**: Every finding reaches the user with reviewer attribution.
6. **Native formats preserved**: pal codereview output stays in its own format rather than being force-mapped to P0-P3. Duplicate detection works across formats by comparing file locations and issue descriptions.
7. **Session-level isolation flag**: Chosen once at `implementation-process` start, applies to all review checkpoints. Avoids repetitive per-checkpoint decisions.
8. **Curated rejected approaches**: Sub-agents receive a brief summary of approaches that were tried and failed, preventing them from suggesting known-broken approaches. This is curated context, not the full debugging narrative.
