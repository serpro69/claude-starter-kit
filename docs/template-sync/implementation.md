# Template Sync Feature - Implementation Plan

## Overview

This document provides a step-by-step implementation guide for the template sync feature. The implementation is divided into tasks that can be completed incrementally.

## Prerequisites

Before implementing, the developer should be familiar with:
- The existing `.github/scripts/template-cleanup.sh` script structure
- GitHub Actions workflow syntax
- Shell scripting (bash)
- JSON manipulation (using `jq`)

## File Inventory

### Files to Create

| File | Purpose |
|------|---------|
| `.github/scripts/template-sync.sh` | Core sync logic script |
| `.github/workflows/template-sync.yml` | GitHub Actions workflow |
| `.github/templates/workflows/template-sync.yml` | Template for sync workflow |

### Files to Modify

| File | Changes |
|------|---------|
| `.github/scripts/template-cleanup.sh` | Add manifest creation, preserve sync workflow |

### Files Generated at Runtime

| File | When Created |
|------|--------------|
| `.github/template-state.json` | During template-cleanup in child repos |

## Implementation Tasks

### Task 1: Create the State Manifest Schema

**Goal**: Define and validate the manifest structure.

**Implementation Notes**:
- Create a JSON schema file for validation (optional but recommended)
- The manifest must be valid JSON with all required fields
- The `schema_version` field enables future migrations

**Manifest Structure**:
```json
{
  "schema_version": "1",
  "upstream_repo": "string (owner/repo)",
  "template_version": "string (tag or SHA)",
  "synced_at": "string (ISO 8601 timestamp)",
  "variables": {
    "PROJECT_NAME": "string",
    "LANGUAGES": "string",
    "CC_MODEL": "string",
    "SERENA_INITIAL_PROMPT": "string",
    "TM_CUSTOM_SYSTEM_PROMPT": "string",
    "TM_APPEND_SYSTEM_PROMPT": "string",
    "TM_PERMISSION_MODE": "string"
  }
}
```

**Acceptance Criteria**:
- Manifest schema is documented
- All variable names match those used in `.github/scripts/template-cleanup.sh`

---

### Task 2: Modify .github/scripts/template-cleanup.sh to Generate Manifest

**Goal**: After cleanup completes, write the state manifest with all applied variables.

**Key Changes**:

1. **Capture variables before substitution**:
   - Store all input variables (from env or CLI args) in shell variables
   - Include: PROJECT_NAME, LANGUAGES, CC_MODEL, SERENA_INITIAL_PROMPT, etc.

2. **Determine template version**:
   - Use `git describe --tags --abbrev=0 2>/dev/null || git rev-parse --short HEAD`
   - This gets the nearest tag or falls back to commit SHA

3. **Write manifest after substitution completes**:
   - Create `.github/template-state.json` with all collected values
   - Use `jq` or heredoc for JSON generation
   - Ensure proper JSON escaping for string values

4. **Update files-to-keep list**:
   - Add `.github/scripts/` to preserved directories
   - Add `.github/workflows/template-sync.yml` to preserved files
   - Add `.github/template-state.json` to preserved files

**Location in script**: After the substitution step (step 1) completes, before file cleanup (step 4).

**Edge Cases**:
- Handle empty strings for optional variables
- Escape special characters in variable values for JSON
- Handle case where git tags don't exist (use SHA)

---

### Task 3: Create template-sync.sh Script

**Goal**: Implement the core sync logic as a standalone script.

**Script Structure**:

```
template-sync.sh
├── Configuration & Constants
├── Helper Functions
│   ├── log_info(), log_error(), log_success()
│   ├── check_dependencies()
│   ├── read_manifest()
│   └── validate_manifest()
├── Core Functions
│   ├── resolve_version()
│   ├── fetch_upstream_templates()
│   ├── apply_substitutions()
│   ├── compare_files()
│   └── generate_diff_report()
├── Main Logic
│   ├── Parse arguments
│   ├── Execute sync steps
│   └── Output results
└── Entry Point
```

**Function Details**:

**`read_manifest()`**:
- Read `.github/template-state.json`
- Parse JSON using `jq`
- Export variables for use in other functions
- Exit with error if manifest missing or invalid

**`resolve_version(target)`**:
- If "latest": fetch tags from upstream, return most recent
- If "main": return "main"
- Otherwise: return as-is (assumed to be tag or SHA)

**`fetch_upstream_templates(version)`**:
- Create temp directory
- Use git sparse-checkout to fetch `.github/templates/` and sync infrastructure files
- Clone with depth=1 for efficiency
- Return path to fetched templates

