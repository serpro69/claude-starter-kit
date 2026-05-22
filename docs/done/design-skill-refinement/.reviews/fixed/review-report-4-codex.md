# Design Skill Refinement - Codex Review Report 4

**Branch:** `feat/design_improvements`
**Date:** 2026-05-22
**Reviewer:** Codex
**Review modes:** `/kk:review-code` standard and `/kk:review-spec` standard
**Requested lenses:** skill improvement, skill complexity, assistant followability
**Diff base:** `master...HEAD`

---

## Executive Summary

**Overall assessment:** COMMENT

The branch is in much better shape than the earlier implementation captured in `.reviews/fixed/`. The prior blockers around generated Codex files, stale `all` scope references, framework count drift, missing Step 3 state tracking, and over-complex CoVe auto-gating have been addressed.

I found one remaining non-blocking followability issue: the non-trivial alternatives path can still collapse 3c (present alternatives) and 3d (evaluate/recommend a direction) into one assistant message because there is no explicit stop/checkpoint after alternatives are shown. This is a skill-complexity concern, not a structural or spec-conformance failure.

---

## Scope

Reviewed canonical files and generated mirrors changed on the branch:

- `docs/wip/design-skill-refinement/{design.md,implementation.md,tasks.md}`
- `klaude-plugin/skills/design/{SKILL.md,idea-process.md,example-tasks.md,frameworks.md,refinement-criteria.md}`
- `klaude-plugin/skills/design/evals/**`
- `klaude-plugin/skills/review-design/{SKILL.md,review-process.md,review-isolated.md}`
- `klaude-plugin/agents/design-reviewer.md`
- `.codex/agents/design-reviewer.toml`
- `kodex-plugin/skills/design/**`
- `kodex-plugin/skills/review-design/**`
- `.gitignore`
- historical reports under `docs/wip/design-skill-refinement/.reviews/fixed/`

For `/kk:review-code`, profile detection activated `skill-md`. Loaded checklists:

- `skill-quality-checklist.md`
- `claude-code-checklist.md`
- `kk-plugin-checklist.md`

For `/kk:review-spec`, `skill-md` has no `review-spec/` phase content, so the review used the generic spec-conformance process.

---

## Code Review Findings

### P0 - Critical

(none)

### P1 - High

(none)

### P2 - Medium

#### CR-1. Non-trivial alternatives can still collapse into immediate convergence

**File:** `klaude-plugin/skills/design/idea-process.md:55`
**Profile:** `skill-md`
**Checklist:** `skill-quality-checklist.md`
**Triggered by:** skill-root adjacency under `klaude-plugin/skills/design/SKILL.md`
**Confidence:** 78% - verified Step 3's tracker and 3c/3d instructions. The tracker records "3c alternatives presented" and "3d direction chosen", and simple ideas explicitly ask which path to proceed with. Non-trivial ideas generate 2-3 alternatives, but there is no explicit instruction to stop and ask before running 3d evaluation.

The branch added a Step 3 progress tracker and classification confirmation, which is a real improvement. The remaining gap is the boundary after alternatives are presented for non-trivial ideas. As written, an assistant can classify the problem, present alternatives, immediately evaluate them, recommend one, and move to assumptions/scope in a single turn. That recreates part of the original "jumping ahead" failure mode, just later in the flow.

**Suggested fix:** Add an explicit checkpoint after 3c alternatives:

> After presenting alternatives, stop and ask which alternatives to carry into 3d or whether to proceed with evaluation. Do not evaluate or recommend a direction in the same message that first presents alternatives unless the user explicitly asks you to continue.

### P3 - Low

#### CR-2. Keeping `all` as a review-design alias would improve compatibility

**File:** `klaude-plugin/skills/review-design/review-process.md:25`
**Profile:** `skill-md`
**Checklist:** `skill-quality-checklist.md`
**Triggered by:** skill-root adjacency under `klaude-plugin/skills/review-design/SKILL.md`
**Confidence:** 62% - current docs/evals consistently use the new default-all-documents behavior, so this is not a spec mismatch. The risk is compatibility with older prompts and review habits that still use `/kk:review-design <feature> all`.

The current branch correctly updates docs and evals away from `all`. Still, preserving `all` as a no-op alias for default scope would make the skill more forgiving at almost no complexity cost. Skills are used conversationally, and stale invocations are common after behavior changes.

**Suggested fix:** Either leave as-is and accept the compatibility break, or document `all` as a backwards-compatible alias that maps to the default all-documents scope.

---

## Spec Review Findings

### Missing Implementation

(none)

### Spec Deviation

(none)

### Extra Implementation

(none)

### Doc Inconsistency

(none)

### Outdated Doc

