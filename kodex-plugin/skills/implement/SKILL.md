---
name: implement
description: |
  TRIGGER when: user asks to implement, fix, build, or work on something — whether from a
  docs/wip plan OR a standalone task (bug fix, GitHub issue, one-off change).
  Examples: "work on task 1", "fix this bug", "implement feature X from the issue".
  Provides structured execution with profile detection, dependency handling, review checkpoints.
---
<!-- codex: tool-name mapping applied. See .codex/scripts/session-start.sh -->

# Implementing Work

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection is delegated to [shared-profile-detection.md](shared-profile-detection.md). When the sub-task's target files activate a profile that contributes an `implement/` subdirectory (e.g., `../klaude-plugin/profiles/k8s/implement/`), its `index.md` lists per-task gotchas the skill must consult BEFORE writing. See Step 2.

## Modes

Two modes, determined automatically: **plan mode** when the user references a docs/wip feature or task number; **standalone mode** otherwise (bug fix, GitHub issue, one-off change). When ambiguous, ask.

- **Plan mode:** Read [plan-mode.md](plan-mode.md) for entry, iteration, and completion procedures.
- **Standalone mode:** Read [standalone-mode.md](standalone-mode.md) for entry procedure.

Both modes share the same execution core (Step 2 onward) — profile detection, dependency handling, verification, review.

## Required Outputs

After each execution + review cycle, verify all outputs:

- [ ] Implementation addresses the requirement (plan mode: matches plan)
- [ ] Verification/tests pass
- [ ] Code review completed (via `review-code` — which owns indexing its own `kk:review-findings`)
- [ ] New project conventions indexed as `kk:project-conventions` (skip if none established)
- [ ] (Plan mode only) `tasks.md` updated to `done`

**Indexing ownership:** Review skills (`review-code`, `review-spec`) index their own findings. This skill only indexes `kk:project-conventions` for non-obvious patterns discovered during implementation. Do NOT duplicate review indexing here.

### Review Mode

By default, review checkpoints use standard mode. The user can request **isolated review mode** for the entire session:

- When invoking the skill: "use isolated review" or "isolated mode"
- In `tasks.md` metadata (plan mode only): a `review-mode: isolated` field in the header

When set, all review checkpoints automatically use isolated variants (`kk:review-code:isolated`, `kk:review-spec:isolated`) without per-checkpoint prompting. The user can override at any checkpoint ("use standard review for this one").

## Workflow

**Mandatory order — understand before executing.** The flow below is strictly sequential. Do not read source files to modify, write code, edit files, run tests, or otherwise act on any task until you have loaded full context (design, implementation plan, task list in **plan mode**, or full problem understanding in **standalone**) and completed profile detection and loaded all resolved profile content. The only early contact with the codebase is the task's target filenames — enough to drive profile detection, not enough to pattern-match implementation. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

## The Process

### Step 1: Load Context

Determine mode (see §Modes), then read the appropriate mode file and follow its entry procedure:

- **Plan mode:** Read [plan-mode.md](plan-mode.md) — loads tasks.md, design.md, implementation.md, identifies next task.
- **Standalone mode:** Read [standalone-mode.md](standalone-mode.md) — parses the problem, explores relevant code, forms an approach.

After completing the mode's entry procedure, continue with Step 2.

### Step 2: Execute

**Mandatory order — instructions before action.** Steps 1–3 load instructions; step 4 is the first step that touches subject matter. Do not write code, edit files, or otherwise act until steps 1–3 have been performed in order. If a later step reveals that an instruction was missed, return to step 1.

1. (Plan mode only) Update `tasks.md`: set the task's status to `in-progress`.
2. **Profile-aware per-task gotchas (pre-write).** Run the shared profile-detection procedure against the target files (and any diff-so-far). For each active profile that contributes an `implement/` subdirectory, load `../klaude-plugin/profiles/<name>/implement/index.md` and read the always-load + any matching conditional content. Apply those gotchas to the upcoming edits — they exist to prevent mistakes the post-write reviewer would otherwise catch. If no active profile contributes an `implement/` subdirectory, skip this step.
3. **Dependency-handling (pre-write).** Whenever the task introduces or changes a dependency — new import, version bump, unfamiliar call, **and per the widened trigger also: a Kubernetes API version, a CRD, a Helm chart or chart dependency, or a container image tag/digest** — apply the `dependency-handling` skill BEFORE writing the call. Do not guess signatures, API versions, or configuration; look them up via capy/context7 per that skill's rules. Per-profile lookup cascades live in each profile's `overview.md` (e.g., `../klaude-plugin/profiles/k8s/overview.md` §Looking up Kubernetes dependencies).
4. Make the changes. (Plan mode: follow the plan exactly.)
5. (Plan mode only) Check off subtasks (`- [x]`) in `tasks.md` as you complete them.
6. Run verifications; run `test` skill.

### Step 3: Report and Review

- Show what was implemented
- Show verification output
- **If session-level isolated review is set**: automatically use `kk:review-code:isolated` — this handles both sub-agent and pal codereview internally with independent reviewers. Do NOT run a separate `pal` codereview call, as it is already included in the isolated workflow. The user can say "use standard review for this one" to override.
- **Otherwise**: prompt user for code-review (mention isolated mode as an option); if user responds 'yes':
  - **Standard review** (default): Use `review-code` skill, then run `pal` mcp code-review, consolidate findings
  - **Isolated review** (if user requests): Use `kk:review-code:isolated` — same as above
- Based on user and code-review feedback: apply changes if needed and finalize
- (Plan mode only) Update `tasks.md`: set the task's status to `done`

**After finalizing**, verify all items in the **Required Outputs** section above:

- [ ] Implementation addresses the requirement (plan mode: implementation matches plan)
- [ ] Verification/tests pass, `test` completed
- [ ] Code review completed (via `review-code` — which owns indexing its own `kk:review-findings`)
- [ ] New project conventions indexed as `kk:project-conventions` (skip if none established)
- [ ] (Plan mode only) `tasks.md` updated to `done`

If any item is unchecked, go back and complete it. Do NOT proceed to the next task with incomplete outputs.

### Step 4: Continue (plan mode only)

Follow the iteration procedure in [plan-mode.md](plan-mode.md) — move to next task, repeat Steps 1–3.

### Step 5: Complete (plan mode only)

Follow the completion procedure in [plan-mode.md](plan-mode.md) — final validation, documentation, reflection.

## When to Stop and Ask for Help

**STOP executing immediately when:**

- Hit a blocker (missing dependency, test fails, instruction unclear)
- (Plan mode) Plan has critical gaps preventing starting
- You don't understand a requirement or instruction is ambiguous
- Verification fails repeatedly

**IMPORTANT! Always ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Step 1 when:**

- Partner updates the plan or clarifies the problem
- Fundamental approach needs rethinking

**IMPORTANT! Don't force through blockers** — stop and ask.

## Remember

- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Use skills when applicable (dependency-handling, test, review-code) (Plan mode: also when the plan says to do so)
- Between batches: just report and wait
- Stop when blocked, don't guess
