# Codex

Codex (OpenAI) is supported as a secondary provider. Skills are generated from the canonical `klaude-plugin/` source via the `generate-kodex` tool.

## Setup

1. Install [Codex](https://openai.com/index/codex/)
2. Install the plugin: `codex plugin marketplace add serpro69/claude-toolbox`
3. Configure [MCP servers](../user-guide/mcp-servers.md#codex) at the user level

## Configuration Files

| File | Purpose |
|------|---------|
| `.codex/config.toml` | Main configuration |
| `.codex/hooks.json` | Pre-tool-use hooks |
| `.codex/rules/default.rules` | Starlark permission rules |
| `.codex/scripts/session-start.sh` | Behavioral instructions (session startup) |
| `.codex/agents/*.toml` | Sub-agent definitions (generated) |
| `kodex-plugin/` | Skills (generated from `klaude-plugin/`) |
| `AGENTS.md` | Project instructions |

## Known Limitations

!!! warning "Current limitations"

    - **Plugin-only installs** provide skills and profile content only — hooks, sub-agents, rules, and project config require [template setup](../getting-started/template-setup.md) or [adopting into an existing repo](../getting-started/adopting.md).
    - **PreToolUse hooks** are only wired for Bash commands. `apply_patch` and MCP tool hooks are documented in [ADR 0005](../adr/0005-codex-hook-enforcement-gap.md) but not yet implemented.
    - **MCP servers** (Context7, Pal) must be configured at the user level — they are not packaged in the plugin. See [Codex MCP Setup](../user-guide/mcp-servers.md#codex).

## Generation Pipeline

`klaude-plugin/` is the single source of truth. The generation tool:

1. Reads `klaude-plugin/` skills and agents
2. Applies Codex-specific transformations (resolves `${CLAUDE_PLUGIN_ROOT}`, injects headers)
3. Produces `kodex-plugin/` (skills) and `.codex/agents/*.toml` (sub-agents)

After editing skills in `klaude-plugin/`, regenerate with:

```bash
make generate-kodex
```

CI checks freshness via `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/`.
