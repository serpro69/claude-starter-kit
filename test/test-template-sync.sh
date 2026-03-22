#!/usr/bin/env bash
# Test suite for template-sync.sh functions
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TEMPLATE_SYNC_SCRIPT="$REPO_ROOT/.github/scripts/template-sync.sh"

# Source the script to get access to functions
# The script has a sourcing guard that prevents main() from running when sourced
# shellcheck source=/dev/null
source "$TEMPLATE_SYNC_SCRIPT"

# =============================================================================
# Section 1: Argument Parsing Tests
# =============================================================================

log_section "Section 1: Argument Parsing"

# Reset globals before each test
reset_globals() {
  MANIFEST_PATH=".github/template-state.json"
  STAGING_DIR=""
  DRY_RUN=false
  CI_MODE=false
  TARGET_VERSION="latest"
  # Reset exclusion tracking arrays
  EXCLUDED_FILES=()
  SYNC_EXCLUSIONS=()
}

log_test "parse_arguments with --version flag"
reset_globals
parse_arguments --version v2.0.0
assert_equals "v2.0.0" "$TARGET_VERSION" "--version sets TARGET_VERSION"

log_test "parse_arguments with --dry-run flag"
reset_globals
parse_arguments --dry-run
assert_equals "true" "$DRY_RUN" "--dry-run sets DRY_RUN=true"

log_test "parse_arguments with --ci flag"
reset_globals
parse_arguments --ci
assert_equals "true" "$CI_MODE" "--ci sets CI_MODE=true"

log_test "parse_arguments with --output-dir flag"
reset_globals
parse_arguments --output-dir /tmp/test-staging
assert_equals "/tmp/test-staging" "$STAGING_DIR" "--output-dir sets STAGING_DIR"

log_test "parse_arguments with multiple flags"
reset_globals
parse_arguments --version v1.5.0 --dry-run --ci --output-dir /tmp/multi
assert_equals "v1.5.0" "$TARGET_VERSION" "Multiple flags: TARGET_VERSION"
assert_equals "true" "$DRY_RUN" "Multiple flags: DRY_RUN"
assert_equals "true" "$CI_MODE" "Multiple flags: CI_MODE"
assert_equals "/tmp/multi" "$STAGING_DIR" "Multiple flags: STAGING_DIR"

log_test "parse_arguments with no flags uses defaults"
reset_globals
parse_arguments
assert_equals "latest" "$TARGET_VERSION" "Default TARGET_VERSION is 'latest'"
assert_equals "false" "$DRY_RUN" "Default DRY_RUN is false"
assert_equals "false" "$CI_MODE" "Default CI_MODE is false"

log_test "parse_arguments --version without value exits with code 2"
reset_globals
set +e
output=$(parse_arguments --version 2>&1)
exit_code=$?
set -e
assert_equals "2" "$exit_code" "--version without value exits with code 2"

log_test "parse_arguments --output-dir without value exits with code 2"
reset_globals
set +e
output=$(parse_arguments --output-dir 2>&1)
exit_code=$?
set -e
assert_equals "2" "$exit_code" "--output-dir without value exits with code 2"

log_test "parse_arguments with unknown option exits with code 2"
reset_globals
set +e
output=$(parse_arguments --unknown-flag 2>&1)
exit_code=$?
set -e
assert_equals "2" "$exit_code" "Unknown option exits with code 2"

# =============================================================================
# Section 2: Manifest Reading Tests
# =============================================================================

log_section "Section 2: Manifest Reading"

