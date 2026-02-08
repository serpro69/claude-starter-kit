# Sync Exclusions Feature - Implementation Plan

## Overview

This document provides a step-by-step implementation guide for adding sync exclusion support to `template-sync.sh`. The feature allows users to configure glob patterns in the manifest that prevent specific paths from being synced.

**Design document**: `docs/template-sync/sync-exclusions/design.md`

## Prerequisites

Before implementing, the developer should be familiar with:
- The existing `template-sync.sh` script structure (see `docs/template-sync/implementation.md`)
- How `compare_files()` works (lines 682-766 in `.github/scripts/template-sync.sh`)
- How `generate_diff_report()` and `generate_markdown_summary()` work (lines 786-956)
- The test patterns in `test/test-template-sync.sh` and `test/helpers.sh`
- The manifest schema at `docs/template-sync/template-state-schema.json`

## File Inventory

### Files to Modify

| File | Changes |
|------|---------|
| `.github/scripts/template-sync.sh` | Add `SYNC_EXCLUSIONS` and `EXCLUDED_FILES` globals, `is_excluded()` function, load exclusions in `read_manifest()`, validate in `validate_manifest()`, filter in `compare_files()`, report in `generate_diff_report()` and `generate_markdown_summary()` |
| `docs/template-sync/template-state-schema.json` | Add `sync_exclusions` property definition |
| `test/test-template-sync.sh` | Add tests for `is_excluded()`, exclusion loading, `compare_files()` with exclusions, and report output |
| `test/fixtures/manifests/valid-manifest.json` | Optionally add `sync_exclusions` field (or create a new fixture) |
| `README.md` | Add documentation for configuring sync exclusions |
| `CLAUDE.md` | Mention sync exclusions in the Template Sync section |
| `docs/template-sync/design.md` | Update the Limitations section (item 1: "All-or-nothing updates" is now partially addressed) |

### Files to Create

| File | Purpose |
|------|---------|
| `test/fixtures/manifests/valid-manifest-with-exclusions.json` | Test fixture with `sync_exclusions` populated |

## Implementation Tasks

### Task 1: Add Global Variables

**Goal**: Declare the new global arrays for exclusion tracking.

**File**: `.github/scripts/template-sync.sh`

**Location**: Global Configuration section (after line 73, where `UNCHANGED_FILES=()` is declared)

**Changes**:
- Add `EXCLUDED_FILES=()` array for tracking excluded file paths
- Add `SYNC_EXCLUSIONS=()` array for storing patterns loaded from the manifest

**Context**: The existing globals follow this pattern (lines 69-73):
```
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
```

---

### Task 2: Add `is_excluded()` Helper Function

**Goal**: Implement the core pattern matching function.

**File**: `.github/scripts/template-sync.sh`

**Location**: Helper Functions section (after `format_languages_yaml()`, around line 148)

**Implementation notes**:
- Function takes a single argument: the project-relative file path (e.g., `.claude/commands/cove/cove.md`)
- Iterates over the global `SYNC_EXCLUSIONS` array
- Uses a bash `case` statement for glob matching (idiomatic, `*` matches slashes in `case`)
- Returns 0 (true/excluded) on match, 1 (false/not excluded) on no match
- If `SYNC_EXCLUSIONS` is empty, the loop body never executes and the function returns 1 immediately

**Important**: The glob pattern must be unquoted in the `case` clause for bash to perform glob expansion. E.g., `$pattern` not `"$pattern"`.

---

### Task 3: Load Exclusions in `read_manifest()`

**Goal**: Parse `sync_exclusions` from the manifest JSON into the `SYNC_EXCLUSIONS` bash array.

**File**: `.github/scripts/template-sync.sh`

**Location**: At the end of `read_manifest()`, after line 241 (`log_info "Manifest loaded: $MANIFEST_PATH"`)