(none)

The implementation now matches the feature docs on the previously problematic areas: seven frameworks including Analogous Inspiration, default review-design scope includes `tasks.md`, the post-design gate text is present, CoVe is user-confirmed rather than auto-gated, and generated Codex files are tracked.

---

## Skill Improvement Lens

The branch materially improves `/kk:design` over the earlier implementation:

- The old Step 3 was essentially "ask questions one at a time"; the new 3a-3e funnel gives the assistant a concrete sequence: frame problem, establish foundations, diverge proportionally, converge, then surface assumptions/scope.
- The Step 3 progress tracker directly addresses multi-turn state loss.
- The hard gate forces user/persona, measurable success, and constraints before solutioning.
- The task output improvements - vertical slices, size tags, parallel markers, and dependency graph - should improve implementation handoff quality.
- `review-design` now checks the new artifacts, closing the loop between design output and review gate.
- The evals target meaningful failure modes: hard-gate bypass, over-engineered divergence for simple ideas, and review-design missing structural issues.
- Generated Kodex output is present and tracked; `git ls-files --others --exclude-standard kodex-plugin .codex/agents` returned no untracked generated files.

The main improvement still worth making is stricter phase separation between 3c and 3d. That is where the assistant is most likely to compress the workflow under conversational pressure.

---

## Skill Complexity Lens

The updated skill is more complex, but the complexity is mostly justified. The earlier implementation was too weak to reliably produce good designs. This version adds enough structure to be useful without turning the whole flow into a rigid process checklist.

Remaining followability risks:

1. **3c/3d boundary:** highest remaining risk. Add an explicit stop before convergence.
2. **Framework selection:** "pick by Best for guidance" is acceptable, but assistants may still overuse frameworks. Consider "choose at most two lenses unless the user asks for broader exploration."
3. **Reference rubric tone:** `refinement-criteria.md` still has product/value language such as "they'll pay" and Slack export examples. This does not violate the current spec because the design explicitly preserves painkiller/vitamin framing, but future refinement could tune examples further toward repository engineering work.
4. **Eval coverage:** current evals cover the highest-risk early failures. Additional evals for 3c/3d separation and 3e artifact surfacing would catch the remaining collapse risks.

---

## Clean Areas

- `design/SKILL.md` mandatory ordering names `frameworks.md` and `refinement-criteria.md` as fresh-idea instructions.
- `idea-process.md` does not reload the reference files after the instruction-load phase.
- Step 3 includes a sub-phase progress tracker.
- CoVe is now a user-confirmed option, not an assistant-judged nested pre/post gate.
- `review-design` standard mode, isolated mode, and `design-reviewer` all contain the new Assumptions, Not Doing, task-format, and soundness checks.
- The new eval JSON files include the required schema fields and real fixtures where filesystem structure matters.
- Generated Kodex mirrors exist for the new design files and evals.
- `git diff --exit-code kodex-plugin/ .codex/agents/` is clean.

---

## Verification

Commands run:

```bash
git diff --stat master...HEAD
git diff --find-renames master...HEAD
git ls-files --others --exclude-standard kodex-plugin .codex/agents docs/wip/design-skill-refinement/.reviews
git diff --exit-code kodex-plugin/ .codex/agents/
go test ./cmd/generate-kodex/...
for test in test/test-*.sh; do $test; done
```

Results:

- Full test suite: passed when rerun outside the read-only sandbox.
- Initial sandboxed test run failed because tests create `/tmp` directories and Go build cache files; rerun with escalation passed.
- `go test ./cmd/generate-kodex/...`: passed.
- Generated-path diff check: clean.
- Untracked generated files under `kodex-plugin` / `.codex/agents`: none.
- Working tree after review has only `.capy/knowledge.db` modified.

I did not run `make generate-kodex` during this review because it writes generated files into the working tree. The source and generated paths are clean relative to the current index, and the branch's task log records that generation was run.

---

## Indexing Notes

No P0/P1 systemic code-review findings were found, so there was nothing new to index as `kk:review-findings`.

No `SPEC_DEV` or `EXTRA_IMPL` findings were found, so there were no user-confirmed intentional deviations to index as `kk:arch-decisions`.

---

## Recommended Action Items

| Priority | Item | Action |
| --- | --- | --- |
| Should | CR-1 | Add an explicit user checkpoint between non-trivial alternatives and convergence in `idea-process.md`. |
| Consider | CR-2 | Keep `all` as a backwards-compatible review-design alias. |
| Consider | Complexity | Add eval coverage for 3c/3d separation and 3e assumptions/Not Doing surfacing. |
| Consider | Reference tone | Further tune `refinement-criteria.md` examples toward engineering-design contexts. |
