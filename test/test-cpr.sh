#!/usr/bin/env bash
# Test suite for .claude/toolbox/scripts/cpr.py (Claude Plugin Root resolver)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CPR="$REPO_ROOT/.claude/toolbox/scripts/cpr.py"

# =============================================================================
# Fixture setup
# =============================================================================

FIXTURE_DIR="$(create_temp_dir "cpr-test")"
PLUGINS_JSON="$FIXTURE_DIR/installed_plugins.json"

# Create fake install directories
mkdir -p "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3"
mkdir -p "$FIXTURE_DIR/cache/cortex-ai/cortex/0.3.0"
mkdir -p "$FIXTURE_DIR/cache/claude-toolbox/kk/0.16.0"
mkdir -p "$FIXTURE_DIR/cache/other-repo/kk-utils/1.0.0"
mkdir -p "$FIXTURE_DIR/cache/user-scope/kk/0.17.3"
mkdir -p "$FIXTURE_DIR/env-root"

cat > "$PLUGINS_JSON" <<EOF
{
  "plugins": {
    "kk@claude-toolbox": [
      {
        "scope": "project",
        "projectPath": "/tmp/some-project",
        "installPath": "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3",
        "version": "0.17.3",
        "installedAt": "2026-05-28T10:00:00.000Z"
      }
    ],
    "cortex@cortex-ai": [
      {
        "scope": "local",
        "projectPath": "/tmp/cortex",
        "installPath": "$FIXTURE_DIR/cache/cortex-ai/cortex/0.3.0",
        "version": "0.3.0",
        "installedAt": "2026-05-20T10:00:00.000Z"
      }
    ],
    "kk-utils@other-repo": [
      {
        "scope": "user",
        "installPath": "$FIXTURE_DIR/cache/other-repo/kk-utils/1.0.0",
        "version": "1.0.0",
        "installedAt": "2026-05-15T10:00:00.000Z"
      }
    ]
  }
}
EOF

# Helper: run cpr.py with fixtures, no env var leak
run_cpr() {
  CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "$@"
}

# Helper: run cpr.py and capture exit code without set -e aborting
run_cpr_rc() {
  set +e
  run_cpr "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  echo "$rc"
}

# =============================================================================
# Section 1: Exact matching
# =============================================================================

log_section "Section 1: Exact Matching"

log_test "Exact match on plugin name"
actual=$(run_cpr "kk")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "kk resolves to kk@claude-toolbox"

log_test "Exact match is case-insensitive"
actual=$(run_cpr "KK")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "KK matches kk"

log_test "Exact match on different plugin"
actual=$(run_cpr "cortex")
assert_equals "$FIXTURE_DIR/cache/cortex-ai/cortex/0.3.0" "$actual" "cortex resolves correctly"

log_test "No substring false positive: 'kk' does not match 'kk-utils'"
actual=$(run_cpr "kk")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "kk is not kk-utils"

log_test "kk-utils matches its own entry"
actual=$(run_cpr "kk-utils")
assert_equals "$FIXTURE_DIR/cache/other-repo/kk-utils/1.0.0" "$actual" "kk-utils resolves to kk-utils@other-repo"

# =============================================================================
# Section 2: Scope priority
# =============================================================================

log_section "Section 2: Scope Priority"

MULTI_SCOPE_JSON="$FIXTURE_DIR/multi-scope.json"
cat > "$MULTI_SCOPE_JSON" <<EOF
{
  "plugins": {
    "kk@claude-toolbox": [
      {
        "scope": "user",
        "installPath": "$FIXTURE_DIR/cache/user-scope/kk/0.17.3",
        "version": "0.17.3",
        "installedAt": "2026-05-28T10:00:00.000Z"
      },
      {
        "scope": "project",
        "projectPath": "/tmp/some-project",
        "installPath": "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3",
        "version": "0.17.3",
        "installedAt": "2026-05-20T10:00:00.000Z"
      }
    ]
  }
}
EOF