log_test "read_manifest fails when file is missing"
reset_globals
MANIFEST_PATH="/nonexistent/manifest.json"
set +e
output=$(read_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "read_manifest exits non-zero for missing file"

log_test "read_manifest fails for invalid JSON"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/invalid-json.txt"
set +e
output=$(read_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "read_manifest exits non-zero for invalid JSON"

log_test "read_manifest succeeds for valid manifest"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
set +e
output=$(read_manifest 2>&1)
exit_code=$?
set -e
assert_equals "0" "$exit_code" "read_manifest succeeds for valid manifest"

log_test "read_manifest fails when schema_version is missing"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/missing-schema-version.json"
set +e
output=$(read_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "read_manifest fails for missing schema_version"

log_test "read_manifest fails when variables object is missing"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/missing-variables.json"
set +e
output=$(read_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "read_manifest fails for missing variables"

# =============================================================================
# Section 3: Manifest Validation Tests
# =============================================================================

log_section "Section 3: Manifest Validation"

log_test "validate_manifest fails for unsupported schema version"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/unsupported-schema.json"
# Need to call read_manifest first (it succeeds since JSON is valid)
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "validate_manifest fails for schema version 2"

log_test "validate_manifest fails for invalid upstream_repo format"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/invalid-upstream-repo.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "validate_manifest fails for invalid upstream_repo format"

log_test "validate_manifest succeeds for valid manifest"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_equals "0" "$exit_code" "validate_manifest succeeds for valid manifest"

# =============================================================================
# Section 4: Escape Function Tests
# =============================================================================

log_section "Section 4: Escape Function"

log_test "escape_sed_replacement escapes ampersand"
result=$(escape_sed_replacement "foo & bar")
assert_equals 'foo \& bar' "$result" "Ampersand escaped to \\&"

log_test "escape_sed_replacement escapes backslash"
result=$(escape_sed_replacement 'C:\Users\test')
assert_equals 'C:\\Users\\test' "$result" "Backslashes escaped"

log_test "escape_sed_replacement escapes forward slash"
result=$(escape_sed_replacement "path/to/file")
assert_equals 'path\/to\/file' "$result" "Forward slashes escaped"

log_test "escape_sed_replacement handles empty string"
result=$(escape_sed_replacement "")
assert_equals "" "$result" "Empty string returns empty"

log_test "escape_sed_replacement handles combined special characters"
result=$(escape_sed_replacement 'a/b&c\d')
# Each special char should be escaped
assert_output_contains '\/' "echo '$result'" "Combined: forward slash escaped"
assert_output_contains '\&' "echo '$result'" "Combined: ampersand escaped"
assert_output_contains '\\' "echo '$result'" "Combined: backslash escaped"

# =============================================================================
# Section 5: Substitution Tests
# =============================================================================

log_section "Section 5: Substitution Application"

log_test "apply_substitutions substitutes PROJECT_NAME in serena config"
reset_globals
test_dir=$(create_temp_dir "subst-test")

# Create a test manifest
MANIFEST_PATH="$test_dir/manifest.json"
cat >"$MANIFEST_PATH" <<'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-custom-project",
    "LANGUAGES": "python",
    "CC_MODEL": "opus",
    "SERENA_INITIAL_PROMPT": ""
  }
}
EOF

# Create template directory with fixtures
mkdir -p "$test_dir/templates/serena"
cat >"$test_dir/templates/serena/project.yml" <<'EOF'
project_name: "PLACEHOLDER"
languages:
  - bash
initial_prompt: ""
EOF

# Apply substitutions
output_dir="$test_dir/output"
apply_substitutions "$test_dir/templates" "$output_dir" 2>/dev/null

# Check result
result=$(grep 'project_name' "$output_dir/serena/project.yml")
assert_output_contains "my-custom-project" "echo '$result'" "PROJECT_NAME substituted in serena config"

log_test "apply_substitutions handles CC_MODEL=default (removes model line)"
reset_globals
test_dir=$(create_temp_dir "subst-model-test")

MANIFEST_PATH="$test_dir/manifest.json"
cat >"$MANIFEST_PATH" <<'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test-proj",
    "LANGUAGES": "bash",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": ""
  }
}
EOF

mkdir -p "$test_dir/templates/claude"
cat >"$test_dir/templates/claude/settings.json" <<'EOF'
{
  "model": "sonnet",
  "permissions": {}
}
EOF

output_dir="$test_dir/output"
apply_substitutions "$test_dir/templates" "$output_dir" 2>/dev/null

# The model line should be removed
if grep -q '"model"' "$output_dir/claude/settings.json"; then
  log_fail "CC_MODEL=default should remove model line"
else
  log_pass "CC_MODEL=default removes model line from settings"
fi

log_test "apply_substitutions substitutes non-default CC_MODEL"
reset_globals
test_dir=$(create_temp_dir "subst-model-value-test")

MANIFEST_PATH="$test_dir/manifest.json"
cat >"$MANIFEST_PATH" <<'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test-proj",
    "LANGUAGES": "bash",
    "CC_MODEL": "claude-opus",
    "SERENA_INITIAL_PROMPT": ""
  }
}
EOF

mkdir -p "$test_dir/templates/claude"
cat >"$test_dir/templates/claude/settings.json" <<'EOF'
{
  "model": "placeholder",
  "permissions": {}
}
EOF

output_dir="$test_dir/output"
apply_substitutions "$test_dir/templates" "$output_dir" 2>/dev/null

result=$(grep 'model' "$output_dir/claude/settings.json")
assert_output_contains "claude-opus" "echo '$result'" "CC_MODEL value substituted"

# =============================================================================
# Section 6: File Comparison Tests
# =============================================================================

log_section "Section 6: File Comparison"

log_test "compare_files detects added files"
reset_globals
test_dir=$(create_temp_dir "compare-added")

# Create staging with a file
mkdir -p "$test_dir/staging/claude"
echo "new content" >"$test_dir/staging/claude/new-file.txt"

# Create empty project directory
mkdir -p "$test_dir/project/.claude"

# Run compare from project directory (use pushd/popd for safe directory handling)
pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#ADDED_FILES[@]}" "One file detected as added"

log_test "compare_files detects modified files"
reset_globals
test_dir=$(create_temp_dir "compare-modified")

# Create staging and project with same file, different content
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "new content" >"$test_dir/staging/claude/existing.txt"
echo "old content" >"$test_dir/project/.claude/existing.txt"

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#MODIFIED_FILES[@]}" "One file detected as modified"

log_test "compare_files detects deleted files"
reset_globals
test_dir=$(create_temp_dir "compare-deleted")

