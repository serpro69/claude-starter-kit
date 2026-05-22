# Design Skill Refinement — Codex Review Report

**Reviewer:** Codex
**Date:** 2026-05-22
**Branch:** `feat/design_improvements`
**Review modes:** `/kk:review-code` standard, `/kk:review-spec` standard
**Primary lens:** skill quality, skill improvement, and assistant-followability complexity

## Scope

Reviewed the current branch against `master...HEAD`, plus staged generated Codex output and untracked generated Codex files.

Canonical files reviewed:

- `docs/wip/design-skill-refinement/design.md`
- `docs/wip/design-skill-refinement/implementation.md`
- `docs/wip/design-skill-refinement/tasks.md`
- `klaude-plugin/agents/design-reviewer.md`
- `klaude-plugin/skills/design/SKILL.md`
- `klaude-plugin/skills/design/idea-process.md`
- `klaude-plugin/skills/design/example-tasks.md`
- `klaude-plugin/skills/design/frameworks.md`
- `klaude-plugin/skills/design/refinement-criteria.md`
- `klaude-plugin/skills/design/evals/**`
- `klaude-plugin/skills/review-design/SKILL.md`
- `klaude-plugin/skills/review-design/review-process.md`
- `klaude-plugin/skills/review-design/review-isolated.md`

Generated mirrors reviewed where relevant:

- `.codex/agents/design-reviewer.toml`
- `kodex-plugin/skills/design/**`
- `kodex-plugin/skills/review-design/**`

## Overall Assessment

**REQUEST_CHANGES**

The design refinement direction is good: Step 3 is more structured, task output is better shaped for implementation, and review-design now checks the new expected artifacts. The blocking issues are around branch completeness and spec/code consistency, not the core idea.

Two P1 issues should be fixed before merge:

1. Generated Codex files are present but untracked.
2. The implementation removes `all` as a review-design scope while docs and evals still invoke `all`.

One P2 issue affects the skill-improvement goal: the adapted reference files still carry product/startup examples and lack the promised software-engineering framing, which makes the skill more likely to steer assistants toward generic product ideation instead of repository-aware engineering design.

## Code Review Findings

### P0 — Critical

None.

### P1 — High

#### CR-1. Generated Codex additions are untracked

**Files:**

- `kodex-plugin/skills/design/frameworks.md`
- `kodex-plugin/skills/design/refinement-criteria.md`
- `kodex-plugin/skills/design/evals/**`

**Profile:** `skill-md`
**Checklist:** `kk-plugin-checklist.md`
**Triggered by:** skill-root adjacency under `klaude-plugin/skills/design/SKILL.md` and generated Codex mirror paths
**Confidence:** 95%

The branch includes canonical new files under `klaude-plugin/skills/design/`, and generated mirrors exist under `kodex-plugin/skills/design/`, but the generated files are untracked in the working tree.

Evidence from `git status -sb`:

- Tracked staged generated files include modified existing Codex files.
- New generated Codex files are listed as `?? kodex-plugin/skills/design/evals/`, `?? kodex-plugin/skills/design/frameworks.md`, and `?? kodex-plugin/skills/design/refinement-criteria.md`.

If committed this way, the canonical plugin and generated Codex plugin will diverge. The repository convention requires generated output freshness after editing `klaude-plugin/`.

**Suggested fix:** Add the generated Codex files to git, or rerun `make generate-kodex` and stage the resulting `kodex-plugin/` and `.codex/agents/` changes.

### P2 — Medium

#### CR-2. Reference files do not fully apply the promised software-engineering adaptation

**Files:**

- `klaude-plugin/skills/design/frameworks.md:7`
- `klaude-plugin/skills/design/frameworks.md:64`
- `klaude-plugin/skills/design/frameworks.md:101`
- `klaude-plugin/skills/design/refinement-criteria.md:7`
- `klaude-plugin/skills/design/refinement-criteria.md:97`
- `klaude-plugin/skills/design/refinement-criteria.md:103`
- `docs/wip/design-skill-refinement/implementation.md:42`
- `docs/wip/design-skill-refinement/implementation.md:59`

**Profile:** `skill-md`
**Checklist:** `skill-quality-checklist.md`
**Triggered by:** skill-root adjacency
**Confidence:** 85%

The implementation plan requires a software-engineering framing note and removal/replacement of consumer-product examples. The actual reference files still read as generic product/startup ideation:

