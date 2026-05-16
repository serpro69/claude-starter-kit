--8<-- "CONTRIBUTING.md"

## Documentation Site

The docs site uses MkDocs Material with mike for versioned publishing.

**Local preview:**

```bash
make docs-serve    # serves at http://localhost:8000
```

**Build without serving:**

```bash
make docs-build
```

**How publishing works:**

- Push to `master` → deploys as `latest` via mike
- Push tag `v0.14.0` → deploys as `0.14` (major.minor) via mike
- GitHub Actions workflow at `.github/workflows/docs.yml` handles both
- Mike pushes to the `gh-pages` branch; GitHub Pages serves from there
- First deploy requires one-time setup: `mike set-default latest` and enabling GitHub Pages on the `gh-pages` branch in repo Settings

**Content structure:** Pages live in `docs/` alongside internal design docs (`wip/`, `done/`, `adr/`). Internal dirs are excluded from search via `exclude_docs` in `mkdocs.yml` but remain accessible by direct URL. The landing page is a custom template at `docs/overrides/home.html`.

**Python deps:** Install via `pip install -r requirements.txt` (mkdocs-material, mike, minify, panzoom).

## Repository Structure

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
├── workflows/                   # template-cleanup, template-sync, docs
└── template-state.json          # Sync manifest and variables

docs/                            # MkDocs site + internal design docs
├── overrides/                   # Template overrides (home.html, main.html)
├── assets/                      # CSS (tokyonight.css, extra.css), JS
├── getting-started/             # Setup guides
├── user-guide/                  # Skills, profiles, MCP, config, sync
├── providers/                   # Claude Code and Codex specifics
├── contributing/                # ARCHITECTURE.md, TESTING.md, plugin dev
├── about/                       # License, changelog
├── adr/                         # Architecture decision records
├── wip/                         # In-progress feature design docs (excluded from search)
└── done/                        # Completed feature docs (excluded from search)

mkdocs.yml                       # MkDocs Material config
requirements.txt                 # Python deps for docs site

cmd/
├── vendor-profiles/             # Profile vendoring tool
└── generate-kodex/              # Codex plugin generation tool

test/
├── helpers.sh                   # Shared test utilities and assertions
├── test-*.sh                    # 8 test suites
└── fixtures/                    # Test manifests and templates
```