log_test "Project scope preferred over user scope"
actual=$(CPR_PLUGINS_FILE="$MULTI_SCOPE_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "kk")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "project scope wins over user scope"

# =============================================================================
# Section 3: CLAUDE_PLUGIN_ROOT env var takes precedence
# =============================================================================

log_section "Section 3: Env Var Precedence"

log_test "CLAUDE_PLUGIN_ROOT overrides JSON lookup"
actual=$(CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="$FIXTURE_DIR/env-root" python3 "$CPR" "kk")
assert_equals "$FIXTURE_DIR/env-root" "$actual" "env var takes precedence"

log_test "CLAUDE_PLUGIN_ROOT ignored when directory does not exist"
actual=$(CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="/nonexistent/path" python3 "$CPR" "kk")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "falls back to JSON when env dir missing"

log_test "Empty CLAUDE_PLUGIN_ROOT is ignored"
actual=$(CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "kk")
assert_equals "$FIXTURE_DIR/cache/claude-toolbox/kk/0.17.3" "$actual" "empty env var falls through"

# =============================================================================
# Section 4: Fuzzy matching
# =============================================================================

log_section "Section 4: Fuzzy Matching"

log_test "Fuzzy match on close name"
actual=$(run_cpr "corte")
assert_equals "$FIXTURE_DIR/cache/cortex-ai/cortex/0.3.0" "$actual" "corte fuzzy-matches cortex"

log_test "No match for completely unrelated name"
rc=$(run_cpr_rc "zzzzz")
assert_not_equals "0" "$rc" "zzzzz should not match anything"

# =============================================================================
# Section 5: Error handling
# =============================================================================

log_section "Section 5: Error Handling"

log_test "No arguments exits non-zero"
rc=$(run_cpr_rc)
assert_not_equals "0" "$rc" "No arguments should fail"

log_test "Usage message on no arguments"
set +e
stderr=$(CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" 2>&1)
set -e
assert_output_contains "Usage:" "echo '$stderr'" "Shows usage on no args"

log_test "Missing plugins file exits non-zero"
rc=$(set +e; CPR_PLUGINS_FILE="/nonexistent/file.json" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "kk" >/dev/null 2>&1; echo $?)
assert_not_equals "0" "$rc" "Missing plugins file should fail"

log_test "Malformed JSON exits non-zero"
BROKEN_JSON="$FIXTURE_DIR/broken.json"
echo "not json" > "$BROKEN_JSON"
rc=$(set +e; CPR_PLUGINS_FILE="$BROKEN_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "kk" >/dev/null 2>&1; echo $?)
assert_not_equals "0" "$rc" "Malformed JSON should fail"

log_test "Plugin not found shows error on stderr"
set +e
stderr=$(CPR_PLUGINS_FILE="$PLUGINS_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "nonexistent" 2>&1 >/dev/null)
set -e
assert_output_contains "Error:" "echo '$stderr'" "Shows error for unknown plugin"

# =============================================================================
# Section 6: Install path validation
# =============================================================================

log_section "Section 6: Install Path Validation"

MISSING_DIR_JSON="$FIXTURE_DIR/missing-dir.json"
cat > "$MISSING_DIR_JSON" <<EOF
{
  "plugins": {
    "ghost@repo": [
      {
        "scope": "project",
        "installPath": "$FIXTURE_DIR/does-not-exist",
        "version": "1.0.0",
        "installedAt": "2026-05-28T10:00:00.000Z"
      }
    ]
  }
}
EOF

log_test "Entry with non-existent installPath is skipped"
rc=$(set +e; CPR_PLUGINS_FILE="$MISSING_DIR_JSON" CLAUDE_PLUGIN_ROOT="" python3 "$CPR" "ghost" >/dev/null 2>&1; echo $?)
assert_not_equals "0" "$rc" "Non-existent installPath should not be returned"

# =============================================================================
# Summary
# =============================================================================

print_summary