- `frameworks.md` opens with generic “Use these frameworks selectively” guidance, not the promised SE-context framing for APIs, infrastructure, developer tools, internal systems, and library design.
- `frameworks.md` still includes consumer examples such as Netflix and “Uber for X”.
- `refinement-criteria.md` still includes examples like users sharing data and preferring self-serve, without engineering-context replacement.

This matters from the skill-improvement lens. These files are methodology loaded before the agent refines an idea; examples strongly shape assistant behavior. If the examples remain consumer-product-oriented, the skill may produce product-discovery conversations when the repo needs engineering design conversations.

**Suggested fix:** Add the promised SE framing near the top of both reference files and replace consumer examples with engineering equivalents, such as RPC vs async eventing, deployment constraints, internal platform users, migration risk, library/API ergonomics, and operational failure modes.

### P3 — Low

None.

## Spec Conformance Findings

### P0 — Critical

None.

### P1 — High

#### SC-1. `all` scope was removed from review-design while docs and evals still depend on it

**Type:** `SPEC_DEV` / `DOC_INCON`
**Files:**

- `klaude-plugin/skills/review-design/SKILL.md:82`
- `klaude-plugin/skills/review-design/review-process.md:25`
- `klaude-plugin/skills/review-design/review-isolated.md:28`
- `klaude-plugin/skills/design/evals/review-design-catches-missing-sections/eval.json:6`
- `docs/wip/design-skill-refinement/tasks.md:66`
- `docs/wip/design-skill-refinement/design.md:130`
- `docs/wip/design-skill-refinement/implementation.md:150`

**Confidence:** 95%

The implementation changes review-design so the default scope reviews all documents and removes `all` from the scope table. That is a reasonable product decision, but the rest of the feature still references `all`:

- The new review-design eval prompt invokes `/kk:review-design notification-system all`.
- The feature task list marks as complete the instruction to recommend `/kk:review-design <feature> all`.
- The design and implementation docs still describe the old reason for `all`: default review did not include `tasks.md`.

This creates a real behavioral mismatch. If the command parser follows the new scope list, `all` may be treated as an invalid scope or ambiguous argument. Even if the parser tolerates it, the docs and eval are now testing stale behavior.

**Suggested fix:** Keep `all` as a backward-compatible alias for the default all-documents scope, or update the design docs, implementation plan, tasks, and eval prompt to remove `all` consistently. Backward-compatible aliasing is the safer option because existing docs and user habits may already include `all`.

### P2 — Medium

#### SC-2. Reference-file adaptation is marked complete but does not meet the implementation plan

**Type:** `SPEC_DEV`
**Files:**

- `docs/wip/design-skill-refinement/tasks.md:20`
- `docs/wip/design-skill-refinement/tasks.md:32`
- `klaude-plugin/skills/design/frameworks.md:7`
- `klaude-plugin/skills/design/refinement-criteria.md:7`

**Confidence:** 85%

Tasks 1 and 2 are marked done, including light adaptation of the upstream reference files. The produced files do include attribution and useful content, but they do not fully satisfy the documented adaptation requirements:

- The promised SE-context framing is not present in substance.
- Consumer examples remain.

This overlaps with CR-2, but from the spec lens it is also a completed-task mismatch.

**Suggested fix:** Either complete the adaptation or update the implementation plan/tasks to explicitly accept a lighter adaptation that preserves some product examples.

## Skill Improvement Lens

### Strong Improvements

- The new Step 3 sequence gives `/kk:design` a real conversation shape: frame the problem, establish foundations, explore alternatives, converge, then surface assumptions and scope.
- The hard gate is a useful correction to the prior “ask questions one at a time” instruction, which was too open-ended to reliably prevent premature solution design.
- The vertical slicing guidance in Step 6 should materially improve implementation handoff quality.
- The updated `example-tasks.md` is a strong teaching artifact. Assistants follow examples more reliably than abstract rules.
- The review-design checks align with the new design outputs, especially Assumptions, Not Doing, Size tags, parallel markers, and dependency graph.
- The evals target high-risk behaviors rather than trivial markdown formatting.

### Improvement Gaps

- The reference files are currently too generic. For this repo, skill improvement means better engineering design, not broader product brainstorming.
- The `all` scope change is directionally fine, but removing the alias makes the skill less forgiving and breaks the new eval. Skills should be robust to common invocation habits when compatibility is cheap.
- The review-design invocation section now says default reviews all documents, but it does not explicitly frame that as the post-design gate after `/kk:design`. The behavior is there; the user-facing affordance is weaker than the design intended.