**Implementation notes**:
- Use `jq -e '.sync_exclusions'` to check if the field exists
- If it exists, use `mapfile -t SYNC_EXCLUSIONS < <(jq -r '.sync_exclusions[]' "$MANIFEST_PATH")` to safely load the array
- If it doesn't exist, `SYNC_EXCLUSIONS` remains empty (the default from globals)
- `mapfile` (aka `readarray`) is the safest way to convert newline-delimited output to a bash array - it handles spaces in patterns correctly
- Log the count of loaded exclusions (e.g., `log_info "Loaded N sync exclusion pattern(s)"`) only when N > 0

---

### Task 4: Validate Exclusions in `validate_manifest()`

**Goal**: Validate the `sync_exclusions` field structure when present.

**File**: `.github/scripts/template-sync.sh`

**Location**: At the end of `validate_manifest()`, before line 298 (`log_success "Manifest validation passed"`)

**Implementation notes**:
- Only validate if the field exists (`jq -e '.sync_exclusions'`)
- Check that it's an array: `jq -e '.sync_exclusions | type == "array"'`
- Check that all elements are strings: `jq -e '.sync_exclusions | all(type == "string")'`
- If validation fails, `log_error` with a descriptive message and `exit 1`
- If the field is absent, skip validation entirely (it's optional)

---

### Task 5: Integrate Exclusions into `compare_files()`

**Goal**: Filter excluded files during the file comparison walk.

**File**: `.github/scripts/template-sync.sh`

**Location**: Two injection points within `compare_files()` (lines 682-766)

**Injection Point 1 - Staging file walk** (after line 722, before line 724):

The current code at line 722 constructs `display_path`:
```bash
local display_path="$project_dir/$relative_path"
```

Insert the exclusion check immediately after this line, before the `if [[ ! -f "$project_file" ]]` block on line 724. If `is_excluded "$display_path"` returns true, append `$display_path` to `EXCLUDED_FILES` and `continue` to skip this file entirely.

**Injection Point 2 - Project file walk** (after line 755, before line 757):

The current code at line 755 constructs `display_path`:
```bash
local display_path="$project_dir/$relative_path"
```

Insert the exclusion check immediately after this line, before the `if [[ ! -f "$staging_file" ]]` check on line 757. If `is_excluded "$display_path"` returns true, `continue` (don't add to `EXCLUDED_FILES` here to avoid double-counting since the staging walk already recorded it; but if the file only exists locally and not in staging, this path won't be reached from the staging walk, so we should still add to `EXCLUDED_FILES`).

**Important edge case**: A file might exist in the project but NOT in staging (deletion candidate). If it matches an exclusion pattern, it should be added to `EXCLUDED_FILES` and skipped. However, a file that exists in BOTH staging and project will already have been recorded in `EXCLUDED_FILES` during the staging walk, so we should avoid double-counting. The simplest approach: always add to `EXCLUDED_FILES` in the project walk too, and deduplicate later if needed - or accept that the count might include duplicates (since the staging walk and project walk cover different scenarios, duplicates only occur for files that exist in both places and are excluded, which is fine to report).

**Simpler approach**: Don't add to `EXCLUDED_FILES` in the project walk at all. The staging walk already covers files that exist upstream. The project walk only finds files that exist locally but not upstream - and if such a file matches an exclusion pattern, it was intentionally excluded from upstream, so we don't need to report it (it's not an upstream file being excluded, it's a local-only file).

**Recommended approach**: Only add to `EXCLUDED_FILES` in the staging walk (Injection Point 1). In the project walk (Injection Point 2), just `continue` without recording. This avoids duplicates and keeps the report focused on "upstream files that were excluded from sync."

**Update the summary log** on line 765: Add excluded count to the log message.

---

### Task 6: Update `generate_diff_report()`

**Goal**: Show excluded files in the human-readable report and CI output.

**File**: `.github/scripts/template-sync.sh`

**Location**: Within `generate_diff_report()` (lines 786-908)

**Changes**:

1. **CI mode output** (lines 793-819): Add `excluded_count=${#EXCLUDED_FILES[@]}` to both the `GITHUB_OUTPUT` block and the stdout block. Do NOT include excluded count in `total_changes` or `has_changes`.

2. **Summary section** (lines 841-846): Add an "Excluded" line after "Unchanged":
   ```
   Excluded:  N
   ```
   Use a distinct color (e.g., `CYAN` or the default/no color) to differentiate from the change categories.

3. **Excluded files list** (after the deleted files section, before the closing separator on line 900): Add a new section that lists excluded files, similar to the added/modified/deleted sections. Use a distinct marker character.

---

### Task 7: Update `generate_markdown_summary()`

**Goal**: Include excluded files in the PR body markdown.

**File**: `.github/scripts/template-sync.sh`

**Location**: Within `generate_markdown_summary()` (lines 911-956)

**Changes**:

1. **Summary table** (lines 923-927): Add a row for excluded files:
   ```
   | Excluded | N |
   ```

2. **Excluded files section** (after the deleted files section): Add a new markdown section listing excluded files, similar to the existing Added/Modified/Deleted sections. Include a note explaining that these files were skipped due to `sync_exclusions` in the manifest.

---

### Task 8: Update Schema Documentation

**Goal**: Document the new `sync_exclusions` field in the JSON schema.

**File**: `docs/template-sync/template-state-schema.json`

**Changes**:
- Add `sync_exclusions` to the `properties` object (NOT to `required`)
- Type: `array` of `string` items
- Description: explain it's for glob patterns of project-relative paths to exclude from sync
- Default: `[]` (empty array)
- Add examples showing common patterns

**Note**: Since the field is optional and not in `required`, the `additionalProperties: false` constraint means we MUST add it to `properties` or existing manifests with the field would fail schema validation.

---

### Task 9: Create Test Fixture

**Goal**: Create a manifest fixture with exclusions for testing.

**File**: `test/fixtures/manifests/valid-manifest-with-exclusions.json`

**Content**: Copy of `valid-manifest.json` with an added `sync_exclusions` array containing 2-3 patterns (e.g., `.claude/commands/cove/*`, `.claude/skills/cove/*`).

---

### Task 10: Write Tests

**Goal**: Comprehensive test coverage for the exclusion feature.

**File**: `test/test-template-sync.sh`

**Location**: Add a new section (e.g., "Section 10: Sync Exclusions") before `print_summary`.

**Tests to add**:

1. **`is_excluded` returns false when no exclusions are configured**
   - Set `SYNC_EXCLUSIONS=()`, call `is_excluded ".claude/settings.json"`, assert exit code 1

2. **`is_excluded` matches exact path**
   - Set `SYNC_EXCLUSIONS=(".claude/commands/cove/cove.md")`, call with matching path, assert exit code 0

3. **`is_excluded` matches glob pattern with wildcard**
   - Set `SYNC_EXCLUSIONS=(".claude/commands/cove/*")`, call with `.claude/commands/cove/cove.md`, assert exit code 0

4. **`is_excluded` does not match non-matching path**
   - Set `SYNC_EXCLUSIONS=(".claude/commands/cove/*")`, call with `.claude/commands/tm/list.md`, assert exit code 1

5. **`is_excluded` matches across directory separators**
   - Set `SYNC_EXCLUSIONS=(".claude/commands/cove/*")`, call with `.claude/commands/cove/subdir/file.md`, assert exit code 0

6. **`read_manifest` loads exclusions from manifest**
   - Use the `valid-manifest-with-exclusions.json` fixture
   - Call `read_manifest`, assert `SYNC_EXCLUSIONS` array is populated with correct values

7. **`read_manifest` handles missing exclusions field gracefully**
   - Use existing `valid-manifest.json` fixture (no `sync_exclusions`)
   - Call `read_manifest`, assert `SYNC_EXCLUSIONS` is empty

8. **`validate_manifest` accepts valid exclusions array**
   - Use fixture with valid `sync_exclusions`
   - Call `validate_manifest`, assert no error (exit code 0)

9. **`validate_manifest` accepts manifest without exclusions**
   - Use existing `valid-manifest.json`
   - Call `validate_manifest`, assert no error

10. **`compare_files` excludes matching files from ADDED**
    - Set up staging with files matching an exclusion pattern
    - Set up project without those files (would normally be ADDED)
    - Run `compare_files`, assert matching files are in `EXCLUDED_FILES` not `ADDED_FILES`

11. **`compare_files` excludes matching files from MODIFIED**
    - Set up staging and project with same file but different content, matching exclusion
    - Run `compare_files`, assert file is in `EXCLUDED_FILES` not `MODIFIED_FILES`

12. **`compare_files` skips excluded files in deletion detection**
    - Set up project with files matching exclusion, staging without them
    - Run `compare_files`, assert files are NOT in `DELETED_FILES`

13. **`generate_diff_report` shows excluded count**
    - Set `EXCLUDED_FILES` with entries, call `generate_diff_report`
    - Assert output contains "Excluded"

14. **`generate_diff_report` CI mode includes excluded_count**
    - Set CI_MODE=true, set `EXCLUDED_FILES`, call `generate_diff_report`
    - Assert output contains `excluded_count=N`

**Test patterns to follow**: Match the existing test style in `test/test-template-sync.sh`:
- Use `log_test` for test case headers
- Use `reset_globals` before each test (update this function to also reset `EXCLUDED_FILES` and `SYNC_EXCLUSIONS`)
- Use `create_temp_dir` for temp directories
- Use `assert_equals`, `assert_output_contains` for assertions
- Use `pushd`/`popd` to set working directory for `compare_files` tests

**Important**: The `reset_globals` helper (if it exists) needs to be updated to also reset `EXCLUDED_FILES=()` and `SYNC_EXCLUSIONS=()`.

---

### Task 11: Update User-Facing Documentation

**Goal**: Document the sync exclusions feature for users.

**Files to update**:

1. **`README.md`** (around line 224-236, the "What's Preserved" section):
   - Add a bullet point about sync exclusions
   - Add a new subsection "Configuring Sync Exclusions" after "What's Preserved" that shows:
     - How to add exclusions to the manifest
     - Example patterns
     - Where excluded files appear in the report

2. **`CLAUDE.md`** (Template Sync section):
   - Mention `sync_exclusions` in the manifest description
   - Add a brief note about configuring exclusions

3. **`docs/template-sync/design.md`**:
   - Update the "Limitations" section (line 271): change item 1 from "All-or-nothing updates" to note that sync exclusions now allow selective file exclusion
   - Update the "File Classification" section to mention the user-excluded category
   - Add a reference to the sync-exclusions design doc

---

## Implementation Order

Recommended sequence:

1. **Task 1**: Add globals (foundation - 2 lines)
2. **Task 2**: Add `is_excluded()` function (core logic)
3. **Task 3**: Load exclusions in `read_manifest()` (wiring)
4. **Task 4**: Validate in `validate_manifest()` (safety)
5. **Task 5**: Integrate into `compare_files()` (main feature)
6. **Task 6**: Update `generate_diff_report()` (reporting)
7. **Task 7**: Update `generate_markdown_summary()` (PR body)
8. **Task 8**: Update schema documentation
9. **Task 9**: Create test fixture
10. **Task 10**: Write tests
11. **Task 11**: Update user documentation

Tasks 1-7 are the core implementation and should be done sequentially (each builds on the previous).
Task 8-9 can be done in parallel with the core implementation.
Task 10 should be done after Tasks 1-7 are complete.
Task 11 can be done last.

## Technical Notes

### Bash `case` Glob Matching Behavior

In bash `case` statements, `*` matches any string including `/` characters. This differs from `find -path` where `*` also matches `/`, but differs from `ls` globs where `*` does not match `/`.

```bash
# This WILL match (case * crosses directory separators)
case ".claude/commands/cove/subdir/file.md" in
    .claude/commands/cove/*) echo "match" ;;
esac
```

### `mapfile` for Safe Array Loading

Using `mapfile` (aka `readarray`) is the safest way to load jq output into a bash array:

```bash
mapfile -t SYNC_EXCLUSIONS < <(jq -r '.sync_exclusions[]' "$MANIFEST_PATH")
```

This correctly handles:
- Spaces in patterns (each line becomes one array element)
- Empty output (array stays empty)
- Special characters in patterns

### The `reset_globals` Function in Tests

The test file uses a `reset_globals` function to clean state between tests. It needs to be found and updated to include the new globals. Search for `reset_globals` in `test/test-template-sync.sh` to find its definition.
