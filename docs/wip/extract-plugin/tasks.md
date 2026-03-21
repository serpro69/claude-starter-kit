# Tasks: Extract to Claude Code Plugin

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-03-20

## Task 1: Create plugin structure and move files
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#phase-1-create-the-plugin](./implementation.md#phase-1-create-the-plugin)

### Subtasks
- [ ] 1.1 Create `klaude-plugin/.claude-plugin/plugin.json` with name `kk`, version `0.4.0`, metadata fields (author, homepage, repository, license, keywords)
- [ ] 1.2 Move all 9 skill directories from `.github/templates/claude/skills/` to `klaude-plugin/skills/` (analysis-process, cove, development-guidelines, documentation-process, implementation-process, implementation-review, merge-docs, solid-code-review, testing-process)
- [ ] 1.3 Move all 4 command directories from `.github/templates/claude/commands/` to `klaude-plugin/commands/` (cove, implementation-review, migrate-from-taskmaster, sync-workflow)
- [ ] 1.4 Move `.github/templates/claude/scripts/validate-bash.sh` to `klaude-plugin/scripts/validate-bash.sh`
- [ ] 1.5 Create `klaude-plugin/hooks/hooks.json` — extract the `hooks` object from `settings.json`, update script path to `${CLAUDE_PLUGIN_ROOT}/scripts/validate-bash.sh`
- [ ] 1.6 Create `.claude-plugin/marketplace.json` at repo root with name `claude-sak`, owner `serpro69`, single plugin entry pointing to `./klaude-plugin`
- [ ] 1.7 Scan all moved skill/command files for `$CLAUDE_PROJECT_DIR/.claude/` path references and cross-skill references — update any that now need `${CLAUDE_PLUGIN_ROOT}` or `/kk:` prefix. Leave references to template files (e.g., `sync-workflow.sh`) pointing at `$CLAUDE_PROJECT_DIR`

