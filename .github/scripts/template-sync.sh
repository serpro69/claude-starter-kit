#!/usr/bin/env bash
#
# Template Sync Script
# Synchronizes template updates from the upstream claude-starter-kit repository.
#
# Usage:
#   ./template-sync.sh                    # Sync to latest version
#   ./template-sync.sh [options]          # Sync with custom options
#
# Options:
#   --version VERSION     Target version to sync (default: latest)
#   --dry-run             Preview changes without applying
#   --ci                  CI mode for GitHub Actions outputs
#   --output-dir DIR      Directory to stage changes (default: temp)
#   -h, --help            Show this help message
#
# Exit Codes:
#   0 - Success (with or without changes)
#   1 - Operational error (missing manifest, network failure, invalid JSON)
#   2 - Invalid CLI arguments

set -euo pipefail

# =============================================================================
# Global Configuration
# =============================================================================

MANIFEST_PATH=".github/template-state.json"
STAGING_DIR=""
DRY_RUN=false
CI_MODE=false
TARGET_VERSION="latest"

# =============================================================================
# Color Output
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_step() {
  echo -e "${CYAN}>>>${NC} $1"
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
  local missing=()

  if ! command -v jq &>/dev/null; then
    missing+=("jq")
  fi

  if ! command -v git &>/dev/null; then
    missing+=("git")
  fi

  if ! command -v curl &>/dev/null; then
    missing+=("curl")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing[*]}"
    echo "Please install the missing dependencies:"
    echo "  macOS:  brew install ${missing[*]}"
    echo "  Linux:  apt-get install ${missing[*]}"
    exit 1
  fi
}

# =============================================================================
# Manifest Functions
# =============================================================================

# Extract a value from the manifest using a jq expression
# Usage: get_manifest_value '.variables.PROJECT_NAME'
get_manifest_value() {
  local jq_expr="$1"
  jq -r "$jq_expr" "$MANIFEST_PATH"
}

# Read and validate the manifest file exists and contains valid JSON
read_manifest() {
  # Check if manifest file exists
  if [[ ! -f "$MANIFEST_PATH" ]]; then
    log_error "Manifest file not found: $MANIFEST_PATH"
    log_error "This repository may not have been initialized with template-cleanup.sh"
    exit 1
  fi

  # Validate JSON syntax
  if ! jq -e '.' "$MANIFEST_PATH" &>/dev/null; then
    log_error "Invalid JSON in manifest file: $MANIFEST_PATH"
    exit 1
  fi

  # Verify required top-level fields exist
  local required_fields=("schema_version" "upstream_repo" "template_version" "variables")
  for field in "${required_fields[@]}"; do
    if [[ "$(get_manifest_value ".$field // empty")" == "" ]]; then
      log_error "Missing required field in manifest: $field"
      exit 1
    fi
  done

  log_info "Manifest loaded: $MANIFEST_PATH"
}

# Validate manifest schema and required variables
validate_manifest() {
  # Check schema version
  local schema_version
  schema_version=$(get_manifest_value '.schema_version')
  if [[ "$schema_version" != "1" ]]; then
    log_error "Unsupported manifest schema version: $schema_version (expected: 1)"
    exit 1
  fi

  # Validate upstream_repo format (owner/repo)
  local upstream_repo
  upstream_repo=$(get_manifest_value '.upstream_repo')
  if [[ ! "$upstream_repo" =~ ^[^/]+/[^/]+$ ]]; then
    log_error "Invalid upstream_repo format: $upstream_repo (expected: owner/repo)"
    exit 1
  fi

  # Verify all required variables exist (can be empty but must be present)
  local required_vars=("PROJECT_NAME" "LANGUAGE" "CC_MODEL" "SERENA_INITIAL_PROMPT" "TM_CUSTOM_SYSTEM_PROMPT" "TM_APPEND_SYSTEM_PROMPT" "TM_PERMISSION_MODE")
  for var in "${required_vars[@]}"; do
    if [[ "$(get_manifest_value ".variables.$var // \"__MISSING__\"")" == "__MISSING__" ]]; then
      log_error "Missing required variable in manifest: $var"
      exit 1
    fi
  done

  log_success "Manifest validation passed"
}

# =============================================================================
# Help / Usage
# =============================================================================

show_help() {
  cat <<'EOF'
Template Sync Script
Synchronizes template updates from the upstream claude-starter-kit repository.

Usage:
  ./template-sync.sh                    # Sync to latest version
  ./template-sync.sh [options]          # Sync with custom options

Options:
  --version VERSION     Target version to sync to
                        - "latest": Most recent tagged release (default)
                        - "main": Latest from main branch
                        - "v1.2.3": Specific tag
                        - SHA: Specific commit
  --dry-run             Preview changes without applying them
  --ci                  CI mode: outputs GitHub Actions compatible format
  --output-dir DIR      Directory to stage changes (default: temporary directory)
  -h, --help            Show this help message

Exit Codes:
  0 - Success (changes found or no changes)
  1 - Operational error (missing manifest, network failure, invalid JSON)
  2 - Invalid CLI arguments

Examples:
  # Sync to latest release
  ./template-sync.sh

  # Preview changes without applying
  ./template-sync.sh --dry-run

  # Sync to specific version
  ./template-sync.sh --version v1.0.0

  # CI mode with custom output directory
  ./template-sync.sh --ci --output-dir ./staging
EOF
}

# =============================================================================
# CLI Argument Parsing
# =============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --version)
      if [[ -z "${2:-}" ]]; then
        log_error "--version requires a value"
        exit 2
      fi
      TARGET_VERSION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    --output-dir)
      if [[ -z "${2:-}" ]]; then
        log_error "--output-dir requires a value"
        exit 2
      fi
      STAGING_DIR="$2"
      shift 2
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      echo ""
      show_help
      exit 2
      ;;
    *)
      log_error "Unexpected argument: $1"
      echo ""
      show_help
      exit 2
      ;;
    esac
  done
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
  # Check dependencies first
  check_dependencies

  # Parse CLI arguments
  parse_arguments "$@"

  # Set default staging directory if not provided
  if [[ -z "$STAGING_DIR" ]]; then
    STAGING_DIR=$(mktemp -d)
    trap 'rm -rf "$STAGING_DIR"' EXIT
  fi

  # Display configuration in non-CI mode
  if ! $CI_MODE; then
    echo ""
    echo -e "${BOLD}Template Sync${NC}"
    echo "  Target version: $TARGET_VERSION"
    echo "  Dry run:        $DRY_RUN"
    echo "  Staging dir:    $STAGING_DIR"
    echo ""
  fi

  # Read and validate manifest
  read_manifest
  validate_manifest

  # Display manifest info
  if ! $CI_MODE; then
    local upstream_repo template_version project_name
    upstream_repo=$(get_manifest_value '.upstream_repo')
    template_version=$(get_manifest_value '.template_version')
    project_name=$(get_manifest_value '.variables.PROJECT_NAME')
    echo "  Upstream repo:  $upstream_repo"
    echo "  Current ver:    $template_version"
    echo "  Project name:   $project_name"
    echo ""
  fi

  # TODO: Implement core sync logic (Task 3.3+)
  log_info "Manifest functions ready - core sync logic to be implemented"
}

# Run main with all arguments
main "$@"
