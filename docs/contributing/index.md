# Contributing

Thanks for your interest in contributing to claude-toolbox!

See [Architecture](architecture.md) for how the components fit together and [Testing](testing.md) for test conventions. The authoritative reference for all conventions is [`CLAUDE.md`](https://github.com/serpro69/claude-toolbox/blob/master/CLAUDE.md) — this guide summarizes the most important rules for quick orientation.

## Getting Started

1. Fork and clone the repo
2. Run the test suite to make sure everything works: `for test in test/test-*.sh; do $test; done`
3. Create a feature branch from `master`

## Key Workflows

- **Editing skills:** Edit in `klaude-plugin/skills/`, then run `make generate-kodex` to regenerate the Codex variant.
- **Editing profiles:** Edit in `klaude-plugin/profiles/`, then run `make generate-kodex`. Vendored profiles (e.g., Go) use `make vendor-profiles` instead.
- **Adding a profile:** Follow the "Adding a new profile" checklist in [Plugin Development](plugin-development.md#profiles).
- **Editing codex config:** Hand-authored files live in `.codex/` (config.toml, hooks.json, rules, scripts). Generated files (agents, kodex-plugin) should not be edited directly.

## Commit Conventions

- Use imperative mood in commit messages ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Include a blank line + body for non-trivial changes explaining the "why"

## Development

### Running Tests

Tests across 8 suites cover plugin structure, codex configuration, and template sync/cleanup infrastructure:

```bash
# Run all test suites
for test in test/test-*.sh; do $test; done

# Run individual suites
./test/test-plugin-structure.sh  # Plugin manifest, skills, commands, hooks, kodex-plugin validation
./test/test-codex-structure.sh   # Codex marketplace, config, hooks, agents, rules, scripts
./test/test-template-sync.sh     # template-sync.sh function tests + plugin migration
./test/test-template-cleanup.sh  # generate_manifest() tests
./test/test-claude-extra.sh      # CLAUDE.extra.md detection and auto-import
./test/test-manifest-jq.sh       # jq JSON pattern tests
```

| Test Suite | Coverage |
|------------|----------|
| test-plugin-structure.sh | Plugin/marketplace manifests, skills, commands, hooks, cross-refs, kodex gen |
| test-codex-structure.sh | Codex marketplace, config.toml, hooks.json, agents, rules, scripts, AGENTS.md |
| test-template-sync.sh | CLI parsing, manifest validation, substitutions, plugin migration |
| test-template-cleanup.sh | Manifest generation, variable capture, git tag/SHA detection |
| test-claude-extra.sh | CLAUDE.extra.md existence, compare_files detection, auto-import |
| test-manifest-jq.sh | JSON generation, special character handling, round-trip validation |

### Repository Structure

```
klaude-plugin/                   # kk plugin — Claude (canonical source of truth)
├── .claude-plugin/plugin.json   # Plugin manifest
├── skills/                      # 10 development workflow skills
├── commands/                    # 4 slash commands
├── agents/                      # Sub-agents (code-reviewer, spec-reviewer, design-reviewer, ...)
├── profiles/                    # Per-domain content (languages, IaC DSLs)
├── hooks/hooks.json             # Bash validation hook config
└── scripts/validate-bash.sh     # Hook script

kodex-plugin/                    # kk plugin — Codex (GENERATED from klaude-plugin/)
├── .codex-plugin/plugin.json    # Generated plugin manifest
├── skills/                      # Generated skills (transformed SKILL.md files)
└── profiles/                    # Per-domain content (languages, IaC DSLs)

.claude-plugin/marketplace.json  # Claude marketplace catalog
.agents/plugins/marketplace.json # Codex marketplace catalog

CLAUDE.md                        # Claude project instructions (this repo)
AGENTS.md                        # Codex project instructions (this repo)

.claude/
├── CLAUDE.extra.md              # Behavioral instructions (synced downstream)
├── settings.json                # Upstream-managed: permissions baseline, env, model, plugins
├── settings.local.json          # Per-repo: hooks, MCP enables, additional permissions
└── scripts/                     # statusline.sh, statusline_enhanced.sh

.codex/
├── config.toml                  # Codex settings: model, approval policy, features, MCP
├── hooks.json                   # SessionStart + PreToolUse hook definitions
├── rules/default.rules          # Starlark command policies (ported from Claude deny list)
├── agents/                      # 5 sub-agent TOML files (generated from klaude-plugin/agents/)
└── scripts/                     # session-start.sh, pretooluse-bash.sh

.github/
├── scripts/                     # template-cleanup.sh, template-sync.sh, bootstrap.sh
├── workflows/                   # template-cleanup, template-sync
└── template-state.json          # Sync manifest and variables

cmd/
├── vendor-profiles/             # Profile vendoring tool
└── generate-kodex/              # Codex plugin generation tool

test/
├── helpers.sh                   # Shared test utilities and assertions
├── test-*.sh                    # 8 test suites
└── fixtures/                    # Test manifests and templates
```

## Pull Requests

- One logical change per PR
- All test suites must pass: `for test in test/test-*.sh; do $test; done`
- If you edited `klaude-plugin/`, verify `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/` shows no drift
- Update documentation if your change affects user-facing behavior

## Sections

- [Architecture](architecture.md) — component overview and data flows
- [Plugin Development](plugin-development.md) — skills, commands, agents, hooks, profiles
- [Testing](testing.md) — test suites and conventions
- [ADRs](adrs.md) — architecture decision records

## License

By contributing, you agree that your contributions will be licensed under the ELv2 License.