## Task 2: Update template configuration
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-2-update-the-template](./implementation.md#phase-2-update-the-template)

### Subtasks
- [ ] 2.1 Delete `.github/templates/claude/skills/` directory (entire tree — files already moved in Task 1)
- [ ] 2.2 Delete `.github/templates/claude/commands/` directory (entire tree — files already moved in Task 1)
- [ ] 2.3 Delete `.github/templates/claude/scripts/validate-bash.sh` (already moved in Task 1)
- [ ] 2.4 Update `.github/templates/claude/settings.json` — remove the `hooks` section, add `extraKnownMarketplaces` with local path source and `enabledPlugins` with `kk@claude-sak`
- [ ] 2.5 Update `.github/templates/claude/CLAUDE.extra.md` — change skill name references to namespaced form (`analysis-process` → `/kk:analysis-process`, etc.)
- [ ] 2.6 Review root `CLAUDE.md` for any skill name or `.claude/` path references that need updating

## Task 3: Update template-cleanup script
- **Status:** pending
- **Depends on:** Task 1, Task 2
- **Docs:** [implementation.md#phase-3-update-template-cleanup](./implementation.md#phase-3-update-template-cleanup)

### Subtasks
- [ ] 3.1 In `execute_cleanup()`, add `jq`-based marketplace rewrite — replace the local-path `extraKnownMarketplaces` source in `settings.json` with the GitHub `git-subdir` source (`serpro69/claude-sak`, path `klaude-plugin`)
- [ ] 3.2 Add deletion of `klaude-plugin/` and `.claude-plugin/` directories during cleanup — either add to the `find` exclusion/removal logic or handle as separate `rm -rf` before the general cleanup step
- [ ] 3.3 Update the "Next steps" output at the end of cleanup — remove the `/init` step, mention the plugin is available via marketplace
- [ ] 3.4 Update `bootstrap.sh` — remove the `claude -p --permission-mode "acceptEdits" /init` call, keep the `@.claude/CLAUDE.extra.md` import logic, add `claude plugin install kk@claude-sak`, update commit message
- [ ] 3.5 Review `.github/workflows/template-cleanup.yml` for any path or step references that need updating

## Task 4: Update template-sync script
- **Status:** pending
- **Depends on:** Task 1, Task 2
- **Docs:** [implementation.md#phase-4-update-template-sync](./implementation.md#phase-4-update-template-sync)

### Subtasks
- [ ] 4.1 In `fetch_upstream_templates()`, add `klaude-plugin/.claude-plugin/plugin.json` to the `git sparse-checkout set` command for migration detection
- [ ] 4.2 Add `needs_plugin_migration()` function — checks fetched upstream for `klaude-plugin/.claude-plugin/plugin.json` AND local `template-state.json` for absence of `"plugin_migrated": true`
- [ ] 4.3 Add `run_plugin_migration()` function implementing the migration logic:
  - Build static list of known template-managed files to delete (all skills, commands, hooks, validate-bash.sh — see implementation.md for full list)
  - Delete each file/directory, skip non-existent ones
  - Use `jq` to update `settings.json`: remove `hooks`, add `extraKnownMarketplaces` (GitHub git-subdir source), add `enabledPlugins`
  - Use `jq` to add `"plugin_migrated": true` to `template-state.json`
  - Track removed files for the diff report
- [ ] 4.4 Wire migration into the main sync flow — call `needs_plugin_migration()` after fetching upstream, call `run_plugin_migration()` before `compare_files()` if needed
- [ ] 4.5 Update PR description generation — when migration occurred, append explanation of the plugin change, list removed files, include instruction to run `/plugin install kk@claude-sak` after merge, note skill namespace change
- [ ] 4.6 Verify `compare_files()` and `apply_substitutions()` work correctly with the slimmer template (they operate on whatever files exist, so likely no changes needed — verify by reading the code)
- [ ] 4.7 Review `.github/workflows/template-sync.yml` for any path or step references that need updating — specifically the "Apply Staged Changes" step which copies files to `.claude/`

## Task 5: Update tests
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4
- **Docs:** [implementation.md#phase-5-update-tests](./implementation.md#phase-5-update-tests)

### Subtasks
- [ ] 5.1 Create `test/test-plugin-structure.sh` — validate plugin manifest JSON, marketplace manifest JSON, expected skill/command directories exist, hooks.json is valid, validate-bash.sh is executable, marketplace source points to `./klaude-plugin`
- [ ] 5.2 Update `test/test-template-cleanup.sh` — add assertions that `klaude-plugin/` and `.claude-plugin/` are deleted after cleanup, `settings.json` has GitHub marketplace config (not local path), `settings.json` has no `hooks` section, `.claude/skills/` and `.claude/commands/` don't exist
- [ ] 5.3 Update `test/test-template-sync.sh` — add test cases for: migration detection (first sync after plugin change), migration execution (files removed, marketplace added, flag set in template-state.json), post-migration sync (normal sync, no re-migration)
- [ ] 5.4 Update `test/test-claude-extra.sh` if skill name references changed to namespaced form
- [ ] 5.5 Run the full test suite and fix any failures: `for test in test/test-*.sh; do $test; done`

## Task 6: Update documentation
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5
- **Docs:** [implementation.md#phase-6-update-documentation](./implementation.md#phase-6-update-documentation)

### Subtasks
- [ ] 6.1 Update `README.md` — add plugin system section, update architecture description, update "Getting Started" with plugin installation, update troubleshooting
- [ ] 6.2 Document the skill namespace change for upgrading users (`/skill-name` → `/kk:skill-name`)

## Task 7: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6

### Subtasks
- [ ] 7.1 Run `/kk:testing-process` skill to verify all tasks — full test suite, integration tests, edge cases
- [ ] 7.2 Run `/kk:documentation-process` skill to update any relevant docs
- [ ] 7.3 Run `/kk:solid-code-review` skill with bash language input to review the implementation
- [ ] 7.4 Run `/kk:implementation-review` skill to verify implementation matches design and implementation docs
