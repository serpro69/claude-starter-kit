# Tasks: diff-skill

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-18

## Task 1: Skill directory scaffold
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#task-1--skill-directory-scaffold](./implementation.md#task-1--skill-directory-scaffold)

### Subtasks
- [ ] 1.1 Create directory `klaude-plugin/skills/diff-skill/`
- [ ] 1.2 Create symlink `klaude-plugin/skills/diff-skill/shared-capy-knowledge-protocol.md` → `../_shared/capy-knowledge-protocol.md`
- [ ] 1.3 Verify the symlink resolves: `cat` through the symlink returns the real content from `_shared/`

## Task 2: Author SKILL.md
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#task-2--author-skillmd](./implementation.md#task-2--author-skillmd), [design.md#goal](./design.md#goal), [design.md#invocation](./design.md#invocation)

### Subtasks
- [ ] 2.1 Write YAML frontmatter (`name: diff-skill`, multi-line `description`) modeled on `merge-docs/SKILL.md`
- [ ] 2.2 Write Overview section with asymmetric framing (lifted from `design.md#goal`)
- [ ] 2.3 Add Conventions section referencing `shared-capy-knowledge-protocol.md`
- [ ] 2.4 Add Required Outputs checklist (report file, inline summary, capy indexing)
- [ ] 2.5 Add Invocation table (copy from `design.md#invocation`) and one-paragraph rename-handling note
- [ ] 2.6 Add Workflow phases summary (eight phases, one line each) with a pointer to `diff-process.md`

## Task 3: Author diff-process.md
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md#task-3--author-diff-processmd](./implementation.md#task-3--author-diff-processmd), [design.md#judgment-pipeline](./design.md#judgment-pipeline), [design.md#scope-of-comparison](./design.md#scope-of-comparison), [design.md#report](./design.md#report)

### Subtasks
- [ ] 3.1 Write Phase 1 "Parse invocation" — argument extraction, rename syntax, defaults
- [ ] 3.2 Write Phase 2 "Validate" — ref resolution via `git rev-parse`, SKILL.md existence via `git show`, exact error messages from `design.md#validation-at-invocation`
- [ ] 3.3 Write Phase 3 "Traverse" — link-extraction algorithm, path resolution, symlink deref, 50-file / depth-20 safety rails, edge cases (code fences, HTML anchors, multi-line links)
- [ ] 3.4 Write Phase 4 "Pass 1 — structural extraction" — enumerate categories of extracted elements, produce candidate findings with category labels
- [ ] 3.5 Write Phase 5 "Pass 2 — LLM judgment" — asymmetric framing prompt, reclassification rules, confidence tagging
- [ ] 3.6 Write Phase 6 "Write report" — directory creation, filename convention, full report template from `design.md#report`
- [ ] 3.7 Write Phase 7 "Present inline summary" — exact ≤10-line format with `Verdict:` as first line
- [ ] 3.8 Write Phase 8 "Index to capy" — skip on `no-degradation`, source label `kk:skill-diff-findings`

## Task 4: Wire skill into manifest and tests
- **Status:** pending
- **Depends on:** Task 2, Task 3
- **Docs:** [implementation.md#task-4--wire-the-skill-into-the-plugin-manifest-and-tests](./implementation.md#task-4--wire-the-skill-into-the-plugin-manifest-and-tests)

### Subtasks
- [ ] 4.1 Add `diff-skill` to `EXPECTED_SKILLS` array in `test/test-plugin-structure.sh`
- [ ] 4.2 Update `log_test "All 10 skill directories exist"` message to `11` in the same file
- [ ] 4.3 Add `diff-skill` row to the Skills table in `klaude-plugin/README.md`
- [ ] 4.4 Mention `diff-skill` in the "Utilities" paragraph of `klaude-plugin/README.md`
- [ ] 4.5 Run `bash test/test-plugin-structure.sh` — all assertions pass

## Task 5: End-to-end smoke test
- **Status:** pending
- **Depends on:** Task 4
- **Docs:** [implementation.md#task-5--smoke-test-the-skill-end-to-end](./implementation.md#task-5--smoke-test-the-skill-end-to-end)

### Subtasks
- [ ] 5.1 On a local throwaway branch, deliberately degrade `merge-docs/SKILL.md` with three regressions: `MUST`→`SHOULD`, drop a required-output bullet, remove one link
- [ ] 5.2 From a fresh Claude Code session, invoke `/kk:diff-skill merge-docs master HEAD` and confirm verdict = `degraded` with all three regressions flagged
- [ ] 5.3 Invoke `/kk:diff-skill merge-docs master master` and confirm verdict = `no-degradation`, no capy indexing triggered
- [ ] 5.4 Confirm the report file exists at `docs/reviews/skill-diff/merge-docs-<short-sha-a>-<short-sha-b>.md` and matches the template from `design.md#report`
- [ ] 5.5 Discard the throwaway branch

## Task 6: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5

### Subtasks
- [ ] 6.1 Run `test` skill to verify the full test suite passes
- [ ] 6.2 Run `document` skill to update any docs referencing the skill list or workflow
- [ ] 6.3 Run `review-code` skill (language: markdown/shell) on the new files
- [ ] 6.4 Run `review-spec` skill to verify `SKILL.md` + `diff-process.md` match `design.md` and `implementation.md`
