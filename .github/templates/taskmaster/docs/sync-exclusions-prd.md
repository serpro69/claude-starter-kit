# Sync Exclusions - Product Requirements Document

## Problem Statement

Users who create repositories from the `claude-starter-kit` template and delete files they don't need (e.g., specific skills or commands) find that Template Sync re-adds those files in every sync PR. There is no way to tell sync "I intentionally removed this; don't bring it back."

## Solution

Add an optional `sync_exclusions` field to the state manifest (`.github/template-state.json`) containing glob patterns of project-relative paths. Template-sync will skip any file matching these patterns during comparison, preventing excluded files from being added, modified, or flagged as deleted.

## Goals

1. Allow users to permanently exclude specific paths from template sync
2. Support glob patterns for flexible path matching
3. Maintain full backward compatibility with existing manifests
4. Report excluded files in the sync report for transparency

## Non-Goals

1. Regex pattern support (glob only)
2. Negation patterns (e.g., "exclude all except X")
3. UI/CLI for managing exclusions (users edit JSON directly)
4. Automatic detection of intentionally deleted files

## Design Documents

- Design: `docs/template-sync/sync-exclusions/design.md`
- Implementation plan: `docs/template-sync/sync-exclusions/implementation.md`

## Technical Requirements

### TR1: Manifest Schema Extension
- Add optional `sync_exclusions` field (array of strings) to `.github/template-state.json`
- Schema version remains "1" (backward-compatible addition)
- Update JSON schema documentation at `docs/template-sync/template-state-schema.json`
- Validate field type (array of strings) when present

### TR2: Core Exclusion Logic
- Implement `is_excluded()` function using bash `case` statement glob matching
- Add `SYNC_EXCLUSIONS` global array loaded from manifest via `mapfile`/`jq`
- Add `EXCLUDED_FILES` global array for tracking excluded paths
- Load exclusions during `read_manifest()`, validate during `validate_manifest()`

### TR3: File Comparison Integration
- Filter excluded files in `compare_files()` at two injection points:
  - Staging file walk (prevents ADDED/MODIFIED/UNCHANGED categorization)
  - Project file walk (prevents DELETED flagging)
- Excluded files must not trigger `diff` operations
- Pattern matching uses project-relative paths (e.g., `.claude/commands/cove/cove.md`)

### TR4: Reporting
- Add "Excluded" section to human-readable diff report
- Add `excluded_count` to CI mode output
- Add "Excluded Files" section to markdown PR summary
- Excluded files do NOT count toward `has_changes`

### TR5: Testing
- Unit tests for `is_excluded()` (empty patterns, exact match, glob match, non-match, cross-directory)
- Integration tests for `read_manifest()` with/without exclusions
- Integration tests for `validate_manifest()` with valid/invalid exclusions
- Integration tests for `compare_files()` excluding files from ADDED, MODIFIED, DELETED
- Report output tests for excluded files display
- Test fixture: `test/fixtures/manifests/valid-manifest-with-exclusions.json`

### TR6: Documentation
- Update README.md with sync exclusions usage and examples
- Update CLAUDE.md with brief mention
- Update `docs/template-sync/design.md` to reference new file classification category
- Create `docs/template-sync/sync-exclusions/design.md` (done)
- Create `docs/template-sync/sync-exclusions/implementation.md` (done)

## Acceptance Criteria

1. A manifest with `sync_exclusions: [".claude/commands/cove/*"]` causes all files under `.claude/commands/cove/` to be skipped during sync
2. Excluded files appear as "Excluded" in the sync report (not as Added, Modified, or Deleted)
3. A manifest without `sync_exclusions` works identically to current behavior (no regression)
4. All existing tests continue to pass
5. New tests cover the exclusion feature with at least 14 test cases
6. `excluded_count` is available in CI mode output
7. PR markdown summary includes excluded files section when exclusions are active
