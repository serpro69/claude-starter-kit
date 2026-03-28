#!/usr/bin/env bash
# Test suite for CLAUDE.extra.md feature (gh-21)
# Tests template file existence, sync detection, and auto-import behavior
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_SYNC_SCRIPT="$REPO_ROOT/.github/scripts/template-sync.sh"

# Source the sync script to get access to functions
# shellcheck source=/dev/null
source "$TEMPLATE_SYNC_SCRIPT"

# Reset globals before each test
reset_globals() {
  MANIFEST_PATH=".github/template-state.json"
  STAGING_DIR=""
  DRY_RUN=false
  CI_MODE=false
  TARGET_VERSION="latest"
  ADDED_FILES=()
  MODIFIED_FILES=()
  DELETED_FILES=()
  UNCHANGED_FILES=()
  EXCLUDED_FILES=()
  SYNC_EXCLUSIONS=()
}

FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# =============================================================================
# Section 1: Template File Existence
# =============================================================================

log_section "Section 1: File Existence"

log_test "CLAUDE.extra.md exists"
assert_file_exists "$REPO_ROOT/.claude/CLAUDE.extra.md" "CLAUDE.extra.md should exist"

log_test "CLAUDE.extra.md contains behavioral instructions"
if grep -q "## Behavioral Instructions" "$REPO_ROOT/.claude/CLAUDE.extra.md"; then
  log_pass "Contains behavioral instructions section"
else
  log_fail "Should contain '## Behavioral Instructions'"
fi

log_test "CLAUDE.extra.md contains Serena best practices"
if grep -q "## Serena Best Practices" "$REPO_ROOT/.claude/CLAUDE.extra.md"; then
  log_pass "Contains Serena best practices section"
else
  log_fail "Should contain '## Serena Best Practices'"
fi

log_test "CLAUDE.extra.md contains task tracking"
if grep -q "## Task Tracking" "$REPO_ROOT/.claude/CLAUDE.extra.md"; then
  log_pass "Contains task tracking section"
else
  log_fail "Should contain '## Task Tracking'"
fi

log_test "CLAUDE.extra.md contains exploration phase"
if grep -q "### Exploration Phase" "$REPO_ROOT/.claude/CLAUDE.extra.md"; then
  log_pass "Contains exploration phase section"
else
  log_fail "Should contain '### Exploration Phase'"
fi

# =============================================================================
# Section 2: CLAUDE.md @import reference
# =============================================================================

log_section "Section 2: CLAUDE.md @import reference"

log_test "CLAUDE.md contains @import reference for CLAUDE.extra.md"
if grep -q '@.claude/CLAUDE.extra.md' "$REPO_ROOT/CLAUDE.md"; then
  log_pass "CLAUDE.md contains @import reference"
else
  log_fail "CLAUDE.md should contain '@.claude/CLAUDE.extra.md'"
fi

log_test "CLAUDE.md does not contain migrated behavioral instructions"
if grep -q "### Independent Thinking" "$REPO_ROOT/CLAUDE.md"; then
  log_fail "CLAUDE.md should not contain 'Independent Thinking' (migrated to CLAUDE.extra.md)"
else
  log_pass "Behavioral instructions correctly removed from CLAUDE.md"
fi

log_test "CLAUDE.md does not contain migrated Serena section"
if grep -q "## Serena Best Practices" "$REPO_ROOT/CLAUDE.md"; then
  log_fail "CLAUDE.md should not contain 'Serena Best Practices' (migrated to CLAUDE.extra.md)"
else
  log_pass "Serena best practices correctly removed from CLAUDE.md"
fi

log_test "CLAUDE.md retains project-specific sections"
if grep -q "## Repository Overview" "$REPO_ROOT/CLAUDE.md" && \
   grep -q "## Testing" "$REPO_ROOT/CLAUDE.md"; then
  log_pass "CLAUDE.md retains project-specific sections"
else
  log_fail "CLAUDE.md should retain Repository Overview and Testing sections"
fi

# =============================================================================
# Section 3: compare_files Detects CLAUDE.extra.md
# =============================================================================

log_section "Section 3: compare_files Detects CLAUDE.extra.md"

log_test "compare_files detects CLAUDE.extra.md as added when project doesn't have it"
reset_globals

test_dir=$(create_temp_dir "compare-extra-added")

# Create staging dir with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Behavioral Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create project .claude/ dir WITHOUT CLAUDE.extra.md
mkdir -p "$test_dir/project/.claude"
echo '{}' > "$test_dir/project/.claude/settings.json"

# Create staging version of settings.json too (unchanged)
echo '{}' > "$test_dir/staging/claude/settings.json"