# Create staging without the file, project with it
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "to be deleted" >"$test_dir/project/.claude/deleted.txt"

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#DELETED_FILES[@]}" "One file detected as deleted"

log_test "compare_files detects unchanged files"
reset_globals
test_dir=$(create_temp_dir "compare-unchanged")

# Create identical files in staging and project
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "same content" >"$test_dir/staging/claude/unchanged.txt"
echo "same content" >"$test_dir/project/.claude/unchanged.txt"

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#UNCHANGED_FILES[@]}" "One file detected as unchanged"

log_test "compare_files does NOT flag scripts/workflows files as deleted (sync infrastructure exclusion)"
reset_globals
test_dir=$(create_temp_dir "compare-scripts-excluded")

# Create staging with only template-sync.sh (mimics what copy_sync_files does)
mkdir -p "$test_dir/staging/scripts"
mkdir -p "$test_dir/staging/workflows"
echo "sync script content" >"$test_dir/staging/scripts/template-sync.sh"
echo "sync workflow content" >"$test_dir/staging/workflows/template-sync.yml"

# Create project with additional files (bootstrap.sh, template-cleanup.*)
mkdir -p "$test_dir/project/.github/scripts"
mkdir -p "$test_dir/project/.github/workflows"
echo "sync script content" >"$test_dir/project/.github/scripts/template-sync.sh"
echo "bootstrap content" >"$test_dir/project/.github/scripts/bootstrap.sh"
echo "cleanup script" >"$test_dir/project/.github/scripts/template-cleanup.sh"
echo "sync workflow content" >"$test_dir/project/.github/workflows/template-sync.yml"
echo "cleanup workflow" >"$test_dir/project/.github/workflows/template-cleanup.yml"

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

# bootstrap.sh and template-cleanup.* should NOT be in DELETED_FILES
assert_equals "0" "${#DELETED_FILES[@]}" "No files should be flagged as deleted in scripts/workflows dirs"
# The sync files should be detected as unchanged
assert_equals "2" "${#UNCHANGED_FILES[@]}" "Only the sync infrastructure files should be compared"

# =============================================================================
# Section 7: Diff Report Generation Tests
# =============================================================================

log_section "Section 7: Diff Report Generation"

log_test "generate_diff_report shows version transition"
reset_globals
test_dir=$(create_temp_dir "diff-report")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "v1.0.0" "echo '$output'" "Report shows current version"
assert_output_contains "v2.0.0" "echo '$output'" "Report shows target version"

log_test "generate_diff_report shows 'up to date' when no changes"
reset_globals
test_dir=$(create_temp_dir "diff-report-nochange")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v1.0.0"
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "up to date" "echo '$output'" "Report shows 'up to date' message"

log_test "generate_diff_report shows counts when changes exist"
reset_globals
test_dir=$(create_temp_dir "diff-report-changes")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=("file1.txt" "file2.txt")
MODIFIED_FILES=("file3.txt")
DELETED_FILES=()
UNCHANGED_FILES=()

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "Added" "echo '$output'" "Report shows added count"
assert_output_contains "Modified" "echo '$output'" "Report shows modified count"

log_test "generate_diff_report CI mode outputs GitHub Actions format"
reset_globals
test_dir=$(create_temp_dir "diff-report-ci")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
CI_MODE=true
ADDED_FILES=("file1.txt")
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "has_changes=true" "echo '$output'" "CI mode outputs has_changes"
assert_output_contains "added_count=1" "echo '$output'" "CI mode outputs added_count"

# =============================================================================
# Section 8: Sync Infrastructure Copying Tests
# =============================================================================

log_section "Section 8: Sync Infrastructure Copying"

log_test "copy_sync_files copies workflow when present"
reset_globals
test_dir=$(create_temp_dir "copy-sync-workflow")

# Create upstream directory structure with workflow
mkdir -p "$test_dir/upstream/.github/workflows"
echo "name: Template Sync" >"$test_dir/upstream/.github/workflows/template-sync.yml"

# Create output directory
output_dir="$test_dir/output"

copy_sync_files "$test_dir/upstream" "$output_dir" 2>/dev/null

assert_file_exists "$output_dir/workflows/template-sync.yml" "Workflow copied to staging"

log_test "copy_sync_files copies script when present"
reset_globals
test_dir=$(create_temp_dir "copy-sync-script")

# Create upstream directory structure with script
mkdir -p "$test_dir/upstream/.github/scripts"
echo "#!/bin/bash" >"$test_dir/upstream/.github/scripts/template-sync.sh"

# Create output directory
output_dir="$test_dir/output"

copy_sync_files "$test_dir/upstream" "$output_dir" 2>/dev/null

assert_file_exists "$output_dir/scripts/template-sync.sh" "Script copied to staging"

log_test "copy_sync_files handles missing files gracefully"
reset_globals
test_dir=$(create_temp_dir "copy-sync-missing")

# Create upstream directory structure without sync files
mkdir -p "$test_dir/upstream/.github"

# Create output directory
output_dir="$test_dir/output"

