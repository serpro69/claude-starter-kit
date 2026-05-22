# Design Skill Refinement - Codex Review Report

**Branch:** `feat/design_improvements`
**Date:** 2026-05-22
**Reviewer:** Codex using `/kk:review-code` and `/kk:review-spec`
**Requested lenses:** skill improvement, skill complexity, assistant followability
**Mode:** review only; no source/spec fixes applied

---

## Executive Summary

The branch improves `/kk:design` in the right direction: it adds a structured refinement funnel, explicit assumptions/scope outputs, better task-slicing guidance, review-design enforcement, and targeted evals. The main blocking risks are not structural test failures. They are release and behavior drift:

1. The generated Codex output has new untracked files that the documented freshness command does not catch.
2. One new eval still uses the removed `all` scope.
3. The feature docs still describe the old `all`-scope model even though implementation now makes all documents the default review scope.

From the skill-complexity lens, the design is beneficial but close to the edge of what assistants reliably follow across multi-turn refinement. The highest-risk pieces are the CoVe pre/post-check logic and the lack of an explicit 3a-3e state tracker.

---

## Review Scope

Reviewed the branch diff against `origin/master`, staged generated Codex changes, untracked generated Codex files, and the feature docs under `docs/wip/design-skill-refinement/`.

Primary files reviewed:

- `klaude-plugin/skills/design/SKILL.md`
- `klaude-plugin/skills/design/idea-process.md`
- `klaude-plugin/skills/design/example-tasks.md`
- `klaude-plugin/skills/design/frameworks.md`
- `klaude-plugin/skills/design/refinement-criteria.md`
- `klaude-plugin/skills/design/evals/**`
- `klaude-plugin/skills/review-design/SKILL.md`
- `klaude-plugin/skills/review-design/review-process.md`
- `klaude-plugin/skills/review-design/review-isolated.md`
- `klaude-plugin/agents/design-reviewer.md`
- generated mirrors under `kodex-plugin/` and `.codex/agents/`
- `docs/wip/design-skill-refinement/{design.md,implementation.md,tasks.md}`

Profile detection for `/kk:review-code` resolved `skill-md` for skill-rooted files. Loaded checklists:

- `skill-quality-checklist.md`
- `claude-code-checklist.md`
- `kk-plugin-checklist.md`

`skill-md` has no `review-spec/` phase content, so `/kk:review-spec` used generic spec-conformance guidance.

---

## Code Review Summary

**Files reviewed:** branch diff contains 15 canonical source/doc files, plus generated Codex mirrors and untracked generated Codex files.
**Overall assessment:** REQUEST_CHANGES

### P0 - Critical

None.

### P1 - High

#### CR-1. Codex freshness check misses untracked generated files

**File:** `docs/wip/design-skill-refinement/tasks.md`, Task 9.2
**Profile:** `skill-md`
**Checklist:** `kk-plugin-checklist.md`
**Confidence:** 95%

The documented freshness check is:

```bash
make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/
```

That command returned clean after generation. However, `git ls-files --others --exclude-standard kodex-plugin .codex/agents` reported seven untracked generated Codex files:

- `kodex-plugin/skills/design/evals/hard-gate-enforcement/eval.json`
- `kodex-plugin/skills/design/evals/proportional-diverge-routing/eval.json`
- `kodex-plugin/skills/design/evals/review-design-catches-missing-sections/eval.json`
- `kodex-plugin/skills/design/evals/review-design-catches-missing-sections/test-files/design.md`
- `kodex-plugin/skills/design/evals/review-design-catches-missing-sections/test-files/tasks.md`
- `kodex-plugin/skills/design/frameworks.md`
- `kodex-plugin/skills/design/refinement-criteria.md`

This can produce a false green freshness check while the Codex plugin omits newly generated files. Because Codex support is a first-class generated artifact in this repo, this should block merge until the generated files are added or the freshness check is strengthened.

**Suggested fix:** Add the untracked generated files to the change set. Also update the documented freshness verification to include an untracked-file check, for example:

```bash
make generate-kodex
git diff --exit-code kodex-plugin/ .codex/agents/
test -z "$(git ls-files --others --exclude-standard kodex-plugin .codex/agents)"
```

This systemic finding was indexed as `kk:review-findings`.

#### CR-2. New review-design eval invokes removed `all` scope

**File:** `klaude-plugin/skills/design/evals/review-design-catches-missing-sections/eval.json`
**Profile:** `skill-md`
**Checklist:** `skill-quality-checklist.md`
**Confidence:** 90%

The eval prompt is `/kk:review-design notification-system all`, but the updated `review-design` standard and isolated workflows removed `all` from scope keyword handling. The scope tables now list only default, `design`, `implementation`, and `tasks`.

This makes the new regression eval test stale invocation behavior. Depending on runtime parsing, it may fail by treating `all` as invalid/extra input, or it may rely on behavior the docs no longer advertise.

**Suggested fix:** Change the eval prompt to `/kk:review-design notification-system`, since default scope now includes `design.md + implementation.md + tasks.md`. Alternatively keep `all` as a backwards-compatible alias in `review-design` and document it.

### P2 - Medium

#### CR-3. Feature docs still describe the old `all`-scope model

**Files:**

- `docs/wip/design-skill-refinement/design.md`
- `docs/wip/design-skill-refinement/implementation.md`
- `docs/wip/design-skill-refinement/tasks.md`

**Confidence:** 95%

The implementation changed `review-design` default scope to all documents and removed the `all` scope keyword. The feature docs still say to recommend `/kk:review-design <feature> all` because default scope excludes `tasks.md`.

This is a spec/documentation drift, not a broken implementation. The implementation is internally consistent; the docs are stale.

**Suggested fix:** Update design and implementation docs to say default scope now includes `tasks.md`, and change the post-design gate recommendation to `/kk:review-design <feature>`.

#### CR-4. Reference files do not fully apply the requested SE-context adaptation

**Files:**

- `klaude-plugin/skills/design/frameworks.md`
- `klaude-plugin/skills/design/refinement-criteria.md`

**Confidence:** 75%

The implementation plan required a brief software-engineering framing paragraph at the top of both reference files and removal of consumer-product examples. The produced files start directly with generic reference prose. `frameworks.md` also still includes the consumer-product example "Netflix competes with sleep."

The files are still useful, but this weakens the skill-improvement goal. `/kk:design` is meant to design software changes in existing repositories; consumer-product discovery language can pull the assistant toward startup/product ideation instead of engineering design.

**Suggested fix:** Add a short SE-context paragraph to both files and replace remaining consumer examples with engineering examples.

#### CR-5. Step 3 has high multi-turn followability risk

**File:** `klaude-plugin/skills/design/idea-process.md`
**Confidence:** 80%

Step 3 now spans HMW confirmation, three hard-gate questions, complexity classification confirmation, alternatives, convergence, and assumptions/scope output. That is a good design funnel, but it has no sub-phase progress tracker.

The top-level workflow checklist tracks Steps 1-6 only. It does not track whether 3a, each 3b foundation, 3c classification, 3d convergence, or 3e assumptions/scope are complete. Assistants commonly lose this state across multi-turn conversations.

**Suggested fix:** Add a compact Step 3 tracker:

```markdown
Step 3 Progress:
- [ ] 3a HMW framing confirmed
- [ ] 3b user/persona confirmed
- [ ] 3b success metric confirmed
- [ ] 3b constraints confirmed
- [ ] 3c complexity classification confirmed
- [ ] 3c alternatives selected
- [ ] 3d direction chosen
- [ ] 3e assumptions and Not Doing presented
```

#### CR-6. CoVe gate is too complex for reliable assistant execution

**File:** `klaude-plugin/skills/design/idea-process.md`
**Confidence:** 75%

The CoVe pre-check and post-check require the assistant to decide:

