# Addendum: Future Improvements

> Parent: [./design.md](./design.md)

Items deferred from the initial lean scope. Each is a potential follow-up iteration.

## Detection/routing evals

The `skill-md` profile has non-trivial detection logic (nearest-ancestor `SKILL.md` walk, conditional loading based on provider signals). This warrants eval scenarios under `klaude-plugin/skills/review-code/evals/` (or a profile-level eval directory if that convention is established).

**Minimum eval set:**
- **Positive: SKILL.md direct edit.** Diff touches a `SKILL.md` file. Assert: `skill-md` profile activates, `skill-quality-checklist.md` loads.
- **Positive: resource subdirectory edit.** Diff touches `skills/my-skill/references/guide.md` where `skills/my-skill/SKILL.md` exists. Assert: profile activates via ancestor walk.
- **Positive: Claude Code conditional.** Diff contains `${CLAUDE_PLUGIN_ROOT}`. Assert: `claude-code-checklist.md` loads.
- **Positive: kk-plugin conditional.** Diff touches files under `klaude-plugin/`. Assert: `kk-plugin-checklist.md` loads.
- **Regression (false positive): unrelated markdown.** Diff touches `docs/README.md` with no `SKILL.md` ancestor. Assert: `skill-md` profile does NOT activate.
- **Regression (false positive): YAML frontmatter without SKILL.md.** Diff touches a `.md` file with `name:` + `description:` frontmatter but no `SKILL.md` in any ancestor directory. Assert: profile does NOT activate (frontmatter alone is not a detection signal).

## Additional phases

Deferred from initial scope (see design.md §Phases):

- **`design/`** — `questions.md` feeding the /kk:design skill's refinement question pool (e.g., "What should this skill enable?", "When should it trigger?", "What's the expected output format?", "Should it bundle scripts?"). `sections.md` requiring design doc sections for skill architecture, detection strategy, resource organization.
- **`test/`** — eval creation guidance using this project's eval.json format (traps, assertions, real filesystem fixtures). Would teach the model to generate eval scenarios for new skills.
- **`document/`** — documentation rubric for skill README/overview content.
- **`review-spec/`** — spec conformance checks between skill design docs and implemented SKILL.md.

## Codex provider checklist {#codex-provider-checklist}

The current conditional checklists cover Claude Code and kk-plugin specifics. A `codex-gotchas.md` / `codex-checklist.md` conditional pair would cover:
- TOML agent format (`.toml` with `developer_instructions`)
- Starlark rules files
- `config.toml` plugin configuration
- Differences in `${CLAUDE_PLUGIN_ROOT}` handling (resolved to relative paths by the generation tool)

**Load if:** diff contains `.toml` agent files, or files under `.codex/`, or `kodex-plugin/` directory structure.

## Description optimization workflow

Anthropic's skill-creator includes a description optimization loop (generate trigger eval queries → test against model → iterate). This could be adapted as a reference file or a lightweight script in the profile's `references/` directory, without porting the full Python eval infrastructure.