# Should not fail even if files don't exist
copy_sync_files "$test_dir/upstream" "$output_dir" 2>/dev/null
exit_code=$?

assert_equals "0" "$exit_code" "copy_sync_files succeeds even when files are missing"

log_test "copy_sync_files copies both files when both present"
reset_globals
test_dir=$(create_temp_dir "copy-sync-both")

# Create upstream directory structure with both files
mkdir -p "$test_dir/upstream/.github/workflows"
mkdir -p "$test_dir/upstream/.github/scripts"
echo "name: Template Sync" >"$test_dir/upstream/.github/workflows/template-sync.yml"
echo "#!/bin/bash" >"$test_dir/upstream/.github/scripts/template-sync.sh"

# Create output directory
output_dir="$test_dir/output"

copy_sync_files "$test_dir/upstream" "$output_dir" 2>/dev/null

assert_file_exists "$output_dir/workflows/template-sync.yml" "Workflow copied when both present"
assert_file_exists "$output_dir/scripts/template-sync.sh" "Script copied when both present"

# =============================================================================
# Section 9: Version Resolution Tests
# =============================================================================

log_section "Section 9: Version Resolution"

# Note: resolve_version() now resolves symbolic refs (main, master, HEAD) to actual SHAs
# via git ls-remote. These tests require network access to GitHub.

log_test "resolve_version returns specific tag as-is"
reset_globals
# Specific tags are returned without modification
result=$(resolve_version "v1.0.0" "serpro69/claude-toolbox")
# Should return the tag name as-is
assert_equals "v1.0.0" "$result" "Specific tag returned as-is"

log_test "resolve_version resolves 'master' to SHA"
reset_globals
set +e
result=$(resolve_version "master" "serpro69/claude-toolbox" 2>/dev/null)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
  # Should be a full SHA (40 hex characters)
  if [[ "$result" =~ ^[a-f0-9]{40}$ ]]; then
    log_pass "master resolved to SHA: ${result:0:12}..."
  else
    log_fail "master should resolve to 40-char SHA, got: $result"
  fi
else
  log_skip "Network required to resolve 'master' branch"
fi

log_test "resolve_version resolves 'HEAD' to SHA"
reset_globals
set +e
result=$(resolve_version "HEAD" "serpro69/claude-toolbox" 2>/dev/null)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
  # Should be a full SHA (40 hex characters)
  if [[ "$result" =~ ^[a-f0-9]{40}$ ]]; then
    log_pass "HEAD resolved to SHA: ${result:0:12}..."
  else
    log_fail "HEAD should resolve to 40-char SHA, got: $result"
  fi
else
  log_skip "Network required to resolve HEAD"
fi

log_test "resolve_version resolves 'latest' to most recent tag"
reset_globals
set +e
result=$(resolve_version "latest" "serpro69/claude-toolbox" 2>/dev/null)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
  # Should return tag name (human-readable), not SHA
  if [[ "$result" =~ ^v[0-9] ]]; then
    log_pass "latest resolved to tag: $result"
  else
    log_fail "latest should resolve to tag name, got: $result"
  fi
else
  log_skip "Network required to resolve 'latest'"
fi

log_test "resolve_version returns arbitrary values as-is (validation happens during fetch)"
reset_globals
# Arbitrary values (like specific tags or SHAs) are returned as-is
# Validation of whether they exist happens in fetch_upstream_templates()
result=$(resolve_version "v99.99.99" "serpro69/claude-toolbox")
assert_equals "v99.99.99" "$result" "Arbitrary value returned as-is"

# =============================================================================
# Section 10: Sync Exclusion - is_excluded() Tests
# =============================================================================

log_section "Section 10: Sync Exclusion - is_excluded()"

log_test "is_excluded returns 1 when no exclusions configured"
reset_globals
SYNC_EXCLUSIONS=()
set +e
is_excluded ".claude/settings.json"
exit_code=$?
set -e
assert_equals "1" "$exit_code" "No exclusions means not excluded"

log_test "is_excluded returns 0 for exact path match"
reset_globals
SYNC_EXCLUSIONS=(".claude/commands/cove/cove.md")
set +e
is_excluded ".claude/commands/cove/cove.md"
exit_code=$?
set -e
assert_equals "0" "$exit_code" "Exact path match is excluded"

log_test "is_excluded returns 0 for glob pattern with trailing wildcard"
reset_globals
SYNC_EXCLUSIONS=(".claude/commands/cove/*")
set +e
is_excluded ".claude/commands/cove/cove.md"
exit_code=$?
set -e
assert_equals "0" "$exit_code" "Glob wildcard matches file in directory"

log_test "is_excluded returns 1 for non-matching path"
reset_globals
SYNC_EXCLUSIONS=(".claude/commands/cove/*")
set +e
is_excluded ".claude/commands/tm/list.md"
exit_code=$?
set -e
assert_equals "1" "$exit_code" "Non-matching path is not excluded"

log_test "is_excluded matches across directory separators (bash case * crosses /)"
reset_globals
SYNC_EXCLUSIONS=(".claude/commands/cove/*")
set +e
is_excluded ".claude/commands/cove/subdir/file.md"
exit_code=$?
set -e
assert_equals "0" "$exit_code" "Glob * matches across directory separators"