- whether alternatives contain "specific verifiable claims"
- whether CoVe questions reference specific constraints/trade-offs
- whether CoVe answers are "substantively identical"
- whether to discard CoVe output after invoking it

Those are abstract judgments, and the post-check is especially fragile. Once an assistant invokes a tool, it tends to rationalize using the output rather than discarding it.

**Suggested fix:** Simplify this to an explicit user choice: "I can run `/kk:chain-of-verification:isolated` to fact-check specific claims before we commit to a direction; otherwise I will proceed with manual criteria-based analysis."

### P3 - Low

#### CR-7. Task checklist currently marks skills as run when they were not run as skills

**File:** `docs/wip/design-skill-refinement/tasks.md`
**Confidence:** 95%

Task 9.3 and 9.4 are currently checked:

- `/kk:test`
- `/kk:document`

During this Codex review, I ran shell tests and `make generate-kodex`, but I did not invoke `/kk:test` or `/kk:document` as skills. If those boxes were checked by another reviewer or process, the task file should record that provenance. If they were inferred from shell verification, that is inaccurate.

**Suggested fix:** Mark them pending unless those exact skill invocations were actually completed.

#### CR-8. `Not Doing` still lists design skill evals while Task 8 adds evals

**File:** `docs/wip/design-skill-refinement/tasks.md`
**Confidence:** 90%

The tasks header says `design skill evals` are not in scope, but Task 8 creates design skill evals. The design doc uses a more precise boundary: comprehensive eval coverage is out of scope, while spec-style evals for high-risk behaviors are in scope.

**Suggested fix:** Change the tasks header to "comprehensive design skill eval coverage" or similar.

---

## Spec Review Summary

**Feature:** `design-skill-refinement`
**Mode:** post-implementation review of completed and in-progress feature tasks
**Documents reviewed:** `design.md`, `implementation.md`, `tasks.md`
**Overall assessment:** REQUEST_CHANGES

### Missing Implementation

None found for completed tasks, subject to the generated-file issue in CR-1.

### Spec Deviation

#### SC-1. Scope invocation changed from `all` to default without updating the spec

**Severity:** P2
**Spec says:** recommend `/kk:review-design <feature> all` because default excludes tasks.
**Implementation does:** default includes tasks and `all` is removed from documented accepted scopes.
**Confidence:** 9/10

This is likely an intentional implementation improvement, but the spec was not updated. It affects `design.md`, `implementation.md`, `tasks.md`, and the new eval prompt.

**Recommendation:** Update docs and evals to the new default-scope model, or restore `all` as a backwards-compatible alias.

### Outdated Doc

#### SC-2. Framework list/count is stale in the design docs

**Severity:** P2
**Spec says:** design text lists six frameworks.
**Implementation does:** `frameworks.md` contains seven frameworks, including Analogous Inspiration.
**Confidence:** 8/10

`tasks.md` now says "all seven frameworks", so the implementation and task tracker agree; `design.md` and part of `implementation.md` still use the older six-framework framing.

**Recommendation:** Add Analogous Inspiration to the design doc list and update any "all six" verification language.

### Extra Implementation

#### SC-3. Assumption categorization goes beyond the design spec

**Severity:** P3
**Spec says:** assumptions should be specific enough to be testable.
**Implementation does:** Step 3e requires categorizing assumptions as Must Be True, Should Be True, and Might Be True using `refinement-criteria.md`.
**Confidence:** 7/10

This may be a useful addition, but it is not propagated into Step 5 or `review-design` checks. That creates a one-step-only artifact that could be skipped or lost.

**Recommendation:** Either remove the categorization requirement for simplicity, or update Step 5 and review-design to preserve/check the categories.

### Doc Inconsistency

#### SC-4. Task header Not Doing conflicts with Task 8

**Severity:** P3
**Docs conflict:** `tasks.md` header says design skill evals are not being done; Task 8 says design evals were created.
**Confidence:** 9/10

**Recommendation:** Narrow the Not Doing item to "comprehensive design skill eval coverage."

