# Adopting into Existing Repositories

You don't need to create a repo from this template to use the full configuration and sync infrastructure. Any existing repo can adopt it.

## Steps

1. **Install the kk plugin** to get all skills, commands, and hooks:

    ```
    /plugin install kk@claude-toolbox
    ```

2. **Set up sync infrastructure.** Create `.github/template-state.json`:

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
        "CC_EFFORT_LEVEL": "high",
        "CC_PERMISSION_MODE": "default",
        "CC_STATUSLINE": "enhanced",
        "CODEX_MODEL": "gpt-5.5",
        "CODEX_APPROVAL_POLICY": "on-request",
        "SKIP_CAPY": "false"
      }
    }
    ```

    Copy `.github/workflows/template-sync.yml` and `.claude/toolbox/scripts/template-sync.sh` from the [template repository](https://github.com/serpro69/claude-toolbox).

3. **Run Template Sync** from your repo's Actions tab to pull in the configuration (settings, statusline, permissions). Review and merge the PR.

!!! tip
    Step 1 works standalone if you only want the skills. Steps 2-3 add the opinionated configuration and keep it in sync with upstream improvements.

## After Adoption

- Run [template sync](../user-guide/template-sync.md) to verify the setup: `/kk:template:sync --dry-run`
- Customize `.claude/settings.json` for your project's permission needs
- Edit `CLAUDE.md` with project-specific instructions
- See [MCP Servers](../user-guide/mcp-servers.md) for Context7, Pal, and Capy configuration
