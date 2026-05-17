#!/usr/bin/env bash
# Test suite for .claude/toolbox/scripts/semver-compare.sh
# Validates semver 2.0.0 compliant comparison (https://semver.org/#spec-item-11)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPARE="$REPO_ROOT/.claude/toolbox/scripts/semver-compare.sh"

# Helper: assert that compare(v1, v2) produces expected output
assert_cmp() {
  local v1="$1" v2="$2" expected="$3" msg="$4"
  local actual
  actual=$(bash "$COMPARE" "$v1" "$v2")
  assert_equals "$expected" "$actual" "$msg"
}

# =============================================================================
# Section 1: Core version comparison (MAJOR.MINOR.PATCH)
# =============================================================================

log_section "Section 1: Core Version Comparison"

log_test "Major version difference"
assert_cmp "1.0.0" "2.0.0" "lt" "1.0.0 < 2.0.0"
assert_cmp "2.0.0" "1.0.0" "gt" "2.0.0 > 1.0.0"

log_test "Minor version difference"
assert_cmp "1.0.0" "1.1.0" "lt" "1.0.0 < 1.1.0"
assert_cmp "1.2.0" "1.1.0" "gt" "1.2.0 > 1.1.0"

log_test "Patch version difference"
assert_cmp "1.0.0" "1.0.1" "lt" "1.0.0 < 1.0.1"
assert_cmp "1.0.2" "1.0.1" "gt" "1.0.2 > 1.0.1"

log_test "Equal versions"
assert_cmp "1.0.0" "1.0.0" "eq" "1.0.0 == 1.0.0"
assert_cmp "0.0.0" "0.0.0" "eq" "0.0.0 == 0.0.0"

log_test "Multi-digit version numbers"
assert_cmp "0.9.0" "0.10.0" "lt" "0.9.0 < 0.10.0 (numeric, not lexical)"
assert_cmp "1.0.99" "1.0.100" "lt" "1.0.99 < 1.0.100"

# =============================================================================
# Section 2: Pre-release precedence (§11.3, §11.4)
# =============================================================================

log_section "Section 2: Pre-release Precedence"

log_test "Pre-release has lower precedence than release (§11.3)"
assert_cmp "1.0.0-alpha" "1.0.0" "lt" "1.0.0-alpha < 1.0.0"
assert_cmp "1.0.0" "1.0.0-alpha" "gt" "1.0.0 > 1.0.0-alpha"
assert_cmp "0.10.0-rc.6" "0.10.0" "lt" "0.10.0-rc.6 < 0.10.0 (reported bug)"

log_test "Numeric pre-release identifiers compared as integers (§11.4.1)"
assert_cmp "1.0.0-1" "1.0.0-2" "lt" "1.0.0-1 < 1.0.0-2"
assert_cmp "1.0.0-2" "1.0.0-11" "lt" "1.0.0-2 < 1.0.0-11 (numeric, not lexical)"

log_test "Alphanumeric pre-release identifiers compared lexically (§11.4.2)"
assert_cmp "1.0.0-alpha" "1.0.0-beta" "lt" "1.0.0-alpha < 1.0.0-beta"
assert_cmp "1.0.0-beta" "1.0.0-alpha" "gt" "1.0.0-beta > 1.0.0-alpha"

log_test "Numeric identifier has lower precedence than alphanumeric (§11.4.3)"
assert_cmp "1.0.0-1" "1.0.0-alpha" "lt" "1.0.0-1 < 1.0.0-alpha"
assert_cmp "1.0.0-alpha" "1.0.0-1" "gt" "1.0.0-alpha > 1.0.0-1"

log_test "Fewer pre-release fields has lower precedence (§11.4.4)"
assert_cmp "1.0.0-alpha" "1.0.0-alpha.1" "lt" "1.0.0-alpha < 1.0.0-alpha.1"
assert_cmp "1.0.0-alpha.1" "1.0.0-alpha" "gt" "1.0.0-alpha.1 > 1.0.0-alpha"

log_test "Equal pre-release versions"
assert_cmp "1.0.0-rc.1" "1.0.0-rc.1" "eq" "1.0.0-rc.1 == 1.0.0-rc.1"
assert_cmp "1.0.0-alpha.1.beta" "1.0.0-alpha.1.beta" "eq" "multi-field pre-release equal"

# =============================================================================
# Section 3: Build metadata ignored (§10)
# =============================================================================

