#!/usr/bin/env bash
# Test suite for template-state.json manifest parsing with jq
# These patterns will be used in template-sync.sh for reading manifests
# and in template-cleanup.sh for generating manifests
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLE_MANIFEST="$REPO_ROOT/.github/templates/template-state.example.json"
SCHEMA_FILE="$REPO_ROOT/docs/wip/template-sync/template-state-schema.json"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
  echo -e "${YELLOW}[TEST]${NC} $1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# =============================================================================
# Section 1: Basic JSON Validation
# =============================================================================

echo ""
echo "=== Section 1: Basic JSON Validation ==="

log_test "Example manifest is valid JSON"
if jq '.' "$EXAMPLE_MANIFEST" > /dev/null 2>&1; then
  log_pass "Valid JSON syntax"
else
  log_fail "Invalid JSON syntax"
fi

# =============================================================================
# Section 2: Field Extraction Patterns (for sync script)
# =============================================================================

echo ""
echo "=== Section 2: Field Extraction Patterns ==="

# These are the jq patterns that template-sync.sh will use to read the manifest

log_test "Extract schema_version"
SCHEMA_VERSION=$(jq -r '.schema_version' "$EXAMPLE_MANIFEST")
if [[ "$SCHEMA_VERSION" == "1" ]]; then
  log_pass "schema_version = $SCHEMA_VERSION"
else
  log_fail "Expected '1', got '$SCHEMA_VERSION'"
fi

log_test "Extract upstream_repo"
UPSTREAM_REPO=$(jq -r '.upstream_repo' "$EXAMPLE_MANIFEST")
if [[ "$UPSTREAM_REPO" == "serpro69/claude-starter-kit" ]]; then
  log_pass "upstream_repo = $UPSTREAM_REPO"
else
  log_fail "Expected 'serpro69/claude-starter-kit', got '$UPSTREAM_REPO'"
fi

log_test "Extract template_version"
TEMPLATE_VERSION=$(jq -r '.template_version' "$EXAMPLE_MANIFEST")
if [[ "$TEMPLATE_VERSION" == "v1.0.0" ]]; then
  log_pass "template_version = $TEMPLATE_VERSION"
else
  log_fail "Expected 'v1.0.0', got '$TEMPLATE_VERSION'"
fi

log_test "Extract synced_at"
SYNCED_AT=$(jq -r '.synced_at' "$EXAMPLE_MANIFEST")
if [[ "$SYNCED_AT" == "2025-01-27T10:00:00Z" ]]; then
  log_pass "synced_at = $SYNCED_AT"
else
  log_fail "Expected '2025-01-27T10:00:00Z', got '$SYNCED_AT'"
fi

log_test "Extract PROJECT_NAME"
PROJECT_NAME=$(jq -r '.variables.PROJECT_NAME' "$EXAMPLE_MANIFEST")
if [[ "$PROJECT_NAME" == "my-project" ]]; then
  log_pass "PROJECT_NAME = $PROJECT_NAME"
else
  log_fail "Expected 'my-project', got '$PROJECT_NAME'"
fi

log_test "Extract all variable keys"
VAR_KEYS=$(jq -r '.variables | keys[]' "$EXAMPLE_MANIFEST" | sort | tr '\n' ',')
EXPECTED_KEYS="CC_MODEL,LANGUAGE,PROJECT_NAME,SERENA_INITIAL_PROMPT,TM_APPEND_SYSTEM_PROMPT,TM_CUSTOM_SYSTEM_PROMPT,TM_PERMISSION_MODE,"
if [[ "$VAR_KEYS" == "$EXPECTED_KEYS" ]]; then
  log_pass "All 7 variable keys present"
else
  log_fail "Expected keys: $EXPECTED_KEYS, got: $VAR_KEYS"
fi

# =============================================================================
# Section 3: jq Patterns for Manifest Generation (for cleanup script)
# =============================================================================

echo ""
echo "=== Section 3: Manifest Generation Pattern ==="

log_test "Generate manifest with jq -n"
GENERATED=$(jq -n \
  --arg schema "1" \
  --arg upstream "serpro69/claude-starter-kit" \
  --arg version "v1.0.0" \
  --arg synced "2025-01-27T10:00:00Z" \
  --arg project "my-project" \
  --arg language "typescript" \
  --arg cc_model "sonnet" \
  --arg serena_prompt "" \
  --arg tm_custom "" \
  --arg tm_append "" \
  --arg tm_permission "default" \
  '{
    schema_version: $schema,
    upstream_repo: $upstream,
    template_version: $version,
    synced_at: $synced,
    variables: {
      PROJECT_NAME: $project,
      LANGUAGE: $language,
      CC_MODEL: $cc_model,
      SERENA_INITIAL_PROMPT: $serena_prompt,
      TM_CUSTOM_SYSTEM_PROMPT: $tm_custom,
      TM_APPEND_SYSTEM_PROMPT: $tm_append,
      TM_PERMISSION_MODE: $tm_permission
    }
  }')

# Verify generated JSON matches example
EXAMPLE_CONTENT=$(jq -S '.' "$EXAMPLE_MANIFEST")
GENERATED_SORTED=$(echo "$GENERATED" | jq -S '.')
if [[ "$EXAMPLE_CONTENT" == "$GENERATED_SORTED" ]]; then
  log_pass "Generated manifest matches example"
else
  log_fail "Generated manifest differs from example"
  echo "Expected:"
  echo "$EXAMPLE_CONTENT"
  echo "Got:"
  echo "$GENERATED_SORTED"
