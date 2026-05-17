# Template Sync

Repos created from this template can pull configuration updates via the **Template Sync** workflow.

## Prerequisites

- `.github/template-state.json` must exist (created automatically for new repos, or [manually for older ones](../getting-started/adopting.md))
- Allow actions to create pull-requests: repo **Settings** → **Actions**

## Using Template Sync

=== "GitHub Actions (creates a PR)"

    1. Go to **Actions** → **Template Sync** → **Run workflow**
    2. Choose a version: `latest` (default), `master`, or a specific tag (e.g., `v1.2.3`)
    3. Optionally enable **dry_run** to preview changes without creating a PR
    4. Review and merge the created PR

=== "Claude Code"

    ```
    /kk:template:sync
    /kk:template:sync --version v1.2.3
    /kk:template:sync --dry-run
    ```

=== "Local script"

    ```bash
    .claude/toolbox/scripts/template-sync.sh --local
    .claude/toolbox/scripts/template-sync.sh --local --version v1.2.3
    .claude/toolbox/scripts/template-sync.sh --local --dry-run  # preview only
    ```

    Requires `jq`, `git`, `curl`, and `yq` ([mikefarah/yq](https://github.com/mikefarah/yq)). Review changes with `git diff` before committing.

## What Gets Synced

**Updated:** `.claude/` (settings, CLAUDE.extra.md, statusline scripts), `.codex/` (config.toml, hooks, rules, scripts, agents), and the sync infrastructure itself (see [Syncing Workflow Files](#syncing-workflow-files) for permission requirements). Skills, commands, and hooks are managed by the plugin system — not template sync.

**Preserved:** Project-specific values (name, language, prompts), `settings.local.json`, gitignored files.

### settings.json merge behavior

The sync uses smart-merge semantics — your downstream `settings.json` is "master" and upstream fills gaps:

- **New keys** from upstream are added (e.g., new deny patterns, new env vars)
- **Existing values** are never overwritten (your customizations are preserved)
- **Arrays** are concatenated with deduplication (e.g., new upstream deny rules are appended)
- **Manifest variables** (`CC_MODEL`, `CC_EFFORT_LEVEL`, etc.) still override after the merge — these are your explicit choices

## Sync Exclusions

If you've removed template files you don't need, prevent sync from re-adding them.

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
- Common patterns: `.claude/CLAUDE.extra.md` (single file), `.codex/*` (entire directory)

**Behavior:**

- Excluded files are NOT added if they exist upstream but not locally
- Excluded files are NOT updated if they exist in both places
- Excluded files are NOT flagged as deleted if they exist locally but not upstream
- Excluded files appear as "Excluded" in the sync report for transparency

## Syncing Workflow Files

Template sync updates its own workflow (`.github/workflows/template-sync.yml`) alongside everything else — the sync script is part of the `.claude/` directory and is synced as part of that tree. However, GitHub does not allow the default `GITHUB_TOKEN` to push changes to workflow files — the push is rejected with a `workflows` permission error ([details](https://github.com/peter-evans/create-pull-request/issues/3558)).

These updates are sometimes required for sync to work correctly (e.g., when the sync logic itself changes between versions), so skipping them indefinitely is not recommended.

### Option A: Update manually before running sync

Update the sync files locally, commit, push, then run the workflow:

```bash
VERSION="v0.12.0"  # use the version you want to sync to
curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-toolbox/${VERSION}/.github/workflows/template-sync.yml" \
  -o .github/workflows/template-sync.yml
```

Or use `/kk:template:sync` in Claude Code — it syncs everything including the workflow files.

### Option B: Set up a GitHub App for automatic sync

A GitHub App token has the `workflows` permission that `GITHUB_TOKEN` lacks. Once configured, the sync workflow handles everything automatically — no manual steps needed.

1. **Create a GitHub App** ([guide](https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md#authenticating-with-github-app-generated-tokens)) with these repository permissions:
    - **Contents:** Read & Write
    - **Pull requests:** Read & Write
    - **Workflows:** Read & Write

2. **Install the app** on the repository (or repositories) where you run template sync.

3. **Generate a private key** for the app (Settings → Private keys → Generate).

4. **Configure your repository:**
    - Add a **repository variable** named `CLAUDE_TOOLBOX_APP_ID` with the app's numeric ID
    - Add a **repository secret** named `CLAUDE_TOOLBOX_APP_KEY` with the app's private key (PEM contents)

    Go to repo **Settings** → **Secrets and variables** → **Actions** to add both.

The workflow detects these credentials automatically and uses them for both pushing the branch and creating the PR.

## Migrating from Task Master

Task Master MCP was removed in favor of native markdown-based task tracking integrated into the `design` and `implement` skills.

The easiest way to migrate is to run the migration command in Claude Code:

```
/kk:migrate-from-taskmaster:migrate
```

It will port pending tasks, clean up TM files, update configs, and walk you through each step with confirmation prompts.

??? note "Manual migration steps"

    If you prefer to migrate manually, follow these steps after syncing:

    1. **Port any pending tasks** to the new format: create `docs/wip/[feature]/tasks.md` files following the example task file in the plugin. Completed tasks don't need porting.

    2. **Remove Task Master files and config:**

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

    6. **Update the template-sync workflow** ([why?](https://github.com/serpro69/claude-toolbox/issues/17)): the old workflow contains taskmaster-specific sync logic that will break future syncs. Run `/kk:template:sync` or manually replace both files:

        ```bash
        VERSION="v0.3.0"  # or use latest tag
        curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-toolbox/${VERSION}/.github/workflows/template-sync.yml" \
          -o .github/workflows/template-sync.yml
        curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-toolbox/${VERSION}/.claude/toolbox/scripts/template-sync.sh" \
          -o .claude/toolbox/scripts/template-sync.sh
        chmod +x .claude/toolbox/scripts/template-sync.sh
        ```

    Task tracking now lives in simple markdown files (`docs/wip/[feature]/tasks.md`) created by the `design` skill and consumed by `implement`. No external MCP server required.

## Upgrading to the Plugin System (v0.5.0+)

Skills and commands have moved from the template to the **kk** plugin:

- Skills remain unprefixed: `/design` (annotated with `(kk)` in the menu)
- Commands are now namespaced: `/project:chain-of-verification` → `/kk:chain-of-verification:default`
- The template-sync workflow handles migration automatically on next sync
- After merging the sync PR, run `/plugin install kk@claude-toolbox`
