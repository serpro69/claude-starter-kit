# claude-starter-kit

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)

Starter template repo for all your Claude Code needs

## About

This is a starter template repository designed to provide a complete development environment for Claude-Code with pre-configured MCP servers and tools for AI-powered, collaborative, development workflows. The defaults are intentionally minimal, containing only configuration templates for three primary systems: Claude Code, Serena, and Task Master. Users can opt-in to additional claude-code features like [skills](https://code.claude.com/docs/en/skills), [plugins](https://code.claude.com/docs/en/plugins), [hooks](https://code.claude.com/docs/en/hooks-guide), [sub-agents](https://code.claude.com/docs/en/sub-agents), and so on.

> [!NOTE]
> This configuration also focuses on collaborative development workflows where multiple developers are working on the same code-base, which is one of the reasons why most of claude- and mcp-related settings are local-scoped (i.e. most claude settings will be in `.claude/settings.local.json` so they can be shared with the entire dev team, and not in user-scoped `~/claude/settings.json`, which are harder to share with others.)
>
> For this same reason, most of the claude/mcp configuration files are not git-ignored, but instead committed to the repo.

## Features

- **🤖 Four Pre-Configured MCP Servers**
  - **Context7**: Up-to-date library documentation and code examples
  - **Serena**: Semantic code analysis with LSP integration for intelligent navigation
  - **Task Master**: AI-powered task management and workflow orchestration
  - **Pal**: Multi-model AI integration for debugging, code review, and planning

- **⚙️ Automated Template Cleanup**
  - GitHub Actions workflow for one-click repository initialization
  - Configurable inputs for language detection and Task Master settings
  - Automatic cleanup of template-specific files for a clean starting point

- **📋 50+ Task Master Slash Commands**
  - Pre-configured hierarchical command structure under `/project:tm/`
  - Commands for task management, complexity analysis, PRD parsing, and workflows
  - Complete command reference in `.claude/TM_COMMANDS_GUIDE.md`

- **🔍 Intelligent Code Navigation**
  - Serena's symbol-based code analysis for efficient exploration
  - Token-efficient reading with overview and targeted symbol queries
  - Reference tracking and semantic understanding across your codebase

- **📝 Configuration Templates**
  - Ready-to-use templates for `.serena/`, `.taskmaster/`, and `.claude/` directories
  - Placeholder-based customization with repository-specific values
  - Permission configuration for tool access control

- **📚 Comprehensive Documentation**
  - Project-level `CLAUDE.md` with integration guidance
  - Task Master integration guide with 400+ lines of best practices
  - Complete workflow specification and command references

## Requirements

You will need the following on your workstation:

### Tools

- [npm](https://www.npmjs.com/package/npm)
- [uv](https://docs.astral.sh/uv/)
- [jq](https://jqlang.github.io/jq/) - Required for `.github/scripts/template-cleanup.sh`

### API Keys

- [Context7](https://context7.com/) API key
- Gemini API key for [pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server). You don't need to use gemini and can configure pal with any other provider/models. See [pal getting started docs](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/getting-started.md) for more details.

### Claude `claude.json` mcp settings

You need to have `mcpServers` present and configured in your `~/.claude.json`.

> [!NOTE]
> The reason we put them in the user's `claude.json` configuration, instead of repo local settings, is to prevent committing API keys, which some MCP servers might require.
>
> These configs are also generic enough that they can be re-used across every project, and hence is better placed in user's settings.

Here's an example `mcpServers` object that you can use as a reference:

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

## Quick Start

1. [Create a new project based on this template repository](https://github.com/new?template_name=claude-starter-kit&template_owner=serpro69) using the Use this template button.

2. A scaffold repo will appear in your GitHub account.

3. Run the `template-cleanup` workflow from your new repo, and provide some inputs for your specific use-case.

**Serena MCP Configuration Inputs:**

- `LANGUAGES` (required) - programming languages for your project, comma-separated (e.g., `python`, `python,typescript`). See [Serena Programming Language Support & Semantic Analysis Capabilities](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities) for supported languages

- `SERENA_INITIAL_PROMPT` - initial prompt for the project; it will always be given to the LLM upon activating the project

> [!TIP]
> Take a look at serena [project.yaml](./.github/templates/serena/project.yml) configuration file for more details.

**Task-Master MCP Configuration Inputs:**

- `TM_CUSTOM_SYSTEM_PROMPT` - custom system prompt to override Claude Code's default behavior

- `TM_APPEND_SYSTEM_PROMPT` - append additional content to the system prompt

- `TM_PERMISSION_MODE` - permission mode for file system operations

> [!TIP]
> See [Task Master Advanced Claude Code Settings Usage](https://github.com/eyaltoledano/claude-task-master/blob/main/docs/examples/claude-code-usage.md#advanced-settings-usage) for more details on the above parameters.

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

     analysis-process
     Turn the idea for a feature into a fully-formed PRD/design/specification and implementation-plan. Use in pre-implementation (idea-to-design) stages to make sure you
     understand the requirements and have a correct implementation plan before writing actual code.

     documentation-process
     After implementing a new feature or fixing a bug, make sure to document the changes. Use after finishing the implementation phase for a feature or a bug-fix.

     task-master-process
     Workflow for task-master-ai when working with task-master tasks and PRDs. Use when creating or parsing PRDs from requirements, adding/updating/expanding tasks and other task-master-ai operations.

     testing-process
     Guidelines describing how to test the code. Use whenever writing new or updating existing code, for example after implementing a new feature or fixing a bug.

     ---
     These skills provide specialized workflows for different stages of development. You can invoke any of them by asking me to use a specific skill (e.g., "use the analysis-process skill" or "help me document this feature").
   ```

5. Update the `README.md` with a full description of your project, then run `chmod +x bootstrap.sh && ./bootstrap.sh` to finalize initialization of the repo.

6. Profit

## Receiving Template Updates

Repositories created from this template can receive configuration updates via the Template Sync feature.

### Prerequisites

- Repository must have been created after template sync feature was added, OR
  - Manually create `.github/template-state.json` (see Migration section below)
- Allow actions to create pull-requests in the repo. Go to repo Settings -> Actions
  <img width="792" height="376" alt="image" src="https://github.com/user-attachments/assets/81343169-fa87-4631-ad5d-60fde7685538" />

### Using Template Sync

1. Navigate to **Actions** → **Template Sync**
2. Click **Run workflow**
3. Configure options:
   - **version**: `latest` (default), `main`, or specific tag (e.g., `v1.2.0`)
   - **dry_run**: Check to preview changes without creating a PR
4. Review the created Pull Request
5. Merge to apply updates

### What Gets Updated

- `.claude/` - Claude Code commands, skills, scripts, settings
- `.serena/` - Serena semantic analysis configuration
- `.taskmaster/` - Task Master configuration and templates
- The sync infa itself (workflow and script)

### What's Preserved

- Project-specific values (name, language, custom prompts)
- User-scoped files (tasks, PRDs, local settings)
- Any gitignored files

### Migration for Existing Repositories

If your repository was created before the sync feature, create `.github/template-state.json` manually:

```json
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T00:00:00Z",
  "variables": {
    "PROJECT_NAME": "your-project-name",
    "LANGUAGES": "typescript",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": "default"
  }
}
```

Then manually copy `.github/workflows/template-sync.yml` and `.github/scripts/template-sync.sh` from the [template repository](https://github.com/serpro69/claude-starter-kit).

### Post-Init Settings

The following tweaks are not mandatory, but will more often than not improve your experience with CC

#### Claude Code Configuration

> [!TIP]
> The following config parameters can be easily configured via `claude /config` command.
>
> The config file can also be modified manually and is usually found at `~/.claude.json`

This is my current config, you may want to tweak it to your needs. **I can't recommend enough disabling auto-compact** feature and controlling the context window manually. I've seen many a time claude starting to compact conversations in the middle of a task, which produces very poor results for the remaining work it does after compacting.

```

> /config
────────────────────────────────────────────────────────────
 Configure Claude Code preferences

   Auto-compact                              false
   Show tips                                 true
   Thinking mode                             true
   Prompt suggestions                        true
   Rewind code (checkpoints)                 true
   Verbose output                            false
   Terminal progress bar                     true
   Default permission mode                   Default
   Respect .gitignore in file picker         true
   Theme                                     Dark mode
   Notifications                             Auto
   Output style                              default
   Editor mode                               vim
   Model                                     claude-opus-4-5
   Auto-connect to IDE (external terminal)   false
   Claude in Chrome enabled by default       false
```

## Development

### Running Tests

The repository includes a test suite for the template-sync feature. Tests are located in the `test/` directory.

```bash
# Run all test suites
for test in test/test-*.sh; do $test; done

# Run individual test suite
./test/test-manifest-jq.sh       # jq JSON pattern tests
./test/test-template-sync.sh     # template-sync.sh function tests
./test/test-template-cleanup.sh  # generate_manifest() tests
```

**Test Coverage:**

| Test Suite               | Description                                                        |
|--------------------------|--------------------------------------------------------------------|
| test-manifest-jq.sh      | JSON generation, special character handling, round-trip validation |
| test-template-sync.sh    | CLI parsing, manifest validation, substitutions, file comparison   |
| test-template-cleanup.sh | Manifest generation, variable capture, git tag/SHA detection       |

### Test Directory Structure

```
test/
├── helpers.sh              # Shared test utilities and assertions
├── test-manifest-jq.sh     # jq pattern tests
├── test-template-sync.sh   # Sync script function tests
├── test-template-cleanup.sh # Cleanup script tests
└── fixtures/
    ├── manifests/          # JSON manifest test fixtures
    └── templates/          # Template file fixtures
```

## Examples

Some examples of the actual claude-code workflows that were executed using templates, configs, skills, and other tools from this repository can be found in [examples](./examples) directory.
