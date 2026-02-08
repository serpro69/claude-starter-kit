# Template Sync Feature - Design Document

## Problem Statement

The `claude-starter-kit` repository is designed as a one-time template. Once users create a new repository from the template and run the cleanup workflow, the template source files are deleted. This means:

1. Users cannot receive updates when the template improves (new skills, better configs, bug fixes)
2. There's no mechanism to track which template version a repository was created from
3. Users who want updates must manually copy changes from upstream

## Solution Overview

Implement a "rehydration" approach that allows child repositories to pull updates from the upstream template:

1. **State Manifest**: Store the template version and substitution variables used during initial setup
2. **Sync Workflow**: GitHub Action that fetches upstream templates, re-applies project-specific values, and creates a PR
3. **PR-Based Review**: Changes are always presented as a Pull Request, giving users control over what gets merged

## Architecture

### Data Flow

```
┌─────────────────────┐
│   Upstream Repo     │
│ (claude-starter-kit)│
│                     │
│ .github/templates/  │
│   ├── claude/       │
│   ├── serena/       │
│   └── taskmaster/   │
└──────────┬──────────┘
           │
           │ 1. Fetch raw templates
           ▼
┌─────────────────────┐
│   Sync Workflow     │
│                     │
│ - Read manifest     │
│ - Fetch upstream    │
│ - Rehydrate         │
│ - Create PR         │
└──────────┬──────────┘
           │
           │ 2. Apply stored variables
           ▼
┌─────────────────────┐
│   Child Repo        │
│                     │
│ .claude/            │ ◄── Updated via PR
│ .serena/            │
│ .taskmaster/        │
│ .github/            │
│   └── template-     │
│       state.json    │ ◄── Version tracking
└─────────────────────┘
```

### Components

#### 1. State Manifest (`.github/template-state.json`)

Persisted during initial template cleanup. Contains:

```json
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-project",
    "LANGUAGES": "typescript",
    "CC_MODEL": "sonnet",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": "default"
  }
}
```

**Fields:**
- `schema_version`: Manifest format version (for future migrations)
- `upstream_repo`: Source template repository (owner/repo format)
- `template_version`: Git tag or commit SHA from initial setup
- `synced_at`: ISO timestamp of last sync
- `variables`: All substitution values applied during cleanup

##### Variable Name Mapping

The manifest variables must align exactly with those used in `.github/scripts/template-cleanup.sh`. This table documents the complete mapping:

| Manifest Variable | Shell Variable | Default Value | Target File(s) | Substitution Pattern |
|-------------------|----------------|---------------|----------------|----------------------|
| `PROJECT_NAME` | `NAME` (from `REPO_NAME`) | `$(basename "$REPO_ROOT")` | `.serena/project.yml`, `.taskmaster/config.json` | `project_name: "..."`, `"projectName": "..."` |
| `LANGUAGES` | `LANGUAGES` | Required | `.serena/project.yml` | `languages:\n  - ...` (YAML array) |
| `CC_MODEL` | `CC_MODEL` | `"default"` | `.claude/settings.json` | `"model": "..."` (or line removal) |
| `SERENA_INITIAL_PROMPT` | `SERENA_INITIAL_PROMPT` | `""` (empty) | `.serena/project.yml` | `initial_prompt: "..."` |
| `TM_CUSTOM_SYSTEM_PROMPT` | `TM_CUSTOM_SYSTEM_PROMPT` | `""` (empty) | `.taskmaster/config.json` | `"customSystemPrompt": "..."` |
| `TM_APPEND_SYSTEM_PROMPT` | `TM_APPEND_SYSTEM_PROMPT` | `""` (empty) | `.taskmaster/config.json` | `"appendSystemPrompt": "..."` |
| `TM_PERMISSION_MODE` | `TM_PERMISSION_MODE` | `"default"` | `.taskmaster/config.json` | `"permissionMode": "..."` |

**Default Value Behaviors:**

- `CC_MODEL="default"`: Special case - the model line is **removed** from settings.json rather than substituted (lines 297-301 in .github/scripts/template-cleanup.sh)
- Empty strings (`""`): For optional fields, substitution only occurs if the value is non-empty (conditional sed)
- `TM_PERMISSION_MODE="default"`: Explicit value, always substituted (not special-cased like CC_MODEL)

**Source File References (.github/scripts/template-cleanup.sh):**

- Variable declarations: lines 27-32
- Environment variable loading: lines 42-47
- Substitution logic: lines 295-329
- Project name derivation: lines 458, 469

**Schema Validation:**

The JSON Schema at `docs/wip/template-sync/template-state-schema.json` enforces:
- `PROJECT_NAME` is required (always derived from repo name)
- `TM_PERMISSION_MODE` restricted to enum: `["default", "full", "minimal"]`
- All other variables are optional strings with empty string defaults

#### 2. Sync Workflow (`.github/workflows/template-sync.yml`)

GitHub Actions workflow with manual dispatch trigger.

**Inputs:**
- `version`: Target version to sync (default: "latest")
  - `"latest"` - Most recent git tag
  - `"main"` - Bleeding edge from main branch
  - `"vX.Y.Z"` - Specific version tag
- `dry_run`: Preview mode - show diff without creating PR (default: false)