## Skill Complexity Lens

### Complexity Assessment

The added structure is worth it overall, but Step 3 now has enough state that an assistant can plausibly lose track during a real multi-turn conversation.

Highest-risk areas:

- **Hard gate state:** The agent must remember which of who/success/constraints have been explicitly answered.
- **3c classification:** The agent must classify simple vs non-trivial, explain why, ask for confirmation, and only then generate alternatives.
- **3c/3d boundary:** The agent may collapse alternatives and evaluation into one message, skipping the intended user checkpoint.
- **CoVe pre/post-check:** The agent must decide whether claims are verifiable, ask before invoking CoVe, then possibly discard CoVe output if it is too generic.
- **3e artifact surfacing:** Assumptions and Not Doing may get compressed into Step 4 instead of being presented as first-class artifacts before Step 4.

### Complexity Recommendations

1. Add a small Step 3 progress checklist directly under Step 3:

   - 3a HMW confirmed
   - 3b user confirmed
   - 3b success confirmed
   - 3b constraints confirmed
   - 3c complexity classification confirmed
   - 3c alternatives selected
   - 3d direction chosen
   - 3e assumptions and Not Doing presented

2. Keep `all` as an alias. Reducing invocation friction is part of making skills assistant-followable.

3. Consider simplifying CoVe to an optional user-confirmed tool:

   “If you want to fact-check technical claims in these alternatives, I can invoke `/kk:chain-of-verification:isolated`; otherwise I’ll proceed with manual criteria-based analysis.”

   This is easier for assistants to follow than a two-stage agent-judged CoVe pre/post gate.

4. Add eval coverage for the 3c/3d boundary and 3e artifact surfacing. The existing evals cover hard-gate and classification routing, but not the later multi-turn failure modes.

## Clean Areas

- Mandatory instruction loading was updated in `design/SKILL.md` to include `frameworks.md` and `refinement-criteria.md`.
- The profile-detection block remains before subject-matter refinement in `idea-process.md`.
- `review-process.md`, `review-isolated.md`, and `design-reviewer.md` all gained task-format and Assumptions/Not Doing checks.
- The generated Codex modifications for existing files match the canonical changes at a high level.
- The eval JSON files include `id`, `name`, `description`, `skills`, `prompt`, `trap`, `files`, and `assertions`.

## Validation

Commands run:

- `bash test/test-plugin-structure.sh` — passed
- `bash test/test-codex-structure.sh` — passed
- `bash test/test-template-sync.sh` — initially failed in the read-only sandbox due `/tmp` writes, rerun outside sandbox and passed
- `bash test/test-claude-extra.sh` — initially failed in the read-only sandbox due `/tmp` writes, rerun outside sandbox and passed
- `bash test/test-hooks.sh` — passed
- `bash test/test-manifest-jq.sh` — initially failed in the read-only sandbox due cache/temp writes, rerun outside sandbox and passed
- `bash test/test-semver-compare.sh` — passed
- `bash test/test-template-cleanup.sh` — initially failed in the read-only sandbox due temporary git repo writes, rerun outside sandbox and passed

Not run:

- `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/`

Reason: running `make generate-kodex` would write generated files; this review stayed review-only.

## Indexing Notes

No P0/P1 systemic review findings were indexed as `kk:review-findings` during this report write.

No `SPEC_DEV` or `EXTRA_IMPL` findings were indexed as `kk:arch-decisions` because indexing intentional deviations requires user confirmation.

## Recommended Action Items

| Priority | Finding | Action |
| --- | --- | --- |
| Must | CR-1 | Stage/add the new generated Codex files under `kodex-plugin/skills/design/`. |
| Must | SC-1 | Restore `all` as a review-design alias or remove all remaining `all` references from docs/evals/tasks. |
| Should | CR-2 / SC-2 | Complete the SE-context adaptation of `frameworks.md` and `refinement-criteria.md`. |
| Should | Complexity | Add a Step 3 sub-phase checklist to reduce multi-turn state loss. |
| Consider | Complexity | Simplify CoVe handling to a user-confirmed optional fact-check step. |
| Consider | Evals | Add evals for 3c/3d boundary preservation and 3e artifact surfacing. |
