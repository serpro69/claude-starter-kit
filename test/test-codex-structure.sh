#!/usr/bin/env bash
# Test suite for codex configuration structure validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXPECTED_AGENTS=(code-reviewer design-reviewer eval-grader profile-resolver spec-reviewer)

# Helper: validate TOML using whatever python+library is available
validate_toml() {
  local file="$1"
  python3 -c "import tomllib; tomllib.load(open('$file','rb'))" 2>/dev/null && return 0
  python3 -c "import tomli; tomli.load(open('$file','rb'))" 2>/dev/null && return 0
  # Try virtualenvwrapper's default venv
  local venv_python="${WORKON_HOME:-$HOME/.virtualenvs}/default/bin/python3"
  if [[ -x "$venv_python" ]]; then
    "$venv_python" -c "import tomli; tomli.load(open('$file','rb'))" 2>/dev/null && return 0
    "$venv_python" -c "import tomllib; tomllib.load(open('$file','rb'))" 2>/dev/null && return 0
  fi
  return 1
}

# =============================================================================
# Section 1: Codex marketplace
# =============================================================================

log_section "Section 1: Codex marketplace"

log_test ".agents/plugins/marketplace.json exists and is valid JSON"
assert_file_exists "$REPO_ROOT/.agents/plugins/marketplace.json" "Codex marketplace exists"
codex_mp_json=$(cat "$REPO_ROOT/.agents/plugins/marketplace.json")
assert_json_valid "$codex_mp_json" "Codex marketplace is valid JSON"

log_test "marketplace.json has kk plugin pointing at kodex-plugin"
mp_path=$(echo "$codex_mp_json" | jq -r '.plugins[0].source.path')
assert_equals "./kodex-plugin" "$mp_path" "Codex marketplace plugin path"

# =============================================================================
# Section 2: Codex config
# =============================================================================

log_section "Section 2: Codex config"

log_test "config.toml exists"
assert_file_exists "$REPO_ROOT/.codex/config.toml" "config.toml exists"

log_test "config.toml is valid TOML"
if validate_toml "$REPO_ROOT/.codex/config.toml"; then
  log_pass "config.toml parses as valid TOML"
else
  log_fail "config.toml is not valid TOML"
fi

# =============================================================================
# Section 3: Codex hooks
# =============================================================================

log_section "Section 3: Codex hooks"

log_test "hooks.json exists and is valid JSON"
assert_file_exists "$REPO_ROOT/.codex/hooks.json" "hooks.json exists"
hooks_json=$(cat "$REPO_ROOT/.codex/hooks.json")
assert_json_valid "$hooks_json" "hooks.json is valid JSON"

log_test "hooks.json has SessionStart and PreToolUse entries"
if echo "$hooks_json" | jq -e '.hooks.SessionStart' &>/dev/null; then
  log_pass "hooks.json has SessionStart"
else
  log_fail "hooks.json missing SessionStart"
fi
if echo "$hooks_json" | jq -e '.hooks.PreToolUse' &>/dev/null; then
  log_pass "hooks.json has PreToolUse"
else
  log_fail "hooks.json missing PreToolUse"
fi

# =============================================================================
# Section 4: Codex agents
# =============================================================================

log_section "Section 4: Codex agents"

log_test "All five agent TOML files exist"
for agent in "${EXPECTED_AGENTS[@]}"; do
  assert_file_exists "$REPO_ROOT/.codex/agents/$agent.toml" "Agent $agent.toml exists"
done

log_test "Agent TOML files parse cleanly"
for agent in "${EXPECTED_AGENTS[@]}"; do
  toml_file="$REPO_ROOT/.codex/agents/$agent.toml"
  if validate_toml "$toml_file"; then
    log_pass "Agent $agent.toml parses as valid TOML"
  else
    log_fail "Agent $agent.toml is not valid TOML"
  fi
done

log_test "No \${CLAUDE_PLUGIN_ROOT} literals in agent files"
if grep -r 'CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/.codex/agents/" &>/dev/null; then
  log_fail "Found CLAUDE_PLUGIN_ROOT literals in .codex/agents/"
else
  log_pass "No CLAUDE_PLUGIN_ROOT literals in agent files"
fi

# =============================================================================
# Section 5: Codex rules
# =============================================================================

log_section "Section 5: Codex rules"

log_test "default.rules exists"
assert_file_exists "$REPO_ROOT/.codex/rules/default.rules" "default.rules exists"

# =============================================================================
# Section 6: Codex scripts
# =============================================================================

log_section "Section 6: Codex scripts"

log_test "session-start.sh exists"
assert_file_exists "$REPO_ROOT/.codex/scripts/session-start.sh" "session-start.sh exists"

log_test "pretooluse-bash.sh exists"
assert_file_exists "$REPO_ROOT/.codex/scripts/pretooluse-bash.sh" "pretooluse-bash.sh exists"

log_test "session-start.sh produces valid JSON"
if bash "$REPO_ROOT/.codex/scripts/session-start.sh" < /dev/null | jq . &>/dev/null; then
  log_pass "session-start.sh output is valid JSON"
else
  log_fail "session-start.sh output is not valid JSON"
fi

# =============================================================================
# Section 7: Root-level files
# =============================================================================

log_section "Section 7: Root-level files"

log_test "AGENTS.md exists at repo root"
assert_file_exists "$REPO_ROOT/AGENTS.md" "AGENTS.md exists"

# =============================================================================
# Summary
# =============================================================================

print_summary
