# claude-toolbox

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)

claude-toolbox is a collection of "tools" for all your Claude Code workflows — pre-configured MCP servers, skills, sub-agents, commands, hooks, statuslines with themes, and more - everything you need for AI-powered development workflows, used and battle-tested daily on many of my own projects.

<img width="3440" height="521" alt="image" src="https://github.com/user-attachments/assets/27ef7269-0153-47c0-b07d-ed6a9504a176" />

## Why claude-toolbox?

Claude Code is powerful on its own, but it doesn't know your development workflow. claude-toolbox gives it a structured pipeline — from idea through design, implementation, code review, testing, to documentation — with persistent knowledge that carries across sessions.

```
/analysis-process → /design-review → /implementation-process → /solid-code-review → /testing-process → /documentation-process
```

Out of the box you get:

- **10 workflow skills** — a complete development pipeline invoked as `/skill-name`
- **Multi-model code review** — independent reviewers using sub-agents and external models (Gemini, etc.)
- **Semantic code analysis** — LSP-powered symbol navigation and reference tracking via Serena
- **Persistent knowledge base** — findings, decisions, and conventions that survive across sessions via Capy
- **Up-to-date library docs** — always-current documentation lookup via Context7
- **Battle-tested configuration** — permissions, statusline themes, hooks, sensible defaults

## Choose Your Path