**`apply_substitutions(template_dir)`**:
- Read variables from manifest
- Apply sed substitutions to all template files
- Mirror the logic from `.github/scripts/template-cleanup.sh`
- Output to a staging directory

**`copy_sync_files(upstream_dir, output_dir)`**:
- Copy sync infrastructure files from upstream to staging
- Copies `.github/workflows/template-sync.yml` and `.github/scripts/template-sync.sh`
- No substitution needed - files are synced as-is
- Handles missing files gracefully

**`compare_files(staging_dir, target_dirs)`**:
- Compare staged files against `.claude/`, `.serena/`, `.taskmaster/`, `.github/workflows/`, `.github/scripts/`
- Generate list of: added, modified, deleted, unchanged
- Return diff statistics

**`generate_diff_report()`**:
- Create human-readable summary
- List all changed files with change type
- Include file-by-file diffs for modified files

**CLI Arguments**:
- `--version VERSION`: Target version (default: latest)
- `--dry-run`: Preview only, don't apply changes
- `--ci`: CI mode for GitHub Actions
- `--output-dir DIR`: Where to stage changes (default: temp)
- `--help`: Show usage

**Exit Codes**:
- 0: Success (changes found or no changes)
- 1: Error (missing manifest, network failure, etc.)
- 2: Invalid arguments

---

### Task 4: Create template-sync.yml Workflow

**Goal**: GitHub Actions workflow that orchestrates the sync process.

**Workflow Structure**:

```yaml
name: Template Sync
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to sync (latest, main, or specific tag)'
        default: 'latest'
        type: string
      dry_run:
        description: 'Preview changes without creating PR'
        default: false
        type: boolean
```

**Jobs**:

1. **sync**:
   - Checkout repository
   - Validate manifest exists
   - Run template-sync.sh
   - Upload diff report as artifact

2. **create-pr** (conditional on changes and not dry_run):
   - Create branch `template-sync/{version}`
   - Copy staged files to working directories
   - Update manifest with new version
   - Commit changes
   - Create PR using `peter-evans/create-pull-request` or `gh pr create`

**PR Template**:
```markdown
## Template Update: {old_version} → {new_version}

This PR updates the repository configuration from the upstream template.

### Changes
{diff_summary}

### Review Checklist
- [ ] Review changed files for any customizations that should be preserved
- [ ] Test that Claude Code still works correctly
- [ ] Verify MCP server configurations

### How to handle conflicts
If you've customized any files that upstream also changed:
1. Review the diff for each file
2. Edit the PR branch to preserve your customizations
3. Or reject specific changes by reverting them in the PR

---
*Generated by Template Sync workflow*
```

**Permissions Required**:
- `contents: write` (to create branch and commit)
- `pull-requests: write` (to create PR)

---

### Task 5: Create Template for Sync Workflow

**Goal**: Add the sync workflow to `.github/templates/` so child repos receive it.

**File**: `.github/templates/workflows/template-sync.yml`

This is a copy of the workflow created in Task 4, placed in the templates directory so it gets deployed during cleanup.

**Modifications needed in `.github/scripts/template-cleanup.sh`**:
- Copy `.github/templates/workflows/` to `.github/workflows/` during deployment
- Or add specific handling for workflow templates

---

### Task 6: Update .github/scripts/template-cleanup.sh Deployment Logic

**Goal**: Ensure sync-related files are properly deployed and preserved.

**Changes**:

1. **Deploy sync script**:
   - Copy `.github/templates/scripts/template-sync.sh` to `.github/scripts/`
   - Set executable permissions

2. **Deploy sync workflow**:
   - Copy `.github/templates/workflows/template-sync.yml` to `.github/workflows/`

3. **Update cleanup step**:
   - Preserve `.github/scripts/` directory
   - Preserve `.github/workflows/template-sync.yml`
   - Preserve `.github/template-state.json`

4. **Add jq dependency check**:
   - The sync script requires `jq` for JSON parsing
   - Add check in script or document as requirement

---

### Task 7: Testing

**Goal**: Verify the implementation works through unit tests and integration testing.

**Status**: ✅ Unit tests implemented

#### Unit Test Suite

Located in `test/` directory with 79 total tests across 3 test files:

**Test Directory Structure**:
```
test/
├── helpers.sh                    # Shared test utilities
├── test-manifest-jq.sh           # 17 tests - jq JSON patterns
├── test-template-sync.sh         # 33 tests - template-sync.sh functions
├── test-template-cleanup.sh      # 18 tests - generate_manifest() function
└── fixtures/
    ├── manifests/                # 6 JSON manifest fixtures
    └── templates/                # 3 template file fixtures
```

