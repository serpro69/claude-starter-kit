# Template Sync Consolidation

Refs: https://github.com/serpro69/claude-toolbox/issues/109

Move all apply logic from `template-sync.yml` into `template-sync.sh` so the YAML just calls `template-sync.sh apply`.

## Task 1: Extract jq-tmp-mv helper

**Status:** done

Extract the repeated `jq ... > tmp && mv tmp original` pattern into a `json_update` helper function in the script. Every call site that does the tempfile dance should use it.

- [x] Write `json_update` helper (takes file path + jq expression + optional jq args)
- [x] Replace all `jq > tmp; mv tmp` call sites (6 sites)
- [x] Run tests green (99 tests, 150 assertions)

## Task 2: Split detect vs. apply in migration functions

**Status:** done

`run_plugin_migration` and `run_serena_removal` currently run in the `sync` job for reporting, then the YAML re-implements the mutations in `create-pr`. Split them so detect+report is side-effect-free and apply is separate.

- [x] Make `run_plugin_migration` only report (no filesystem mutations) when not in apply mode
- [x] Make `run_serena_removal` only report when not in apply mode
- [x] Verify detect-only mode populates DELETED_FILES for reporting without actual deletions

## Task 3: Add `apply` subcommand to the script

**Status:** done

Add `--apply` mode that performs all mutations the YAML currently does inline:

- [x] Copy staged files into working tree (.claude/, .codex/, workflows, scripts)
- [x] Run plugin migration (actual deletions + settings.json updates)
- [x] Run serena removal (actual deletions + gitignore + settings.local.json)
- [x] Patch .gitignore for .codex (currently YAML lines 259–271)
- [x] Auto-import CLAUDE.extra.md into CLAUDE.md (currently YAML lines 275–280)
- [x] Update manifest version + backfill defaults (currently YAML lines 289–318)
- [x] Cleanup staging artifacts

## Task 4: Slim down the YAML `create-pr` job

**Status:** done

Replace all inline mutation steps with a single call to `template-sync.sh apply`.

- [x] Replace "Run Plugin Migration" step
- [x] Replace "Remove Serena Artifacts" step
- [x] Replace "Apply Staged Changes" step
- [x] Replace "Cleanup Staging Artifacts" step
- [x] Replace "Update Manifest Version" step
- [x] Keep PR creation and summary steps unchanged
- [x] Remove unused `plugin_migrated` output from sync job
- [x] Make dependency check mode-aware (skip curl/yq in apply mode)
- [x] Move parse_arguments before check_dependencies

## Task 5: Tests + backward compat

**Status:** done

- [x] Add tests for `json_update` helper (3 tests: basic, --arg, failure + file-unchanged)
- [x] Add tests for apply mode (4 tests: copy, auto-import, import-skip, backfill)
- [x] Add tests for --apply argument parsing (3 tests)
- [x] Add tests for detect-only mode (2 tests: plugin + serena detect without mutations)
- [x] Fix test-claude-extra.sh to check script instead of YAML for auto-import logic
- [x] Ensure script without `--apply` still works (backward compat for downstream repos on older YAML)
- [x] Run full test suite green (8 suites, 243 cases, 502 assertions, 0 failures)
