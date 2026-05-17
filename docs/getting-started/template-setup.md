# Template Setup

Use the GitHub template to create a new project with the full claude-toolbox configuration pre-wired.

## Steps

1. **Create from template**: [Create a new project from this template](https://github.com/new?template_name=claude-toolbox&template_owner=serpro69) using the **Use this template** button.

2. **Initialize the template** — choose one method:

    === "Option A: GitHub Actions (recommended)"

        Go to your new repo's **Actions** tab → **Template Cleanup** → **Run workflow**. Provide:

        - `LANGUAGES` (required) — programming languages, comma-separated (e.g., `python`, `python,typescript`)
        - Other inputs are optional with sensible defaults

    === "Option B: Run locally"

        ```bash
        ./.claude/toolbox/scripts/template-cleanup.sh
        ```

        Interactive mode walks you through each option. Run with `--help` for all flags, or pass them directly:

        ```bash
        ./.claude/toolbox/scripts/template-cleanup.sh --languages python,typescript -y
        ```

3. **Clone your repo** (if using Option A) and **verify MCP servers**:

    ```
    > /mcp
    ╭────────────────────────────────────────────────────────────────────╮
    │ Manage MCP servers                                                 │
    │                                                                    │
    │ ❯ 1. context7                  ✔ connected · Enter to view details │
    │   2. pal                       ✔ connected · Enter to view details │
    ╰────────────────────────────────────────────────────────────────────╯
    ```

    The kk plugin (skills, commands, hooks) is available via the claude-toolbox marketplace configured in `.claude/settings.json`.

4. **Finalize initialization**:

    ```bash
    chmod +x .claude/toolbox/scripts/bootstrap.sh && ./.claude/toolbox/scripts/bootstrap.sh
    ```

    This installs the kk plugin, wires up the Capy knowledge base (if installed), and commits the configuration.

5. **Recommended:** Run `/config` in Claude Code and **disable Auto-compact**. This prevents Claude from compacting context mid-task, which degrades quality significantly. See [Recommended Settings](../user-guide/configuration.md#recommended-settings) for the full config.

6. [Try it out!](quickstart.md)

## What You Get

- `.claude/` — settings, statusline, sync infrastructure
- `.codex/` — Codex-equivalent configuration
- `CLAUDE.md` / `AGENTS.md` — project instructions
- Template sync — pull future updates from upstream

## Next Steps

- [Try It](quickstart.md) — run the pipeline in 5 minutes
- [Template Sync](../user-guide/template-sync.md) — how to receive upstream updates
- [MCP Servers](../user-guide/mcp-servers.md) — configure Context7, Pal, Capy
