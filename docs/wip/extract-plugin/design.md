# Design: Extract to Claude Code Plugin

> Issue: [#33](https://github.com/serpro69/claude-sak/issues/33)
> Status: Draft
> Created: 2026-03-20

## Overview

Extract skills, commands, hooks, and utility scripts from the template into a Claude Code plugin. This enables easier distribution and updates via the plugin system, following Claude Code's recommended approach for sharing reusable functionality.

After this change, the repository serves dual purposes:

1. **Template repository** — users create new repos from this template, getting project-specific configuration (settings, CLAUDE.md instructions, Serena config, statusline, sync infrastructure)
2. **Plugin marketplace** — users install the `kk` plugin via `/plugin install kk@claude-sak` to get skills, commands, hooks, and scripts

## Problem Statement

The current approach distributes all functionality (skills, commands, hooks, scripts, settings) as template files copied into new repositories. Updates require the template-sync mechanism to push file-level changes via PRs. This has drawbacks:

- **Tight coupling**: skills and commands are mixed with project-specific config in `.github/templates/claude/`
- **Sync overhead**: every skill/command update goes through the template-sync PR workflow
- **No independent versioning**: skills can't be updated without a full template sync
- **Against CC recommendations**: Claude Code's plugin system is the intended distribution mechanism for reusable skills and commands

## Design Decisions

### Plugin Name: `kk`

Short, fast to type, memorable. Skills are invoked as `/kk:analysis-process`, `/kk:cove`, etc. The name can be thought of as "klaude-kit."

### Plugin Directory: `klaude-plugin/`

The plugin lives at `klaude-plugin/` in the repo root (not `claude-plugin/`) to avoid confusion with the `.claude-plugin/` marketplace manifest directory.

### What Moves to the Plugin

| Component | Current Location | Plugin Location |
|-----------|-----------------|-----------------|
| Skills (9) | `.github/templates/claude/skills/` | `klaude-plugin/skills/` |
| Commands (4) | `.github/templates/claude/commands/` | `klaude-plugin/commands/` |
| Hooks config | `.github/templates/claude/settings.json` (hooks section) | `klaude-plugin/hooks/hooks.json` |
| Bash validator | `.github/templates/claude/scripts/validate-bash.sh` | `klaude-plugin/scripts/validate-bash.sh` |

### What Stays in the Template

| Component | Location | Reason |
|-----------|----------|--------|
| `settings.json` | `.github/templates/claude/` | Permissions, env vars, model, statusline, marketplace config are project-specific |
| `CLAUDE.extra.md` | `.github/templates/claude/` | Always-loaded instructions; plugins have no mechanism to inject into CLAUDE.md import chain |
| Statusline scripts | `.github/templates/claude/scripts/` | Referenced by `settings.json` statusline command; no env var to reference plugin files from statusline context |
| Serena config | `.github/templates/serena/` | Project-specific (languages, project name) |
| Sync infrastructure | `.github/scripts/`, `.github/workflows/` | Template-specific automation |

### Marketplace Architecture

The repo root contains `.claude-plugin/marketplace.json` — the marketplace catalog pointing to `./klaude-plugin` as the plugin source.

**This repo (upstream)** consumes the plugin via local path:
```json
{
  "extraKnownMarketplaces": {
    "claude-sak": {
      "source": {
        "source": "local",
        "path": "./klaude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "kk@claude-sak": true
  }
}
```

**Downstream repos** consume from GitHub after template cleanup:
```json
{
  "extraKnownMarketplaces": {
    "claude-sak": {
      "source": {
        "source": "git-subdir",
        "url": "https://github.com/serpro69/claude-sak.git",
        "path": "klaude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "kk@claude-sak": true
  }
}
```

### Hook Migration

The `PreToolUse` bash validator hook moves from `settings.json` to the plugin's `hooks/hooks.json`. The hook script reference changes from `$CLAUDE_PROJECT_DIR/.claude/scripts/validate-bash.sh` to `${CLAUDE_PLUGIN_ROOT}/scripts/validate-bash.sh`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

## Impact on Existing Workflows

### Template Cleanup (new repos)

The cleanup script gains these additional responsibilities:

1. Replace local-path marketplace config in `settings.json` with GitHub `git-subdir` source
2. Delete `klaude-plugin/` directory (downstream repos install from GitHub)
3. Delete `.claude-plugin/` directory (downstream repos are consumers, not marketplace hosts)

The bootstrap script changes:

1. No longer runs `claude -p --permission-mode "acceptEdits" /init`
2. Adds the `@.claude/CLAUDE.extra.md` import to CLAUDE.md
3. Runs `claude plugin install kk@claude-sak` to install the plugin
4. Commits and cleans up

### Template Sync (existing repos)

The sync script needs a one-time migration path for existing downstream repos:

**Detection**: After fetching upstream, check if `klaude-plugin/.claude-plugin/plugin.json` exists in the fetched content AND `template-state.json` lacks `"plugin_migrated": true`.

**Migration logic** (runs once):

1. Delete known template-managed files from `.claude/` — only files that were previously synced from the template (specific skills, commands, hooks config, validate-bash.sh)
2. Add `extraKnownMarketplaces` and `enabledPlugins` to the local `settings.json`
3. Set `"plugin_migrated": true` in `template-state.json`
4. Add instructions in the PR description to run `/plugin install kk@claude-sak` after merge

**Post-migration syncs**: Only sync the slimmed template (settings.json, CLAUDE.extra.md, statusline scripts, serena config, sync infrastructure). Plugin updates happen through the plugin system itself.

### Slimmed Template

After migration, `.github/templates/claude/` contains only:

```
.github/templates/claude/
├── settings.json
├── CLAUDE.extra.md
└── scripts/
    ├── statusline.sh
    ├── statusline_enhanced.sh
    └── sync-workflow.sh
```

## Version

This change will be released as version **0.4.0**.