# Run comparison from project dir
pushd "$test_dir/project" >/dev/null
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null

# Check that CLAUDE.extra.md appears in ADDED_FILES
found_in_added=false
for f in "${ADDED_FILES[@]}"; do
  if [[ "$f" == ".claude/CLAUDE.extra.md" ]]; then
    found_in_added=true
    break
  fi
done

if $found_in_added; then
  log_pass "CLAUDE.extra.md detected as added"
else
  log_fail "CLAUDE.extra.md should be in ADDED_FILES (got: ${ADDED_FILES[*]:-none})"
fi

log_test "compare_files detects CLAUDE.extra.md as unchanged when identical"
reset_globals

test_dir=$(create_temp_dir "compare-extra-unchanged")

# Create staging dir with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Behavioral Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create project .claude/ dir WITH identical CLAUDE.extra.md
mkdir -p "$test_dir/project/.claude"
echo "## Behavioral Instructions" > "$test_dir/project/.claude/CLAUDE.extra.md"

# Run comparison from project dir
pushd "$test_dir/project" >/dev/null
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null

found_in_unchanged=false
for f in "${UNCHANGED_FILES[@]}"; do
  if [[ "$f" == ".claude/CLAUDE.extra.md" ]]; then
    found_in_unchanged=true
    break
  fi
done

if $found_in_unchanged; then
  log_pass "CLAUDE.extra.md detected as unchanged when identical"
else
  log_fail "CLAUDE.extra.md should be in UNCHANGED_FILES (got: ${UNCHANGED_FILES[*]:-none})"
fi

log_test "compare_files detects CLAUDE.extra.md as modified when content differs"
reset_globals

test_dir=$(create_temp_dir "compare-extra-modified")

# Create staging dir with CLAUDE.extra.md (new content)
mkdir -p "$test_dir/staging/claude"
echo "## Updated Behavioral Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create project .claude/ dir WITH different CLAUDE.extra.md
mkdir -p "$test_dir/project/.claude"
echo "## Old Behavioral Instructions" > "$test_dir/project/.claude/CLAUDE.extra.md"

# Run comparison from project dir
pushd "$test_dir/project" >/dev/null
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null

found_in_modified=false
for f in "${MODIFIED_FILES[@]}"; do
  if [[ "$f" == ".claude/CLAUDE.extra.md" ]]; then
    found_in_modified=true
    break
  fi
done

if $found_in_modified; then
  log_pass "CLAUDE.extra.md detected as modified when content differs"
else
  log_fail "CLAUDE.extra.md should be in MODIFIED_FILES (got: ${MODIFIED_FILES[*]:-none})"
fi

log_test "compare_files respects exclusion for CLAUDE.extra.md"
reset_globals
SYNC_EXCLUSIONS=(".claude/CLAUDE.extra.md")

test_dir=$(create_temp_dir "compare-extra-excluded")

# Create staging dir with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Behavioral Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create project .claude/ dir WITHOUT CLAUDE.extra.md
mkdir -p "$test_dir/project/.claude"

# Run comparison from project dir
pushd "$test_dir/project" >/dev/null
compare_files "$test_dir/staging" 2>/dev/null
popd >/dev/null

found_in_excluded=false
for f in "${EXCLUDED_FILES[@]}"; do
  if [[ "$f" == ".claude/CLAUDE.extra.md" ]]; then
    found_in_excluded=true
    break
  fi
done

if $found_in_excluded; then
  log_pass "CLAUDE.extra.md excluded when in sync_exclusions"
else
  log_fail "CLAUDE.extra.md should be in EXCLUDED_FILES when excluded (got: ${EXCLUDED_FILES[*]:-none})"
fi

# =============================================================================
# Section 4: Auto-Import Append Logic
# =============================================================================

log_section "Section 4: Auto-Import Append Logic"

log_test "Import line is appended to CLAUDE.md when CLAUDE.extra.md is staged and no import exists"
test_dir=$(create_temp_dir "auto-import-append")

# Create staging with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create CLAUDE.md without import line
echo "# My Project" > "$test_dir/CLAUDE.md"

# Simulate the workflow logic
if [[ -f "$test_dir/staging/claude/CLAUDE.extra.md" && -f "$test_dir/CLAUDE.md" ]]; then
  if ! grep -q '@.claude/CLAUDE.extra.md' "$test_dir/CLAUDE.md"; then
    printf '\n@.claude/CLAUDE.extra.md\n' >> "$test_dir/CLAUDE.md"
  fi
fi

if grep -q '@.claude/CLAUDE.extra.md' "$test_dir/CLAUDE.md"; then
  log_pass "Import line appended to CLAUDE.md"
