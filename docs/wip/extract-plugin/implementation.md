# Implementation Plan: Extract to Claude Code Plugin

> Design: [./design.md](./design.md)
> Created: 2026-03-20

## Phase 1: Create the Plugin

### 1.1 Plugin Directory and Manifest

Create `klaude-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "kk",
  "description": "Development workflow skills, commands, and hooks from claude-toolbox",
  "version": "0.4.0",
  "author": {
    "name": "serpro69"
  },
  "homepage": "https://github.com/serpro69/claude-toolbox",
  "repository": "https://github.com/serpro69/claude-toolbox",
  "license": "MIT",
  "keywords": ["development", "workflow", "code-review", "testing", "documentation"]
}
```

### 1.2 Move Skills

Move all 9 skill directories from `.github/templates/claude/skills/` to `klaude-plugin/skills/`:

- `analysis-process/`
- `cove/`
- `development-guidelines/`
- `documentation-process/`
- `implementation-process/`
- `implementation-review/`
- `merge-docs/`
- `solid-code-review/`
- `testing-process/`

No content changes needed — skills work the same inside a plugin. The only difference is invocation: `/analysis-process` becomes `/kk:analysis-process`.

**Important**: Check every SKILL.md and supporting file for references to `$CLAUDE_PROJECT_DIR/.claude/` paths. Any references to sibling skills/commands may need updating since the plugin uses `${CLAUDE_PLUGIN_ROOT}` for its own files. Specifically, cross-references between skills (e.g., analysis-process referencing implementation-process) should use the new `/kk:` prefix if they reference skill names.

### 1.3 Move Commands

Move all 4 command directories from `.github/templates/claude/commands/` to `klaude-plugin/commands/`:

- `cove/` (cove.md, cove-isolated.md)
- `implementation-review/` (implementation-review.md)
- `migrate-from-taskmaster/` (migrate.md)
- `sync-workflow/` (sync-workflow.md)

