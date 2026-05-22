# Design Skill Refinement — Current Branch Review

**Branch:** `feat/design_improvements`  
**Base:** `master...HEAD`  
**Date:** 2026-05-22  
**Reviewer:** Codex using `kk:review-code` and `kk:review-spec` workflows  
**Requested lenses:** code/spec conformance, skill improvement, skill complexity / assistant followability  
**Assessment:** REQUEST_CHANGES for followability polish; no blocking correctness defects

## Scope

Reviewed the current branch implementation for `docs/wip/design-skill-refinement/`.

Primary files reviewed:

- `docs/wip/design-skill-refinement/{design.md,implementation.md,tasks.md}`
- `klaude-plugin/skills/design/{SKILL.md,idea-process.md,example-tasks.md,frameworks.md,refinement-criteria.md}`
- `klaude-plugin/skills/design/evals/**`
- `klaude-plugin/skills/review-design/{SKILL.md,review-process.md,review-isolated.md}`
- `klaude-plugin/agents/design-reviewer.md`
- generated mirrors under `kodex-plugin/skills/**` and `.codex/agents/design-reviewer.toml`
- fixed prior review reports under `docs/wip/design-skill-refinement/.reviews/fixed/`

`kk:review-code` profile detection resolved `skill-md` and loaded:

- `skill-quality-checklist.md`
- `claude-code-checklist.md`
- `kk-plugin-checklist.md`

`kk:review-spec` found no `skill-md/review-spec/` profile slot, so it used the generic spec-conformance workflow.

## Findings

### P0 — Critical

None.

### P1 — High

None.

### P2 — Medium

#### CR-1. Non-trivial alternatives can still collapse into immediate convergence

**Profile:** `skill-md`  
**Checklist:** `skill-quality-checklist.md`  
**File:** `klaude-plugin/skills/design/idea-process.md:55`  
**Related lines:** `klaude-plugin/skills/design/idea-process.md:66`, `klaude-plugin/skills/design/idea-process.md:71`  
**Confidence:** 8/10

The branch adds a Step 3 progress tracker and classification confirmation, which materially improves followability. The remaining weak boundary is between 3c and 3d for non-trivial ideas.

For simple ideas, the skill explicitly asks which path to proceed with. For non-trivial ideas, it says to generate 2-3 alternatives and present trade-off summaries, then the next sub-phase says to evaluate each direction and recommend one. There is no explicit checkpoint after alternatives are presented. An assistant can therefore present alternatives and immediately evaluate/recommend in the same message, compressing the diverge and converge phases.

That is a skill-complexity issue: it partially recreates the “jump ahead” failure mode this refinement is trying to fix, just later in the process.

**Recommendation:** Add a stop/checkpoint after presenting non-trivial alternatives, for example: “After presenting alternatives, stop and ask which alternatives to carry into 3d, or whether to proceed with evaluation. Do not evaluate or recommend a direction in the same message that first presents alternatives unless the user explicitly asks you to continue.”

### P3 — Low

#### SC-1. Task tracker still claims CoVe fallback triggers were implemented

**Type:** `OUTDATED_DOC`  
**File:** `docs/wip/design-skill-refinement/tasks.md:48`  
**Related implementation:** `klaude-plugin/skills/design/idea-process.md:73`  
**Related specs:** `docs/wip/design-skill-refinement/design.md:63`, `docs/wip/design-skill-refinement/implementation.md:102`  
**Confidence:** 9/10

Task 3.7 says Step 3d implemented “CoVe scoped to verifiable claims only, concrete fallback triggers.” The current design and implementation intentionally removed the fallback-trigger machinery and simplified CoVe to a user-confirmed option:

- The design says the agent offers the user a choice to run `/kk:chain-of-verification:isolated` or proceed as-is.
- `idea-process.md` matches that simpler behavior and explicitly says not to auto-invoke or auto-skip CoVe.

This is not a code defect. It is a stale task description left over from the earlier, more complex CoVe design.

