# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a starter template repository designed to provide a complete development environment for Claude Code with pre-configured MCP servers and tools for AI-powered development workflows. The repository is intentionally minimal, containing only configuration templates for three primary systems: Claude Code, Serena, and Task Master.

## Architecture

This is a **configuration-only repository** - there is no application code. The architecture consists of three integrated MCP server configurations:

### 1. Claude Code Configuration (`.claude/`)

- **settings.local.json**: Permission allowlist/denylist for tools and MCP servers
- **commands/tm/**: 50+ slash commands for Task Master workflows organized hierarchically
- **TM_COMMANDS_GUIDE.md**: Complete command reference for Task Master integration

### 2. Serena MCP Configuration (`.serena/`)

- **project.yml**: Semantic code analysis configuration
  - Language detection (empty by default - set via template-cleanup workflow)
  - Gitignore integration
  - Tool exclusions
  - Read-only mode settings

Purpose: Provides intelligent code navigation, symbol analysis, and semantic understanding of codebases through LSP integration.

### 3. Task Master Configuration (`.taskmaster/`)

- **config.json**: AI model configuration for task generation and management
  - Main model: claude-code/sonnet
  - Research model: claude-code/opus
  - Fallback model: claude-code/sonnet
  - Global project settings (10 default tasks, 5 default subtasks)
- **CLAUDE.md**: Comprehensive Task Master integration guide (400+ lines)
- **templates/example_prd.txt**: Example Product Requirements Document format

Purpose: Provides AI-powered task management, PRD parsing, complexity analysis, and development workflow orchestration.

## Required API Keys

The following API keys must be configured in `~/.claude.json` under the `mcpServers` object (NOT in this repository):

### Essential Keys

- **Context7 API Key** (`CONTEXT7_API_KEY`): Up-to-date library documentation
- **Gemini API Key** (`GEMINI_API_KEY`): Pal MCP server (or alternative provider - see pal docs)

### Task Master Keys (at least one required)

- `ANTHROPIC_API_KEY` (recommended for Claude models)
- `PERPLEXITY_API_KEY` (recommended for research features)
- `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `OPENROUTER_API_KEY`, `XAI_API_KEY`

## MCP Server Configuration

All MCP servers must be configured in `~/.claude.json` (user-level) to prevent committing API keys. See README.md lines 24-77 for complete configuration examples.

### MCP Server Descriptions

**context7**: Library documentation lookup and code examples
**serena**: Semantic code analysis via LSP with symbol-based navigation
**task-master-ai**: AI-powered task management and workflow orchestration
**pal**: Multi-model AI integration for chat, debugging, code review, planning

### Verification

Run `/mcp` in Claude Code to verify all four servers are connected.

## Getting Started Workflow

1. **Create from template**: Use GitHub's "Use this template" button
2. **Run template-cleanup workflow**: Configure language and Task Master settings
   - Set `LANGUAGES` for Serena (comma-separated, required - see Serena language support docs)
   - Optional: Set Task Master custom prompts and permission modes
3. **Clone repository**
4. **Verify MCP setup**: Run `/mcp` to confirm all servers connected
5. **Initialize CLAUDE.md**: Run `/init` to create project-specific guidance
6. **Start using**: Reference `.claude/TM_COMMANDS_GUIDE.md` for available slash commands

## Permission Configuration

The `.claude/settings.local.json` file controls tool access:

### Allowed Tools (Auto-approved)

- File operations: `cat`, `ls`, `mkdir`
- All Context7 tools for documentation lookup
- Serena read-only tools: `get_symbols_overview`, `find_file`, `find_symbol`, `list_dir`, `search_for_pattern`
- Task Master workflow tools: task operations, complexity analysis, PRD parsing
- Pal code review: `mcp__pal__codereview`
- `WebSearch` for documentation lookup

### Denied Tools

- Direct CLI: `Bash(task-master:*)` (use MCP tools instead)
- Generated reports: `consensus*.md`, `review*.md` (prevent context pollution)

## Task Master Integration

Task Master is the primary workflow orchestration system. Key integration points:

### Slash Command Structure

Commands are organized under `/project:tm/[category]/[action]`:

- Setup: `/project:tm/setup/quick-install`, `/project:tm/init/quick`
- Daily: `/project:tm/next`, `/project:tm/list`, `/project:tm/show <id>`
- Status: `/project:tm/set-status/to-{done|in-progress|review|pending|deferred|cancelled} <id>`
- Analysis: `/project:tm/analyze-complexity`, `/project:tm/expand <id>`
- Workflows: `/project:tm/workflows/smart-flow`, `/project:tm/workflows/auto-implement`

### Working with Tasks

1. Parse requirements: `/project:tm/parse-prd .taskmaster/docs/prd.txt`
2. Analyze complexity: `/project:tm/analyze-complexity --research`
3. Expand tasks: `/project:tm/expand/all`
4. Get next task: `/project:tm/next`
5. Update progress: Use MCP `update_subtask` to log implementation notes
6. Complete: `/project:tm/set-status/to-done <id>`

### MCP vs CLI

**Always prefer MCP tools over CLI commands** - the permission configuration enforces this by denying `Bash(task-master:*)`. Benefits:

- Better error handling
- Automatic permission management
- Structured outputs
- No shell escaping issues

See `.taskmaster/CLAUDE.md` for complete 400+ line Task Master integration guide.

## Serena Best Practices

Serena provides semantic code analysis - use it efficiently:

### Intelligent Code Reading Strategy

1. **Never read entire files** unless absolutely necessary
2. **Start with overview**: Use `get_symbols_overview` to see top-level structure
3. **Target symbol reads**: Use `find_symbol` with `include_body=true` only for specific symbols
4. **Pattern search**: Use `search_for_pattern` for flexible regex-based discovery
5. **Reference tracking**: Use `find_referencing_symbols` to understand usage

### Symbol Navigation

Symbols are identified by `name_path` and `relative_path`:

- Top-level: `ClassName` or `function_name`
- Methods: `ClassName/method_name`
- Nested: `OuterClass/InnerClass/method`
- Python constructors: `ClassName/__init__`

### Efficiency Principles

- Read symbol bodies incrementally as needed
- Use `depth` parameter to get method lists without bodies: `find_symbol("Foo", depth=1, include_body=False)`
- Avoid re-reading code you've already seen
- Use symbolic tools BEFORE reading full files

## Important Notes

### File Management

- **Never manually edit** `.taskmaster/tasks/tasks.json` - use Task Master commands
- **Never manually edit** `.taskmaster/config.json` - use `/project:tm/models/setup`
- Task markdown files in `.taskmaster/tasks/*.md` are auto-generated

### Template Cleanup Workflow

The repository includes a GitHub workflow that customizes the template:

- Sets Serena language configuration
- Configures Task Master custom system prompts
- Allows permission mode customization
- Run once after creating repository from template

### Context Management

- Use `/clear` frequently between different tasks
- This CLAUDE.md is automatically loaded
- Task Master commands pull task context on demand
- Generated reports (consensus, reviews) are denied from Read tool to prevent context bloat

### Git Integration

- Repository is a Git repo (branch: master)
- Serena respects `.gitignore` by default
- Task Master can track progress alongside commits
- Use conventional commits with task IDs: `feat: implement JWT auth (task 1.2)`

### Template Sync

- `.github/template-state.json` tracks template version and configuration variables
- Use Actions → Template Sync to pull upstream configuration updates
- Always review PR changes before merging to preserve local customizations
- Sync preserves project-specific values (name, language, prompts) via manifest variables
- User-scoped files like `.taskmaster/tasks/`, `.taskmaster/docs/`, and `.taskmaster/reports/` are never modified
- Sync infrastructure (workflow and script) are also updated when upstream has changes

### Sync Exclusions

- Users can add `sync_exclusions` array to `.github/template-state.json` to prevent specific paths from being synced
- Patterns use glob syntax (e.g., `.claude/commands/cove/*`)
- See README.md "Configuring Sync Exclusions" section for details

## Testing

The repository includes a comprehensive test suite for the template-sync feature located in the `test/` directory.

### Test Directory Structure

```
test/
├── helpers.sh                    # Shared test utilities and assertions
├── test-manifest-jq.sh           # Tests for jq JSON patterns
├── test-template-sync.sh         # Tests for template-sync.sh functions
├── test-template-cleanup.sh      # Tests for generate_manifest() function
└── fixtures/
    ├── manifests/                # JSON manifest test fixtures
    │   ├── valid-manifest.json
    │   ├── invalid-json.txt
    │   ├── missing-schema-version.json
    │   ├── missing-variables.json
    │   ├── unsupported-schema.json
    │   └── invalid-upstream-repo.json
    └── templates/                # Template file fixtures
        ├── claude/settings.json
        ├── serena/project.yml
        └── taskmaster/config.json
```

### Running Tests

```bash
# Run all test suites
for test in test/test-*.sh; do $test; done

# Run individual test suite
./test/test-manifest-jq.sh
./test/test-template-sync.sh
./test/test-template-cleanup.sh
```

### Test Coverage

| Test Suite               | Tests | Coverage                                                                                                                          |
| ------------------------ | ----- | --------------------------------------------------------------------------------------------------------------------------------- |
| test-manifest-jq.sh      | 17    | jq patterns, JSON generation, special characters, round-trip validation                                                           |
| test-template-sync.sh    | 37    | CLI parsing, manifest reading/validation, sed escaping, substitutions, file comparison, diff reports, sync infrastructure copying |
| test-template-cleanup.sh | 18    | Manifest generation, field validation, variable capture, special characters, git tag/SHA detection                                |

### Writing New Tests

Tests use shared utilities from `test/helpers.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/helpers.sh"

log_section "Section Name"

log_test "Test description"
# ... test logic ...
assert_equals "expected" "$actual" "Assertion message"

print_summary
```

**Available Assertions:**

- `assert_equals "expected" "actual" "message"` - Compare values
- `assert_not_equals "unexpected" "actual" "message"` - Verify inequality
- `assert_file_exists "path" "message"` - Check file exists
- `assert_dir_exists "path" "message"` - Check directory exists
- `assert_exit_code expected "command" "message"` - Verify exit code
- `assert_output_contains "needle" "command" "message"` - Check command output
- `assert_json_valid "json_string" "message"` - Validate JSON syntax
- `assert_json_field "json" "jq_path" "expected" "message"` - Check JSON field

**Helper Functions:**

- `create_temp_dir "prefix"` - Create temp directory (auto-cleaned)
- `create_temp_git_repo "tag"` - Create temp git repo with optional tag
- `cleanup_temp` - Manual cleanup (automatic on exit)

## Common Issues

### MCP Connection Problems

1. Check `~/.claude.json` has all four servers configured with correct API keys
2. Verify Node.js and uv installed for server execution
3. Use `--mcp-debug` flag when starting Claude Code
4. Run `/mcp` to see connection status

### Task Master AI Failures

1. Verify at least one API key configured in `.taskmaster/config.json`
2. Check model configuration: `/project:tm/models`
3. AI operations take up to a minute - be patient
4. Use `--research` flag for enhanced operations (requires Perplexity or research-capable model)

### Serena Language Detection

1. If semantic analysis fails, check `.serena/project.yml` has correct `language` value
2. Run template-cleanup workflow to set language automatically
3. See Serena documentation for supported languages and requirements (e.g., C# requires .sln file)

### Template Sync Issues

1. "Manifest not found" - Repository needs `.github/template-state.json`; see README migration section
2. "Version not found" - Use `latest`, `main`, or existing git tags from upstream
3. Merge conflicts in PR - Review diff, edit PR branch to preserve customizations, or revert specific files

## Resources

- **Task Master Docs**: .taskmaster/CLAUDE.md (400+ lines of integration guidance)
- **Command Guide**: .claude/TM_COMMANDS_GUIDE.md (complete slash command reference)
- **Serena Language Support**: https://github.com/oraios/serena#programming-language-support
- **Pal Getting Started**: https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/getting-started.md
- **Context7**: https://context7.com/

## Claude-Code Behavioral Instructions

Always follow these guidelines for the given phase.

### Exploration Phase

When you run Explore:

- DO NOT spawn exploration agents unless explicitly asked to do so by the user. **Always explore everything on your own** to gain a complete and thorough understanding.
  <!-- Why: Claude tends to first spawn exploration agents,
       and then re-reads all the files on it's own...
       resulting in double token consumption -->

## Task Master AI Instructions

**IMPORTANT!!! Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**

@./.taskmaster/CLAUDE.md
