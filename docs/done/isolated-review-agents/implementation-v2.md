# Implementation Plan v2: Isolated Review Agents

> Design: [./design-v2.md](./design-v2.md)
> Previous version: [./implementation.md](./implementation.md)
> Created: 2026-04-03
>
> **Context:** v1 implementation (Tasks 1-7) is complete. This plan covers the delta work required by the v2 design changes — primarily the shift from disposition-based reconciliation to annotation-based presentation, error handling, and structural simplifications.

## Overview

The v2 changes are architectural in the reconciliation/presentation layer, not in the detection layer. Agent definitions (code-reviewer, spec-reviewer) are unaffected. The main work is:

1. Delete the shared reconciliation protocol (dissolved per v2 design)
2. Rework both isolated workflows (annotation model, error handling, native pal format)
3. Minor SKILL.md updates to reflect the new model
4. Add session-level isolated review flag to implementation-process

The developer implementing this should read the v1 implementation plan for context on the original structure, then apply the changes described here. All existing skills in `klaude-plugin/` serve as reference implementations.

## Task 1: Delete Shared Reconciliation Protocol

**File to delete**: `klaude-plugin/skills/_shared/review-reconciliation-protocol.md`

The shared protocol is dissolved — its logic is inlined into each workflow (Tasks 3 and 4). Delete the file entirely.

### Notes for implementer

- Verify no other files reference this path before deleting. Search for `review-reconciliation-protocol` across the repo.
- The `review-isolated.md` files from v1 reference this protocol — they'll be rewritten in Tasks 3 and 4, so broken references are expected temporarily.

## Task 2: Rework Isolated Code Review Workflow

**File**: `klaude-plugin/skills/solid-code-review/review-isolated.md` (rewrite in place)

This is the most substantial change. The workflow keeps its four-step structure but Phase 2-3 change fundamentally.

### Workflow structure

```
Isolated Code Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
```

#### Step 1: Prepare artifacts (updated)

Same as v1, plus:

- **Curated rejected approaches**: Before spawning sub-agents, prepare a brief summary of approaches that were tried and failed during implementation. Keep it to concrete facts ("approach X caused regression Y"), not the full debugging narrative. If no approaches were rejected, skip this.
- `pal` `listmodels` call to resolve most capable model — unchanged from v1.

#### Step 2: Spawn reviewers (parallel) (updated)

Two reviewers, same as v1, with two changes:

**Sub-agent A** (`code-reviewer` agent):
- Same as v1, plus: include the curated rejected approaches summary in the prompt

**Sub-agent B** (`pal codereview`):
- Same as v1. **Important change for Step 3**: the pal output is NOT mapped to P0-P3 — it stays in native format.

**Error handling** (new):
- If `pal listmodels` returns no models or `pal codereview` fails: note the failure, proceed to Step 3 with code-reviewer findings only.
- If the `code-reviewer` sub-agent times out or fails: note the failure, proceed to Step 3 with pal findings only. Suggest `/kk:solid-code-review` (standard) as supplement.
- If both fail: abort isolated mode. Display message suggesting fallback to `/kk:solid-code-review` (standard mode). Do not proceed to Step 3.
- If sub-agent output is malformed: attempt best-effort parsing. If completely unparseable, treat as a failure (apply rules above).

#### Step 3: Annotate findings (replaces "Reconcile")

This replaces the v1 disposition-based reconciliation. The main agent performs annotation, not judgment:

**3a. Duplicate merging:**
- Compare findings from both reviewers by file location and issue description.
- When both flag the same logical issue: merge into one entry, tag as **"corroborated"**.
- Severity stays as each reviewer assessed it. If they disagree on severity, show both assessments.

**3b. Author context annotations:**
- For each finding, consider whether the implementation session context adds relevant information.
- If yes: add a clearly-labeled "Author context" annotation explaining the decision ("I chose bcrypt cost 10 because benchmarks showed cost 12 added 400ms").
- If no: leave the finding as-is — not every finding needs an annotation.
- Annotations are context, not judgments. "I chose X because Y" is correct. "This finding is invalid" is not.

**3c. Author-sourced findings:**
- If the close re-reading during annotation triggers new observations, add them.
- Tag as **"author-sourced"** — clearly distinct from sub-agent findings.
- The user knows these come from the author and can weight accordingly.

**3d. pal follow-up (optional):**
- If a pal finding is ambiguous or unclear, the main agent MAY use pal's follow-up interaction capability to clarify before presenting to the user.

#### Step 4: Present report (simplified)

Present the report organized by agreement level:

1. **Corroborated findings** (both reviewers flagged) — highest signal
2. **Code reviewer findings** (code-reviewer sub-agent only) — P0-P3 format
3. **External review findings** (pal only) — native format
4. **Author-sourced findings** (main agent observations) — clearly separated

Use the report template from design-v2.md § Report Format.

Then follow the same next-steps flow as existing skill: ask user how to proceed (fix all, fix P0/P1, fix specific, no changes).

### Notes for implementer

