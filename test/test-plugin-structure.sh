#!/usr/bin/env bash
# Test suite for kk plugin structure validation
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# =============================================================================
# Section 1: Plugin Manifest
# =============================================================================

log_section "Section 1: Plugin Manifest"

log_test "plugin.json exists"
assert_file_exists "$REPO_ROOT/klaude-plugin/.claude-plugin/plugin.json" "Plugin manifest exists"

log_test "plugin.json is valid JSON"
plugin_json=$(cat "$REPO_ROOT/klaude-plugin/.claude-plugin/plugin.json")
assert_json_valid "$plugin_json" "Plugin manifest is valid JSON"

log_test "plugin.json has correct name"
assert_json_field "$plugin_json" '.name' "kk" "Plugin name is kk"

log_test "plugin.json has required metadata fields"
assert_json_field "$plugin_json" '.author.name' "serpro69" "Author is serpro69"
for field in description version homepage repository license; do
  value=$(echo "$plugin_json" | jq -r ".$field")
  if [[ -n "$value" && "$value" != "null" ]]; then
    log_pass "plugin.json has $field"
  else
    log_fail "plugin.json missing $field"
  fi
done

# =============================================================================
# Section 2: Marketplace Manifest
# =============================================================================

log_section "Section 2: Marketplace Manifest"

log_test "marketplace.json exists"
assert_file_exists "$REPO_ROOT/.claude-plugin/marketplace.json" "Marketplace manifest exists"

log_test "marketplace.json is valid JSON"
marketplace_json=$(cat "$REPO_ROOT/.claude-plugin/marketplace.json")
assert_json_valid "$marketplace_json" "Marketplace manifest is valid JSON"

log_test "marketplace.json has correct name"
assert_json_field "$marketplace_json" '.name' "claude-toolbox" "Marketplace name is claude-toolbox"

log_test "marketplace.json plugin source is relative path to klaude-plugin"
plugin_source=$(echo "$marketplace_json" | jq -r '.plugins[0].source')
assert_equals "./klaude-plugin" "$plugin_source" "Plugin source is ./klaude-plugin"

log_test "marketplace.json plugin name matches plugin.json"
mp_plugin_name=$(echo "$marketplace_json" | jq -r '.plugins[0].name')
assert_equals "kk" "$mp_plugin_name" "Marketplace plugin name matches plugin name"

# =============================================================================
# Section 3: Skills
# =============================================================================

log_section "Section 3: Skills"

EXPECTED_SKILLS=(
  analysis-process
  cove
  development-guidelines
  documentation-process
  implementation-process
  implementation-review
  merge-docs
  solid-code-review
  testing-process
)

log_test "All 9 skill directories exist"
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [[ -d "$REPO_ROOT/klaude-plugin/skills/$skill" ]]; then
    log_pass "Skill exists: $skill"
  else
    log_fail "Skill missing: $skill"
  fi
done

log_test "Each skill has a SKILL.md"
for skill in "${EXPECTED_SKILLS[@]}"; do
  assert_file_exists "$REPO_ROOT/klaude-plugin/skills/$skill/SKILL.md" "SKILL.md for $skill"
done

# =============================================================================
# Section 4: Commands
# =============================================================================

log_section "Section 4: Commands"

EXPECTED_COMMANDS=(cove implementation-review migrate-from-taskmaster sync-workflow)

log_test "All 4 command directories exist"
for cmd in "${EXPECTED_COMMANDS[@]}"; do
  if [[ -d "$REPO_ROOT/klaude-plugin/commands/$cmd" ]]; then
    log_pass "Command exists: $cmd"
  else
    log_fail "Command missing: $cmd"
  fi
done

# =============================================================================
# Section 5: Hooks and Scripts
# =============================================================================

log_section "Section 5: Hooks and Scripts"

log_test "hooks.json exists and is valid JSON"
assert_file_exists "$REPO_ROOT/klaude-plugin/hooks/hooks.json" "hooks.json exists"
hooks_json=$(cat "$REPO_ROOT/klaude-plugin/hooks/hooks.json")
assert_json_valid "$hooks_json" "hooks.json is valid JSON"