log_test "is_excluded handles multiple patterns (second pattern matches)"
reset_globals
SYNC_EXCLUSIONS=(".serena/project.yml" ".claude/commands/cove/*")
set +e
is_excluded ".claude/commands/cove/cove.md"
exit_code=$?
set -e
assert_equals "0" "$exit_code" "Second pattern in list matches"

# =============================================================================
# Section 11: Manifest sync_exclusions - read_manifest() and validate_manifest()
# =============================================================================

log_section "Section 11: Manifest sync_exclusions Loading and Validation"

log_test "read_manifest loads sync_exclusions from manifest"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest-with-exclusions.json"
read_manifest 2>/dev/null
assert_equals "2" "${#SYNC_EXCLUSIONS[@]}" "SYNC_EXCLUSIONS has 2 patterns"
assert_equals ".claude/commands/cove/*" "${SYNC_EXCLUSIONS[0]}" "First exclusion pattern correct"
assert_equals ".claude/skills/cove/*" "${SYNC_EXCLUSIONS[1]}" "Second exclusion pattern correct"

log_test "read_manifest handles missing sync_exclusions (optional field)"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
read_manifest 2>/dev/null
assert_equals "0" "${#SYNC_EXCLUSIONS[@]}" "SYNC_EXCLUSIONS is empty when field absent"

log_test "validate_manifest accepts valid sync_exclusions array"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest-with-exclusions.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_equals "0" "$exit_code" "validate_manifest passes with valid sync_exclusions"

log_test "validate_manifest accepts manifest without sync_exclusions"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_equals "0" "$exit_code" "validate_manifest passes without sync_exclusions"

log_test "validate_manifest rejects sync_exclusions that is not an array"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/exclusions-not-array.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "validate_manifest fails when sync_exclusions is a string"

log_test "validate_manifest rejects sync_exclusions with non-string elements"
reset_globals
MANIFEST_PATH="$FIXTURES_DIR/manifests/exclusions-non-string-elements.json"
read_manifest 2>/dev/null || true
set +e
output=$(validate_manifest 2>&1)
exit_code=$?
set -e
assert_not_equals "0" "$exit_code" "validate_manifest fails when sync_exclusions contains non-strings"

# =============================================================================
# Section 12: compare_files() Exclusion Integration Tests
# =============================================================================

log_section "Section 12: compare_files() Exclusion Integration"

log_test "compare_files excludes matching files from ADDED"
reset_globals
test_dir=$(create_temp_dir "compare-excl-added")

# Create staging with a file that matches exclusion pattern
mkdir -p "$test_dir/staging/claude/commands/cove"
echo "excluded content" >"$test_dir/staging/claude/commands/cove/cove.md"

# Create empty project directory
mkdir -p "$test_dir/project/.claude/commands/cove"

