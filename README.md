# claude-toolbox

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)

claude-toolbox is a collection of "tools" for all your Claude Code workflows — pre-configured MCP servers, skills, sub-agents, commands, hooks, statuslines with themes, and more - everything you need for AI-powered development workflows, used and battle-tested daily on many of my own projects.

## About

This is a template repository and claude-plugin system that gives you a ready-to-use Claude Code development environment. It ships with mcp servers, development-related skills, hooks, slash commands — all configured and wired together.

> [!NOTE]
> We focus on collaborative development. Most claude- and mcp-related settings are project-scoped (`.claude/settings.json`) so they can be shared across your team via git, rather than living in user-scoped `~/.claude.local.json`.

## What's Included

### MCP Servers

Three servers, configured at user-level (`~/.claude.json`) to keep API keys out of the repo:

| Server                                                          | Purpose                                                                                |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **[Context7](https://context7.com/)**                           | Up-to-date library documentation and code examples                                     |
| **[Serena](https://github.com/oraios/serena)**                  | Semantic code analysis via LSP — symbol navigation, reference tracking, targeted reads |
| **[Pal](https://github.com/BeehiveInnovations/pal-mcp-server)** | Multi-model AI integration — chat, debugging, code review, planning, security audit    |

### Skills (`.claude/skills/`)

Skills are specialized workflows Claude invokes during different development phases:

| Skill                      | When to use                                                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **analysis-process**       | Pre-implementation. Turns ideas/specs into design docs, implementation plans, and task lists.                                                                            |
| **implementation-process** | Execute an implementation plan with batched steps and architect review checkpoints.                                                                                      |
| **testing-process**        | After writing code. Guidelines for test coverage — table-driven tests, mocking, integration, benchmarks.                                                                 |
| **documentation-process**  | Post-implementation. Updates ARCHITECTURE.md, TESTING.md, and records ADRs.                                                                                              |
| **development-guidelines** | During implementation. Enforces best practices like using latest deps and context7 for docs.                                                                             |
| **solid-code-review**      | Code review with a senior-engineer lens. Checks SOLID principles, security, code quality. Includes language-specific checklists for Go, Java, JS/TS, Kotlin, and Python. |
| **cove**                   | Chain-of-Verification prompting. Two modes: standard (prompt-based) and isolated (sub-agent). For high-stakes accuracy and fact-checking.                                |

### Commands (`.claude/commands/`)

- **CoVe** (`/project:cove/`) — 2 commands for Chain-of-Verification prompting (standard and isolated modes)
- **Migrate from Task Master** (`/project:migrate-from-taskmaster`) — one-time migration from Task Master MCP to native markdown task tracking
- **Sync Workflow** (`/project:sync-workflow [version]`) — update the template-sync workflow and script from upstream (`latest`, `master`, or a specific tag like `v0.3.0`)

### Hooks (`.claude/hooks/`)

- **Bash validation** (`PreToolUse`) — blocks bash commands that touch `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`, and other sensitive paths

### Other Configuration

- **Permission allowlist/denylist** (`.claude/settings.json`) — auto-approves safe tools (context7, serena, pal code review) while blocking dangerous ones
- **Status line** (`.claude/scripts/statusline_enhanced.sh`) — rich statusline with model, context %, git branch, session duration, thinking mode, and rate limits. Themes: set `CLAUDE_STATUSLINE_THEME` to `darcula`, `nord`, or `catppuccin`, and `CLAUDE_STATUSLINE_MODE` to `dark` (default) or `light` to match your terminal background
- **Serena config** (`.serena/project.yml`) — language detection, gitignore integration, encoding settings

### Template Infrastructure

- **template-cleanup** workflow — one-click GitHub Action to initialize a new repo from this template
- **template-sync** workflow — pull upstream configuration updates into your project via PR
- **Sync exclusions** — prevent specific files from being re-added during sync
- **Test suite** — 72 tests across 3 suites covering the sync/cleanup infrastructure

## Requirements

### Tools

- [npm](https://www.npmjs.com/package/npm)
- [uv](https://docs.astral.sh/uv/)
- [jq](https://jqlang.github.io/jq/) — required for template-cleanup

### API Keys

- [Context7](https://context7.com/) API key
- Gemini API key for [Pal](https://github.com/BeehiveInnovations/pal-mcp-server) (or [any other provider](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/getting-started.md))

### MCP Server Configuration

> [!NOTE]
> MCP servers must be configured in `~/.claude.json` (not in the repo) to keep API keys safe.
> These configs are generic enough to reuse across all your projects.

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

## Quick Start

1. [Create a new project from this template](https://github.com/new?template_name=claude-toolbox&template_owner=serpro69) using the **Use this template** button.

2. A scaffold repo will appear in your GitHub account.

3. Run the **template-cleanup** workflow from your new repo's Actions tab. Provide inputs:

**Serena:**

- `LANGUAGES` (required) — programming languages, comma-separated (e.g., `python`, `python,typescript`).
  See [supported languages](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities).
- `SERENA_INITIAL_PROMPT` — initial prompt given to the LLM on project activation

> [!TIP]
> Take a look at serena [project.yaml](./.github/templates/serena/project.yml) configuration file for more details.

4. Clone your new repo and cd into it

   Run `claude /mcp`, you should see the mcp servers configured and active:

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

   Run `claude "list your skills"`, you should see the skills from this repo present:

   ```
   > list your skills

   ● I have access to the following skills:

     Available Skills
     ...

     ---
     These skills provide specialized workflows for different stages of development. You can invoke any of them by asking me to use a specific skill (e.g., "use the analysis-process skill" or "help me document this feature").
   ```

5. Update the `README.md` with your project description, then run `chmod +x bootstrap.sh && ./bootstrap.sh` to finalize initialization.

6. Profit

## Receiving Template Updates

Repos created from this template can pull configuration updates via the **Template Sync** workflow.

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

**Updated:** `.claude/` (commands, skills, agents, scripts, settings), `.serena/`, and the sync infrastructure itself

**Preserved:** Project-specific values (name, language, prompts), user-scoped files (local settings), gitignored files

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
+   ".claude/commands/cove/*",
+   ".claude/skills/cove/*"
+ ],
  "variables": { "..." : "..." }
}
```

**Pattern syntax:**

- Patterns use glob syntax where `*` matches any characters including directory separators
- Patterns are matched against project-relative paths (e.g., `.claude/commands/cove/cove.md`)
- Common patterns: `.claude/commands/cove/*` (entire directory), `.serena/project.yml` (single file)

**Behavior:**

- Excluded files are NOT added if they exist upstream but not locally
- Excluded files are NOT updated if they exist in both places
- Excluded files are NOT flagged as deleted if they exist locally but not upstream
- Excluded files appear as "Excluded" in the sync report for transparency

### Migrating from Task Master

Task Master MCP was removed in favor of native markdown-based task tracking integrated into the `analysis-process` and `implementation-process` skills.

The easiest way to migrate is to run the migration command in Claude Code:

```
/project:migrate-from-taskmaster
```

It will port pending tasks, clean up TM files, update configs, and walk you through each step with confirmation prompts.

<details>
<summary>Manual migration steps</summary>

If you prefer to migrate manually, follow these steps after syncing:

1. **Port any pending tasks** to the new format: create `/docs/wip/[feature]/tasks.md` files following the [example task file](./.github/templates/claude/skills/analysis-process/example-tasks.md). Completed tasks don't need porting.

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

6. **Update the template-sync workflow** ([why?](https://github.com/serpro69/claude-toolbox/issues/17)): the old workflow contains taskmaster-specific sync logic that will break future syncs. Run `/project:sync-workflow latest` or manually replace both files:

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

### Post-Init Settings

The following tweaks are not mandatory, but will more often than not improve your experience with CC

#### Claude Code Configuration

> [!TIP]
> The following config parameters can be easily configured via `claude /config` command.
>
> The config file can also be modified manually and is usually found at `~/.claude.json`

<details>
<summary>Recommended <code>/config</code> settings</summary>

This is my current config, you may want to tweak it to your needs. **I can't recommend enough disabling auto-compact** feature and controlling the context window manually. I've seen many a time claude starting to compact conversations in the middle of a task, which produces very poor results for the remaining work it does after compacting.

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

## Development

### Running Tests

Tests across 3 suites covere the template sync/cleanup infrastructure:

```bash
# Run all test suites
for test in test/test-*.sh; do $test; done

# Run individual suites
./test/test-manifest-jq.sh       # jq JSON pattern tests
./test/test-template-sync.sh     # template-sync.sh function tests
./test/test-template-cleanup.sh  # generate_manifest() tests
```

| Test Suite               | Coverage                                                           |
| ------------------------ | ------------------------------------------------------------------ |
| test-manifest-jq.sh      | JSON generation, special character handling, round-trip validation |
| test-template-sync.sh    | CLI parsing, manifest validation, substitutions, file comparison   |
| test-template-cleanup.sh | Manifest generation, variable capture, git tag/SHA detection       |

## Repository Structure

```
.claude/
├── commands/
│   └── cove/              # 2 CoVe verification commands
├── hooks/                 # Bash validation hook config
├── scripts/               # statusline.sh, validate-bash.sh
├── skills/                # 7 development workflow skills
└── settings.json          # Shared permission config

.serena/
└── project.yml            # Serena LSP configuration

.github/
├── scripts/               # template-cleanup.sh, template-sync.sh, bootstrap.sh
├── workflows/             # template-cleanup, template-sync
└── template-state.json    # Sync manifest and variables

test/
├── helpers.sh             # Shared test utilities and assertions
├── test-*.sh              # 3 test suites
└── fixtures/              # Test manifests and templates
```

## Examples

Examples of actual Claude Code workflows executed using this template's configs, skills, and tools: [examples/](./examples)

## Contributing

Feel free to open new PRs/issues. Any contributions you make are greatly appreciated.

## License

Copyright &copy; 2025 - present, [serpro69](https://github.com/serpro69)

Distributed under the MIT License.

See [`LICENSE.md`](https://github.com/serpro69/claude-toolbox/blob/master/LICENSE.md) file for more information.
