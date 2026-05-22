# Tasks: diff-skill

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-05-22
> Not Doing: cross-rename syntax, mechanical extraction pass, confidence levels, behavioral evals, CI integration, multi-skill invocation, auto-fix suggestions, extension points

## Task 1: Skill directory and SKILL.md
- **Status:** done
- **Depends on:** —
- **Size:** S
- **Can run in parallel with:** —
- **Docs:** [implementation.md#skillmd-authoring](./implementation.md#skillmd-authoring)

### Subtasks
- [x] 1.1 Create directory `klaude-plugin/skills/diff-skill/`
- [x] 1.2 Create symlink `shared-capy-knowledge-protocol.md → ../_shared/capy-knowledge-protocol.md` — verify with `readlink` and `cat` through the symlink
- [x] 1.3 Author `SKILL.md` with YAML frontmatter (`name: diff-skill`, multi-line `description` under 1,024 chars), overview (two judgment axes), conventions (capy protocol reference), required outputs checklist, invocation section, and workflow with mandatory-order directive pointing to `diff-process.md`. Model after `merge-docs/SKILL.md`
- [x] 1.4 Verify all internal `[text](path)` links in SKILL.md resolve to files in the skill directory

## Task 2: Author diff-process.md
- **Status:** done
- **Depends on:** Task 1
- **Size:** M
- **Can run in parallel with:** —
- **Docs:** [implementation.md#diff-processmd-authoring](./implementation.md#diff-processmd-authoring)

### Subtasks
- [x] 2.1 Write progress checklist at top (7 phases) and Phase 1 "Parse invocation" — skill-name extraction, SKILL.md path resolution (convenience shortcut + user fallback with repo-relative normalization), report slug extraction (frontmatter `name` or directory basename), ref defaults (`HEAD` → working tree)
- [x] 2.2 Write Phase 2 "Validate" — `git rev-parse` for refs, `git cat-file -e` for SKILL.md existence at both refs, clear error messages
- [x] 2.3 Write Phase 3 "Build reachable file sets" — link-walk algorithm (frontier/visited), markdown link extraction with fragment stripping (`path.md#anchor` → `path.md`) and best-effort fenced-code-block exclusion, relative path resolution, symlink detection via `git ls-tree` mode `120000` + `git cat-file -p` for target resolution, `missing_links` tracking for broken references, ~100KB combined content-size warning
- [x] 2.4 Write Phase 4 "Judgment" — three-axis framing (degradation + complexity regression + pre-existing complexity advisory), missing_links fed as input, relocation handling, explicit asymmetric instructions for the LLM
- [x] 2.5 Write Phase 5 "Write report" — directory creation, filename convention, report template
- [x] 2.6 Write Phase 6 "Present inline summary" — under 10 lines, verdict + counts + report path
- [x] 2.7 Write Phase 7 "Index to capy" — conditional indexing under `kk:review-findings`, skip on clean results

## Task 3: Author eval scenarios
- **Status:** done
- **Depends on:** Task 1
- **Size:** S
- **Can run in parallel with:** Task 2
- **Docs:** [design.md#evaluation-scenarios](./design.md#evaluation-scenarios)

### Subtasks
- [x] 3.1 Create `klaude-plugin/skills/diff-skill/evals/known-degradation/` with `eval.json` and `test-files/` — a minimal SKILL.md + process file where a `MUST` is weakened to `SHOULD`, a required-output bullet is removed, and a link is broken. Assertions: all three flagged as degradations
- [x] 3.2 Create `klaude-plugin/skills/diff-skill/evals/clean-refactor/` with `eval.json` and `test-files/` — a restructured skill where 2 sections are extracted from SKILL.md into a new process file and links are updated accordingly; no substance is lost. Assertions: no degradations reported, pre-existing complexity advisory may appear but no complexity regressions
- [x] 3.3 Each `eval.json` follows the schema in `CLAUDE.md` §Skill evaluations — `id`, `name`, `description`, `skills`, `prompt`, `trap`, `files`, `assertions` with `<eval-id>.<n>` numbering

## Task 4: Wire into plugin manifest, docs, and tests
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3
- **Size:** S
- **Can run in parallel with:** —
- **Docs:** [implementation.md#files-to-create](./implementation.md#files-to-create)

### Subtasks
- [ ] 4.1 Add `diff-skill` to `EXPECTED_SKILLS` array in `test/test-plugin-structure.sh` and update the skill count in the log message to match the new array length
- [ ] 4.2 Update `klaude-plugin/README.md` — change "10 workflow skills" bullet to reflect the new count
- [ ] 4.3 Add `diff-skill` row to the Skill Reference table in `docs/user-guide/skills.md` — one-sentence description matching the tone of surrounding rows. Update the "ships N workflow skills" count in the opening line
- [ ] 4.4 Run `make generate-kodex` to regenerate `kodex-plugin/` and `.codex/agents/`, then verify no unexpected diffs with `git status`
- [ ] 4.5 Run `bash test/test-plugin-structure.sh` and confirm all assertions pass (including kodex-plugin skill count parity at line ~388)

## Task 5: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4
- **Size:** S
- **Can run in parallel with:** —

### Subtasks
- [ ] 5.1 Run `/kk:test` skill to verify the full test suite passes
- [ ] 5.2 Run `/kk:document` skill to update any relevant docs
- [ ] 5.3 Run `/kk:review-code` skill with markdown/shell input to review the new skill files
- [ ] 5.4 Run `/kk:review-spec` skill to verify SKILL.md + diff-process.md match design.md and implementation.md

## Dependency Graph

```
Task 1 → Task 2 ──→ Task 4 → Task 5
  │                    ↑
  └──→ Task 3 ────────┘
```
