# Code Review: Design Skill Refinement

**Branch:** `feat/design_improvements` vs `master`
**Date:** 2026-05-22
**Files reviewed:** 35 files, 1909 lines added / 149 removed
**Profile:** `skill-md` (triggered by SKILL.md ancestry for `klaude-plugin/skills/design/`, `klaude-plugin/skills/review-design/`, and `kodex-plugin/` mirrors)
**Checklists applied:** skill-quality-checklist.md, claude-code-checklist.md, kk-plugin-checklist.md
**Overall assessment:** APPROVE

---

## Findings

### P0 - Critical

(none)

### P1 - High

(none)

### P2 - Medium

(none)

### P3 - Low

- **[klaude-plugin/skills/design/evals/]** Missing regression eval (negative case)
  - Profile: skill-md · Checklist: skill-quality-checklist.md (eval coverage)
  - Triggered by: filename — SKILL.md ancestry
  - The three evals all verify positive behaviors: hard gate enforcement, proportional diverge routing, review-design catching missing sections. CLAUDE.md §Skill evaluations requires "at least one regression eval proving the skill does NOT activate (or falls back to default behavior) when it shouldn't." No such eval exists. Example negative case: "Given a WIP feature with existing design docs, verify the agent does NOT run HMW framing or hard gate sub-phases (those are `idea-process.md`-only; a WIP feature uses `existing-task-process.md`)."
  - Confidence: 70% — the checklist requirement is explicit, but practical risk is low given the separate process files act as a natural guardrail.
  - Suggested fix: Add a fourth eval directory `evals/wip-feature-no-subphases/` testing that `/kk:design` on a WIP feature directory does NOT trigger the 3a-3e flow.

---

## Clean Areas

### Workflow ordering compliance (skill-quality-checklist)
- SKILL.md mandatory-order directive names `frameworks.md` and `refinement-criteria.md` in the instruction enumeration.
- Content-level reads appear exactly once — Step 3's note explicitly states "already loaded during the mandatory instruction-load phase (SKILL.md step 2). Do not reload them here."
- No duplicate `git diff` / `Read` steps across SKILL.md and idea-process.md.

### Progressive disclosure (skill-quality-checklist)
- SKILL.md is 50 lines. Reference files (`frameworks.md`, `refinement-criteria.md`) loaded on-demand for fresh ideas only — not eagerly for WIP features.
- Descriptive filenames throughout (`frameworks.md`, `refinement-criteria.md`, `example-tasks.md`).

### Description quality (skill-quality-checklist)
- Description leads with trigger keywords ("Use in pre-implementation (idea-to-design) stages"). Well under 1,536 character cap.
- (Description frontmatter unchanged in this diff.)

### Instruction clarity (skill-quality-checklist)
- Instructions explain *why* at each sub-phase: "This anchors all subsequent questions on the problem, not a solution" (3a), "This prevents designing solutions that conflict with the project's actual technical landscape" (3b).
- Step 3 Progress checklist added — copy-paste progress tracking for the multi-turn sub-phases.
- CoVe simplified to a user-initiated gate (previous review SQ-1 addressed): "Let the user decide — do not auto-invoke or auto-skip CoVe."

### Eval coverage (skill-quality-checklist)
- Three evals with real filesystem fixtures (`test-files/design.md`, `test-files/tasks.md`).
- Each eval.json includes well-targeted `trap` fields.
- Assertion IDs follow `<eval-id>.<n>` convention.

### `${CLAUDE_PLUGIN_ROOT}` usage (claude-code-checklist)
- Brace form used only in SKILL.md (plugin-load file): `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/design/`.
- Runtime-read files (`idea-process.md`) use `<plugin_root>` prose instruction with "the absolute plugin-root path you already know from SKILL.md context."
- Relative links (`[frameworks.md](frameworks.md)`) used throughout idea-process.md — no literal token forwarding.

### Cross-path consistency (review-design)
- Scope tables identical across all three locations: `review-design/SKILL.md`, `review-process.md`, `review-isolated.md`.
- Default scope: `design.md + implementation.md + tasks.md` in all three. `all` keyword removed from all three.
- New Assumptions/Not Doing checks: textually identical in `review-process.md` §3 and `design-reviewer.md` §3.
- New assumptions testability / Not Doing validity checks: semantically identical in `review-process.md` §4 and `design-reviewer.md` §4 (minor wording differences, same behavior).

### Naming conventions (kk-plugin-checklist)
- `/kk:` prefix used consistently: `/kk:chain-of-verification:isolated`, `/kk:review-design <feature>`, `/kk:test`, `/kk:document`, `/kk:review-code`, `/kk:review-spec`.
- Agent name `design-reviewer` describes the role, not the invoking skill.

### Codex generation (kk-plugin-checklist)
- `kodex-plugin/` mirror matches `klaude-plugin/` changes. Commit `991f34a` ran `make generate-kodex`.
- `.codex/agents/design-reviewer.toml` updated with same quality/soundness checks.

### License attribution (generic)
- Both `frameworks.md` and `refinement-criteria.md` include HTML comment attribution headers with MIT license notice, upstream URL, and pinned commit SHA (`539a785`).

### Previous review fixes verified
- C1 (stale scope references): Fixed — design.md and implementation.md now reference default scope including tasks.md; `all` keyword removed; post-design gate note present in review-design/SKILL.md.
- C2 (assumption categorization scope creep): Fixed — Step 3e no longer references Must/Should/Might from refinement-criteria.md's Assumption Audit section.
- C3 (framework count 6 vs 7): Fixed — design.md now lists all 7 frameworks including Analogous Inspiration.
- SQ-1 (CoVe complexity): Addressed — CoVe simplified to user-initiated option, removing the pre-check/post-check conditional gates.
- SQ-2 (sub-phase state tracking): Addressed — Step 3 Progress checklist added with 8 checkboxes tracking 3a-3e sub-phases.

---

## Indexing

No findings to index — no P0/P1 systemic findings.
