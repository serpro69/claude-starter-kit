# Plugin-Only Setup

Already have a project? Install just the plugin to get all 11 workflow skills.

## Claude Code

```
/plugin install kk@claude-toolbox
```

Skills are available as `/kk:(skill-name)` (annotated with `(kk)` in the slash command menu). The Claude plugin also includes commands, hooks (Bash validation), and sub-agents. See the [kk plugin documentation](https://github.com/serpro69/claude-toolbox/tree/master/klaude-plugin) for details.

!!! tip
    Want the full configuration too (settings, statusline, sync infrastructure)? See [Adopting into Existing Repositories](adopting.md).
    For MCP servers, see [MCP Server Configuration](../user-guide/mcp-servers.md).

## Codex

```bash
codex plugin marketplace add serpro69/claude-toolbox
```

The Codex plugin includes skills and language-specific profile content (review checklists, implementation gotchas, etc.). See [kodex-plugin](https://github.com/serpro69/claude-toolbox/tree/master/kodex-plugin) for details.

!!! note "Codex limitations"
    The Codex plugin provides **skills and profiles only** — it does not include hooks, sub-agents, Starlark rules, or project configuration. For the full Codex experience (SessionStart/PreToolUse hooks, sub-agents, config, rules), use the [template setup](template-setup.md) or [adopt into an existing repo](adopting.md).

For MCP servers (Context7, Pal), see [Codex MCP Setup](../user-guide/mcp-servers.md#codex).

## What's Included

The plugin gives you:

- **11 workflow skills** — `/kk:design`, `/kk:implement`, `/kk:review-code`, etc.
- **Language profiles** — Go, Java, JS/TS, Kotlin, Kubernetes, Python
- **Commands** — isolated variants for code review, CoVe, spec review, design review
- **Hooks** — Bash validation (Claude Code only)
- **Sub-agents** — independent reviewers (Claude Code only)

## What's Not Included

- MCP server configuration (Context7, Pal, Capy)
- Permission baselines and statusline
- Template sync infrastructure

For the full setup, use [Template Setup](template-setup.md) or [Adopt into Existing Repos](adopting.md).
