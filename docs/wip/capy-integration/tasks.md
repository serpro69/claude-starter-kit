# Tasks: Capy Knowledge Base Integration

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-01

## Task 1: Create the shared protocol file
- **Status:** done
- **Depends on:** —
- **Docs:** [implementation.md#protocol](./implementation.md#protocol)

### Subtasks
- [x] 1.1 Create `klaude-plugin/skills/_shared/capy-knowledge-protocol.md` with: conditional preamble (skip if capy unavailable), source label taxonomy table (6 `kk:*` labels), search conventions (query specificity, source filtering, limit defaults, cold-start fallback), index conventions (non-obvious only, concise, one concept per call)
- [x] 1.2 Verify the file is ~30-50 lines — lean and direct, no fluff

## Task 2: Integrate capy into analysis-process
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#analysis-idea](./implementation.md#analysis-idea), [implementation.md#analysis-existing](./implementation.md#analysis-existing)

### Subtasks
- [x] 2.1 Add protocol file reference to `klaude-plugin/skills/analysis-process/idea-process.md`
- [x] 2.2 Insert search step before Step 3 in `idea-process.md` — search `kk:arch-decisions` and `kk:project-conventions` for prior design context
- [x] 2.3 Insert index step after Step 5 in `idea-process.md` — index key architecture decisions as `kk:arch-decisions`
- [x] 2.4 Add protocol file reference to `klaude-plugin/skills/analysis-process/existing-task-process.md`
- [x] 2.5 Insert search step in `existing-task-process.md` during plan review — search `kk:arch-decisions` and `kk:project-conventions`

## Task 3: Integrate capy into implementation-process
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#implementation](./implementation.md#implementation)

### Subtasks
- [x] 3.1 Add protocol file reference to `klaude-plugin/skills/implementation-process/SKILL.md`
- [x] 3.2 Extend Step 1 (Load and Review Plan) — add search of `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, `kk:review-findings` for task-relevant context
- [x] 3.3 Extend Step 3 (Report) — add conditional index of non-obvious patterns/conventions as `kk:project-conventions`

## Task 4: Integrate capy into solid-code-review
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#code-review](./implementation.md#code-review)

### Subtasks
- [x] 4.1 Add protocol file reference to `klaude-plugin/skills/solid-code-review/SKILL.md`
- [x] 4.2 Extend Step 1 (Preflight context) — add search of `kk:review-findings` for prior findings in the same area, and `kk:lang-idioms` for language best practices
- [x] 4.3 Add `capy_fetch_and_index` fallback in Step 1 — if `kk:lang-idioms` returns no results for detected language, optionally fetch a well-known idioms resource and label it `kk:lang-idioms`
- [x] 4.4 Insert index step after Step 7 (Self-check) — index P0/P1 recurring pattern findings as `kk:review-findings`

## Task 5: Integrate capy into testing-process
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#testing](./implementation.md#testing)

### Subtasks
- [x] 5.1 Add protocol file reference to `klaude-plugin/skills/testing-process/SKILL.md`
- [x] 5.2 Insert search step before test guidelines — search `kk:test-patterns` for project-specific approaches and known edge cases
- [x] 5.3 Insert index step at end — conditionally index novel testing approaches or tricky edge cases as `kk:test-patterns`

## Task 6: Integrate capy into development-guidelines
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#dev-guidelines](./implementation.md#dev-guidelines)

### Subtasks
- [x] 6.1 Add protocol file reference to `klaude-plugin/skills/development-guidelines/SKILL.md`
- [x] 6.2 Insert search step before context7 consultation — search `kk:lang-idioms` and `kk:project-conventions` for previously indexed dependency knowledge
- [x] 6.3 Insert index step after resolving dependency question — index valuable best-practice nuggets as `kk:lang-idioms`

## Task 7: Integrate capy into implementation-review
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#impl-review](./implementation.md#impl-review)

### Subtasks
- [x] 7.1 Add protocol file reference to `klaude-plugin/skills/implementation-review/SKILL.md`
- [x] 7.2 Extend Phase 1 (Load feature documents) — add search of `kk:arch-decisions` for intentional deviation rationale, and `kk:review-findings` for known patterns
- [x] 7.3 Insert index step after presenting findings — index user-confirmed intentional deviations (`SPEC_DEV`, `EXTRA_IMPL`) as `kk:arch-decisions`

## Task 8: Integrate capy into documentation-process
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#docs](./implementation.md#docs)

### Subtasks
- [x] 8.1 Add protocol file reference to `klaude-plugin/skills/documentation-process/SKILL.md`
- [x] 8.2 Insert search step before writing docs — search `kk:arch-decisions` and `kk:project-conventions` for decisions that should be reflected in documentation

## Task 9: Integrate capy into merge-docs
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#merge](./implementation.md#merge)

### Subtasks
- [ ] 9.1 Add protocol file reference to `klaude-plugin/skills/merge-docs/SKILL.md` (or `merge-process.md` if that's the workflow file)
- [ ] 9.2 Insert search step before merging — search `kk:arch-decisions` for prior decisions relevant to competing approaches
- [ ] 9.3 Insert index step after merge — conditionally index architectural conflict resolutions as `kk:arch-decisions`

## Task 10: Integrate capy into cove
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#cove](./implementation.md#cove)

### Subtasks
- [ ] 10.1 Add protocol file reference to `klaude-plugin/skills/cove/cove-process.md`
- [ ] 10.2 Insert search step during Step 3 (Independent Verification) in `cove-process.md` — broad search on `kk:` for project-specific facts
- [ ] 10.3 Add protocol file reference to `klaude-plugin/skills/cove/cove-isolated.md`
- [ ] 10.4 Insert search step during Step 3 in `cove-isolated.md` — same broad search on `kk:`

## Task 11: Bootstrap integration
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#bootstrap](./implementation.md#bootstrap)

### Subtasks
- [ ] 11.1 Modify `bootstrap.sh` — add capy setup step after plugin installation: check `SKIP_CAPY` env var / `--no-capy` flag for opt-out, check `command -v capy` for binary availability, run `capy setup` if found, print warning to stderr if not found
- [ ] 11.2 Test all three paths: capy present (runs setup), capy absent (prints warning), opt-out flag (skips silently)

## Task 12: README updates
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#readme](./implementation.md#readme)

### Subtasks
- [ ] 12.1 Add capy row to the MCP Servers table in `README.md`
- [ ] 12.2 Add "Knowledge Base" section explaining what capy provides, how skills use it, and installation instructions

## Task 13: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12

### Subtasks
- [ ] 13.1 Run `testing-process` skill — verify all existing tests still pass, check relative paths in skill files
- [ ] 13.2 Run `documentation-process` skill — update any relevant docs
- [ ] 13.3 Run `solid-code-review` skill to review all changes
- [ ] 13.4 Run `implementation-review` skill to verify implementation matches design and implementation docs
