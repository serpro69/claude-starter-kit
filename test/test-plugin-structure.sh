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
assert_file_exists "$REPO_ROOT/plugins/claude/.claude-plugin/plugin.json" "Plugin manifest exists"

log_test "plugin.json is valid JSON"
plugin_json=$(cat "$REPO_ROOT/plugins/claude/.claude-plugin/plugin.json")
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

log_test "marketplace.json plugin source is relative path to plugins/claude"
plugin_source=$(echo "$marketplace_json" | jq -r '.plugins[0].source')
assert_equals "./plugins/claude" "$plugin_source" "Plugin source is ./plugins/claude"

log_test "marketplace.json plugin name matches plugin.json"
mp_plugin_name=$(echo "$marketplace_json" | jq -r '.plugins[0].name')
assert_equals "kk" "$mp_plugin_name" "Marketplace plugin name matches plugin name"

# =============================================================================
# Section 3: Skills
# =============================================================================

log_section "Section 3: Skills"

EXPECTED_SKILLS=(
  design
  chain-of-verification
  dependency-handling
  document
  implement
  review-design
  review-spec
  merge-docs
  review-code
  test
)

log_test "All 10 skill directories exist"
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [[ -d "$REPO_ROOT/skills/$skill" ]]; then
    log_pass "Skill exists: $skill"
  else
    log_fail "Skill missing: $skill"
  fi
done

log_test "Each skill has a SKILL.md"
for skill in "${EXPECTED_SKILLS[@]}"; do
  assert_file_exists "$REPO_ROOT/skills/$skill/SKILL.md" "SKILL.md for $skill"
done

# =============================================================================
# Section 4: Commands
# =============================================================================

log_section "Section 4: Commands"

EXPECTED_COMMANDS=(chain-of-verification review-spec migrate-from-taskmaster sync-workflow)

log_test "All 4 command directories exist"
for cmd in "${EXPECTED_COMMANDS[@]}"; do
  if [[ -d "$REPO_ROOT/plugins/claude/commands/$cmd" ]]; then
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
assert_file_exists "$REPO_ROOT/plugins/claude/hooks/hooks.json" "hooks.json exists"
hooks_json=$(cat "$REPO_ROOT/plugins/claude/hooks/hooks.json")
assert_json_valid "$hooks_json" "hooks.json is valid JSON"

log_test "hooks.json references CLAUDE_PLUGIN_ROOT"
if echo "$hooks_json" | grep -q 'CLAUDE_PLUGIN_ROOT'; then
  log_pass "hooks.json uses CLAUDE_PLUGIN_ROOT path"
else
  log_fail "hooks.json should reference CLAUDE_PLUGIN_ROOT"
fi

log_test "validate-bash.sh exists and is executable"
assert_file_exists "$REPO_ROOT/plugins/claude/scripts/validate-bash.sh" "validate-bash.sh exists"
if [[ -x "$REPO_ROOT/plugins/claude/scripts/validate-bash.sh" ]]; then
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
wrongly_prefixed=$(grep -rE '`kk:(plan|implement|test|document|review-code|review-spec|merge-docs)`' \
  "$REPO_ROOT/skills/" 2>/dev/null || true)
if [[ -z "$wrongly_prefixed" ]]; then
  log_pass "Skill references correctly unprefixed"
else
  log_fail "Found wrongly-prefixed skill references: $wrongly_prefixed"
fi

log_test "Command references use /kk: prefix"
# Commands in command files should use /kk: prefix in examples
has_kk_commands=$(grep -rE '/kk:(chain-of-verification|review-spec|migrate-from-taskmaster|sync-workflow):' \
  "$REPO_ROOT/plugins/claude/commands/" 2>/dev/null || true)
if [[ -n "$has_kk_commands" ]]; then
  log_pass "Command references use /kk: prefix"
else
  log_fail "Command references should use /kk: prefix"
fi

# =============================================================================
# Section 8: Profiles
# =============================================================================

log_section "Section 8: Profiles"

EXPECTED_PROFILES=(go java js_ts k8s k8s-operator kotlin python)
PHASE_SUBDIRS=(review-code design test implement document review-spec)
REQUIRED_DETECTION_HEADINGS=("Path signals" "Filename signals" "Content signals")

log_test "All profile directories exist"
for profile in "${EXPECTED_PROFILES[@]}"; do
  if [[ -d "$REPO_ROOT/profiles/$profile" ]]; then
    log_pass "Profile exists: $profile"
  else
    log_fail "Profile missing: $profile"
  fi
done

log_test "Each profile has DETECTION.md and overview.md"
for profile in "${EXPECTED_PROFILES[@]}"; do
  assert_file_exists "$REPO_ROOT/profiles/$profile/DETECTION.md" "DETECTION.md for $profile"
  assert_file_exists "$REPO_ROOT/profiles/$profile/overview.md" "overview.md for $profile"
done