# Set exclusion pattern
SYNC_EXCLUSIONS=(".claude/commands/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "0" "${#ADDED_FILES[@]}" "Excluded file not in ADDED_FILES"
assert_equals "1" "${#EXCLUDED_FILES[@]}" "Excluded file tracked in EXCLUDED_FILES"

log_test "compare_files excludes matching files from MODIFIED"
reset_globals
test_dir=$(create_temp_dir "compare-excl-modified")

# Create staging and project with same file (different content) matching exclusion
mkdir -p "$test_dir/staging/claude/commands/cove"
mkdir -p "$test_dir/project/.claude/commands/cove"
echo "new content" >"$test_dir/staging/claude/commands/cove/cove.md"
echo "old content" >"$test_dir/project/.claude/commands/cove/cove.md"

SYNC_EXCLUSIONS=(".claude/commands/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "0" "${#MODIFIED_FILES[@]}" "Excluded file not in MODIFIED_FILES"
assert_equals "1" "${#EXCLUDED_FILES[@]}" "Excluded file tracked in EXCLUDED_FILES"

log_test "compare_files skips excluded files in deletion detection"
reset_globals
test_dir=$(create_temp_dir "compare-excl-deleted")

# Create project with file matching exclusion (not in staging)
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude/commands/cove"
echo "local only" >"$test_dir/project/.claude/commands/cove/cove.md"

SYNC_EXCLUSIONS=(".claude/commands/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "0" "${#DELETED_FILES[@]}" "Excluded file not in DELETED_FILES"

log_test "compare_files categorizes non-excluded files normally alongside exclusions"
reset_globals
test_dir=$(create_temp_dir "compare-excl-mixed")

# Create staging with excluded and non-excluded files
mkdir -p "$test_dir/staging/claude/commands/cove"
mkdir -p "$test_dir/staging/claude/commands/tm"
echo "excluded" >"$test_dir/staging/claude/commands/cove/cove.md"
echo "included" >"$test_dir/staging/claude/commands/tm/list.md"

# Create empty project dirs
mkdir -p "$test_dir/project/.claude/commands/cove"
mkdir -p "$test_dir/project/.claude/commands/tm"

SYNC_EXCLUSIONS=(".claude/commands/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#ADDED_FILES[@]}" "Non-excluded file still categorized as added"
assert_equals "1" "${#EXCLUDED_FILES[@]}" "Excluded file tracked"
assert_equals "0" "${#MODIFIED_FILES[@]}" "No modified files"

log_test "compare_files handles multiple exclusion patterns"
reset_globals
test_dir=$(create_temp_dir "compare-excl-multi")

# Create staging with files matching different exclusion patterns
mkdir -p "$test_dir/staging/claude/commands/cove"
mkdir -p "$test_dir/staging/claude/skills/cove"
mkdir -p "$test_dir/staging/claude/commands/tm"
echo "excluded1" >"$test_dir/staging/claude/commands/cove/cove.md"
echo "excluded2" >"$test_dir/staging/claude/skills/cove/skill.md"
echo "included" >"$test_dir/staging/claude/commands/tm/list.md"

# Create empty project dirs
mkdir -p "$test_dir/project/.claude/commands/cove"
mkdir -p "$test_dir/project/.claude/skills/cove"
mkdir -p "$test_dir/project/.claude/commands/tm"

SYNC_EXCLUSIONS=(".claude/commands/cove/*" ".claude/skills/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#ADDED_FILES[@]}" "Non-excluded file categorized as added"
assert_equals "2" "${#EXCLUDED_FILES[@]}" "Both excluded files tracked"

log_test "compare_files does not double-count files in EXCLUDED_FILES"
reset_globals
test_dir=$(create_temp_dir "compare-excl-nodup")

# Create file in both staging and project matching exclusion
mkdir -p "$test_dir/staging/claude/commands/cove"
mkdir -p "$test_dir/project/.claude/commands/cove"
echo "same content" >"$test_dir/staging/claude/commands/cove/cove.md"
echo "same content" >"$test_dir/project/.claude/commands/cove/cove.md"

SYNC_EXCLUSIONS=(".claude/commands/cove/*")

pushd "$test_dir/project" >/dev/null || {
  log_fail "Failed to cd to test directory"
  exit 1
}
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null || true

assert_equals "1" "${#EXCLUDED_FILES[@]}" "Excluded file counted only once (not double-counted)"
assert_equals "0" "${#UNCHANGED_FILES[@]}" "Excluded file not in UNCHANGED_FILES"

# =============================================================================
# Section 13: Reporting Functions - Excluded Files Display
# =============================================================================

log_section "Section 13: Reporting Functions - Excluded Files Display"

log_test "generate_diff_report shows excluded count in summary"
reset_globals
test_dir=$(create_temp_dir "diff-report-excluded-summary")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=("file1.txt")
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
EXCLUDED_FILES=(".claude/commands/cove/cove.md" ".claude/skills/cove/SKILL.md")

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "Excluded:" "echo '$output'" "Report shows 'Excluded:' line in summary"

log_test "generate_diff_report lists excluded files with marker"
reset_globals
test_dir=$(create_temp_dir "diff-report-excluded-list")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=("file1.txt")
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
EXCLUDED_FILES=(".claude/commands/cove/cove.md" ".claude/skills/cove/SKILL.md")

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "Excluded files (via sync_exclusions):" "echo '$output'" "Report shows excluded files header"
assert_output_contains ".claude/commands/cove/cove.md" "echo '$output'" "Report lists first excluded file"
assert_output_contains ".claude/skills/cove/SKILL.md" "echo '$output'" "Report lists second excluded file"

log_test "generate_diff_report CI mode includes excluded_count"
reset_globals
test_dir=$(create_temp_dir "diff-report-ci-excluded")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
CI_MODE=true
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
EXCLUDED_FILES=(".claude/commands/cove/cove.md" ".claude/skills/cove/SKILL.md")

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "excluded_count=2" "echo '$output'" "CI mode outputs excluded_count=2"

log_test "excluded_count does NOT affect has_changes"
reset_globals
test_dir=$(create_temp_dir "diff-report-excluded-no-changes")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
CI_MODE=true
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
EXCLUDED_FILES=(".claude/commands/cove/cove.md")

output=$(generate_diff_report "$test_dir/staging" 2>&1)
assert_output_contains "has_changes=false" "echo '$output'" "has_changes is false when only excluded files present"
assert_output_contains "excluded_count=1" "echo '$output'" "excluded_count still reported"

log_test "generate_markdown_summary includes excluded files section"
reset_globals
test_dir=$(create_temp_dir "markdown-summary-excluded")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
EXCLUDED_FILES=(".claude/commands/cove/cove.md" ".claude/skills/cove/SKILL.md")

output=$(generate_markdown_summary "$test_dir/staging" 2>&1)
assert_output_contains "| Excluded | 2 |" "echo '$output'" "Markdown table contains Excluded row"
assert_output_contains "### Excluded Files" "echo '$output'" "Markdown contains Excluded Files heading"
assert_output_contains "sync_exclusions" "echo '$output'" "Markdown contains explanatory text about sync_exclusions"
assert_output_contains ".claude/commands/cove/cove.md" "echo '$output'" "Markdown lists first excluded file"
assert_output_contains ".claude/skills/cove/SKILL.md" "echo '$output'" "Markdown lists second excluded file"

log_test "generate_diff_report does not show excluded section when no exclusions"
reset_globals
test_dir=$(create_temp_dir "diff-report-no-excluded")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=("file1.txt")
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()
EXCLUDED_FILES=()

output=$(generate_diff_report "$test_dir/staging" 2>&1)
# Should NOT contain the excluded files header when there are no exclusions
if [[ "$output" == *"Excluded files (via sync_exclusions):"* ]]; then
  log_fail "Report should not show excluded files section when EXCLUDED_FILES is empty"
else
  log_pass "Report correctly omits excluded files section when no exclusions"
fi

log_test "generate_markdown_summary omits excluded section when no exclusions"
reset_globals
test_dir=$(create_temp_dir "markdown-no-excluded")
mkdir -p "$test_dir/staging"

MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
RESOLVED_VERSION="v2.0.0"
ADDED_FILES=("file1.txt")
MODIFIED_FILES=()
DELETED_FILES=()
EXCLUDED_FILES=()

output=$(generate_markdown_summary "$test_dir/staging" 2>&1)
assert_output_contains "| Excluded | 0 |" "echo '$output'" "Markdown table shows Excluded count 0"
if [[ "$output" == *"### Excluded Files"* ]]; then
  log_fail "Markdown should not show Excluded Files section when EXCLUDED_FILES is empty"
else
  log_pass "Markdown correctly omits Excluded Files section when no exclusions"
fi

# =============================================================================
# Section 14: Manifest Migration Tests
# =============================================================================

log_section "Section 14: Manifest Migration"

log_test "migrate_manifest rewrites old upstream_repo to new value"
reset_globals
test_dir=$(mktemp -d)
cat > "$test_dir/manifest.json" <<'JSON'
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-project",
    "LANGUAGES": "typescript",
    "CC_MODEL": "sonnet",
    "SERENA_INITIAL_PROMPT": ""
  }
}
JSON
MANIFEST_PATH="$test_dir/manifest.json"
read_manifest
validate_manifest
migrate_manifest
result=$(jq -r '.upstream_repo' "$MANIFEST_PATH")
assert_equals "serpro69/claude-toolbox" "$result" "upstream_repo rewritten to serpro69/claude-toolbox"
rm -rf "$test_dir"

log_test "migrate_manifest does not modify manifest with current upstream_repo"
reset_globals
test_dir=$(mktemp -d)
cp "$FIXTURES_DIR/manifests/valid-manifest.json" "$test_dir/manifest.json"
MANIFEST_PATH="$test_dir/manifest.json"
read_manifest
validate_manifest
# Capture file checksum before migration
before=$(md5sum "$MANIFEST_PATH" | cut -d' ' -f1)
migrate_manifest
after=$(md5sum "$MANIFEST_PATH" | cut -d' ' -f1)
assert_equals "$before" "$after" "manifest not modified when upstream_repo is already current"
rm -rf "$test_dir"

log_test "migrate_manifest emits log message when migration triggers"
reset_globals
test_dir=$(mktemp -d)
cat > "$test_dir/manifest.json" <<'JSON'
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-project",
    "LANGUAGES": "typescript",
    "CC_MODEL": "sonnet",
    "SERENA_INITIAL_PROMPT": ""
  }
}
JSON
MANIFEST_PATH="$test_dir/manifest.json"
read_manifest
validate_manifest
output=$(migrate_manifest 2>&1)
assert_output_contains "Migrating upstream_repo" "echo '$output'" "migration emits log message"
rm -rf "$test_dir"

# =============================================================================
# Section: Plugin Migration Detection
# =============================================================================

log_section "Plugin Migration Detection"

log_test "needs_plugin_migration returns true when upstream has plugin and not yet migrated"
reset_globals
test_dir=$(create_temp_dir "plugin-migration")
# Create upstream with plugin manifest
mkdir -p "$test_dir/upstream/klaude-plugin/.claude-plugin"
echo '{"name":"kk"}' > "$test_dir/upstream/klaude-plugin/.claude-plugin/plugin.json"
# Create manifest without plugin_migrated flag
mkdir -p "$test_dir/project/.github"
cat > "$test_dir/project/.github/template-state.json" <<'JSON'
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-toolbox",
  "template_version": "v0.4.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test",
    "LANGUAGES": "bash",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": ""
  }
}
JSON
MANIFEST_PATH="$test_dir/project/.github/template-state.json"
if needs_plugin_migration "$test_dir/upstream"; then
  log_pass "Migration needed when upstream has plugin and no flag set"
else
  log_fail "Should need migration when upstream has plugin and no plugin_migrated flag"
fi

log_test "needs_plugin_migration returns false when already migrated"
reset_globals
# Add plugin_migrated flag
jq '.plugin_migrated = true' "$test_dir/project/.github/template-state.json" > "$test_dir/project/.github/template-state.json.tmp"
mv "$test_dir/project/.github/template-state.json.tmp" "$test_dir/project/.github/template-state.json"
MANIFEST_PATH="$test_dir/project/.github/template-state.json"
if needs_plugin_migration "$test_dir/upstream"; then
  log_fail "Should not need migration when plugin_migrated is true"
else
  log_pass "No migration needed when plugin_migrated flag is set"
fi

log_test "needs_plugin_migration returns false when upstream has no plugin"
reset_globals
test_dir2=$(create_temp_dir "plugin-migration-no-upstream")
# Upstream without plugin manifest
mkdir -p "$test_dir2/upstream"
mkdir -p "$test_dir2/project/.github"
cat > "$test_dir2/project/.github/template-state.json" <<'JSON'
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-toolbox",
  "template_version": "v0.3.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test",
    "LANGUAGES": "bash",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": ""
  }
}
JSON
MANIFEST_PATH="$test_dir2/project/.github/template-state.json"
if needs_plugin_migration "$test_dir2/upstream"; then
  log_fail "Should not need migration when upstream has no plugin"
