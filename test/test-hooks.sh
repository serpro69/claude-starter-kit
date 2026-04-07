#!/usr/bin/env bash
# Test suite for hook scripts — structured JSON output compliance
# See: https://github.com/serpro69/claude-toolbox/issues/57
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE_BASH="$REPO_ROOT/klaude-plugin/scripts/validate-bash.sh"
CAPY_SH="$REPO_ROOT/.claude/scripts/capy.sh"

# =============================================================================
# Section 1: validate-bash.sh — Allow cases
# =============================================================================

log_section "Section 1: validate-bash.sh — Allow cases"

log_test "Allow: safe command exits 0 with no stdout"
output=$(echo '{"tool_input":{"command":"ls /tmp"}}' | bash "$VALIDATE_BASH" 2>/dev/null)
exit_code=$?
assert_equals "0" "$exit_code" "Exit code is 0"
assert_equals "" "$output" "No stdout for allowed command"

log_test "Allow: empty command exits 0 with no stdout"
output=$(echo '{"tool_input":{}}' | bash "$VALIDATE_BASH" 2>/dev/null)
exit_code=$?
assert_equals "0" "$exit_code" "Exit code is 0 for empty command"
assert_equals "" "$output" "No stdout for empty command"

log_test "Allow: missing tool_input exits 0 with no stdout"
output=$(echo '{}' | bash "$VALIDATE_BASH" 2>/dev/null)
exit_code=$?
assert_equals "0" "$exit_code" "Exit code is 0 for missing tool_input"
assert_equals "" "$output" "No stdout for missing tool_input"

# =============================================================================
# Section 2: validate-bash.sh — Deny cases
# =============================================================================

log_section "Section 2: validate-bash.sh — Deny cases"

log_test "Deny: .env pattern produces structured JSON"
output=$(echo '{"tool_input":{"command":"cat .env"}}' | bash "$VALIDATE_BASH" 2>/dev/null)
exit_code=$?
assert_equals "0" "$exit_code" "Exit code is 0 even when denying"
assert_json_valid "$output" "Deny output is valid JSON"
assert_json_field "$output" '.hookSpecificOutput.hookEventName' "PreToolUse" "hookEventName is PreToolUse"
assert_json_field "$output" '.hookSpecificOutput.permissionDecision' "deny" "permissionDecision is deny"

log_test "Deny: reason contains the matched pattern"
reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')
if [[ "$reason" == *".env"* ]]; then
  log_pass "Reason mentions .env pattern"
else
  log_fail "Reason should mention .env pattern (got: $reason)"
fi

log_test "Deny: no output on stderr"
stderr_output=$(echo '{"tool_input":{"command":"cat .env"}}' | bash "$VALIDATE_BASH" 2>&1 1>/dev/null)
assert_equals "" "$stderr_output" "No stderr output when denying"

# =============================================================================
# Section 3: validate-bash.sh — All forbidden patterns
# =============================================================================

log_section "Section 3: validate-bash.sh — All forbidden patterns"

FORBIDDEN_PATTERNS=(
  ".env:cat .env.local"
  ".ansible/:ls .ansible/vault"
  ".terraform/:cat .terraform/state"
  "build/:rm -rf build/output"
  "dist/:cat dist/bundle.js"
  "node_modules:cat node_modules/foo"
  "__pycache__:rm __pycache__/bar"
  ".git/:cat .git/config"
  "venv/:cat venv/bin/activate"
  ".pyc:cat foo.pyc"
  ".csv:cat data.csv"
  ".log:cat app.log"
)

log_test "Each forbidden pattern triggers deny with structured JSON"
for entry in "${FORBIDDEN_PATTERNS[@]}"; do
  pattern="${entry%%:*}"
  command="${entry#*:}"
  output=$(echo "{\"tool_input\":{\"command\":\"$command\"}}" | bash "$VALIDATE_BASH" 2>/dev/null)
  exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    log_fail "Pattern '$pattern': exit code $exit_code (expected 0)"
    continue
  fi

  decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  if [[ "$decision" == "deny" ]]; then
    log_pass "Pattern '$pattern' correctly denied"
  else
    log_fail "Pattern '$pattern': expected deny, got '$decision'"
  fi
done

# =============================================================================
# Section 4: capy.sh — Graceful degradation
# =============================================================================

log_section "Section 4: capy.sh — Graceful degradation"

log_test "capy.sh exits 0 when capy binary is not found"
# Use a temporary empty dir as PATH so capy can't be found.
# Must use full path to bash since PATH is restricted.
capy_test_dir=$(create_temp_dir "capy-path")
bash_bin=$(command -v bash)
set +e
output=$(env PATH="$capy_test_dir" HOME="/nonexistent" "$bash_bin" "$CAPY_SH" hook pretooluse 2>/dev/null </dev/null)
exit_code=$?
set -e
assert_equals "0" "$exit_code" "Exit code is 0 when capy not found"

# =============================================================================
# Summary
# =============================================================================

print_summary
