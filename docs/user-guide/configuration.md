# Configuration

claude-toolbox provides opinionated defaults for permissions, statusline, hooks, and project settings.

## How Configuration Works

!!! note
    Claude Code settings are split between two project-scoped files:

    - **`.claude/settings.json`** — upstream-managed defaults, synced from this template (permissions baseline, env vars, model, plugins, statusline)
    - **`.claude/settings.local.json`** — your per-repo overrides, never synced (hooks, MCP server enables, additional permissions, personal preferences)

    You can edit `settings.json` directly — values will be intelligently merged with upstream settings. But the general advice is to place your customizations in `settings.local.json`. As an added bonus, "Don't ask again" grant prompts in Claude Code sessions land in local settings automatically (as of v2.1.92).

## Permission Baselines

The template ships with a tuned permission set:

- **Read-only tools** — always allowed (file reads, glob, grep, git status)
- **Write tools** — allowed for project files (edit, write)
- **Bash commands** — allowed for safe patterns (git, npm, go, make, python, etc.)
- **Blocked patterns** — `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`

Customize in `.claude/settings.json` under `permissions.allow` and `permissions.deny`. Per-repo MCP tool permissions go in `settings.local.json`.

## Hooks

The plugin ships one hook:

| Hook | Trigger | Description |
|------|---------|-------------|
| Bash validation | `PreToolUse` on `Bash` | Blocks commands touching `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`, and other sensitive paths |

## Statusline

Rich statusline with model, context %, git branch, session duration, thinking mode, and rate limits.

**Themes:** Set `CLAUDE_STATUSLINE_THEME` to `darcula`, `nord`, or `catppuccin`, and `CLAUDE_STATUSLINE_MODE` to `dark` (default) or `light` to match your terminal background.

## Recommended Settings

!!! tip
    Configure via `claude /config`. The config file is usually at `~/.claude.json`.

**I can't recommend enough disabling auto-compact** — I've seen many a time claude starting to compact conversations in the middle of a task, which produces very poor results for the remaining work it does after compacting.

??? example "Full `/config` settings"

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

## Project Instructions

- `CLAUDE.md` — project-specific instructions for Claude Code (checked into the repo)
- `.claude/CLAUDE.extra.md` — behavioral instructions (independent thinking, fail-loud, assumptions)
- `AGENTS.md` — equivalent instructions for Codex