else
  log_pass "No migration needed when upstream lacks plugin manifest"
fi

# =============================================================================
# Section: Plugin Migration Execution
# =============================================================================

log_section "Plugin Migration Execution"

log_test "run_plugin_migration removes skills, commands, and validate-bash.sh"
reset_globals
test_dir=$(create_temp_dir "plugin-exec")
mkdir -p "$test_dir/.claude/skills/cove" "$test_dir/.claude/skills/analysis-process"
mkdir -p "$test_dir/.claude/commands/cove" "$test_dir/.claude/commands/sync-workflow"
mkdir -p "$test_dir/.claude/scripts"
echo "skill" > "$test_dir/.claude/skills/cove/SKILL.md"
echo "skill" > "$test_dir/.claude/skills/analysis-process/SKILL.md"
echo "cmd" > "$test_dir/.claude/commands/cove/cove.md"
echo "cmd" > "$test_dir/.claude/commands/sync-workflow/sync-workflow.md"
echo "script" > "$test_dir/.claude/scripts/validate-bash.sh"
echo "keep" > "$test_dir/.claude/scripts/statusline.sh"
cat > "$test_dir/.claude/settings.json" <<'JSON'
{
  "hooks": {"PreToolUse": [{"matcher": "Bash"}]},
  "model": "sonnet"
}
JSON
mkdir -p "$test_dir/.github"
cat > "$test_dir/.github/template-state.json" <<'JSON'
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-toolbox",
  "template_version": "v0.4.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test",
    "LANGUAGES": "bash",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": ""
  }
}
JSON
MANIFEST_PATH="$test_dir/.github/template-state.json"
DELETED_FILES=()
pushd "$test_dir" >/dev/null
run_plugin_migration >/dev/null 2>&1
popd >/dev/null