**Starting a new project?** Use the template — you get everything pre-configured: MCP servers, plugin, Serena, statusline, sync infrastructure.
→ [Template Setup](#template-setup)

**Adding to an existing project?** Install just the kk plugin — all 10 skills, commands, and hooks in one command.
→ [Plugin-Only Setup](#plugin-only-setup)

## Requirements

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the AI coding assistant this toolbox extends
- **[npm](https://www.npmjs.com/package/npm)** — used by some MCP server installations
- **[uv](https://docs.astral.sh/uv/)** — Python package runner for Serena and Pal MCP servers
- **[jq](https://jqlang.github.io/jq/)** — JSON processor, required for template-cleanup

### API Keys

- [Context7](https://context7.com/) API key — for library documentation lookups
- Gemini API key for [Pal](https://github.com/BeehiveInnovations/pal-mcp-server) (or [any other provider](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/getting-started.md)) — for multi-model code review

### MCP Server Configuration

> [!NOTE]
> MCP servers must be configured in `~/.claude.json` (not in the repo) to keep API keys safe.
> These configs are generic enough to reuse across all your projects.

You don't need all servers to get started. Add them incrementally:

1. **Serena** (no API key needed) — semantic code analysis via LSP. Works immediately after setup.
2. **Context7** (needs API key) — up-to-date library documentation and code examples.
3. **Pal** (needs API key) — multi-model AI integration for code review, debugging, planning, and security audit.
4. **Capy** (optional, auto-configured by bootstrap) — persistent knowledge base across sessions. Install with `brew install serpro69/tap/capy`.

<details>
<summary>Example <code>mcpServers</code> configuration</summary>

```json
{
  "context7": {
    "type": "http",
    "url": "https://mcp.context7.com/mcp",
    "headers": {
      "CONTEXT7_API_KEY": "YOUR_CONTEXT7_API_KEY"
    }
  },
  "serena": {
    "type": "stdio",
    "command": "uvx",
    "args": [
      "--from",
      "git+https://github.com/oraios/serena",
      "serena",
      "start-mcp-server",
      "--context",
      "ide-assistant",
      "--project",
      "."
    ],
    "env": {}
  },
  "pal": {
    "command": "sh",
    "args": [
      "-c",
      "$HOME/.local/bin/uvx --from git+https://github.com/BeehiveInnovations/pal-mcp-server.git pal-mcp-server"
    ],
    "env": {
      "PATH": "/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md#model-configuration
      "DEFAULT_MODEL": "auto",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/advanced-usage.md#thinking-modes
      "DEFAULT_THINKING_MODE_THINKDEEP": "high",
      "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md#model-usage-restrictions
      "GOOGLE_ALLOWED_MODELS": "gemini-3.1-pro-preview,gemini-3-flash-preview"
    }
  }
}
```

See [Pal configuration docs](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md) for model and thinking mode options.

</details>

> [!TIP]
> If you're using my [claude-in-docker](https://github.com/serpro69/claude-in-docker) images, consider replacing `npx` and `uvx` calls with direct tool invocations. The images come shipped with all of the above MCP tools pre-installed, and you will avoid downloading dependencies every time you launch claude cli.
>
> ```json
>   "serena": {
>     "type": "stdio",
>     "command": "serena",
>     "args": [
>       "start-mcp-server",
>       "--context",
>       "ide-assistant",
>       "--project",
>       "."
>     ],
>     "env": {}
>   },
>   "pal": {
>     "command": "pal-mcp-server",
>     "args": [],
>     "env": { ... }
>   }
> ```
>
> You also may want to look into your `env` settings for the given mcp server, especially the `PATH` variable, and make sure you're not adding anything custom that may not be avaiable in the image.
> This may cause the mcp server to fail to connect.

## Template Setup

1. [Create a new project from this template](https://github.com/new?template_name=claude-toolbox&template_owner=serpro69) using the **Use this template** button.

2. Initialize the template — choose one method:

   **Option A: GitHub Actions** (recommended)

   Go to your new repo's **Actions** tab → **Template Cleanup** → **Run workflow**. Provide:
   - `LANGUAGES` (required) — programming languages, comma-separated (e.g., `python`, `python,typescript`).
     See [supported languages](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities).
   - `SERENA_INITIAL_PROMPT` — initial prompt given to the LLM on project activation
   - Other inputs are optional with sensible defaults.

   > [!TIP]
   > Take a look at serena [project.yaml](./.serena/project.yml) configuration file for more details.

   **Option B: Run locally**

   ```bash
   ./.github/scripts/template-cleanup.sh
   ```

   Interactive mode walks you through each option. Run with `--help` for all flags, or pass them directly:

   ```bash
   ./.github/scripts/template-cleanup.sh --languages python,typescript -y
   ```

3. Clone your repo (if using Option A) and verify MCP servers:

   ```
   > /mcp
   ╭────────────────────────────────────────────────────────────────────╮
   │ Manage MCP servers                                                 │
   │                                                                    │
   │ ❯ 1. context7                  ✔ connected · Enter to view details │
   │   2. serena                    ✔ connected · Enter to view details │
   │   3. pal                       ✔ connected · Enter to view details │
   ╰────────────────────────────────────────────────────────────────────╯
   ```

   The kk plugin (skills, commands, hooks) is available via the claude-toolbox marketplace configured in `.claude/settings.json`.

4. Finalize initialization:

   ```bash
   chmod +x .github/scripts/bootstrap.sh && ./.github/scripts/bootstrap.sh
   ```

   This installs the kk plugin, wires up the Capy knowledge base (if installed), and commits the configuration.

5. **Recommended:** Run `/config` in Claude Code and disable **Auto-compact**. This prevents Claude from compacting context mid-task, which degrades quality significantly. See [Recommended Settings](#recommended-settings) for the full config.

6. [Try it out!](#try-it)

## Plugin-Only Setup

Already have a project? Install just the kk plugin to get all skills, commands, and hooks:

```
/plugin install kk@claude-toolbox
```

That's it. All 10 skills are now available as `/skill-name` (annotated with `(kk)` in the slash command menu). See the [kk plugin documentation](./klaude-plugin/README.md) for details.

> [!TIP]
> For the full experience (MCP servers, statusline, Serena config), see [MCP Server Configuration](#mcp-server-configuration) above and add the configs you want to `~/.claude.json`.

## Try It

After setup, try the core workflow:

1. **Start with an idea.** Type `/analysis-process` and describe a feature you want to build. Claude will ask you refinement questions one at a time, then produce design docs and a task list in `docs/wip/`.

2. **Review the design.** Run `/design-review your-feature` to catch gaps before writing code.

3. **Build it.** Type `/implementation-process` — Claude executes the task list with code review checkpoints between batches.

4. **Review the code.** `/solid-code-review` checks for SOLID violations, security risks, and quality issues. Use `/solid-code-review:isolated` for independent sub-agent reviewers with zero authorship bias.

This is the core loop. See the [kk plugin README](./klaude-plugin/README.md) for all available skills and the full workflow pipeline.

## What's Included

### MCP Servers

Four servers provide complementary capabilities:

| Server                                                          | Purpose                                                                                |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **[Context7](https://context7.com/)**                           | Up-to-date library documentation and code examples                                     |
| **[Serena](https://github.com/oraios/serena)**                  | Semantic code analysis via LSP — symbol navigation, reference tracking, targeted reads |
| **[Pal](https://github.com/BeehiveInnovations/pal-mcp-server)** | Multi-model AI integration — chat, debugging, code review, planning, security audit    |
| **[Capy](https://github.com/serpro69/capy)**                    | Persistent knowledge base — cross-session project memory with FTS5 search              |

### Knowledge Base (Capy)

Skills are **knowledge-aware** via [Capy](https://github.com/serpro69/capy). They search for relevant context before executing (architecture decisions, review findings, language idioms) and index valuable learnings after producing output. Knowledge persists across sessions per-project using an FTS5 full-text search index.

Without Capy, each session starts fresh — all skills still work, they just don't carry learnings forward. Install when you want cross-session memory.

**Installation:** `brew install serpro69/tap/capy` then run `capy setup` in your project directory. The bootstrap script sets up Capy automatically if the binary is on PATH.

### kk Plugin ([`klaude-plugin/`](./klaude-plugin/README.md))

The **kk** plugin contains all development workflow functionality — 10 skills, 4 commands, and hooks — distributed via the Claude Code plugin system. Skills are invoked as `/skill-name`, commands as `/kk:dir:command`.

Includes: **analysis-process**, **implementation-process**, **testing-process**, **documentation-process**, **development-guidelines**, **solid-code-review**, **implementation-review**, **design-review**, **merge-docs**, **cove** (Chain-of-Verification). Plus commands for CoVe, implementation review, design review, Task Master migration, and sync workflow updates. See the [plugin README](./klaude-plugin/README.md) for full details.

### Configuration

- **Permission allowlist/denylist** (`.claude/settings.json`) — baseline permissions: auto-approves safe bash commands and WebSearch while blocking dangerous patterns. Per-repo MCP tool permissions go in `settings.local.json`.
- **Status line** (`.claude/scripts/statusline_enhanced.sh`) — rich statusline with model, context %, git branch, session duration, thinking mode, and rate limits. Themes: set `CLAUDE_STATUSLINE_THEME` to `darcula`, `nord`, or `catppuccin`, and `CLAUDE_STATUSLINE_MODE` to `dark` (default) or `light` to match your terminal background
- **Serena config** (`.serena/project.yml`) — language detection, gitignore integration, encoding settings

### Template Infrastructure

- **template-cleanup** — GitHub Action or local CLI script to initialize a new repo from this template
- **template-sync** workflow — pull upstream configuration updates into your project via PR
- **Sync exclusions** — prevent specific files from being re-added during sync
- **Test suite** — 157 tests across 5 suites covering the plugin structure, sync/cleanup infrastructure

## Recommended Settings

> [!TIP]
> Configure via `claude /config`. The config file is usually at `~/.claude.json`.

This is my current config, tweaked for best results. **I can't recommend enough disabling auto-compact** — I've seen many a time claude starting to compact conversations in the middle of a task, which produces very poor results for the remaining work it does after compacting.

<details>
<summary>Full <code>/config</code> settings</summary>

```

> /config
────────────────────────────────────────────────────────────
 Configure Claude Code preferences

    Auto-compact                              false
    Show tips                                 true
    Reduce motion                             false
    Thinking mode                             true
    Prompt suggestions                        true
    Rewind code (checkpoints)                 true
    Verbose output                            false
    Terminal progress bar                     true
    Default permission mode                   Default
    Respect .gitignore in file picker         true
    Auto-update channel                       latest
    Theme                                     Dark mode
    Notifications                             Auto
    Output style                              default
    Language                                  Default (English)
    Editor mode                               vim
    Show code diff footer                     true
    Show PR status footer                     true
    Model                                     opus
    Auto-connect to IDE (external terminal)   false
    Claude in Chrome enabled by default       false
```

</details>

## Receiving Template Updates

Repos created from this template can pull configuration updates via the **Template Sync** workflow.

### How Configuration Works

> [!NOTE]
> Claude Code settings are split between two project-scoped files:
> - **`.claude/settings.json`** — upstream-managed defaults, synced from this template (permissions baseline, env vars, model, plugins, statusline)
> - **`.claude/settings.local.json`** — your per-repo overrides, never synced (hooks, MCP server enables, additional permissions, personal preferences)
>
> Don't edit `settings.json` directly — your customizations go in `settings.local.json`. "Don't ask again" permission grants land there automatically.

### Prerequisites

- `.github/template-state.json` must exist (created automatically for new repos, or [manually for older ones](#migration-for-existing-repositories))
- Allow actions to create pull-requests: repo **Settings** → **Actions**
  <img width="792" height="376" alt="image" src="https://github.com/user-attachments/assets/81343169-fa87-4631-ad5d-60fde7685538" />

### Using Template Sync

1. Go to **Actions** → **Template Sync** → **Run workflow**
2. Choose a version: `latest` (default), `master`, or a specific tag (e.g., `v1.2.3`)
3. Optionally enable **dry_run** to preview changes without creating a PR
4. Review and merge the created PR
5. Merge to apply updates

### What Gets Synced

**Updated:** `.claude/` (settings, CLAUDE.extra.md, statusline scripts), `.serena/`, and the sync infrastructure itself. Skills, commands, and hooks are managed by the plugin system — not template sync.

**Preserved:** Project-specific values (name, language, prompts), `settings.local.json`, gitignored files

**settings.json merge behavior:** The sync uses smart-merge semantics — your downstream `settings.json` is "master" and upstream fills gaps:
- **New keys** from upstream are added (e.g., new deny patterns, new env vars)
- **Existing values** are never overwritten (your customizations are preserved)
- **Arrays** are concatenated with deduplication (e.g., new upstream deny rules are appended)
- **Manifest variables** (`CC_MODEL`, `CC_EFFORT_LEVEL`, etc.) still override after the merge — these are your explicit choices

### Sync Exclusions

If you've removed template files you don't need, prevent sync from re-adding them:

Edit `.github/template-state.json` and add a `sync_exclusions` array:

```diff
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-toolbox",
  "template_version": "v0.2.0",
  "synced_at": "2025-01-27T10:00:00Z",
+ "sync_exclusions": [
+   ".claude/CLAUDE.extra.md",
+   ".claude/settings.json"
+ ],
  "variables": { "..." : "..." }
}
```

**Pattern syntax:**

- Patterns use glob syntax where `*` matches any characters including directory separators
- Patterns are matched against project-relative paths (e.g., `.claude/settings.json`)
- Common patterns: `.claude/CLAUDE.extra.md` (single file), `.serena/*` (entire directory)

**Behavior:**

- Excluded files are NOT added if they exist upstream but not locally
- Excluded files are NOT updated if they exist in both places
- Excluded files are NOT flagged as deleted if they exist locally but not upstream
- Excluded files appear as "Excluded" in the sync report for transparency

### Migrating from Task Master

Task Master MCP was removed in favor of native markdown-based task tracking integrated into the `analysis-process` and `implementation-process` skills.

The easiest way to migrate is to run the migration command in Claude Code:

```
/kk:migrate-from-taskmaster:migrate
```

It will port pending tasks, clean up TM files, update configs, and walk you through each step with confirmation prompts.

<details>
<summary>Manual migration steps</summary>

If you prefer to migrate manually, follow these steps after syncing:

1. **Port any pending tasks** to the new format: create `/docs/wip/[feature]/tasks.md` files following the [example task file](./klaude-plugin/skills/analysis-process/example-tasks.md). Completed tasks don't need porting.

1. **Remove Task Master files and config:**

   ```bash
   rm -rf .taskmaster
   rm -rf .claude/commands/tm
   rm -f .claude/TM_COMMANDS_GUIDE.md
   rm -f .claude/agents/task-orchestrator.md
   rm -f .claude/agents/task-executor.md
   rm -f .claude/agents/task-checker.md
   ```

3. **Remove Task Master from `~/.claude.json`:** delete the `task-master-ai` entry from your `mcpServers` config.

4. **Remove TM variables from `.github/template-state.json`:** delete `TM_CUSTOM_SYSTEM_PROMPT`, `TM_APPEND_SYSTEM_PROMPT`, and `TM_PERMISSION_MODE` from the `variables` object.

5. **Remove TM references from `CLAUDE.md`:** delete the "Task Master Integration" and "Task Master AI Instructions" sections (including the `@./.taskmaster/CLAUDE.md` import).

6. **Update the template-sync workflow** ([why?](https://github.com/serpro69/claude-toolbox/issues/17)): the old workflow contains taskmaster-specific sync logic that will break future syncs. Run `/kk:sync-workflow:sync-workflow latest` or manually replace both files:

   ```bash
   VERSION="v0.3.0"  # or use latest tag
   curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-toolbox/${VERSION}/.github/workflows/template-sync.yml" \
     -o .github/workflows/template-sync.yml
   curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-toolbox/${VERSION}/.github/scripts/template-sync.sh" \
     -o .github/scripts/template-sync.sh
   chmod +x .github/scripts/template-sync.sh
   ```

Task tracking now lives in simple markdown files (`/docs/wip/[feature]/tasks.md`) created by the `analysis-process` skill and consumed by `implementation-process`. No external MCP server required.

</details>

### Upgrading to the Plugin System (v0.5.0+)

Skills and commands have moved from the template to the **kk** plugin:

- Skills remain unprefixed: `/analysis-process` (annotated with `(kk)` in the menu)
- Commands are now namespaced: `/project:cove` → `/kk:cove:cove`
- The template-sync workflow handles migration automatically on next sync
- After merging the sync PR, run `/plugin install kk@claude-toolbox`

### Migration for Existing Repositories

If your repo was created before the sync feature (or even if your repo wasn't created from this template at all), create `.github/template-state.json`:

```json
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-toolbox",
  "template_version": "v1.0.0",
  "synced_at": "1970-01-01T00:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-cool-project",
    "LANGUAGES": "go",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": ""
  }
}
```

Then copy `.github/workflows/template-sync.yml` and `.github/scripts/template-sync.sh` from the [template repository](https://github.com/serpro69/claude-toolbox).

## Development

### Running Tests

Tests across 5 suites cover the plugin structure, template sync/cleanup infrastructure:

```bash
# Run all test suites
for test in test/test-*.sh; do $test; done

# Run individual suites
./test/test-plugin-structure.sh  # Plugin manifest, skills, commands, hooks validation
./test/test-template-sync.sh     # template-sync.sh function tests + plugin migration
./test/test-template-cleanup.sh  # generate_manifest() tests
./test/test-claude-extra.sh      # CLAUDE.extra.md detection and auto-import
./test/test-manifest-jq.sh       # jq JSON pattern tests
```

| Test Suite                | Coverage                                                            |
| ------------------------- | ------------------------------------------------------------------- |
| test-plugin-structure.sh  | Plugin/marketplace manifests, skills, commands, hooks, cross-refs   |
| test-template-sync.sh     | CLI parsing, manifest validation, substitutions, plugin migration   |
| test-template-cleanup.sh  | Manifest generation, variable capture, git tag/SHA detection        |
| test-claude-extra.sh      | CLAUDE.extra.md existence, compare_files detection, auto-import     |
| test-manifest-jq.sh       | JSON generation, special character handling, round-trip validation  |

## Repository Structure

```
klaude-plugin/                   # kk plugin (distributed via plugin system)
├── .claude-plugin/plugin.json   # Plugin manifest
├── skills/                      # 10 development workflow skills
├── commands/                    # 4 slash commands
├── hooks/hooks.json             # Bash validation hook config
└── scripts/validate-bash.sh     # Hook script

.claude-plugin/marketplace.json  # Marketplace catalog

.claude/
├── CLAUDE.extra.md              # Always-loaded instructions
├── settings.json                # Upstream-managed: permissions baseline, env, model, plugins
├── settings.local.json          # Per-repo: hooks, MCP enables, additional permissions
└── scripts/                     # statusline.sh, statusline_enhanced.sh, sync-workflow.sh

.serena/
└── project.yml                  # Serena LSP configuration

.github/
├── scripts/                     # template-cleanup.sh, template-sync.sh, bootstrap.sh
├── workflows/                   # template-cleanup, template-sync
└── template-state.json          # Sync manifest and variables

test/
├── helpers.sh                   # Shared test utilities and assertions
├── test-*.sh                    # 5 test suites
└── fixtures/                    # Test manifests and templates
```

## Examples

Examples of actual Claude Code workflows executed using this template's configs, skills, and tools: [examples/](./examples)

## Contributing

Feel free to open new PRs/issues. Any contributions you make are greatly appreciated.

## License

Copyright &copy; 2025 - present, [serpro69](https://github.com/serpro69)

Distributed under the ELv2 License.

See [`LICENSE.md`](https://github.com/serpro69/claude-toolbox/blob/master/LICENSE.md) file for more information.
