# Implementation: `skill-md` Profile

> Design: [./design.md](./design.md)

## Profile skeleton {#skeleton}

Create the profile directory at `klaude-plugin/profiles/skill-md/` with:

- `DETECTION.md` — three mandatory headings (`## Path signals`, `## Filename signals`, `## Content signals`) plus `## Design signals`. Filename signals: `SKILL.md` (exact) and the adjacency rule (any file sibling to a `SKILL.md`). Path and content signals: empty (stated explicitly per schema). Design signals with `display_name: Agent Skills` and the token list.
- `overview.md` — profile summary, activation conditions, reference to agentskills.io. "Looking up dependencies" section targets provider skill documentation via context7.

Register the profile:
- Append `skill-md` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` (after existing profiles, alphabetical not required but keep consistent with existing order).
- Append `skill-md` to the Known Profiles list in `klaude-plugin/skills/_shared/profile-detection.md`.

Verify: `bash test/test-plugin-structure.sh` — the profile existence assertion passes; phase assertions don't fire yet (no phase subdirectories).

## Reference content {#references}

Create `klaude-plugin/profiles/skill-md/references/skill-building-guide.md`.

Source material to distill:
- Anthropic's "Complete Guide to Building Skills for Claude" PDF (available at `https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf`)
- Anthropic's skill best practices docs (already indexed in capy as `claude-skill-best-practices`)
- ADR 0004 (workflow ordering failure mode and decision)
- CLAUDE.md §Skill & Command Naming Conventions, §Skill description budget, §Skill workflow ordering, §Skill evaluations
- CONTRIBUTING.md §Plugin Development (skills, shared instructions, commands, agents, hooks, profiles, evaluations, common pitfalls)

Organize by topic, not by source. The reference file should be self-contained — a reader shouldn't need to chase links to understand the advice. Include concrete examples of good vs bad patterns where they clarify the guidance.

Keep the file under 300 lines. If it exceeds that, add a table of contents at the top per the progressive disclosure convention for long reference files.

## Implement phase {#implement}

Create `klaude-plugin/profiles/skill-md/implement/` with four files:

### `index.md`

Always-load section:
- `[skill-structure-gotchas.md](skill-structure-gotchas.md)` — Universal skill-authoring rules (workflow ordering, progressive disclosure, description, resource organization, evals).

Conditional section:
- `[claude-code-gotchas.md](claude-code-gotchas.md)` — **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or sibling directories of the skill being created/modified include `hooks/`, `commands/`, or `agents/` alongside `skills/`.
- `[kk-plugin-gotchas.md](kk-plugin-gotchas.md)` — **Load if:** files are within a `klaude-plugin/` directory, or diff touches files under `_shared/`.

### `skill-structure-gotchas.md`

Universal gotchas — these apply to any agent skill regardless of provider. Content as specified in [design.md §implement phase](./design.md#phase-content):
- Workflow ordering (ADR 0004 distilled to actionable rule + the failure mode explanation)
- Progressive disclosure three-tier model with line budgets
- Description effectiveness with concrete examples of good vs bad descriptions
- Resource organization (scripts/ vs references/ vs assets/) with the execute-vs-read distinction
- "Explain the why" principle — reasoning over rigid MUSTs
- Eval structure expectations

### `claude-code-gotchas.md`

Claude Code provider-specific gotchas:
- `${CLAUDE_PLUGIN_ROOT}` substitution boundary (plugin-load vs Read-time, brace form requirement)
- Glob cwd-scoping limitation
- Hook script contract (JSON stdin, structured JSON output, exit 0)
- Command variant naming (`default.md` / `isolated.md`)

### `kk-plugin-gotchas.md`

kk-plugin-specific gotchas for this project's plugin system:
- Shared instruction symlink pattern and constraints
- Bidirectional index invariant
- Test registration (`EXPECTED_SKILLS`, `EXPECTED_COMMANDS`)
- `make generate-kodex` for Codex parity
- Agent naming convention (role-based, not skill-based)

## Review-code phase {#review-code}

Create `klaude-plugin/profiles/skill-md/review-code/` with four files:

### `index.md`

Always-load section:
- `[skill-quality-checklist.md](skill-quality-checklist.md)` — Universal skill quality checks.

Conditional section:
- `[claude-code-checklist.md](claude-code-checklist.md)` — **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or files are under a Claude Code plugin structure.
- `[kk-plugin-checklist.md](kk-plugin-checklist.md)` — **Load if:** files within `klaude-plugin/` or diff touches `_shared/`.

### `skill-quality-checklist.md`

Universal review checklist — mirrors the gotchas but framed as review questions:
- Is there a mandatory-order directive? Does the actual workflow comply?
- Is SKILL.md under 500 lines? Content properly delegated?
- Description quality (trigger-first, budget, third person, specificity)?
- Resource separation correct?
- Instruction clarity (reasoning vs rigid rules)?
- Eval coverage for non-trivial skills?

### `claude-code-checklist.md`

Claude Code-specific review checks:
- `${CLAUDE_PLUGIN_ROOT}` usage correctness
- Hook script well-formedness
- Command variant naming

### `kk-plugin-checklist.md`

kk-plugin-specific review checks:
- Shared symlink correctness
- Bidirectional index invariant
- Naming conventions (skill names, agent names)
- Test registration and Codex generation

## Verification {#verification}

- `bash test/test-plugin-structure.sh` — all assertions pass including bidirectional invariant for both phase subdirectories
- `make generate-kodex && git diff --exit-code kodex-plugin/` — Codex parity clean
- Manual smoke test: trigger `review-code` on a diff touching a SKILL.md file, verify `skill-md` profile activates and checklists load
- Manual smoke test: trigger `implement` standalone with "create a skill" prompt, verify profile activates via design signals