**Recommendation:** Reword task 3.7 to match the implemented behavior, for example: “manual criteria-based analysis as default, CoVe offered as a user-confirmed fact-check option for specific technical claims.”

## Additional Suggestions

### Keep `all` as a compatibility alias for `review-design`

The branch correctly updates docs and evals so `/kk:review-design <feature>` is the post-design gate and default scope includes `design.md + implementation.md + tasks.md`. That is simpler than requiring `all`.

Still, removing `all` entirely is a small compatibility loss. Existing users or old transcripts may still invoke `/kk:review-design <feature> all`. Keeping `all` as an undocumented or documented alias for the default all-documents scope would be cheap and would make the skill more forgiving.

This is not a spec violation because the current docs consistently describe the new default behavior.

### Update `review-design` frontmatter to mention task lists

`klaude-plugin/skills/review-design/SKILL.md:4` still says the skill reviews “design and implementation docs.” The invocation section now correctly says the default scope reviews all documents including task-format checks, but the frontmatter description is what the harness uses for skill selection.

Consider changing it to mention task lists explicitly, e.g. “Review design, implementation, and task documents produced by design.”

## Skill Improvement Lens

The branch is a real improvement over the earlier design skill.

- The old Step 3 gave the assistant a weak instruction: ask questions one at a time. The new 3a-3e flow gives it a usable refinement funnel: problem framing, foundation gate, alternatives, convergence, then assumptions/scope.
- The Step 3 progress checklist directly addresses the earlier multi-turn state-loss risk.
- CoVe was simplified from an assistant-judged pre/post gate to a user-confirmed optional fact-check. That is materially easier to follow.
- `frameworks.md` and `refinement-criteria.md` now have explicit software-engineering framing and pinned upstream attribution.
- Step 6’s vertical slicing, size tags, parallel markers, and dependency graph should improve implementation handoff quality.
- `review-design` now checks the new artifacts instead of letting design output drift silently.
- The evals target the right failure modes: skipping the hard gate, over-engineering a simple idea, and missing required task/design structure.

## Skill Complexity Lens

The skill is more complex than before, but the current version is inside a reasonable followability envelope.

The risk is concentrated in Step 3. It now asks the assistant to manage HMW confirmation, three foundation questions, complexity classification, alternatives, convergence, and artifact surfacing. The added Step 3 progress checklist is what makes that acceptable. Without it, the flow would likely collapse in longer conversations.

The main remaining risk is the 3c/3d boundary for non-trivial ideas. The skill should stop after presenting alternatives and let the user decide whether to evaluate all options, narrow the set, or add a missed constraint. Without that checkpoint, the assistant may compress divergence and convergence into one turn.

The other complexity trade-off is “always show at least two options.” That improves design quality, but it can add ceremony for trivial changes. The simple-path branch mitigates this by requiring only the direct path plus one alternative and by confirming with the user before exploring more broadly.

## Clean Areas

- Workflow ordering is respected: `SKILL.md` names `frameworks.md` and `refinement-criteria.md` as fresh-idea instruction files.
- No duplicate content-read instructions were introduced in the design skill flow.
- `${CLAUDE_PLUGIN_ROOT}` usage stays in plugin-load files; runtime-read files use relative links or `<plugin_root>` prose.
- `review-design` standard mode, isolated mode, and `design-reviewer` all gained the new Assumptions / Not Doing / task-format checks.
- Generated Codex mirrors are tracked and fresh.
- Previous fixed-review findings about untracked generated files, stale `all` scope references, missing SE framing, stale framework count, missing Step 3 tracker, and over-complex CoVe auto-gating are resolved in the current branch.

## Verification

Commands run:

- `for test in test/test-*.sh; do "$test"; done` — passed outside the read-only sandbox.
- `make generate-kodex` — passed.
- `git diff --exit-code kodex-plugin .codex/agents` — passed after generation.
- `git ls-files --others --exclude-standard kodex-plugin .codex/agents` — no untracked generated files.
- `git diff --check master...HEAD` — passed.

The only dirty worktree item after review is `.capy/knowledge.db`, which is local capy state and unrelated to the branch implementation.