else
  log_fail "Import line should be appended to CLAUDE.md"
fi

log_test "Import line is NOT duplicated when already present"
test_dir=$(create_temp_dir "auto-import-no-dup")

# Create staging with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# Create CLAUDE.md WITH existing import line
cat > "$test_dir/CLAUDE.md" << 'EOF'
# My Project

@.claude/CLAUDE.extra.md
EOF

# Simulate the workflow logic
if [[ -f "$test_dir/staging/claude/CLAUDE.extra.md" && -f "$test_dir/CLAUDE.md" ]]; then
  if ! grep -q '@.claude/CLAUDE.extra.md' "$test_dir/CLAUDE.md"; then
    printf '\n@.claude/CLAUDE.extra.md\n' >> "$test_dir/CLAUDE.md"
  fi
fi

# Count occurrences
count=$(grep -c '@.claude/CLAUDE.extra.md' "$test_dir/CLAUDE.md")
if [[ "$count" -eq 1 ]]; then
  log_pass "Import line not duplicated when already present"
else
  log_fail "Import line should appear exactly once (found: $count)"
fi

log_test "Import not appended when CLAUDE.md doesn't exist"
test_dir=$(create_temp_dir "auto-import-no-claude")

# Create staging with CLAUDE.extra.md
mkdir -p "$test_dir/staging/claude"
echo "## Instructions" > "$test_dir/staging/claude/CLAUDE.extra.md"

# No CLAUDE.md in project
appended=false
if [[ -f "$test_dir/staging/claude/CLAUDE.extra.md" && -f "$test_dir/CLAUDE.md" ]]; then
  appended=true
fi

if ! $appended; then
  log_pass "Import not appended when CLAUDE.md doesn't exist"
else
  log_fail "Should not attempt to append when CLAUDE.md is missing"
fi

log_test "Import not appended when CLAUDE.extra.md not in staging"
test_dir=$(create_temp_dir "auto-import-no-extra")

# No CLAUDE.extra.md in staging
mkdir -p "$test_dir/staging/claude"

# CLAUDE.md exists
echo "# My Project" > "$test_dir/CLAUDE.md"

appended=false
if [[ -f "$test_dir/staging/claude/CLAUDE.extra.md" && -f "$test_dir/CLAUDE.md" ]]; then
  appended=true
fi

if ! $appended; then
  log_pass "Import not appended when CLAUDE.extra.md not in staging"
else
  log_fail "Should not attempt to append when CLAUDE.extra.md is not staged"
fi

# =============================================================================
# Section 5: Bootstrap Script
# =============================================================================

log_section "Section 5: Bootstrap Script"

log_test "bootstrap.sh contains import append logic"
if grep -q '@.claude/CLAUDE.extra.md' "$REPO_ROOT/.github/scripts/bootstrap.sh"; then
  log_pass "bootstrap.sh references CLAUDE.extra.md import"
else
  log_fail "bootstrap.sh should contain '@.claude/CLAUDE.extra.md'"
fi

log_test "bootstrap.sh does not contain old behavioral instructions append"
if grep -q '## Claude-Code Behavioral Instructions' "$REPO_ROOT/.github/scripts/bootstrap.sh"; then
  log_fail "bootstrap.sh should not contain old behavioral instructions (migrated to CLAUDE.extra.md)"
else
  log_pass "Old behavioral instructions removed from bootstrap.sh"
fi

log_test "bootstrap.sh has idempotent import (grep guard)"
if grep -q "grep -q '@.claude/CLAUDE.extra.md'" "$REPO_ROOT/.github/scripts/bootstrap.sh"; then
  log_pass "bootstrap.sh checks for existing import before appending"
else
  log_fail "bootstrap.sh should check for existing import to be idempotent"
fi

# =============================================================================
# Section 6: Workflow Auto-Import
# =============================================================================

log_section "Section 6: Workflow Auto-Import"

log_test "template-sync.yml contains auto-import logic"
workflow_file="$REPO_ROOT/.github/workflows/template-sync.yml"
if grep -q '@.claude/CLAUDE.extra.md' "$workflow_file"; then
  log_pass "Workflow contains CLAUDE.extra.md auto-import logic"
else
  log_fail "Workflow should contain auto-import logic for CLAUDE.extra.md"
fi

log_test "template-sync.yml has idempotent import check"
if grep -q "grep -q '@.claude/CLAUDE.extra.md'" "$workflow_file"; then
  log_pass "Workflow checks for existing import before appending"
else
  log_fail "Workflow should check for existing import to prevent duplication"
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
