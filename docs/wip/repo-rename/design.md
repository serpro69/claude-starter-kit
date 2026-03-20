# Repo Rename: claude-starter-kit -> claude-sak

> Issue: [#36](https://github.com/serpro69/claude-starter-kit/issues/36)
> Related: [#33](https://github.com/serpro69/claude-starter-kit/issues/33) (plugin extraction — coordinate naming)

## Problem Statement

The repository name `claude-starter-kit` is too generic, gets lost in search results, and doesn't convey the tool's purpose well. Renaming to `claude-sak` (Swiss Army Knife) improves discoverability and memorability.

The name `claude-starter-kit` appears in ~80+ locations across scripts, workflows, tests, fixtures, and documentation. Beyond a simple find-and-replace, existing users who created repositories from this template have hardcoded references to the old name in their local files and manifests.

## Impact Analysis

### In-Repo References

All occurrences of `claude-starter-kit` across:

| Category | Files | Nature of Reference |
|----------|-------|-------------------|
| Sync scripts | `template-sync.sh`, `template-cleanup.sh`, `sync-workflow.sh` | Hardcoded repo name in URLs, defaults, comments |
| Workflow guards | `template-sync.yml`, `template-cleanup.yml` | `if: github.event.repository.name != 'claude-starter-kit'` |
| Test files | `test/test-template-cleanup.sh`, `test/test-template-sync.sh`, `test/test-manifest-jq.sh` | Assertions, fixture data |
| Test fixtures | `test/fixtures/manifests/*.json` | `"upstream_repo"` values |
| Config | `.github/templates/serena/project.yml` | `project_name` field |
| Example manifest | `.github/templates/template-state.example.json` | `"upstream_repo"` value |
| README | `README.md` | URLs, instructions, examples |
| WIP docs | `docs/wip/extract-plugin/`, `docs/wip/language-specific-skills/` | Design/implementation references |
| Completed docs | `docs/template-sync/` | Design docs, schema |
| Commands | `.claude/commands/sync-workflow/`, `.claude/commands/migrate-from-taskmaster/` | URLs to raw content |

### Existing User Impact

Users who created repos from this template have:

1. **`template-state.json`** with `"upstream_repo": "serpro69/claude-starter-kit"` — used by `template-sync.sh` to construct git URLs for fetching upstream templates.

2. **Local copies of `sync-workflow.sh`** (at `.github/templates/claude/scripts/sync-workflow.sh`) with hardcoded `UPSTREAM_REPO="serpro69/claude-starter-kit"` and `raw.githubusercontent.com` URLs.

3. **Local copies of workflow files** with the old `!= 'claude-starter-kit'` guards (these are irrelevant for downstream repos since their repo names don't match either way).

#### GitHub Redirect Behavior

When a GitHub repo is renamed, GitHub sets up redirects:

| URL Type | Redirects? | Used By |
|----------|-----------|---------|
| `github.com/owner/old-name.git` (git operations) | Yes | `template-sync.sh` (fetch via sparse checkout) |
| `github.com/owner/old-name` (web) | Yes | Links in docs, README |
| `raw.githubusercontent.com/owner/old-name/...` | **No** | `sync-workflow.sh` (curl-based file fetch) |
| `api.github.com/repos/owner/old-name` | Yes | Not currently used |

**Key insight:** The core sync mechanism (`template-sync.sh`) uses git URLs which redirect, so it continues working. The `sync-workflow.sh` helper uses `raw.githubusercontent.com` URLs which do NOT redirect — this is the main breakage vector.

#### Self-Healing Path

1. User triggers template-sync (works via git redirect)
2. Sync fetches updated templates from upstream (now named `claude-sak`)
3. Updated `sync-workflow.sh` with new repo name is delivered to the user's repo
4. User merges the sync PR — `sync-workflow.sh` is now fixed

The only gap: the user's `template-state.json` `upstream_repo` field is not updated by sync (it's only written during initial cleanup). This needs a migration step.

## Design

### 1. In-Repo Rename

Replace all occurrences of `claude-starter-kit` with `claude-sak` across the entire repository. This is a mechanical find-and-replace with two special cases:

- **Workflow guards**: `!= 'claude-starter-kit'` becomes `!= 'claude-sak'`
- **Serena project name**: `project_name: "claude-starter-kit"` becomes `project_name: "claude-sak"`

### 2. Manifest Migration in template-sync.sh

Add a migration step early in the sync script's `main()` function that detects and rewrites stale `upstream_repo` values:

- **When:** After `read_manifest()` and `validate_manifest()`, before `resolve_version()`
- **What:** If `upstream_repo` equals `serpro69/claude-starter-kit`, rewrite the manifest file in-place to `serpro69/claude-sak` and reload
- **Why:** Ensures the manifest is correct going forward, and eliminates dependency on GitHub's redirect (which can break if someone creates a repo with the old name)
- **Logging:** Emit a `log_info` message so the user sees the migration happened

### 3. Release Sequencing

1. **Tag a release** on the current `master` before merging the rename — ensures existing pinned `raw.githubusercontent.com` URLs (e.g., `v1.x.x/.github/workflows/template-sync.yml`) continue to resolve for users referencing specific versions
2. **Merge the rename PR**
3. **Rename the GitHub repo** via Settings > General > Repository name
4. **Verify** git redirect works and template-sync succeeds from a downstream repo

### 4. Relationship to #33 (Plugin Extraction)

The plugin extraction design docs (`docs/wip/extract-plugin/`) contain extensive references to `claude-starter-kit` in marketplace names, install commands, and repository URLs. The rename should land before (or simultaneously with) plugin extraction so that all plugin-related names use `claude-sak` from the start. No special coordination mechanism is needed — the rename PR simply needs to merge first.

## Out of Scope

- **Notifying existing users** — GitHub's redirect handles the transition; users will see the updated name on their next sync PR
- **Backwards compatibility shims** — No aliases, no dual-name support. GitHub redirect is sufficient
- **Updating existing users' repos** — Their next template-sync will deliver updated files; the manifest migration handles the rest