log_test "hooks.json references CLAUDE_PLUGIN_ROOT"
if echo "$hooks_json" | grep -q 'CLAUDE_PLUGIN_ROOT'; then
  log_pass "hooks.json uses CLAUDE_PLUGIN_ROOT path"
else
  log_fail "hooks.json should reference CLAUDE_PLUGIN_ROOT"
fi

log_test "validate-bash.sh exists and is executable"
assert_file_exists "$REPO_ROOT/klaude-plugin/scripts/validate-bash.sh" "validate-bash.sh exists"
if [[ -x "$REPO_ROOT/klaude-plugin/scripts/validate-bash.sh" ]]; then
  log_pass "validate-bash.sh is executable"
else
  log_fail "validate-bash.sh should be executable"
fi

# =============================================================================
# Section 6: Template is slimmed
# =============================================================================

log_section "Section 6: Config Slimmed Down"

log_test ".claude/ does not have skills directory"
if [[ -d "$REPO_ROOT/.claude/skills" ]]; then
  log_fail ".claude/ should not have skills/ directory (moved to plugin)"
else
  log_pass "skills/ not in .claude/"
fi

log_test ".claude/ does not have commands directory"
if [[ -d "$REPO_ROOT/.claude/commands" ]]; then
  log_fail ".claude/ should not have commands/ directory (moved to plugin)"
else
  log_pass "commands/ not in .claude/"
fi

log_test ".claude/ does not have validate-bash.sh"
if [[ -f "$REPO_ROOT/.claude/scripts/validate-bash.sh" ]]; then
  log_fail ".claude/ should not have validate-bash.sh (moved to plugin)"
else
  log_pass "validate-bash.sh not in .claude/"
fi

log_test "settings.json has no hooks section"
settings_json=$(cat "$REPO_ROOT/.claude/settings.json")
if echo "$settings_json" | jq -e '.hooks' &>/dev/null; then
  log_fail "settings.json should not have hooks section"
else
  log_pass "hooks section removed from settings.json"
fi

log_test "settings.json has marketplace config"
if echo "$settings_json" | jq -e '.extraKnownMarketplaces' &>/dev/null; then
  log_pass "settings.json has extraKnownMarketplaces"
else
  log_fail "settings.json should have extraKnownMarketplaces"
fi

log_test "settings.json has enabledPlugins"
if echo "$settings_json" | jq -e '.enabledPlugins."kk@claude-toolbox"' &>/dev/null; then
  log_pass "settings.json has kk@claude-toolbox enabled"
else
  log_fail "settings.json should have kk@claude-toolbox in enabledPlugins"
fi

# =============================================================================
# Section 7: Cross-references
# =============================================================================

log_section "Section 7: Cross-references"

log_test "Skill references do NOT have kk: prefix (skills are unprefixed)"
# Skills should be referenced without kk: prefix in skill files
wrongly_prefixed=$(grep -rE '`kk:(analysis-process|implementation-process|testing-process|documentation-process|solid-code-review|implementation-review|merge-docs)`' \
  "$REPO_ROOT/klaude-plugin/skills/" 2>/dev/null || true)
if [[ -z "$wrongly_prefixed" ]]; then
  log_pass "Skill references correctly unprefixed"
else
  log_fail "Found wrongly-prefixed skill references: $wrongly_prefixed"
fi

log_test "Command references use /kk: prefix"
# Commands in command files should use /kk: prefix in examples
has_kk_commands=$(grep -rE '/kk:(cove|implementation-review|migrate-from-taskmaster|sync-workflow):' \
  "$REPO_ROOT/klaude-plugin/commands/" 2>/dev/null || true)
if [[ -n "$has_kk_commands" ]]; then
  log_pass "Command references use /kk: prefix"
else
  log_fail "Command references should use /kk: prefix"
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