**Note**: The `sync-workflow` command references `.claude/scripts/sync-workflow.sh`. This script stays in the template (it's sync infrastructure). The command's path reference needs to remain `$CLAUDE_PROJECT_DIR/.claude/scripts/sync-workflow.sh` since the script it invokes is part of the template, not the plugin.

### 1.4 Move Hooks and Validator Script

Create `klaude-plugin/hooks/hooks.json` with the PreToolUse hook config currently in `settings.json`:

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

Move `validate-bash.sh` from `.github/templates/claude/scripts/` to `klaude-plugin/scripts/`.

### 1.5 Create Marketplace Manifest

Create `.claude-plugin/marketplace.json` at the repo root:

```json
{
  "name": "claude-toolbox",
  "owner": {
    "name": "serpro69"
  },
  "metadata": {
    "description": "Development workflow plugin from claude-toolbox"
  },
  "plugins": [
    {
      "name": "kk",
      "source": "./klaude-plugin",
      "description": "Development workflow skills, commands, and hooks"
    }
  ]
}
```

## Phase 2: Update the Template

### 2.1 Slim Down `.github/templates/claude/`

Remove from `.github/templates/claude/`:

- `skills/` directory (entire tree)
- `commands/` directory (entire tree)
- `scripts/validate-bash.sh`

Keep:

- `settings.json` (will be modified)
- `CLAUDE.extra.md`
- `scripts/statusline.sh`
- `scripts/statusline_enhanced.sh`
- `scripts/sync-workflow.sh`

### 2.2 Update `settings.json`

Remove the `hooks` section (moved to plugin).

Add marketplace and plugin configuration:

```json
{
  "extraKnownMarketplaces": {
    "claude-toolbox": {
      "source": {
        "source": "local",
        "path": "./klaude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "kk@claude-toolbox": true
  }
}
```

Keep everything else (permissions, env, model, statusLine).

### 2.3 Update CLAUDE.extra.md

Check for any references to skill invocation that need the `/kk:` prefix. The task tracking section references `analysis-process`, `implementation-process`, `testing-process`, `documentation-process`, `solid-code-review`, `implementation-review` — these need to be updated to their namespaced form (e.g., `analysis-process` → `/kk:analysis-process`).

### 2.4 Update CLAUDE.md

Check the root `CLAUDE.md` for any references to skill names or `.claude/` paths that changed.

## Phase 3: Update Template Cleanup

### 3.1 Update `template-cleanup.sh`

In `execute_cleanup()`:

1. **Marketplace rewrite**: After variable substitution, replace the local-path marketplace config in `settings.json` with the GitHub `git-subdir` source:
   ```json
   {
     "extraKnownMarketplaces": {
       "claude-toolbox": {
         "source": {
           "source": "git-subdir",
           "url": "https://github.com/serpro69/claude-toolbox.git",
           "path": "klaude-plugin"
         }
       }
     }
   }
   ```
   Use `jq` to perform this substitution safely.

2. **Delete plugin and marketplace directories**: Add cleanup of `klaude-plugin/` and `.claude-plugin/` in the file removal step. These must be removed before the general template cleanup (the `find . -mindepth 1 -maxdepth 1 ...` command) or be added to its exclusion list and removed separately.

3. **"Next steps" output**: Update the printed instructions — remove the `/init` step, add a note about the plugin being available via marketplace.

### 3.2 Update `bootstrap.sh`

Replace the current bootstrap logic:

**Current**:
1. Run `claude -p --permission-mode "acceptEdits" /init`
2. Append `@.claude/CLAUDE.extra.md` import to CLAUDE.md
3. Commit and clean up

**New**:
1. Append `@.claude/CLAUDE.extra.md` import to CLAUDE.md (create minimal CLAUDE.md if it doesn't exist)
2. Run `claude plugin install kk@claude-toolbox`
3. Commit and clean up

Remove the `/init` call entirely (per issue #23, it's proving useless). Let users run `/init` on their own when the repo has actual code.

### 3.3 Update Template Cleanup Workflow

Review `.github/workflows/template-cleanup.yml` for any references to paths or files that changed.

## Phase 4: Update Template Sync

### 4.1 Update Sparse Checkout

In `fetch_upstream_templates()`, update the `git sparse-checkout set` command. Currently it fetches:
- `.github/templates`
- `.github/workflows/template-sync.yml`
- `.github/scripts/template-sync.sh`
- `docs/update.sh`

Add `klaude-plugin/.claude-plugin/plugin.json` to the sparse checkout — this is needed for migration detection. The actual plugin content is NOT synced (plugin system handles that).

### 4.2 Add Migration Detection

After fetching upstream and before comparing files, add a migration check function:

```
needs_plugin_migration():
  - Check if fetched upstream contains klaude-plugin/.claude-plugin/plugin.json
  - Check if local template-state.json does NOT have "plugin_migrated": true
  - Return true if both conditions met
```

### 4.3 Implement Migration Logic

When `needs_plugin_migration()` returns true:

1. **Build file removal list**: Enumerate the known template-managed files to remove. This is a static list of files that the old template synced:
   - `.claude/skills/analysis-process/` (and all contents)
   - `.claude/skills/cove/` (and all contents)
   - `.claude/skills/development-guidelines/` (and all contents)
   - `.claude/skills/documentation-process/` (and all contents)
   - `.claude/skills/implementation-process/` (and all contents)
   - `.claude/skills/implementation-review/` (and all contents)
   - `.claude/skills/merge-docs/` (and all contents)
   - `.claude/skills/solid-code-review/` (and all contents)
   - `.claude/skills/testing-process/` (and all contents)
   - `.claude/commands/cove/` (and all contents)
   - `.claude/commands/implementation-review/` (and all contents)
   - `.claude/commands/migrate-from-taskmaster/` (and all contents)
   - `.claude/commands/sync-workflow/` (and all contents)
   - `.claude/scripts/validate-bash.sh`

2. **Remove files**: Delete each file/directory from the list. Skip any that don't exist (may have been manually removed).

3. **Update settings.json**: Use `jq` to:
   - Remove the `hooks` section
   - Add `extraKnownMarketplaces` with the GitHub `git-subdir` source
   - Add `enabledPlugins` with `"kk@claude-toolbox": true`
   - Preserve all other settings

4. **Update template-state.json**: Add `"plugin_migrated": true` using `jq`.

5. **Track changes**: Add removed files to the sync diff report for PR description.

### 4.4 Update PR Description

When migration is detected, append additional content to the PR body:

- Explain that skills/commands have been migrated to a plugin
- List the files that were removed
- **Include instruction to run `/plugin install kk@claude-toolbox` after merging**
- Note that skills are now namespaced: `/skill-name` → `/kk:skill-name`

### 4.5 Update `compare_files()`

After migration, the sync script compares a slimmer set of template files. The `compare_files()` function already works dynamically based on what's in the staging directory, so it should handle the reduced file set automatically. Verify this is the case.

### 4.6 Update `apply_substitutions()`

This function applies project-specific variables to fetched templates. With fewer files in the template, there are fewer substitutions to make. The function should still work since it operates on whatever files exist in the staging directory. Verify this is the case.

## Phase 5: Update Tests

### 5.1 Existing Test Updates

- **`test-template-cleanup.sh`**: Update assertions to verify:
  - `klaude-plugin/` is deleted after cleanup
  - `.claude-plugin/` is deleted after cleanup
  - `settings.json` has GitHub marketplace config (not local path)
  - `settings.json` has no `hooks` section
  - `.claude/skills/` and `.claude/commands/` don't exist after cleanup

- **`test-template-sync.sh`**: Update assertions for the slimmer template. Add test cases for:
  - Migration detection (first sync after plugin change)
  - Migration execution (files removed, marketplace added, flag set)
  - Post-migration sync (normal sync with no migration)

- **`test-claude-extra.sh`**: Update if any skill name references changed to namespaced form.

### 5.2 New Plugin Tests

Add `test-plugin-structure.sh`:
- Verify `klaude-plugin/.claude-plugin/plugin.json` exists and is valid JSON
- Verify `klaude-plugin/skills/` contains expected skill directories
- Verify `klaude-plugin/commands/` contains expected command directories
- Verify `klaude-plugin/hooks/hooks.json` exists and is valid JSON
- Verify `klaude-plugin/scripts/validate-bash.sh` exists and is executable
- Verify `.claude-plugin/marketplace.json` exists and is valid JSON
- Verify marketplace plugin source points to `./klaude-plugin`

## Phase 6: Update Documentation

### 6.1 README.md

- Add section about the plugin system and how to install `kk`
- Update the architecture section to reflect the template/plugin split
- Update "Getting Started" to mention plugin installation
- Update troubleshooting for plugin-related issues

### 6.2 Skill/Command Rename Documentation

Document the namespace change for users upgrading:
- `/analysis-process` → `/kk:analysis-process`
- `/cove` → `/kk:cove`
- etc.

## File Reference

### Files Created

| File | Purpose |
|------|---------|
| `klaude-plugin/.claude-plugin/plugin.json` | Plugin manifest |
| `klaude-plugin/hooks/hooks.json` | Plugin hook configuration |
| `.claude-plugin/marketplace.json` | Marketplace catalog |

### Files Moved (template → plugin)

| From | To |
|------|-----|
| `.github/templates/claude/skills/*` | `klaude-plugin/skills/*` |
| `.github/templates/claude/commands/*` | `klaude-plugin/commands/*` |
| `.github/templates/claude/scripts/validate-bash.sh` | `klaude-plugin/scripts/validate-bash.sh` |

### Files Modified

| File | Changes |
|------|---------|
| `.github/templates/claude/settings.json` | Remove hooks, add marketplace/plugin config |
| `.github/templates/claude/CLAUDE.extra.md` | Update skill name references to namespaced form |
| `CLAUDE.md` | Update any skill/path references |
| `.github/scripts/template-cleanup.sh` | Marketplace rewrite, delete plugin/marketplace dirs |
| `.github/scripts/bootstrap.sh` | Replace /init with plugin install |
| `.github/scripts/template-sync.sh` | Migration detection and logic |
| `.github/workflows/template-cleanup.yml` | Review for path changes |
| `.github/workflows/template-sync.yml` | Review for path changes |

### Files Deleted (from template)

| File | Reason |
|------|--------|
| `.github/templates/claude/skills/` (entire tree) | Moved to plugin |
| `.github/templates/claude/commands/` (entire tree) | Moved to plugin |
| `.github/templates/claude/scripts/validate-bash.sh` | Moved to plugin |
