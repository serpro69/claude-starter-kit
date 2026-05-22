# Implementation Review: Design Skill Refinement

**Scope:** 9 of 9 tasks reviewed | Mode: post-implementation
**Documents reviewed:**

- Design: [docs/wip/design-skill-refinement/design.md](../design.md)
- Implementation: [docs/wip/design-skill-refinement/implementation.md](../implementation.md)
- Tasks: [docs/wip/design-skill-refinement/tasks.md](../tasks.md)

**Profile:** `skill-md` active (no `review-spec/` phase content)
**Date:** 2026-05-22
**Summary:** 1 finding: 0 critical, 0 high, 0 medium, 1 low

---

## Findings

### Missing Implementation (MISSING_IMPL)

(none)

### Spec Deviation (SPEC_DEV)

(none)

### Outdated Doc (OUTDATED_DOC)

- **[P3] tasks.md subtask 3.7 references removed CoVe fallback triggers**
  - **Code does:** `idea-process.md:71-73` implements CoVe as a user-initiated option: "Want me to run `/kk:chain-of-verification:isolated` to verify them, or should I proceed with the analysis as-is?" — no pre-check or fallback triggers.
  - **Doc says:** `tasks.md:48` subtask 3.7: "Write sub-phase 3d (converge): manual criteria-based analysis as default, CoVe scoped to verifiable claims only, concrete fallback triggers"
  - **Confidence:** 9/10 — implementation.md was updated (zero grep hits for "fallback trigger"), and the code matches the updated spec. Only the subtask description in tasks.md retained the pre-fix wording. The original design had agent-evaluated pre-check/post-check fallback triggers; review finding SQ-1 simplified this to a user-initiated gate.
  - **Recommendation:** Update subtask 3.7 text to: "Write sub-phase 3d (converge): criteria-based analysis as default, CoVe as user-initiated option for verifiable claims"

### Doc Inconsistency (DOC_INCON)

(none)

### Ambiguous Spec (AMBIGUOUS)

(none)

### Extra Implementation (EXTRA_IMPL)

(none)

---

## Clean Areas

### Task 1 (frameworks.md) — Verified
- File exists at `klaude-plugin/skills/design/frameworks.md` with MIT license/attribution header pinned to SHA `539a785`.
- All 7 frameworks present with "Best for" guidance. SE framing note at top. No consumer-product examples.
- design.md, implementation.md, and tasks.md all agree on the framework count (7).

### Task 2 (refinement-criteria.md) — Verified
- File exists at `klaude-plugin/skills/design/refinement-criteria.md` with same attribution header.
- Three evaluation dimensions (User Value, Feasibility, Differentiation), Assumption Audit, Decision Framework, MVP Scoping Principles. SE framing note present.

### Task 3 (Step 3 rewrite) — Verified
- All five sub-phases (3a-3e) present in `idea-process.md` in correct order.
- Profile detection block preserved at original position before sub-phases.
- `frameworks.md` and `refinement-criteria.md` referenced as "already loaded" (no duplicate load).
- Step 3 Progress checklist added (8 checkboxes tracking 3a-3e completion).
- 3a: HMW framing with quality guidance link. 3b: Hard gate with three explicit requirements. 3c: Proportional diverge with classification confirmation and two paths. 3d: Converge with user-initiated CoVe option. 3e: Assumptions and Not Doing outputs.

### Task 4 (Steps 5 and 6) — Verified
- Step 5: Assumptions and Not Doing section requirements added before DO NOT list.
- Step 6: All 7 additions present — Not Doing header, vertical slicing mandate with anti-pattern, Size tags with L-forbidden rule, slicing strategies, parallel markers, dependency graph, review scope recommendation.

### Task 5 (example-tasks.md) — Verified
- Not Doing in header. Size and Can run in parallel with on every task. Tasks resliced to vertical (User login e2e, Token refresh e2e, Protected routes e2e). Dependency graph at bottom.

### Task 6 (SKILL.md) — Verified
- Mandatory-order directive names `frameworks.md` and `refinement-criteria.md`.
- Step 2 lists both for fresh-idea flow.
- Conventions section describes their purpose.

### Task 7 (review-design all paths) — Verified
- `review-process.md` Step 3: Assumptions/Not Doing checks, task format conventions (Not Doing header, Size tags, vertical slicing, parallel markers, dependency graph). Finding types match design spec.
- `review-process.md` Step 4: Assumptions testability check, Not Doing validity check.
- `design-reviewer.md` §3 and §4: Same checks, textually identical to review-process.md.
- `review-design/SKILL.md`: Post-design gate note present in Invocation section.
- All three scope tables updated: default includes `tasks.md`, `all` keyword removed.
- `review-isolated.md`: Scope table and argument disambiguation updated consistently.

### Task 8 (evals) — Verified
- Three eval directories under `klaude-plugin/skills/design/evals/`.
- Each has `eval.json` with `id`, `name`, `description`, `skills`, `prompt`, `trap`, `files`, `assertions` per CLAUDE.md schema.
- Assertion IDs follow `<eval-id>.<n>` convention.
- Eval 3 has `test-files/` with intentionally broken design.md and tasks.md.

### Task 9 (verification) — Verified
- All subtasks checked done. Previous review findings (C1-C3, SQ-1, SQ-2) addressed in fix commit.

### Cross-cutting: Design assumptions hold
1. "Implement skill will naturally respect Not Doing header" — tasks.md header convention is clear; no implement changes needed. ✓
2. "CoVe isolated mode scoped to verifiable claims" — Simplified to user-initiated. ✓
3. "Profile detection compatible with new sub-phases" — Profile detection preserved before 3a. ✓
4. "Agents will exercise judgment with frameworks" — "Pick the lens that fits; don't run every framework" instruction present. ✓

### Cross-cutting: Not Doing boundaries respected
1. existing-task-process.md — not changed. ✓
2. implement skill — not changed. ✓
3. pal-based stress-testing — not implemented (documented in Addendums). ✓
4. Mermaid graphs — ASCII format used. ✓
5. Full eval coverage — only 3 high-risk evals (per scope). ✓
6. skill-md profile design/ subdirectory — not updated. ✓

---

## Doc Update Suggestions

1. **tasks.md:48** — Update subtask 3.7 to remove "concrete fallback triggers" and reflect the user-initiated CoVe approach.

---

## Indexing

No deviations to index — no `SPEC_DEV` or `EXTRA_IMPL` findings.
