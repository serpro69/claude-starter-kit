#!/usr/bin/env bash
# Test suite for .github/scripts/template-cleanup.sh manifest generation
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_FILE="$REPO_ROOT/docs/template-sync/template-state-schema.json"
TEMPLATE_CLEANUP_SCRIPT="$REPO_ROOT/.github/scripts/template-cleanup.sh"

# Source the script to get access to functions
# The script has a sourcing guard that prevents main execution when sourced
# shellcheck source=/dev/null
source "$TEMPLATE_CLEANUP_SCRIPT"

# =============================================================================
# Section 1: Basic Manifest Generation
# =============================================================================

log_section "Section 1: Basic Manifest Generation"

log_test "generate_manifest creates .github/template-state.json"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

# Set required variables
PROJECT_NAME="test-project"
LANGUAGES="typescript"
CC_MODEL="sonnet"
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE="default"

generate_manifest "test-project" >/dev/null 2>&1

assert_file_exists ".github/template-state.json" "Manifest file created"
cd "$REPO_ROOT"

log_test "Generated manifest is valid JSON"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test-project" >/dev/null 2>&1

if jq '.' .github/template-state.json >/dev/null 2>&1; then
  log_pass "Generated manifest is valid JSON"
else
  log_fail "Generated manifest is not valid JSON"
fi
cd "$REPO_ROOT"

# =============================================================================
# Section 2: Required Fields
# =============================================================================

log_section "Section 2: Required Fields"

log_test "Manifest contains schema_version = 1"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test-project" >/dev/null 2>&1

schema_version=$(jq -r '.schema_version' .github/template-state.json)
assert_equals "1" "$schema_version" "schema_version is 1"
cd "$REPO_ROOT"

log_test "Manifest contains upstream_repo with default value"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""
unset UPSTREAM_REPO 2>/dev/null || true

generate_manifest "test-project" >/dev/null 2>&1

upstream_repo=$(jq -r '.upstream_repo' .github/template-state.json)
assert_equals "serpro69/claude-starter-kit" "$upstream_repo" "upstream_repo has default value"
cd "$REPO_ROOT"

log_test "Manifest uses custom UPSTREAM_REPO when set"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""
# Use a valid GitHub repo to test UPSTREAM_REPO is captured correctly
UPSTREAM_REPO="serpro69/claude-starter-kit"

generate_manifest "test-project" >/dev/null 2>&1

upstream_repo=$(jq -r '.upstream_repo' .github/template-state.json)
assert_equals "serpro69/claude-starter-kit" "$upstream_repo" "upstream_repo uses custom value"
unset UPSTREAM_REPO
cd "$REPO_ROOT"

log_test "Manifest contains synced_at in ISO 8601 format"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test-project" >/dev/null 2>&1

