# Design: `skill-md` Profile

> GitHub issue: [#24](https://github.com/serpro69/claude-toolbox/issues/24)
> Status: approved

## Problem

Creating good agent skills is hard. The principles that make skills reliable — workflow ordering, progressive disclosure, description effectiveness, resource separation — are documented across ADRs, CLAUDE.md, Anthropic's skill-building guide, and hard-won session experience. There is no mechanism for the existing workflow pipeline (`design` → `implement` → `review-code` → `test` → `document`) to apply this domain knowledge automatically when a user is authoring skills.

## Decision

Create a `skill-md` profile rather than a standalone skill. Agent skills are a [provider-agnostic concept](https://agentskills.io/home); each provider (Claude Code, Codex, etc.) adds its own conventions on top. The profile encodes universal skill-authoring knowledge in always-load checklists and provider-specific knowledge in conditional checklists.

No new skill is needed. The existing pipeline handles the workflow — `implement` in standalone mode handles ad-hoc "create a skill" requests, `review-code` reviews skill quality, etc. The profile injects domain expertise at each phase.

### Alternatives considered

- **Standalone skill-creator skill.** Rejected: duplicates the existing pipeline's capabilities. `implement` already supports ad-hoc tasks; `review-code` already reviews; `design` already interviews. A separate skill would need to replicate or delegate to all of these.
- **Port of Anthropic's official skill-creator.** Rejected: heavily coupled to their Python eval tooling (HTML viewer, benchmark aggregation, blind A/B comparison). The eval infrastructure doesn't align with this project's eval conventions (eval.json with traps/assertions, test-files/ directories). Users who want Anthropic's eval loop can install it independently.
- **Bundled reference files in the skill-creator skill.** Rejected in favor of profiles: a profile integrates with the entire pipeline automatically, while a skill's reference files are only accessible when that skill is invoked.

## Architecture

### Three-tier knowledge model

1. **Universal (always-load)** — skill-authoring principles that apply across all providers: progressive disclosure, workflow ordering, description effectiveness, resource organization, evaluation design.
2. **Provider-specific (conditional)** — Claude Code's `${CLAUDE_PLUGIN_ROOT}` substitution boundary, hooks integration, command variants. Codex TOML format and rules files. Loaded when provider-specific signals appear in the diff.
3. **kk-plugin-specific (conditional)** — shared instruction symlinks, bidirectional index invariant, profile conventions, `make generate-kodex`, test updates. Loaded when working within a `klaude-plugin/` directory structure.

### Detection

**Filename signals (authoritative):**
- `SKILL.md` (exact) — the canonical skill entry point.
- Any file in the same directory as a `SKILL.md` — adjacency rule. If the diff touches `skills/review-code/plan-mode.md` and `skills/review-code/SKILL.md` exists as a sibling, the profile activates. The binding constraint is sibling `SKILL.md` in the same directory, following the same adjacency pattern as the Helm `values*` + `Chart.yaml` rule in the k8s profile.

**Content signals:** None.

**Path signals:** None.

**Design signals:**
- `display_name`: Agent Skills
- `tokens`: skill, SKILL.md, agent skill, slash command, skill description, skill trigger

**Multi-profile behavior:** Additive. A Go skill activates both `go` and `skill-md`.

### Phases

**Initial scope (lean start):**
- `implement/` — gotchas for scaffolding skills correctly
- `review-code/` — quality checklists for skill files

**Deferred (future iterations):**
- `design/` — skill design questions feeding the question pool
- `test/` — eval creation guidance using this project's eval.json format
- `document/` — skill documentation rubric
- `review-spec/` — spec conformance for skills

### Reference content

A `references/skill-building-guide.md` at the profile root, distilled from the Anthropic PDF guide and accumulated project learnings. Organized by topic:
- Three-tier progressive disclosure model (with examples)
- How skill triggering works (metadata pre-loaded, description as primary selection)
- Writing effective descriptions (third person, trigger-first, budget awareness)
- Bundling executable scripts (execute vs read, token savings)
- Evaluation-driven development (evals before extensive docs, baselines, iteration)
- The "develop with Claude" pattern (Claude A writes, Claude B tests)
- Anti-patterns (monolithic skills, vague instructions, rigid MUSTs without reasoning)

## Phase content

### `implement/` phase

**Always load:**
- `skill-structure-gotchas.md` — universal rules:
  - Workflow ordering (ADR 0004): instructions load before subject-matter action. Mandatory-order directive at top of Workflow section, named by intent not step numbers.
  - Progressive disclosure: metadata ~100 words, SKILL.md body <500 lines, bundled resources unlimited on-demand.
  - Description effectiveness: trigger keywords first, 1,536 char cap, third person, be "pushy."
  - Resource organization: scripts/ (execute, don't read), references/ (on-demand context), assets/ (static). Descriptive filenames.
  - Explain the why over rigid MUSTs. Keep instructions lean — cut unproductive steps.
  - Eval structure: one directory per eval, real filesystem fixtures, trap + regression evals.

**Conditional:**
- `claude-code-gotchas.md` — **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or sibling directories include `hooks/`, `commands/`, `agents/` alongside `skills/`:
  - `${CLAUDE_PLUGIN_ROOT}` substitution: plugin-load time for SKILL.md/agents, NOT by Read tool. Runtime-read files must not forward the literal token.
  - Brace form required. Glob is cwd-scoped (won't work on plugin-root paths).
  - Hook scripts: JSON stdin, structured JSON output, exit 0.
  - Command variants: `default.md` / `isolated.md`.

- `kk-plugin-gotchas.md` — **Load if:** files within `klaude-plugin/` or diff touches `_shared/`:
  - Shared instruction symlinks: `../_shared/<name>.md` → `shared-<name>.md`.
  - Bidirectional index invariant (every link resolves, every .md referenced).
  - `EXPECTED_SKILLS` in test, `make generate-kodex` for Codex parity.
  - Agent names describe roles, not invoking skills.

### `review-code/` phase

**Always load:**
- `skill-quality-checklist.md` — universal checks:
  - Mandatory-order directive present and workflow matches (no early content-read steps).
  - SKILL.md under 500 lines; longer content delegated to references with clear pointers.
  - Description: trigger-first, under 1,536 chars, third person, specific enough for selection from 100+ skills.
  - Resource separation: scripts executed not read, references on-demand, descriptive filenames.
  - Instruction clarity: reasoning over rigid MUSTs, conditional workflows in separate files.
  - Eval coverage for skills with non-trivial decision logic.

**Conditional:**
- `claude-code-checklist.md` — **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or Claude Code plugin structure:
  - Correct `${CLAUDE_PLUGIN_ROOT}` usage (brace form, no forwarding from runtime-read files).
  - Hook script well-formedness.
  - Command variant naming (no stuttering).

- `kk-plugin-checklist.md` — **Load if:** files within `klaude-plugin/` or diff touches `_shared/`:
  - Shared symlinks within `skills/` tree.
  - Bidirectional index invariant maintained.
  - Role-based agent names, imperative-verb skill names.
  - `EXPECTED_SKILLS` updated, `make generate-kodex` clean.

## File layout

```
klaude-plugin/profiles/skill-md/
├── DETECTION.md
├── overview.md
├── references/
│   └── skill-building-guide.md
├── implement/
│   ├── index.md
│   ├── skill-structure-gotchas.md
│   ├── claude-code-gotchas.md
│   └── kk-plugin-gotchas.md
└── review-code/
    ├── index.md
    ├── skill-quality-checklist.md
    ├── claude-code-checklist.md
    └── kk-plugin-checklist.md
```

## Files to modify

- `test/test-plugin-structure.sh` — append `skill-md` to `EXPECTED_PROFILES`
- `klaude-plugin/skills/_shared/profile-detection.md` — append `skill-md` to the Known Profiles list