**Steps:**
1. Checkout repository
2. Read and validate manifest
3. Determine target version (resolve "latest" to actual tag)
4. Fetch upstream templates at target version
5. Run rehydration with stored variables
6. Compare against current files
7. Create PR if changes detected (unless dry_run)

#### 3. Sync Script (`.github/scripts/template-sync.sh`)

Shell script containing the core sync logic. Supports:
- CI mode (for GitHub Actions)
- Local mode (for manual execution)
- Dry-run mode (preview only)

**Key Functions:**
- `read_manifest()` - Parse JSON manifest file
- `fetch_upstream_templates()` - Download templates via git sparse checkout
- `apply_substitutions()` - Replace placeholders with stored variables
- `generate_diff_report()` - Create human-readable change summary

#### 4. Modified Cleanup Script

The existing `.github/scripts/template-cleanup.sh` is enhanced to:
- Write the state manifest after applying substitutions
- Preserve the sync workflow in the files-to-keep list
- Record the template version (from git describe or HEAD SHA)

## User Experience

### Initial Setup (unchanged)

1. Create repo from template
2. Run `template-cleanup` workflow with configuration inputs
3. Cleanup script now also creates `.github/template-state.json`
4. Sync workflow is preserved (not deleted during cleanup)

### Receiving Updates

1. User sees notification or manually checks for updates
2. Navigate to Actions → "Template Sync" → "Run workflow"
3. Optionally specify version (default: latest)
4. Workflow runs and creates PR titled "Template update: v1.0.0 → v1.1.0"
5. User reviews diff in PR:
   - New files are additions
   - Changed files show line-by-line diff
   - User can edit PR branch if needed
6. Merge PR to apply updates
7. Manifest is updated with new version

### Conflict Handling

The PR-based approach handles customizations gracefully:

| Scenario | Behavior |
|----------|----------|
| New file in upstream | Added to PR as new file |
| File deleted in upstream | Deleted in PR (user can reject) |
| File unchanged | Not included in PR |
| Upstream changed, local unchanged | File updated in PR |
| Upstream changed, local also changed | PR shows upstream version; user resolves |
| User-only files (gitignored) | Never touched |
| User-excluded (sync_exclusions) | Ignored by sync |

**Key principle**: Users always see the diff before merge. No silent overwrites.

## File Classification

### Template-Managed Files (updated by sync)

Files that originate from `.github/templates/`:
- `.claude/settings.json`
- `.claude/commands/**`
- `.claude/skills/**`
- `.claude/agents/**`
- `.claude/scripts/**`
- `.claude/TM_COMMANDS_GUIDE.md`
- `.serena/project.yml`
- `.taskmaster/config.json`
- `.taskmaster/CLAUDE.md`
- `.taskmaster/templates/**`

Sync infrastructure files (synced directly, not from templates/):
- `.github/workflows/template-sync.yml`
- `.github/scripts/template-sync.sh`

### User-Scoped Files (never touched)

Files that are user-specific or gitignored:
- `.claude/settings.local.json` (if it existed, would be gitignored)
- `.taskmaster/tasks/**` (project-specific task data)
- `.taskmaster/docs/**` (project-specific PRDs)
- `.taskmaster/reports/**` (project-specific analysis reports)
- `.env` files
- Any gitignored files

### User-Excluded Files (ignored by sync)

Files matching patterns in the manifest `sync_exclusions` array. These are template-managed files that the user has intentionally removed and wants to keep excluded from future syncs. Excluded files are not added, modified, or flagged as deleted during sync. See `docs/template-sync/sync-exclusions/design.md` for full details.

### Project-Specific Files (preserved via substitution)

Files with project values that get re-applied:
- Project name in configs
- Language setting in Serena
- Custom prompts in Task Master

## Version Strategy

### Upstream Versioning

The template repository uses semantic versioning via git tags:
- `v1.0.0` - Initial stable release
- `v1.1.0` - New features (backwards compatible)
- `v1.2.0` - More features
- `v2.0.0` - Breaking changes (new manifest schema, etc.)

### Version Resolution

| Input | Resolution |
|-------|------------|
| `"latest"` | Most recent tag (via `git describe --tags --abbrev=0`) |
| `"main"` | HEAD of main branch |
| `"v1.2.0"` | Exact tag |
| `"abc1234"` | Exact commit SHA |

### Breaking Changes

When manifest `schema_version` changes:
1. Sync script detects version mismatch
2. Provides migration instructions in workflow output
3. Does not proceed until manifest is migrated

## Security Considerations

1. **No credential exposure**: Sync only touches config files, not secrets
2. **PR review gate**: All changes require human approval before merge
3. **Trusted upstream**: Users control which upstream repo to sync from
4. **No code execution**: Sync script only performs file operations

## Limitations

1. **All-or-nothing updates**: Cannot selectively update specific directories (partially addressed by `sync_exclusions` for per-file opt-out; see `docs/template-sync/sync-exclusions/design.md`)
2. **No automatic merging**: Conflicts require manual resolution in PR
3. **Requires GitHub Actions**: Local-only users need manual process
4. **Single upstream**: Cannot sync from multiple template sources

## Future Enhancements

Potential improvements for future versions:
- Selective component updates (e.g., only skills)
- Automatic conflict resolution for simple cases
- Notification when new upstream version available
- Support for local execution without GitHub Actions
- Multiple upstream sources (for extension templates)