synced_at=$(jq -r '.synced_at' .github/template-state.json)
# Check ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
if [[ "$synced_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  log_pass "synced_at is in ISO 8601 format: $synced_at"
else
  log_fail "synced_at is not in ISO 8601 format: $synced_at"
fi
cd "$REPO_ROOT"

# =============================================================================
# Section 3: Variable Capture
# =============================================================================

log_section "Section 3: Variable Capture"

log_test "Manifest captures PROJECT_NAME"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="my-awesome-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "my-awesome-project" >/dev/null 2>&1

project_name=$(jq -r '.variables.PROJECT_NAME' .github/template-state.json)
assert_equals "my-awesome-project" "$project_name" "PROJECT_NAME captured correctly"
cd "$REPO_ROOT"

log_test "Manifest captures all 7 variables"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="python"
CC_MODEL="opus"
SERENA_INITIAL_PROMPT="hello"
TM_CUSTOM_SYSTEM_PROMPT="custom"
TM_APPEND_SYSTEM_PROMPT="append"
TM_PERMISSION_MODE="full"

generate_manifest "test" >/dev/null 2>&1

# Check each variable
assert_equals "test" "$(jq -r '.variables.PROJECT_NAME' .github/template-state.json)" "PROJECT_NAME"
assert_equals "python" "$(jq -r '.variables.LANGUAGES' .github/template-state.json)" "LANGUAGES"
assert_equals "opus" "$(jq -r '.variables.CC_MODEL' .github/template-state.json)" "CC_MODEL"
assert_equals "hello" "$(jq -r '.variables.SERENA_INITIAL_PROMPT' .github/template-state.json)" "SERENA_INITIAL_PROMPT"
assert_equals "custom" "$(jq -r '.variables.TM_CUSTOM_SYSTEM_PROMPT' .github/template-state.json)" "TM_CUSTOM_SYSTEM_PROMPT"
assert_equals "append" "$(jq -r '.variables.TM_APPEND_SYSTEM_PROMPT' .github/template-state.json)" "TM_APPEND_SYSTEM_PROMPT"
assert_equals "full" "$(jq -r '.variables.TM_PERMISSION_MODE' .github/template-state.json)" "TM_PERMISSION_MODE"
cd "$REPO_ROOT"

log_test "Manifest handles empty string values for optional fields"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash" # LANGUAGES is now required, use valid value
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test" >/dev/null 2>&1

# Empty strings should be captured as empty, not null
cc_model=$(jq -r '.variables.CC_MODEL' .github/template-state.json)
assert_equals "" "$cc_model" "Empty CC_MODEL captured as empty string"
# Verify LANGUAGES has the required value
languages=$(jq -r '.variables.LANGUAGES' .github/template-state.json)
assert_equals "bash" "$languages" "LANGUAGES has required value"
cd "$REPO_ROOT"

# =============================================================================
# Section 4: Special Characters
# =============================================================================

log_section "Section 4: Special Characters"

log_test "Manifest handles double quotes in prompts"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT='Say "hello" to the world'
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test" >/dev/null 2>&1

serena_prompt=$(jq -r '.variables.SERENA_INITIAL_PROMPT' .github/template-state.json)
assert_equals 'Say "hello" to the world' "$serena_prompt" "Double quotes preserved in prompt"
cd "$REPO_ROOT"

log_test "Manifest handles backslashes in prompts"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT='Path: C:\Users\test'
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test" >/dev/null 2>&1

tm_custom=$(jq -r '.variables.TM_CUSTOM_SYSTEM_PROMPT' .github/template-state.json)
assert_equals 'Path: C:\Users\test' "$tm_custom" "Backslashes preserved in prompt"
cd "$REPO_ROOT"

log_test "Manifest handles newlines in prompts"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=$'Line 1\nLine 2'
TM_PERMISSION_MODE=""

generate_manifest "test" >/dev/null 2>&1

tm_append=$(jq -r '.variables.TM_APPEND_SYSTEM_PROMPT' .github/template-state.json)
expected=$'Line 1\nLine 2'
assert_equals "$expected" "$tm_append" "Newlines preserved in prompt"
cd "$REPO_ROOT"

log_test "Manifest handles hyphens and underscores in project name"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="my-project_v2.0"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "my-project_v2.0" >/dev/null 2>&1

project_name=$(jq -r '.variables.PROJECT_NAME' .github/template-state.json)
assert_equals "my-project_v2.0" "$project_name" "Hyphens and underscores preserved"
cd "$REPO_ROOT"

# =============================================================================
# Section 5: Template Version Detection
# =============================================================================

log_section "Section 5: Template Version Detection (from upstream)"

# Note: generate_manifest() now fetches template_version from the UPSTREAM repo
# via git ls-remote, not from the local repo. This ensures downstream repos
# track the actual upstream template version.

log_test "Manifest fetches version from upstream repo (default)"
test_dir=$(create_temp_git_repo "v2.5.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""
unset UPSTREAM_REPO 2>/dev/null || true

# This requires network access to the actual upstream repo
if generate_manifest "test" >/dev/null 2>&1; then
  template_version=$(jq -r '.template_version' .github/template-state.json)
  # Should NOT be the local repo's tag (v2.5.0), should be upstream's tag (v0.1.0)
  if [[ "$template_version" == "v0.1.0" ]]; then
    log_pass "template_version is upstream tag: $template_version"
  elif [[ "$template_version" != "v2.5.0" ]] && [[ -n "$template_version" ]] && [[ "$template_version" != "null" ]]; then
    log_pass "template_version is from upstream, not local repo: $template_version"
  else
    log_fail "template_version should be from upstream (expected v0.1.0), got: $template_version"
  fi
else
  log_skip "Network required to fetch upstream version"
fi
cd "$REPO_ROOT"

log_test "Manifest uses custom UPSTREAM_REPO when set"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""
UPSTREAM_REPO="serpro69/claude-starter-kit"

if generate_manifest "test" >/dev/null 2>&1; then
  upstream_repo=$(jq -r '.upstream_repo' .github/template-state.json)
  assert_equals "serpro69/claude-starter-kit" "$upstream_repo" "upstream_repo uses custom value"
  template_version=$(jq -r '.template_version' .github/template-state.json)
  # Should have some value (tag or SHA from upstream)
  if [[ -n "$template_version" ]] && [[ "$template_version" != "null" ]]; then
    log_pass "template_version fetched from custom upstream: $template_version"
  else
    log_fail "template_version should be fetched from upstream"
  fi
else
  log_skip "Network required to fetch upstream version"
fi
unset UPSTREAM_REPO
cd "$REPO_ROOT"

# =============================================================================
# Section 6: Schema Validation
# =============================================================================

log_section "Section 6: Schema Validation"

log_test "Generated manifest passes JSON Schema validation"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"

PROJECT_NAME="schema-test"
LANGUAGES="go"
CC_MODEL="sonnet"
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE="default"

generate_manifest "schema-test" >/dev/null 2>&1

if command -v uv &>/dev/null; then
  if uv run --with check-jsonschema check-jsonschema --schemafile "$SCHEMA_FILE" .github/template-state.json 2>&1; then
    log_pass "Generated manifest passes JSON Schema validation"
  else
    log_fail "Generated manifest fails JSON Schema validation"
  fi
else
  log_skip "uv not available, skipping schema validation"
fi
cd "$REPO_ROOT"

# =============================================================================
# Section 7: Edge Cases
# =============================================================================

log_section "Section 7: Edge Cases"

log_test "generate_manifest creates .github directory if missing"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"
# Ensure .github doesn't exist
rm -rf .github 2>/dev/null || true

PROJECT_NAME="test"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "test" >/dev/null 2>&1

assert_dir_exists ".github" ".github directory created"
assert_file_exists ".github/template-state.json" "Manifest created in new directory"
cd "$REPO_ROOT"

log_test "generate_manifest overwrites existing manifest"
test_dir=$(create_temp_git_repo "v1.0.0")
cd "$test_dir"
mkdir -p .github
echo '{"old": "manifest"}' >.github/template-state.json

PROJECT_NAME="new-project"
LANGUAGES="bash"
CC_MODEL=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE=""

generate_manifest "new-project" >/dev/null 2>&1

project_name=$(jq -r '.variables.PROJECT_NAME' .github/template-state.json)
assert_equals "new-project" "$project_name" "Existing manifest overwritten with new content"
cd "$REPO_ROOT"

# =============================================================================
# Summary
# =============================================================================

print_summary
