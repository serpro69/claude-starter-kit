# claude-starter-kit

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)

Starter template repo for all your Claude Code needs — pre-configured MCP servers, skills, sub-agents, commands, and hooks for AI-powered development workflows.

## About

This is a template repository that gives you a ready-to-use Claude Code development environment. It ships with mcp servers, development-related skills, task orchestration tooling, hooks, slash commands — all configured and wired together.

> [!NOTE]
> We focus on collaborative development. Most claude- and mcp-related settings are project-scoped (`.claude/settings.json`) so they can be shared across your team via git, rather than living in user-scoped `~/.claude.local.json`.

## What's Included

### MCP Servers

Four servers, configured at user-level (`~/.claude.json`) to keep API keys out of the repo:

| Server                                                                | Purpose                                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **[Context7](https://context7.com/)**                                 | Up-to-date library documentation and code examples                                     |
| **[Serena](https://github.com/oraios/serena)**                        | Semantic code analysis via LSP — symbol navigation, reference tracking, targeted reads |
| **[Task Master](https://github.com/eyaltoledano/claude-task-master)** | AI-powered task management — PRD parsing, complexity analysis, workflow orchestration  |
| **[Pal](https://github.com/BeehiveInnovations/pal-mcp-server)**       | Multi-model AI integration — chat, debugging, code review, planning, security audit    |

### Skills (`.claude/skills/`)

Skills are specialized workflows Claude invokes during different development phases:

| Skill                      | When to use                                                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **analysis-process**       | Pre-implementation. Turns ideas/specs into PRDs, design docs, and implementation plans.                                                                                  |
| **implementation-process** | Execute an implementation plan with batched steps and architect review checkpoints.                                                                                      |
| **testing-process**        | After writing code. Guidelines for test coverage — table-driven tests, mocking, integration, benchmarks.                                                                 |
| **documentation-process**  | Post-implementation. Updates ARCHITECTURE.md, TESTING.md, and records ADRs.                                                                                              |
| **development-guidelines** | During implementation. Enforces best practices like using latest deps and context7 for docs.                                                                             |
| **solid-code-review**      | Code review with a senior-engineer lens. Checks SOLID principles, security, code quality. Includes language-specific checklists for Go, Java, JS/TS, Kotlin, and Python. |
| **cove**                   | Chain-of-Verification prompting. Two modes: standard (prompt-based) and isolated (sub-agent). For high-stakes accuracy and fact-checking.                                |

### Sub-Agents (`.claude/agents/`)

Three agents for task-driven development workflows:

| Agent                 | Role                                                                                                                 |
| --------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **task-orchestrator** | Analyzes task dependencies, identifies parallelization opportunities, deploys executors. Runs on Opus.               |
| **task-executor**     | Implements specific tasks — transforms task specs into working code with progress tracking. Runs on Sonnet.          |
| **task-checker**      | QA verification — checks implementations against requirements, runs tests before marking tasks done. Runs on Sonnet. |

### Commands (`.claude/commands/`)

Slash commands organized hierarchically:

- **Task Master** (`/project:tm/`) — 47 commands covering the full task lifecycle:
  - **Setup**: `init`, `install-taskmaster`, `setup-models`
  - **Daily workflow**: `next`, `list`, `show`, `set-status/to-{done,in-progress,review,...}`
  - **Task management**: `add-task`, `update`, `expand`, `remove-task`
  - **Analysis**: `analyze-complexity`, `complexity-report`, `analyze-project`
  - **Dependencies**: `add-dependency`, `remove-dependency`, `validate-dependencies`, `fix-dependencies`
  - **Subtasks**: `add-subtask`, `remove-subtask`, `clear-subtasks`
  - **Workflows**: `smart-workflow`, `command-pipeline`, `auto-implement-tasks`
  - Full reference: `.claude/TM_COMMANDS_GUIDE.md`
- **CoVe** (`/project:cove/`) — 2 commands for Chain-of-Verification prompting (standard and isolated modes)

### Hooks (`.claude/hooks/`)

- **Bash validation** (`PreToolUse`) — blocks bash commands that touch `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`, and other sensitive paths

### Other Configuration

- **Permission allowlist/denylist** (`.claude/settings.json`) — auto-approves safe tools (context7, serena read-only, task master, pal code review) while blocking dangerous ones
- **Status line** (`.claude/scripts/statusline.sh`) — minimalistic statusline that shows current model and context window usage percentage
- **Serena config** (`.serena/project.yml`) — language detection, gitignore integration, encoding settings
- **Task Master config** (`.taskmaster/config.json`) — AI model roles (main/research/fallback), task defaults

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
  "task-master-ai": {
    "type": "stdio",
    "command": "npx",
    "args": [
      "-y",
      "--package=task-master-ai",
      "task-master-ai"
    ],
    "headers": {}
  },
  "pal": {
    "command": "sh",
    "args": [
      "-c",
      "$HOME/.local/bin/uvx --from git+https://github.com/BeehiveInnovations/pal-mcp-server.git pal-mcp-server"
    ],
    "env": {
      "PATH": "/usr/local/bin:/usr/bin:/bin:~/.local/bin",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md#model-configuration
      "DEFAULT_MODEL": "auto",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/advanced-usage.md#thinking-modes
      "DEFAULT_THINKING_MODE_THINKDEEP": "high",
      "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY",
      # see https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md#model-usage-restrictions
      "GOOGLE_ALLOWED_MODELS": "gemini-3-pro-preview,gemini-2.5-pro,gemini-2.5-flash"
    }
  }
}
```

See [Pal configuration docs](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md) for model and thinking mode options.

</details>

## Quick Start

1. [Create a new project from this template](https://github.com/new?template_name=claude-starter-kit&template_owner=serpro69) using the **Use this template** button.

2. A scaffold repo will appear in your GitHub account.

3. Run the **template-cleanup** workflow from your new repo's Actions tab. Provide inputs:

**Serena:**

- `LANGUAGES` (required) — programming languages, comma-separated (e.g., `python`, `python,typescript`).
  See [supported languages](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities).
- `SERENA_INITIAL_PROMPT` — initial prompt given to the LLM on project activation

> [!TIP]
> Take a look at serena [project.yaml](./.github/templates/serena/project.yml) configuration file for more details.

**Task Master:**

- `TM_CUSTOM_SYSTEM_PROMPT` — override Claude Code's default system prompt
- `TM_APPEND_SYSTEM_PROMPT` — append to the system prompt
- `TM_PERMISSION_MODE` — permission mode for file system operations

  > [!TIP]
  > See [Task Master advanced settings](https://github.com/eyaltoledano/claude-task-master/blob/main/docs/examples/claude-code-usage.md#advanced-settings-usage) for details on these parameters.

4. Clone your new repo and cd into it

   Run `claude /mcp`, you should see the mcp servers configured and active:

   ```
   > /mcp
   ╭────────────────────────────────────────────────────────────────────╮
   │ Manage MCP servers                                                 │
   │                                                                    │
   │ ❯ 1. context7                  ✔ connected · Enter to view details │
   │   2. serena                    ✔ connected · Enter to view details │
   │   3. task-master-ai            ✔ connected · Enter to view details │
   │   4. pal                       ✔ connected · Enter to view details │
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

**Updated:** `.claude/` (commands, skills, agents, scripts, settings), `.serena/`, `.taskmaster/` configs, and the sync infrastructure itself

**Preserved:** Project-specific values (name, language, prompts), user-scoped files (tasks, PRDs, local settings), gitignored files

### Sync Exclusions

If you've removed template files you don't need, prevent sync from re-adding them:

Edit `.github/template-state.json` and add a `sync_exclusions` array:

```diff
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
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
- Common patterns: `.claude/commands/cove/*` (entire directory), `.taskmaster/templates/example_prd.txt` (single file)

**Behavior:**

- Excluded files are NOT added if they exist upstream but not locally
- Excluded files are NOT updated if they exist in both places
- Excluded files are NOT flagged as deleted if they exist locally but not upstream
- Excluded files appear as "Excluded" in the sync report for transparency

### Migration for Existing Repositories

If your repo was created before the sync feature (or even if your repo wasn't created from this template at all), create `.github/template-state.json`:

```json
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v1.0.0",
  "synced_at": "1970-01-01T00:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-cool-project",
    "LANGUAGES": "go",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": "default"
  }
}
```

Then copy `.github/workflows/template-sync.yml` and `.github/scripts/template-sync.sh` from the [template repository](https://github.com/serpro69/claude-starter-kit).

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
├── agents/                 # 3 sub-agents (orchestrator, executor, checker)
├── commands/
│   ├── cove/              # 2 CoVe verification commands
│   └── tm/                # 47 Task Master commands
├── hooks/                 # Bash validation hook config
├── scripts/               # statusline.sh, validate-bash.sh
├── skills/                # 7 development workflow skills
├── settings.json          # Shared permission config
└── TM_COMMANDS_GUIDE.md   # Task Master command reference

.serena/
└── project.yml            # Serena LSP configuration

.taskmaster/
├── config.json            # AI model configuration
├── docs/                  # PRDs and requirements
├── reports/               # Analysis reports
├── tasks/                 # Task database and generated files
├── templates/             # Example PRD template
└── CLAUDE.md              # Task Master integration guide (400+ lines)

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

See [`LICENSE.md`](https://github.com/serpro69/claude-starter-kit/blob/master/LICENSE.md) file for more information.
