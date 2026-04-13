---
name: implementation-process
description: |
  TRIGGER when: user asks to work on, implement, or continue tasks from docs/wip (e.g. "work on task 1", "do the next task", "implement first task for X").
  Executes written implementation plans with review checkpoints. Use when you have a fully-formed implementation plan to execute in a separate session.
---

# Executing Plans

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Required Outputs

Per sub-task cycle (Steps 2–3), verify all outputs are delivered:

- [ ] Implementation matches plan
- [ ] Verification/tests pass
- [ ] Code review completed (via `solid-code-review` — which owns indexing its own `kk:review-findings`)
- [ ] New project conventions indexed as `kk:project-conventions` (skip if none established)
- [ ] `tasks.md` updated to `done`

**Indexing ownership:** Review skills (`solid-code-review`, `implementation-review`) index their own findings. This skill only indexes `kk:project-conventions` for non-obvious patterns discovered during implementation. Do NOT duplicate review indexing here.

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

**Core principle:** Batch execution with checkpoints for architect review.

### Review Mode

By default, review checkpoints use standard mode. The user can request **isolated review mode** for the entire session:

- When invoking the skill: "use isolated review" or "isolated mode"
- In `tasks.md` metadata: a `review-mode: isolated` field in the header

When set, all review checkpoints automatically use isolated variants (`kk:solid-code-review:isolated`, `kk:implementation-review:isolated`) without per-checkpoint prompting. The user can override at any checkpoint ("use standard review for this one").

## The Process

### Step 1: Load and Review Plan

1. Read the feature's `tasks.md` file to get the task list and current progress
2. Read the linked `design.md` and `implementation.md` for full context
3. Identify the next pending task (one whose dependencies are all done)
4. **Capy search:** Search `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, and `kk:review-findings` for context relevant to the identified task
5. Review critically — identify any questions or concerns about the plan
6. If concerns: Raise them with your human partner before starting

### Step 2: Execute Sub-Task

1. Update `tasks.md`: set the task's status to `in-progress`
2. Follow the plan exactly
3. Check off subtasks (`- [x]`) in `tasks.md` as you complete them
4. Run verifications as specified; use `testing-process` skill

### Step 3: Report

- Show what was implemented
- Show verification output
- **If session-level isolated review is set**: automatically use `kk:solid-code-review:isolated` — this handles both sub-agent and pal codereview internally with independent reviewers. Do NOT run a separate `pal` codereview call, as it is already included in the isolated workflow. The user can say "use standard review for this one" to override.
- **Otherwise**: prompt user for code-review (mention isolated mode as an option); if user responds 'yes':
  - **Standard review** (default): Use `kk:solid-code-review` skill, then run `pal` mcp code-review, consolidate findings
  - **Isolated review** (if user requests): Use `kk:solid-code-review:isolated` — same as above
- Based on user and code-review feedback: apply changes if needed and finalize the sub-task
- When completed, update `tasks.md`: set the task's status to `done`

**After finalizing the sub-task**, verify all items in the **Required Outputs** section above before moving to Step 4:

- [ ] Implementation matches plan
- [ ] Verification/tests pass
- [ ] Code review completed (review skill owns its own `kk:review-findings` indexing)
- [ ] New project conventions indexed as `kk:project-conventions` (or noted "No new conventions to index")
- [ ] `tasks.md` updated to `done`

If any item is unchecked, go back and complete it. Do NOT proceed to the next task with incomplete outputs.

### Step 4: Continue

- Move to the next pending task in `tasks.md`
- Repeat until all tasks are completed

### Step 5: Complete Development

After all tasks complete and verified:

- Use `testing-process` skill to verify and validate functionality
- Use `documentation-process` skill to create or update any relevant docs
- **Reflect:** briefly note where the implementation diverged from the plan, what turned out harder or simpler than expected, and any surprises that future work in this area should know about. Keep it short — a paragraph, not an essay. Index non-obvious learnings as `kk:project-conventions` or `kk:arch-decisions` if they weren't already captured during per-task cycles.
- Update the feature status in `tasks.md` header to `done`

## When to Stop and Ask for Help

**STOP executing immediately when:**

- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**IMPORTANT! Always ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**

- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**IMPORTANT! Don't force through blockers** - stop and ask.

## Remember

- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Use skills when the plan says to do so
- Between batches: just report and wait
- Stop when blocked, don't guess
