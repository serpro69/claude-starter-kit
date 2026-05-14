# Tasks: `skill-md` Profile

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-05-14

## Task 1: Profile skeleton and registration
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#skeleton](./implementation.md#skeleton)

### Subtasks
- [ ] 1.1 Create `klaude-plugin/profiles/skill-md/DETECTION.md` — three mandatory headings (Path signals empty, Filename signals with `SKILL.md` exact + adjacency rule, Content signals empty) plus `## Design signals` with `display_name: Agent Skills` and token list
- [ ] 1.2 Create `klaude-plugin/profiles/skill-md/overview.md` — profile summary, activation conditions, agentskills.io reference, dependency-lookup targets
- [ ] 1.3 Append `skill-md` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh`
- [ ] 1.4 Append `skill-md` to the Known Profiles list in `klaude-plugin/skills/_shared/profile-detection.md`
- [ ] 1.5 Verify: `bash test/test-plugin-structure.sh` passes

## Task 2: Reference content
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#references](./implementation.md#references)

### Subtasks
- [ ] 2.1 Fetch and review the Anthropic skill-building guide PDF and the indexed `claude-skill-best-practices` capy content
- [ ] 2.2 Create `klaude-plugin/profiles/skill-md/references/skill-building-guide.md` — distill source material by topic (progressive disclosure, triggering, descriptions, scripts, evals, anti-patterns). Under 300 lines; add TOC if approaching limit.
- [ ] 2.3 Verify: file is self-contained, examples are concrete, no dead links

## Task 3: Implement phase
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#implement](./implementation.md#implement)

### Subtasks
- [ ] 3.1 Create `klaude-plugin/profiles/skill-md/implement/index.md` — always-load (`skill-structure-gotchas.md`) and conditional entries (`claude-code-gotchas.md`, `kk-plugin-gotchas.md`) with explicit `Load if:` clauses
- [ ] 3.2 Create `klaude-plugin/profiles/skill-md/implement/skill-structure-gotchas.md` — universal rules (workflow ordering, progressive disclosure, description effectiveness, resource organization, explain-the-why, eval structure)
- [ ] 3.3 Create `klaude-plugin/profiles/skill-md/implement/claude-code-gotchas.md` — provider-specific gotchas (`${CLAUDE_PLUGIN_ROOT}` substitution, Glob cwd-scoping, hooks contract, command variants)
- [ ] 3.4 Create `klaude-plugin/profiles/skill-md/implement/kk-plugin-gotchas.md` — kk-plugin gotchas (shared symlinks, bidirectional invariant, test registration, `make generate-kodex`, agent naming)
- [ ] 3.5 Verify: `bash test/test-plugin-structure.sh` passes (bidirectional invariant for implement/)

## Task 4: Review-code phase
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#review-code](./implementation.md#review-code)

### Subtasks
- [ ] 4.1 Create `klaude-plugin/profiles/skill-md/review-code/index.md` — always-load (`skill-quality-checklist.md`) and conditional entries (`claude-code-checklist.md`, `kk-plugin-checklist.md`) with explicit `Load if:` clauses
- [ ] 4.2 Create `klaude-plugin/profiles/skill-md/review-code/skill-quality-checklist.md` — universal checks (workflow ordering compliance, progressive disclosure, description quality, resource separation, instruction clarity, eval coverage)
- [ ] 4.3 Create `klaude-plugin/profiles/skill-md/review-code/claude-code-checklist.md` — Claude Code checks (`${CLAUDE_PLUGIN_ROOT}` correctness, hook well-formedness, command naming)
- [ ] 4.4 Create `klaude-plugin/profiles/skill-md/review-code/kk-plugin-checklist.md` — kk-plugin checks (shared symlinks, bidirectional invariant, naming conventions, test registration, Codex generation)
- [ ] 4.5 Verify: `bash test/test-plugin-structure.sh` passes (bidirectional invariant for review-code/)

## Task 5: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4

### Subtasks
- [ ] 5.1 Run `test` skill — full test suite (`for test in test/test-*.sh; do $test; done`)
- [ ] 5.2 Run `make generate-kodex && git diff --exit-code kodex-plugin/` — Codex parity clean
- [ ] 5.3 Run `review-code` skill to review the implementation
- [ ] 5.4 Run `review-spec` skill to verify implementation matches design and implementation docs
- [ ] 5.5 Manual smoke test: verify `skill-md` profile activates when `review-code` runs on a diff touching a SKILL.md