---

## Skill Improvement Lens

### Improvements That Look Strong

- The 3a-3e funnel addresses a real failure mode in the old skill: jumping from an idea straight into solutioning.
- The hard gate is a useful forcing function. "Who, success, constraints" is the right minimum set before alternatives.
- Proportional divergence is a good correction to over-engineering. Simple ideas should not get a heavyweight ideation process.
- Assumptions and Not Doing sections are durable artifacts, which fits this repo's fail-loud guidance.
- The task format changes should improve implementation quality: vertical slices, size tags, parallel markers, and dependency graph all reduce hidden integration risk.
- The review-design checks match the new design outputs and close the loop.
- The evals target meaningful assistant failure modes rather than superficial formatting.

### Improvement Gaps

- The generated Codex untracked-file gap means Codex users may not get the new design references/evals unless the files are added.
- The eval suite does not yet cover 3c/3d collapse, skipped 3e, or framework-selection misuse.
- The SE-context adaptation of upstream reference files is incomplete.
- The scope evolution from `all` keyword to default-all-docs is good, but docs/evals must move together.

---

## Skill Complexity Lens

### Main Followability Risks

1. **State tracking across Step 3.** The assistant must remember multiple gates over many turns. Add an explicit sub-checklist.
2. **CoVe conditional complexity.** The current pre/post gate is too abstract. Prefer a simple user-confirmed optional verification branch.
3. **Simple/non-trivial classification.** The classification rule is useful but borderline vague. Add concrete examples or a short decision table.
4. **Framework selection.** "Pick by Best for guidance" is directionally good, but some ideas will match multiple frameworks. A "choose at most two lenses unless the user asks for broader exploration" rule would reduce overuse.
5. **3c/3d separation.** The skill should explicitly say not to evaluate/recommend in the same message where alternatives are first introduced unless the user asks to proceed.

### Complexity Verdict

The skill is more powerful but also more brittle. The current shape is acceptable if Step 3 gets a tracker and CoVe is simplified. Without those changes, the skill will work in careful sessions but fail in faster conversations where the assistant compresses sub-phases.

---

## Verification Performed

Commands run:

```bash
bash test/test-plugin-structure.sh
bash test/test-codex-structure.sh
bash test/test-template-sync.sh
make generate-kodex
git diff --exit-code kodex-plugin/ .codex/agents/
git ls-files --others --exclude-standard kodex-plugin .codex/agents
```

Results:

- `test-plugin-structure.sh`: pass
- `test-codex-structure.sh`: pass
- `test-template-sync.sh`: pass after rerun outside the read-only sandbox because the sandbox could not create `/tmp` directories
- `make generate-kodex`: pass
- `git diff --exit-code kodex-plugin/ .codex/agents/`: pass
- untracked generated Codex files: present, see CR-1

---

## Required Indexing

Indexed as `kk:review-findings`:

- Codex generation freshness checks using only `git diff --exit-code kodex-plugin/ .codex/agents/` miss newly generated untracked files. Add an untracked-file check after generation.

No `SPEC_DEV` or `EXTRA_IMPL` findings were indexed as `kk:arch-decisions` because user confirmation of intentional deviations is required first.

---

## Recommended Action Plan

1. Add the untracked generated Codex files and strengthen the freshness check.
2. Decide whether `all` remains a backwards-compatible alias. Then update the eval prompt and feature docs consistently.
3. Add SE-context framing to `frameworks.md` and `refinement-criteria.md`; replace remaining consumer-product examples.
4. Add a Step 3 sub-phase progress tracker.
5. Simplify CoVe to an explicit optional user-confirmed branch.
6. Fix task checklist/doc drift around `/kk:test`, `/kk:document`, and design eval scope.

---

## Residual Risk

This review did not execute the interactive `/kk:design` flow end to end. The highest-risk behavior is conversational, so static review plus spec-style evals cannot fully prove the assistant will honor every sub-phase in real multi-turn use.
