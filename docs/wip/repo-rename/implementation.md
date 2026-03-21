# Repo Rename: Implementation Plan

> Design: [./design.md](./design.md)

## Overview

The rename involves three categories of work: (1) mechanical find-and-replace across the repo, (2) a migration step in the sync script for existing users, and (3) post-merge GitHub repo rename. The first two are code changes; the third is a manual step.

## 1. Find-and-Replace Across the Repo

### Target String

All occurrences of the literal string `claude-starter-kit` are replaced with `claude-toolbox`. There are no partial matches or regex edge cases to worry about — the string is unique and unambiguous.

### Files by Category

#### Scripts

- **`.github/scripts/template-cleanup.sh`** — default `UPSTREAM_REPO` value, safety guard checking repo name, comments
- **`.github/scripts/template-sync.sh`** — comments referencing the repo URL
- **`.github/templates/claude/scripts/sync-workflow.sh`** — hardcoded `UPSTREAM_REPO` variable

#### Workflows

- **`.github/workflows/template-sync.yml`** — repo name guard in `if:` condition, comments
- **`.github/workflows/template-cleanup.yml`** — repo name guard in `if:` condition, comments

#### Config

- **`.github/templates/serena/project.yml`** — `project_name` field
- **`.github/templates/template-state.example.json`** — `upstream_repo` value

#### Tests

- **`test/test-template-cleanup.sh`** — assertions and test data referencing `upstream_repo`
- **`test/test-template-sync.sh`** — `resolve_version` test calls with repo name
- **`test/test-manifest-jq.sh`** — manifest parsing assertions
- **`test/fixtures/manifests/*.json`** (7 files) — `upstream_repo` values in all fixture manifests

#### Documentation

- **`README.md`** — heading, "Use this template" link, example manifests, curl URLs, repo links
- **`docs/template-sync/design.md`** — problem statement, architecture diagram, example manifest
- **`docs/template-sync/template-state-schema.json`** — `$id` URL, example values
- **`docs/template-sync/tm/docs/template-sync-prd.md`** — problem statement, user stories
- **`docs/template-sync/tm/docs/sync-exclusions-prd.md`** — context references
- **`docs/template-sync/sync-exclusions/design.md`** — context references, example manifest

#### WIP Documentation

- **`docs/wip/extract-plugin/design.md`** — marketplace config, install commands, repo URLs
- **`docs/wip/extract-plugin/implementation.md`** — plugin config, marketplace JSON, install commands, migration steps
- **`docs/wip/extract-plugin/tasks.md`** — task descriptions referencing repo name
- **`docs/wip/language-specific-skills/design.md`** — context reference
- **`docs/wip/language-specific-skills/implementation.md`** — context reference

#### Commands

- **`.github/templates/claude/commands/sync-workflow/sync-workflow.md`** — raw content URL
- **`.github/templates/claude/commands/migrate-from-taskmaster/migrate.md`** — issue URL, raw content URL

### Verification

After the replacement, run `grep -r 'claude-starter-kit' .` to confirm zero remaining occurrences (excluding `.git/`).

## 2. Manifest Migration in template-sync.sh

<a id="manifest-migration"></a>

### Location

In `.github/scripts/template-sync.sh`, inside the `main()` function, after `read_manifest()` and `validate_manifest()` complete, and before `resolve_version()` is called.

### Logic

```
if upstream_repo from manifest == "serpro69/claude-starter-kit":
    log_info "Migrating upstream_repo from serpro69/claude-starter-kit to serpro69/claude-toolbox"
    rewrite upstream_repo in template-state.json using jq
    reload manifest into memory
```

### Implementation Details

- Use `jq` to update the `upstream_repo` field in-place in the manifest file (`.github/template-state.json`)
- The manifest is already loaded into a global variable by `read_manifest()` — after the file rewrite, re-run `read_manifest()` to refresh the in-memory state
- This migration is idempotent: if `upstream_repo` is already `serpro69/claude-toolbox`, the condition doesn't trigger
- The migration runs in both CI mode and local mode

### Function Structure

Create a dedicated `migrate_manifest()` function (not inline in `main()`) to keep the migration logic isolated and testable. Place it near `validate_manifest()` since they're called in sequence.

### Testing

Add test cases in `test/test-template-sync.sh`:
- Test that a manifest with `upstream_repo = "serpro69/claude-starter-kit"` gets rewritten to `"serpro69/claude-toolbox"` after migration
- Test that a manifest already set to `"serpro69/claude-toolbox"` is not modified
- Test that the migration logs an info message when it triggers

## 3. Post-Merge Steps (Manual)

These steps happen after the code changes are merged. They are not automated and should be documented in the PR description.

1. **Tag a release** on the commit just before the rename PR merges — this preserves `raw.githubusercontent.com` URLs for users pinned to specific versions
2. **Rename the repo** in GitHub Settings > General > Repository name: `claude-starter-kit` → `claude-toolbox`
3. **Verify the redirect** — confirm `git ls-remote https://github.com/serpro69/claude-starter-kit.git` resolves to the renamed repo
4. **Update GitHub topics/description** if needed to reflect the new name
5. **Update any external references** (e.g., blog posts, social media links) — these are outside the scope of this repo but worth noting

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| GitHub redirect breaks if someone creates `claude-starter-kit` under `serpro69` | Very low (you control the namespace) | High — sync breaks for users who haven't synced yet | Manifest migration auto-heals on next sync; redirect is a temporary bridge |
| Existing users' `sync-workflow.sh` fails (raw URL 404) | Medium — affects users who run sync-workflow before template-sync | Low — they can run template-sync first, which delivers updated script | Document in release notes; sync-workflow failure message could hint at rename |
| Plugin extraction (#33) starts before rename lands | Low — coordination is in the issue | Medium — rework needed | Merge rename first; issue already says "do together" |