log_test "Each DETECTION.md has the three required section headings"
for profile in "${EXPECTED_PROFILES[@]}"; do
  detection_file="$REPO_ROOT/profiles/$profile/DETECTION.md"
  if [[ ! -f "$detection_file" ]]; then
    log_fail "DETECTION.md missing for $profile — cannot check headings"
    continue
  fi
  for heading in "${REQUIRED_DETECTION_HEADINGS[@]}"; do
    if grep -q "^## ${heading}\$" "$detection_file"; then
      log_pass "DETECTION.md ($profile) has heading: ## $heading"
    else
      log_fail "DETECTION.md ($profile) missing heading: ## $heading"
    fi
  done
done

log_test "Presence-conditional: each existing phase subdirectory has index.md"
for profile in "${EXPECTED_PROFILES[@]}"; do
  for phase in "${PHASE_SUBDIRS[@]}"; do
    phase_dir="$REPO_ROOT/profiles/$profile/$phase"
    if [[ -d "$phase_dir" ]]; then
      assert_file_exists "$phase_dir/index.md" "index.md for $profile/$phase"
    fi
  done
done

log_test "Bidirectional index invariant: forward (all index references resolve)"
for profile in "${EXPECTED_PROFILES[@]}"; do
  for phase in "${PHASE_SUBDIRS[@]}"; do
    index_file="$REPO_ROOT/profiles/$profile/$phase/index.md"
    [[ -f "$index_file" ]] || continue
    # Extract markdown link targets ending in .md (basename form — flat phase dirs)
    referenced=()
    while IFS= read -r link; do
      [[ -z "$link" ]] && continue
      referenced+=("$(basename "$link")")
    done < <(grep -oE '\]\([^) ]+\.md\)' "$index_file" | sed -E 's/^\]\((.*)\)$/\1/')
    all_resolve=true
    for ref in "${referenced[@]}"; do
      if [[ ! -f "$REPO_ROOT/profiles/$profile/$phase/$ref" ]]; then
        log_fail "Forward invariant broken: $profile/$phase/index.md references missing file: $ref"
        all_resolve=false
      fi
    done
    if [[ "$all_resolve" == "true" ]]; then
      log_pass "Forward invariant: $profile/$phase/index.md references all resolve"
    fi
  done
done

log_test "Bidirectional index invariant: reverse (no orphan .md files)"
for profile in "${EXPECTED_PROFILES[@]}"; do
  for phase in "${PHASE_SUBDIRS[@]}"; do
    phase_dir="$REPO_ROOT/profiles/$profile/$phase"
    index_file="$phase_dir/index.md"
    [[ -f "$index_file" ]] || continue
    referenced=$(grep -oE '\]\([^) ]+\.md\)' "$index_file" \
      | sed -E 's/^\]\((.*)\)$/\1/' \
      | while IFS= read -r path; do basename "$path"; done \
      | sort -u)
    no_orphans=true
    for f in "$phase_dir"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f")
      [[ "$base" == "index.md" ]] && continue
      if ! printf '%s\n' "$referenced" | grep -qx "$base"; then
        log_fail "Reverse invariant broken: $profile/$phase/$base exists but is not referenced in index.md"
        no_orphans=false
      fi
    done
    if [[ "$no_orphans" == "true" ]]; then
      log_pass "Reverse invariant: $profile/$phase/ has no orphan .md files"
    fi
  done
done

# =============================================================================
# Section 9: Profile-detection shared file and consumer symlinks
# =============================================================================

log_section "Section 9: Profile-detection shared file and consumer symlinks"

log_test "Shared profile-detection.md exists"
assert_file_exists "$REPO_ROOT/skills/_shared/profile-detection.md" \
  "_shared/profile-detection.md exists"

PROFILE_DETECTION_CONSUMERS=(review-code review-spec design implement test document)

log_test "Each consumer skill has a shared-profile-detection.md symlink"
for skill in "${PROFILE_DETECTION_CONSUMERS[@]}"; do
  symlink_path="$REPO_ROOT/skills/$skill/shared-profile-detection.md"
  if [[ -L "$symlink_path" ]]; then
    target=$(readlink "$symlink_path")
    if [[ "$target" == "../_shared/profile-detection.md" ]]; then
      log_pass "Symlink target correct for $skill: $target"
    else
      log_fail "Symlink target wrong for $skill (got: $target)"
    fi
    if [[ -f "$symlink_path" ]]; then
      log_pass "Symlink resolves to existing file for $skill"
    else
      log_fail "Symlink does not resolve for $skill: $symlink_path"
    fi
  else
    log_fail "Not a symlink for $skill: $symlink_path"
  fi
done

# =============================================================================
# Section 10: Skill description length
# =============================================================================

log_section "Section 10: Skill description length"

log_test "dependency-handling description fits within 1,536-character per-entry cap"
dep_skill="$REPO_ROOT/skills/dependency-handling/SKILL.md"
dep_desc=$(awk '/^description:/{in_desc=1; next} in_desc { if (/^[^ \t]/) exit; sub(/^  /, ""); printf "%s", $0 }' "$dep_skill")
dep_desc_len=${#dep_desc}
if (( dep_desc_len == 0 )); then
  log_fail "dependency-handling description: parsing returned empty string"
elif (( dep_desc_len <= 1536 )); then
  log_pass "dependency-handling description length ($dep_desc_len chars) ≤ 1,536"
else
  log_fail "dependency-handling description length ($dep_desc_len chars) exceeds 1,536-character cap"
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
