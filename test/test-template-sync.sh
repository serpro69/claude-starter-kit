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
cat > "$MANIFEST_PATH" << 'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "my-custom-project",
    "LANGUAGE": "python",
    "CC_MODEL": "opus",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": ""
  }
}
EOF

# Create template directory with fixtures
mkdir -p "$test_dir/templates/serena"
cat > "$test_dir/templates/serena/project.yml" << 'EOF'
project_name: "PLACEHOLDER"
language: ""
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
cat > "$MANIFEST_PATH" << 'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test-proj",
    "LANGUAGE": "",
    "CC_MODEL": "default",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": ""
  }
}
EOF

mkdir -p "$test_dir/templates/claude"
cat > "$test_dir/templates/claude/settings.json" << 'EOF'
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
cat > "$MANIFEST_PATH" << 'EOF'
{
  "schema_version": "1",
  "upstream_repo": "test/repo",
  "template_version": "v1.0.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "variables": {
    "PROJECT_NAME": "test-proj",
    "LANGUAGE": "",
    "CC_MODEL": "claude-opus",
    "SERENA_INITIAL_PROMPT": "",
    "TM_CUSTOM_SYSTEM_PROMPT": "",
    "TM_APPEND_SYSTEM_PROMPT": "",
    "TM_PERMISSION_MODE": ""
  }
}
EOF

mkdir -p "$test_dir/templates/claude"
cat > "$test_dir/templates/claude/settings.json" << 'EOF'
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
echo "new content" > "$test_dir/staging/claude/new-file.txt"

# Create empty project directory
mkdir -p "$test_dir/project/.claude"

# Run compare from project directory (use pushd/popd for safe directory handling)
pushd "$test_dir/project" > /dev/null || { log_fail "Failed to cd to test directory"; exit 1; }
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd > /dev/null || true

assert_equals "1" "${#ADDED_FILES[@]}" "One file detected as added"

log_test "compare_files detects modified files"
reset_globals
test_dir=$(create_temp_dir "compare-modified")

# Create staging and project with same file, different content
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "new content" > "$test_dir/staging/claude/existing.txt"
echo "old content" > "$test_dir/project/.claude/existing.txt"

pushd "$test_dir/project" > /dev/null || { log_fail "Failed to cd to test directory"; exit 1; }
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd > /dev/null || true

assert_equals "1" "${#MODIFIED_FILES[@]}" "One file detected as modified"

log_test "compare_files detects deleted files"
reset_globals
test_dir=$(create_temp_dir "compare-deleted")

# Create staging without the file, project with it
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "to be deleted" > "$test_dir/project/.claude/deleted.txt"

pushd "$test_dir/project" > /dev/null || { log_fail "Failed to cd to test directory"; exit 1; }
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd > /dev/null || true

assert_equals "1" "${#DELETED_FILES[@]}" "One file detected as deleted"

log_test "compare_files detects unchanged files"
reset_globals
test_dir=$(create_temp_dir "compare-unchanged")

# Create identical files in staging and project
mkdir -p "$test_dir/staging/claude"
mkdir -p "$test_dir/project/.claude"
echo "same content" > "$test_dir/staging/claude/unchanged.txt"
echo "same content" > "$test_dir/project/.claude/unchanged.txt"

pushd "$test_dir/project" > /dev/null || { log_fail "Failed to cd to test directory"; exit 1; }
MANIFEST_PATH="$FIXTURES_DIR/manifests/valid-manifest.json"
compare_files "$test_dir/staging" 2>/dev/null
popd > /dev/null || true

assert_equals "1" "${#UNCHANGED_FILES[@]}" "One file detected as unchanged"

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
# Summary
# =============================================================================

print_summary
