# Tasks v2: Isolated Review Agents

> Design: [./design-v2.md](./design-v2.md)
> Implementation: [./implementation-v2.md](./implementation-v2.md)
> Previous tasks: [./tasks.md](./tasks.md) (v1 — all tasks done except Task 8)
> Status: in-progress
> Created: 2026-04-03
>
> **Context:** v1 Tasks 1-7 are complete. This task list covers only the delta work from the v2 design review. Agent definitions (v1 Tasks 2-3) are unaffected and not listed here.

## Task 1: Delete shared reconciliation protocol
- **Status:** done
- **Depends on:** —
- **Docs:** [implementation-v2.md#task-1-delete-shared-reconciliation-protocol](./implementation-v2.md#task-1-delete-shared-reconciliation-protocol)

### Subtasks
- [x] 1.1 Search the repo for references to `review-reconciliation-protocol` to confirm only the two `review-isolated.md` files reference it (they'll be rewritten in Tasks 2-3)
- [x] 1.2 Delete `klaude-plugin/skills/_shared/review-reconciliation-protocol.md`

## Task 2: Rework isolated code review workflow
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation-v2.md#task-2-rework-isolated-code-review-workflow](./implementation-v2.md#task-2-rework-isolated-code-review-workflow)

### Subtasks
- [x] 2.1 Update Step 1 in `klaude-plugin/skills/solid-code-review/review-isolated.md` to add curated rejected approaches preparation
- [x] 2.2 Update Step 2 to add error handling: pal failure (proceed with code-reviewer only), code-reviewer failure (proceed with pal only), both fail (abort with fallback suggestion), malformed output (best-effort parse then failure)
- [x] 2.3 Replace Step 3 ("Reconcile") with "Annotate" — remove all disposition logic (Confirmed, Disputed, etc.), replace with: duplicate merging with "corroborated" tag, author context annotations, author-sourced findings, optional pal follow-up
- [x] 2.4 Replace Step 4 ("Report") with simplified presentation organized by agreement level: corroborated → single-reviewer → author-sourced. Remove reconciliation summary table. Use report template from design-v2.md
- [x] 2.5 Remove all references to the shared reconciliation protocol — annotation logic is now inline
- [x] 2.6 Remove pal-to-P0-P3 format mapping — pal output stays in native format

## Task 3: Rework isolated spec conformance workflow
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation-v2.md#task-3-rework-isolated-spec-conformance-workflow](./implementation-v2.md#task-3-rework-isolated-spec-conformance-workflow)

### Subtasks
- [x] 3.1 Update Step 2 in `klaude-plugin/skills/implementation-review/review-isolated.md` to add error handling: sub-agent timeout/failure (abort with fallback suggestion), malformed output (best-effort parse then failure)
- [x] 3.2 Replace Step 3 ("Reconcile") with "Annotate" — remove disposition logic and trust level table, replace with type-specific annotation guidance: low-relevance types (MISSING_IMPL, DOC_INCON, OUTDATED_DOC, AMBIGUOUS) get brief annotations; high-relevance types (SPEC_DEV, EXTRA_IMPL) get detailed annotations with spec update suggestions
- [x] 3.3 Replace Step 4 ("Report") with simplified presentation organized by finding type. Remove reconciliation summary table. Use spec review report template from design-v2.md
- [x] 3.4 Remove all references to the shared reconciliation protocol — annotation logic is now inline
- [x] 3.5 Add author-sourced findings support, tagged distinctly

## Task 4: Update SKILL.md descriptions
- **Status:** done
- **Depends on:** Task 2, Task 3
- **Docs:** [implementation-v2.md#task-4-update-skillmd-descriptions](./implementation-v2.md#task-4-update-skillmd-descriptions)

### Subtasks
- [x] 4.1 Update isolated mode section in `klaude-plugin/skills/solid-code-review/SKILL.md` — change "reconciles findings" wording to "annotates with context", mention native pal format, mention graceful degradation on failure
- [x] 4.2 Update isolated mode section in `klaude-plugin/skills/implementation-review/SKILL.md` — change to annotation model wording, mention type-specific annotation guidance, mention error handling

## Task 5: Add session-level isolated review flag to implementation-process
- **Status:** done
- **Depends on:** Task 4
- **Docs:** [implementation-v2.md#task-5-add-session-level-isolated-review-flag-to-implementation-process](./implementation-v2.md#task-5-add-session-level-isolated-review-flag-to-implementation-process)

### Subtasks
- [x] 5.1 Add a note in the preamble/Step 0 of `klaude-plugin/skills/implementation-process/SKILL.md` that the user can request isolated review mode for the entire session (via invocation flag or `review-mode: isolated` in tasks.md metadata)
- [x] 5.2 Update Step 3 to check the session-level flag: if set, automatically use isolated variants without per-checkpoint prompting; if not set, existing behavior unchanged
- [x] 5.3 Add per-checkpoint override note: user can say "use standard review for this one" to override the session flag

## Task 6: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5

### Subtasks
- [ ] 6.1 Verify `review-reconciliation-protocol.md` is deleted and no dangling references remain (search for `reconciliation-protocol` across repo)
- [ ] 6.2 Verify neither `review-isolated.md` file contains disposition categories (Confirmed, Disputed — Intentional, Disputed — False Positive) — search for these strings
- [ ] 6.3 Verify error handling is present in both `review-isolated.md` files
- [ ] 6.4 Run `testing-process` skill to verify all components
- [ ] 6.5 Run `documentation-process` skill to update any relevant docs
- [ ] 6.6 Run `solid-code-review` skill to review the changed files
- [ ] 6.7 Run `implementation-review` skill to verify implementation matches design-v2 and implementation-v2 docs