fi

# =============================================================================
# Section 4: Special Character Handling
# =============================================================================

echo ""
echo "=== Section 4: Special Character Handling ==="

log_test "Handle quotes in string values"
MANIFEST_WITH_QUOTES=$(jq -n \
  --arg prompt 'Say "hello" to the world' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_QUOTES" | jq -r '.test')
if [[ "$EXTRACTED" == 'Say "hello" to the world' ]]; then
  log_pass "Quotes preserved correctly"
else
  log_fail "Quote handling failed: $EXTRACTED"
fi

log_test "Handle backslashes in string values"
MANIFEST_WITH_BACKSLASH=$(jq -n \
  --arg prompt 'Path: C:\Users\test' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_BACKSLASH" | jq -r '.test')
if [[ "$EXTRACTED" == 'Path: C:\Users\test' ]]; then
  log_pass "Backslashes preserved correctly"
else
  log_fail "Backslash handling failed: $EXTRACTED"
fi

log_test "Handle newlines in string values"
MANIFEST_WITH_NEWLINE=$(jq -n \
  --arg prompt $'Line 1\nLine 2' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_NEWLINE" | jq -r '.test')
EXPECTED=$'Line 1\nLine 2'
if [[ "$EXTRACTED" == "$EXPECTED" ]]; then
  log_pass "Newlines preserved correctly"
else
  log_fail "Newline handling failed"
fi

log_test "Handle project names with hyphens and underscores"
MANIFEST_WITH_SPECIAL_NAME=$(jq -n \
  --arg name 'my-project_v2.0' \
  '{PROJECT_NAME: $name}')
EXTRACTED=$(echo "$MANIFEST_WITH_SPECIAL_NAME" | jq -r '.PROJECT_NAME')
if [[ "$EXTRACTED" == "my-project_v2.0" ]]; then
  log_pass "Special characters in project name preserved"
else
  log_fail "Project name handling failed: $EXTRACTED"
fi

log_test "Handle empty strings correctly"
MANIFEST_WITH_EMPTY=$(jq -n \
  --arg prompt "" \
  '{SERENA_INITIAL_PROMPT: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_EMPTY" | jq -r '.SERENA_INITIAL_PROMPT')
if [[ "$EXTRACTED" == "" ]]; then
  log_pass "Empty strings handled correctly"
else
  log_fail "Empty string handling failed: got '$EXTRACTED'"
fi

# =============================================================================
# Section 5: Round-Trip Test
# =============================================================================

echo ""
echo "=== Section 5: Round-Trip Test ==="

log_test "Generate -> Parse -> Verify round-trip"
# Generate a manifest with all fields populated
ROUND_TRIP_MANIFEST=$(jq -n \
  --arg schema "1" \
  --arg upstream "test-org/test-repo" \
  --arg version "abc1234" \
  --arg synced "2026-01-27T12:00:00Z" \
  --arg project "test-project" \
  --arg language "python" \
  --arg cc_model "opus" \
  --arg serena_prompt "Test prompt with \"quotes\"" \
  --arg tm_custom "Custom system prompt" \
  --arg tm_append "Append prompt" \
  --arg tm_permission "full" \
  '{
    schema_version: $schema,
    upstream_repo: $upstream,
    template_version: $version,
    synced_at: $synced,
    variables: {
      PROJECT_NAME: $project,
      LANGUAGE: $language,
      CC_MODEL: $cc_model,
      SERENA_INITIAL_PROMPT: $serena_prompt,
      TM_CUSTOM_SYSTEM_PROMPT: $tm_custom,
      TM_APPEND_SYSTEM_PROMPT: $tm_append,
      TM_PERMISSION_MODE: $tm_permission
    }
  }')

# Parse it back and verify
RT_PROJECT=$(echo "$ROUND_TRIP_MANIFEST" | jq -r '.variables.PROJECT_NAME')
RT_SERENA=$(echo "$ROUND_TRIP_MANIFEST" | jq -r '.variables.SERENA_INITIAL_PROMPT')
RT_PERMISSION=$(echo "$ROUND_TRIP_MANIFEST" | jq -r '.variables.TM_PERMISSION_MODE')

if [[ "$RT_PROJECT" == "test-project" ]] && \
   [[ "$RT_SERENA" == 'Test prompt with "quotes"' ]] && \
   [[ "$RT_PERMISSION" == "full" ]]; then
  log_pass "Round-trip preserves all values including special characters"
else
  log_fail "Round-trip failed"
  echo "PROJECT_NAME: $RT_PROJECT"
  echo "SERENA_INITIAL_PROMPT: $RT_SERENA"
  echo "TM_PERMISSION_MODE: $RT_PERMISSION"
fi

# =============================================================================
# Section 6: Schema Validation (if check-jsonschema available)
# =============================================================================

echo ""
echo "=== Section 6: Schema Validation ==="

log_test "Validate example manifest against JSON Schema"
if command -v uv &> /dev/null; then
  if uv run --with check-jsonschema check-jsonschema --schemafile "$SCHEMA_FILE" "$EXAMPLE_MANIFEST" 2>&1; then
    log_pass "Example manifest passes schema validation"
  else
    log_fail "Example manifest fails schema validation"
  fi
else
  echo -e "${YELLOW}[SKIP]${NC} uv not available, skipping schema validation"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=== Test Summary ==="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "\n${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed!${NC}"
  exit 1
fi