**Running Tests**:
```bash
# Run all tests
for test in test/test-*.sh; do $test; done

# Run individual suite
./test/test-manifest-jq.sh
./test/test-template-sync.sh
./test/test-template-cleanup.sh
```

**Test Coverage by Suite**:

| Suite | Tests | Coverage |
|-------|-------|----------|
| test-manifest-jq.sh | 17 | jq patterns, JSON generation, special characters, round-trip |
| test-template-sync.sh | 44 | CLI parsing, manifest reading/validation, sed escaping, substitutions, file comparison, diff reports, user-scoped directory exclusions |
| test-template-cleanup.sh | 18 | Manifest generation, fields, variables, special chars, git tag/SHA detection, schema validation |

**Functions Tested in template-sync.sh**:
- `parse_arguments()` - CLI argument handling
- `read_manifest()` - Manifest file loading and JSON validation
- `validate_manifest()` - Schema version and field validation
- `escape_sed_replacement()` - Special character escaping for sed
- `apply_substitutions()` - Variable substitution logic
- `compare_files()` - File change detection (added/modified/deleted/unchanged)
- `generate_diff_report()` - Human-readable and CI output formatting

**Functions Tested in `.github/scripts/template-cleanup.sh`**:
- `generate_manifest()` - State manifest creation with all variables

#### Integration Tests (Manual)

The following scenarios require manual testing with actual GitHub repositories:

1. **Fresh template cleanup**:
   - Create repo from template
   - Run cleanup with various input combinations
   - Verify manifest is created with correct values

2. **Sync with upstream changes**:
   - Modify a template file in upstream
   - Create new tag
   - Run sync in child repo
   - Verify changes detected correctly

3. **GitHub Actions workflow**:
   - Trigger workflow with dry_run=true
   - Verify diff report generated
   - Trigger workflow with dry_run=false
   - Verify PR created correctly

4. **Version targeting**:
   - Test "latest" resolves to most recent tag
   - Test specific tag version works

---

### Task 8: Documentation

**Goal**: Update user-facing documentation.

**Files to Update**:

1. **README.md**:
   - Add section on receiving updates
   - Document sync workflow usage
   - Add troubleshooting for common issues

2. **CLAUDE.md**:
   - Add guidance on when to sync
   - Document manifest file purpose

---

## Implementation Order

Recommended sequence:

1. **Task 1**: Define manifest schema (foundation for everything)
2. **Task 2**: Modify cleanup to generate manifest (enables testing early)
3. **Task 3**: Create sync script (core logic)
4. **Task 4**: Create workflow (orchestration)
5. **Task 5**: Template the workflow (deployment)
6. **Task 6**: Update deployment logic (integration)
7. **Task 7**: Testing (validation)
8. **Task 8**: Documentation (user guidance)

Tasks 3-6 can be developed in parallel once Task 1-2 are complete.

---

## Technical Notes

### JSON Generation in Bash

For generating the manifest, use a heredoc with proper escaping:

```bash
# Example approach using jq for safe JSON generation
jq -n \
  --arg schema "1" \
  --arg upstream "$UPSTREAM_REPO" \
  --arg version "$TEMPLATE_VERSION" \
  --arg synced "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg project "$PROJECT_NAME" \
  --arg languages "$LANGUAGES" \
  '{
    schema_version: $schema,
    upstream_repo: $upstream,
    template_version: $version,
    synced_at: $synced,
    variables: {
      PROJECT_NAME: $project,
      LANGUAGES: $languages
    }
  }' > .github/template-state.json
```

### Git Sparse Checkout

For efficient template fetching:

```bash
git clone --depth 1 --filter=blob:none --sparse \
  "https://github.com/$UPSTREAM_REPO.git" "$TEMP_DIR"
cd "$TEMP_DIR"
git sparse-checkout set .github/templates
git checkout "$VERSION"
```

### Substitution Logic Reuse

The substitution logic should be extracted into a shared function that both `.github/scripts/template-cleanup.sh` and `template-sync.sh` can use. This ensures consistency and reduces maintenance burden.

Consider:
- Extracting to a shared script (`.github/scripts/substitute.sh`)
- Or duplicating with clear comments about keeping in sync

---

## Rollback Plan

If a sync goes wrong:
1. User can close the PR without merging
2. If already merged, standard git revert works
3. Manifest tracks previous version for reference

No special rollback mechanism needed - standard git workflow handles it.