log_section "Section 3: Build Metadata Ignored"

log_test "Build metadata ignored for precedence"
assert_cmp "1.0.0+build1" "1.0.0+build2" "eq" "1.0.0+build1 == 1.0.0+build2"
assert_cmp "1.0.0+build" "1.0.0" "eq" "1.0.0+build == 1.0.0"
assert_cmp "1.0.0-rc.1+alpha.5" "1.0.0-rc.1" "eq" "rc.1+alpha.5 == rc.1 (reported bug)"

log_test "Build metadata on both sides ignored"
assert_cmp "1.0.0-rc.1+b1" "1.0.0-rc.2+b2" "lt" "rc.1+b1 < rc.2+b2 (compare pre-release, ignore build)"
assert_cmp "1.0.0+20130313" "1.0.0+20240101" "eq" "date build metadata ignored"

# =============================================================================
# Section 4: Semver.org spec example ordering (§11)
# =============================================================================

log_section "Section 4: Spec Example Ordering"

log_test "Full semver.org precedence chain"
assert_cmp "1.0.0-alpha"      "1.0.0-alpha.1"    "lt" "alpha < alpha.1"
assert_cmp "1.0.0-alpha.1"    "1.0.0-alpha.beta"  "lt" "alpha.1 < alpha.beta"
assert_cmp "1.0.0-alpha.beta" "1.0.0-beta"        "lt" "alpha.beta < beta"
assert_cmp "1.0.0-beta"       "1.0.0-beta.2"      "lt" "beta < beta.2"
assert_cmp "1.0.0-beta.2"     "1.0.0-beta.11"     "lt" "beta.2 < beta.11"
assert_cmp "1.0.0-beta.11"    "1.0.0-rc.1"        "lt" "beta.11 < rc.1"
assert_cmp "1.0.0-rc.1"       "1.0.0"             "lt" "rc.1 < 1.0.0"

# =============================================================================
# Section 5: Workflow-specific scenarios
# =============================================================================

log_section "Section 5: Workflow Scenarios"

log_test "Release: RC to release is a valid upgrade"
assert_cmp "0.10.0-rc.6" "0.10.0" "lt" "0.10.0-rc.6 -> 0.10.0 should pass"

log_test "Release: cannot downgrade"
assert_cmp "1.0.0" "0.9.0" "gt" "1.0.0 -> 0.9.0 should fail"

log_test "Pre-release: RC bump"
assert_cmp "0.10.0-rc.1" "0.10.0-rc.2" "lt" "rc.1 -> rc.2 should pass"
assert_cmp "0.10.0-rc.9" "0.10.0-rc.10" "lt" "rc.9 -> rc.10 numeric comparison"

log_test "Pre-release: build metadata does not block same-precedence release"
assert_cmp "0.10.0-rc.1+alpha.5" "0.10.0-rc.1" "eq" "rc.1+alpha.5 == rc.1"
assert_cmp "0.10.0-rc.1+alpha.5" "0.10.0-rc.2" "lt" "rc.1+alpha.5 < rc.2"

# =============================================================================
# Section 6: Edge cases
# =============================================================================

log_section "Section 6: Edge Cases"

log_test "Zero versions"
assert_cmp "0.0.0" "0.0.1" "lt" "0.0.0 < 0.0.1"
assert_cmp "0.0.0-alpha" "0.0.0" "lt" "0.0.0-alpha < 0.0.0"

log_test "Leading zeros in pre-release numeric identifiers"
assert_cmp "1.0.0-01" "1.0.0-1" "gt" "01 is alphanumeric (leading zero), 1 is numeric; alpha > numeric"

log_test "Mixed numeric and alphanumeric pre-release fields"
assert_cmp "1.0.0-0.3.7" "1.0.0-0.3.8" "lt" "all-numeric dot-separated fields"
assert_cmp "1.0.0-x.7.z.92" "1.0.0-x.7.z.93" "lt" "mixed alpha+numeric fields"

log_test "Usage error exits non-zero"
set +e
bash "$COMPARE" "1.0.0" >/dev/null 2>&1
EXIT_CODE=$?
set -e
assert_not_equals "0" "$EXIT_CODE" "Single argument should fail"

set +e
bash "$COMPARE" >/dev/null 2>&1
EXIT_CODE=$?
set -e
assert_not_equals "0" "$EXIT_CODE" "No arguments should fail"

# =============================================================================
# Summary
# =============================================================================

print_summary