# Verify deletions
if [[ ! -d "$test_dir/.claude/skills" ]]; then
  log_pass "skills/ directory removed"
else
  log_fail "skills/ directory should be removed"
fi
if [[ ! -d "$test_dir/.claude/commands" ]]; then
  log_pass "commands/ directory removed"
else
  log_fail "commands/ directory should be removed"
fi
if [[ ! -f "$test_dir/.claude/scripts/validate-bash.sh" ]]; then
  log_pass "validate-bash.sh removed"
else
  log_fail "validate-bash.sh should be removed"
fi
# statusline.sh should be preserved
assert_file_exists "$test_dir/.claude/scripts/statusline.sh" "statusline.sh preserved"

log_test "run_plugin_migration updates settings.json"
settings_json=$(cat "$test_dir/.claude/settings.json")
if echo "$settings_json" | jq -e '.hooks' &>/dev/null; then
  log_fail "hooks should be removed from settings.json"
else
  log_pass "hooks removed from settings.json"
fi
if echo "$settings_json" | jq -e '.extraKnownMarketplaces' &>/dev/null; then
  log_pass "extraKnownMarketplaces added to settings.json"
else
  log_fail "extraKnownMarketplaces should be added to settings.json"
fi
if echo "$settings_json" | jq -e '.enabledPlugins' &>/dev/null; then
  log_fail "enabledPlugins should not be set (user installs plugin separately)"
else
  log_pass "enabledPlugins not set in migrated settings.json"
fi
# model should be preserved
assert_json_field "$settings_json" '.model' "sonnet" "model preserved in settings.json"

log_test "run_plugin_migration sets plugin_migrated flag in manifest"
manifest_json=$(cat "$test_dir/.github/template-state.json")
if echo "$manifest_json" | jq -e '.plugin_migrated == true' &>/dev/null; then
  log_pass "plugin_migrated flag set in manifest"
else
  log_fail "plugin_migrated should be true in manifest"
fi

log_test "run_plugin_migration tracks deleted files"
if [[ ${#DELETED_FILES[@]} -gt 0 ]]; then
  log_pass "DELETED_FILES populated (${#DELETED_FILES[@]} entries)"
else
  log_fail "DELETED_FILES should have entries for removed files"
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
