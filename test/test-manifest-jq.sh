#!/usr/bin/env bash
# Test suite for template-state.json manifest parsing with jq
# These patterns will be used in .github/scripts/template-sync.sh for reading manifests
# and in .github/scripts/template-cleanup.sh for generating manifests
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_MANIFEST="$REPO_ROOT/.github/templates/template-state.example.json"
SCHEMA_FILE="$REPO_ROOT/docs/template-sync/template-state-schema.json"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/manifests"

# =============================================================================
# Section 1: Basic JSON Validation
# =============================================================================

log_section "Section 1: Basic JSON Validation"

log_test "Example manifest is valid JSON"
if jq '.' "$EXAMPLE_MANIFEST" >/dev/null 2>&1; then
  log_pass "Valid JSON syntax"
else
  log_fail "Invalid JSON syntax"
fi

# =============================================================================
# Section 2: Field Extraction Patterns (for sync script)
# =============================================================================

log_section "Section 2: Field Extraction Patterns"

# These are the jq patterns that template-sync.sh will use to read the manifest

log_test "Extract schema_version"
SCHEMA_VERSION=$(jq -r '.schema_version' "$EXAMPLE_MANIFEST")
assert_equals "1" "$SCHEMA_VERSION" "schema_version = $SCHEMA_VERSION"

log_test "Extract upstream_repo"
UPSTREAM_REPO=$(jq -r '.upstream_repo' "$EXAMPLE_MANIFEST")
assert_equals "serpro69/claude-starter-kit" "$UPSTREAM_REPO" "upstream_repo = $UPSTREAM_REPO"

log_test "Extract template_version"
TEMPLATE_VERSION=$(jq -r '.template_version' "$EXAMPLE_MANIFEST")
assert_equals "v1.0.0" "$TEMPLATE_VERSION" "template_version = $TEMPLATE_VERSION"

log_test "Extract synced_at"
SYNCED_AT=$(jq -r '.synced_at' "$EXAMPLE_MANIFEST")
assert_equals "2025-01-27T10:00:00Z" "$SYNCED_AT" "synced_at = $SYNCED_AT"

log_test "Extract PROJECT_NAME"
PROJECT_NAME=$(jq -r '.variables.PROJECT_NAME' "$EXAMPLE_MANIFEST")
assert_equals "my-project" "$PROJECT_NAME" "PROJECT_NAME = $PROJECT_NAME"

log_test "Extract all variable keys"
VAR_KEYS=$(jq -r '.variables | keys[]' "$EXAMPLE_MANIFEST" | sort | tr '\n' ',')
EXPECTED_KEYS="CC_MODEL,LANGUAGES,PROJECT_NAME,SERENA_INITIAL_PROMPT,TM_APPEND_SYSTEM_PROMPT,TM_CUSTOM_SYSTEM_PROMPT,TM_PERMISSION_MODE,"
assert_equals "$EXPECTED_KEYS" "$VAR_KEYS" "All 7 variable keys present"

# =============================================================================
# Section 3: jq Patterns for Manifest Generation (for cleanup script)
# =============================================================================

log_section "Section 3: Manifest Generation Pattern"

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
      LANGUAGES: $language,
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

log_section "Section 4: Special Character Handling"

log_test "Handle quotes in string values"
MANIFEST_WITH_QUOTES=$(jq -n \
  --arg prompt 'Say "hello" to the world' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_QUOTES" | jq -r '.test')
assert_equals 'Say "hello" to the world' "$EXTRACTED" "Quotes preserved correctly"

log_test "Handle backslashes in string values"
MANIFEST_WITH_BACKSLASH=$(jq -n \
  --arg prompt 'Path: C:\Users\test' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_BACKSLASH" | jq -r '.test')
assert_equals 'Path: C:\Users\test' "$EXTRACTED" "Backslashes preserved correctly"

log_test "Handle newlines in string values"
MANIFEST_WITH_NEWLINE=$(jq -n \
  --arg prompt $'Line 1\nLine 2' \
  '{test: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_NEWLINE" | jq -r '.test')
EXPECTED=$'Line 1\nLine 2'
assert_equals "$EXPECTED" "$EXTRACTED" "Newlines preserved correctly"

log_test "Handle project names with hyphens and underscores"
MANIFEST_WITH_SPECIAL_NAME=$(jq -n \
  --arg name 'my-project_v2.0' \
  '{PROJECT_NAME: $name}')
EXTRACTED=$(echo "$MANIFEST_WITH_SPECIAL_NAME" | jq -r '.PROJECT_NAME')
assert_equals "my-project_v2.0" "$EXTRACTED" "Special characters in project name preserved"

log_test "Handle empty strings correctly"
MANIFEST_WITH_EMPTY=$(jq -n \
  --arg prompt "" \
  '{SERENA_INITIAL_PROMPT: $prompt}')
EXTRACTED=$(echo "$MANIFEST_WITH_EMPTY" | jq -r '.SERENA_INITIAL_PROMPT')
assert_equals "" "$EXTRACTED" "Empty strings handled correctly"

# =============================================================================
# Section 5: Round-Trip Test
# =============================================================================

log_section "Section 5: Round-Trip Test"

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
      LANGUAGES: $language,
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

if [[ "$RT_PROJECT" == "test-project" ]] &&
  [[ "$RT_SERENA" == 'Test prompt with "quotes"' ]] &&
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

log_section "Section 6: Schema Validation"

log_test "Validate example manifest against JSON Schema"
if command -v uv &>/dev/null; then
  if uv run --with check-jsonschema check-jsonschema --schemafile "$SCHEMA_FILE" "$EXAMPLE_MANIFEST" 2>&1; then
    log_pass "Example manifest passes schema validation"
  else
    log_fail "Example manifest fails schema validation"
  fi
else
  log_skip "uv not available, skipping schema validation"
fi

# =============================================================================
# Section 7: Fixture Validation
# =============================================================================

log_section "Section 7: Test Fixtures Validation"

log_test "Valid fixture is valid JSON"
if jq '.' "$FIXTURES_DIR/valid-manifest.json" >/dev/null 2>&1; then
  log_pass "valid-manifest.json is valid JSON"
else
  log_fail "valid-manifest.json is invalid JSON"
fi

log_test "Invalid JSON fixture is actually invalid"
if jq '.' "$FIXTURES_DIR/invalid-json.txt" >/dev/null 2>&1; then
  log_fail "invalid-json.txt should be invalid JSON but parsed successfully"
else
  log_pass "invalid-json.txt is correctly invalid JSON"
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
