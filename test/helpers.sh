#!/usr/bin/env bash
# Shared test utilities for template-sync test suite
# Source this file in test scripts: source "$(dirname "$0")/helpers.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
# TESTS_RUN counts test cases (log_test calls)
# ASSERTIONS_PASSED/FAILED count individual assertions (log_pass/log_fail calls)
TESTS_RUN=0
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
TESTS_SKIPPED=0

# Temporary directories for cleanup
TEMP_DIRS=()

# =============================================================================
# Logging Functions
# =============================================================================

log_test() {
  echo -e "${YELLOW}[TEST]${NC} $1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
}

log_skip() {
  echo -e "${BLUE}[SKIP]${NC} $1"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_section() {
  echo ""
  echo "=== $1 ==="
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# =============================================================================
# Assertion Functions
# =============================================================================

# assert_equals "expected" "actual" "message"
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should be equal}"

  if [[ "$expected" == "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (expected: '$expected', got: '$actual')"
    return 1
  fi
}

# assert_not_equals "unexpected" "actual" "message"
assert_not_equals() {
  local unexpected="$1"
  local actual="$2"
  local message="${3:-Values should not be equal}"

  if [[ "$unexpected" != "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (got unexpected value: '$actual')"
    return 1
  fi
}

# assert_file_exists "path" "message"
assert_file_exists() {
  local path="$1"
  local message="${2:-File should exist: $path}"

  if [[ -f "$path" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (file not found: $path)"
    return 1
  fi
}

# assert_file_not_exists "path" "message"
assert_file_not_exists() {
  local path="$1"
  local message="${2:-File should not exist: $path}"

  if [[ ! -f "$path" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (file exists: $path)"
    return 1
  fi
}

# assert_dir_exists "path" "message"
assert_dir_exists() {
  local path="$1"
  local message="${2:-Directory should exist: $path}"

  if [[ -d "$path" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (directory not found: $path)"
    return 1
  fi
}

# assert_exit_code expected_code "command" "message"
# Usage: assert_exit_code 0 "ls /tmp" "ls should succeed"
assert_exit_code() {
  local expected="$1"
  local command="$2"
  local message="${3:-Command should exit with code $expected}"

  set +e
  eval "$command" >/dev/null 2>&1
  local actual=$?
  set -e

  if [[ "$expected" -eq "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (expected exit code: $expected, got: $actual)"
    return 1
  fi
}

# assert_output_contains "needle" "command" "message"
# Usage: assert_output_contains "hello" "echo hello world" "Output should contain hello"
assert_output_contains() {
  local needle="$1"
  local command="$2"
  local message="${3:-Output should contain: $needle}"

  set +e
  local output
  output=$(eval "$command" 2>&1)
  set -e

  if [[ "$output" == *"$needle"* ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (needle: '$needle' not found in output)"
    return 1
  fi
}

# assert_output_not_contains "needle" "command" "message"
assert_output_not_contains() {
  local needle="$1"
  local command="$2"
  local message="${3:-Output should not contain: $needle}"

  set +e
  local output
  output=$(eval "$command" 2>&1)
  set -e

  if [[ "$output" != *"$needle"* ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (unexpected needle: '$needle' found in output)"
    return 1
  fi
}

# assert_json_valid "json_string" "message"
assert_json_valid() {
  local json="$1"
  local message="${2:-JSON should be valid}"

  if echo "$json" | jq '.' >/dev/null 2>&1; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (invalid JSON)"
    return 1
  fi
}

# assert_json_field "json_string" "jq_path" "expected_value" "message"
assert_json_field() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local message="${4:-JSON field $jq_path should equal $expected}"

  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)

  if [[ "$expected" == "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (expected: '$expected', got: '$actual')"
    return 1
  fi
}

# =============================================================================
# Test Environment Helpers
# =============================================================================

# Create a temporary directory and register it for cleanup
create_temp_dir() {
  local prefix="${1:-test}"
  local temp_dir
  temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
  TEMP_DIRS+=("$temp_dir")
  echo "$temp_dir"
}

# Create a temp git repo with an initial commit and optional tag
# Usage: create_temp_git_repo [tag_name]
# Returns: path to the temp repo
create_temp_git_repo() {
  local tag_name="${1:-}"
  local temp_dir
  temp_dir=$(create_temp_dir "git-repo")

  (
    cd "$temp_dir"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "initial" >README.md
    git add README.md
    git commit -m "Initial commit" --quiet

    if [[ -n "$tag_name" ]]; then
      git tag "$tag_name"
    fi
  )

  echo "$temp_dir"
}

# Cleanup all registered temporary directories
cleanup_temp() {
  for dir in "${TEMP_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
  TEMP_DIRS=()
}

# Register cleanup on script exit
trap cleanup_temp EXIT

# =============================================================================
# Summary Function
# =============================================================================

print_summary() {
  echo ""
  echo "=== Test Summary ==="
  echo "Test cases:        $TESTS_RUN"
  echo -e "Assertions passed: ${GREEN}$ASSERTIONS_PASSED${NC}"
  echo -e "Assertions failed: ${RED}$ASSERTIONS_FAILED${NC}"
  if [[ $TESTS_SKIPPED -gt 0 ]]; then
    echo -e "Tests skipped:     ${BLUE}$TESTS_SKIPPED${NC}"
  fi

  if [[ $ASSERTIONS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some tests failed!${NC}"
    return 1
  fi
}

# =============================================================================
# Path Helpers
# =============================================================================

# Get the directory containing the test script
get_test_dir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Get the repository root directory
get_repo_root() {
  local test_dir
  test_dir=$(get_test_dir)
  cd "$test_dir/.." && pwd
}