- The v1 version of this file exists and has the right structure — rewrite it in place rather than starting from scratch
- The sub-agent prompt for code-reviewer needs a new section for rejected approaches — add it after the spec context
- The pal output was previously parsed and mapped to P0-P3 — remove that mapping logic entirely
- Error handling should be placed inline within Step 2 (where failures occur) rather than as a separate section

## Task 3: Rework Isolated Spec Conformance Workflow

**File**: `klaude-plugin/skills/implementation-review/review-isolated.md` (rewrite in place)

Similar structural change — annotation replaces disposition, error handling added.

### Workflow structure

```
Isolated Implementation Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn spec reviewer
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
```

#### Step 1: Prepare artifacts — unchanged from v1

Locate feature directory, verify docs exist, determine review scope.

#### Step 2: Spawn spec reviewer (updated)

Spawn a single `spec-reviewer` sub-agent — same as v1.

**Error handling** (new):
- If the sub-agent times out or fails: abort isolated mode. Suggest fallback to `/kk:implementation-review` (standard mode).
- If output is malformed: best-effort parse. If unparseable, treat as failure.

#### Step 3: Annotate findings (replaces "Reconcile")

This replaces the v1 disposition-based reconciliation with type-specific trust levels. The main agent annotates using **type-specific annotation guidance**:

**Low author-context-relevance types** (MISSING_IMPL, DOC_INCON, OUTDATED_DOC, AMBIGUOUS):
- These are objective or spec-clarity issues. The main agent's session context is less relevant.
- Keep annotations brief: point to implementing code if it exists, confirm/deny inconsistencies, clarify intent if known.

**High author-context-relevance types** (SPEC_DEV, EXTRA_IMPL):
- These may be intentional deviations. The main agent's session context IS relevant.
- Annotations should explain the decision and suggest a spec update if the deviation was deliberate.

**Author-sourced findings:** Allowed, tagged as "author-sourced" — same as code review.

#### Step 4: Present report (simplified)

Findings organized by type (not by agreement level — single reviewer, so "corroborated" doesn't apply):

- Group findings under their type headings (MISSING_IMPL, SPEC_DEV, DOC_INCON, etc.)
- Each finding shows: type, severity, the finding, evidence, and author context annotation where relevant
- Author-sourced findings in a separate section at the end

Use the spec review report template from design-v2.md § Report Format.

If within `implementation-process`, feed findings back into the task workflow. If standalone, present to user directly.

### Notes for implementer

- The v1 version exists — rewrite in place
- The trust level table from v1 is gone. Replace with the annotation guidance described above — it tells the annotator when context is useful, not how much to trust the finding
- No disposition categories to assign — if you find yourself writing "Confirmed" or "Disputed", you're using the old model

## Task 4: Update SKILL.md Descriptions

Two files need minor updates to reflect the annotation model.

### `klaude-plugin/skills/solid-code-review/SKILL.md`

Update the isolated mode section to reflect:
- Annotation model (not disposition-based reconciliation)
- Native pal format (not P0-P3 mapping)
- Error handling / graceful degradation
- Wording should mention "annotates with context" rather than "reconciles findings"

### `klaude-plugin/skills/implementation-review/SKILL.md`

Same pattern:
- Annotation model with type-specific guidance
- Error handling
- Updated wording

### Notes for implementer

- These are description-only changes — the routing to `review-isolated.md` is already correct from v1
- Keep the changes minimal — just reflect the new model in the descriptive text

## Task 5: Add Session-Level Isolated Review Flag to implementation-process

**File**: `klaude-plugin/skills/implementation-process/SKILL.md`

### Changes

The current implementation (from v1 Task 7) mentions isolated review as an option at each Step 3 checkpoint. Replace this with a session-level flag:

1. **At session start** (Step 0 / preamble): Add a note that the user can request isolated review mode for the entire session. This can be specified:
   - When invoking the skill ("use isolated review")
   - In `tasks.md` metadata (a `review-mode: isolated` field in the header)
2. **At each Step 3 checkpoint**: If the session-level flag is set, automatically use `kk:solid-code-review:isolated` and/or `kk:implementation-review:isolated`. No per-checkpoint prompt needed.
3. **Per-checkpoint override**: The user can still say "use standard review for this one" to override at any checkpoint.
4. **Default**: Standard mode. No behavioral change unless the user opts in.

### Notes for implementer

- This is a small change to the existing Step 3 wording plus a new note in the preamble
- The v1 change already routes correctly — this just moves the decision point from per-checkpoint to per-session
- The `pal` codereview call is already inside the isolated workflow — no duplication concern

## Task 6: Final Verification

Verify all components work together:

- Shared reconciliation protocol file is deleted and no dangling references remain
- Both isolated workflows reflect the annotation model (no disposition categories anywhere)
- Error handling is present in both workflows
- SKILL.md descriptions match the new model
- Session-level flag works in implementation-process
- Agent definitions are unchanged and still valid
- Existing (non-isolated) skill behavior is completely unchanged
