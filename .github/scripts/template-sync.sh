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
FETCHED_TEMPLATES_PATH=""
SUBSTITUTED_TEMPLATES_PATH=""

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
# Version Resolution and Template Fetching
# =============================================================================

# Resolve target version to a concrete git ref
# Usage: resolve_version "latest" "owner/repo"
# Returns: tag name, branch name, or SHA (via stdout)
# Note: All logging goes to stderr to keep stdout clean for return value
resolve_version() {
  local target="$1"
  local upstream="$2"
  local resolved=""

  case "$target" in
    latest)
      # Get the most recent tag sorted by version
      resolved=$(git ls-remote --tags --sort=-v:refname "https://github.com/$upstream.git" 2>/dev/null \
        | grep -v '\^{}' \
        | head -1 \
        | sed 's/.*refs\/tags\///')

      # If no tags exist, fall back to default branch (HEAD)
      if [[ -z "$resolved" ]]; then
        log_warn "No tags found in upstream repository, using default branch" >&2
        resolved="HEAD"
      fi
      ;;
    main|master|HEAD)
      resolved="$target"
      ;;
    *)
      # Assume specific tag or SHA
      resolved="$target"
      ;;
  esac

  # Validate we got something
  if [[ -z "$resolved" ]]; then
    log_error "Failed to resolve version: $target"
    exit 1
  fi

  echo "$resolved"
}

# Fetch upstream templates using git sparse-checkout
# Usage: fetch_upstream_templates "v1.0.0" "owner/repo" "/tmp/workdir"
# Sets FETCHED_TEMPLATES_PATH to the path of fetched templates
fetch_upstream_templates() {
  local version="$1"
  local upstream="$2"
  local work_dir="$3"
  local repo_url="https://github.com/$upstream.git"

  log_step "Fetching templates from $upstream @ $version"

  # Create work directory
  mkdir -p "$work_dir"

  # Clone with blob filter for efficiency (don't use --sparse flag for compatibility)
  if ! git clone --depth 1 --filter=blob:none \
    "$repo_url" "$work_dir/upstream" --quiet 2>/dev/null; then
    log_error "Failed to clone upstream repository: $repo_url"
    log_error "Please check your network connection and try again"
    exit 1
  fi

  cd "$work_dir/upstream"

  # For non-default branches/tags, we need to fetch explicitly since we used --depth 1
  # HEAD means use whatever was cloned (default branch)
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  if [[ "$version" != "HEAD" && "$version" != "$current_branch" ]]; then
    # Fetch the specific version
    if ! git fetch --depth 1 origin "$version" --quiet 2>/dev/null; then
      # Try as a tag
      if ! git fetch --depth 1 origin "refs/tags/$version:refs/tags/$version" --quiet 2>/dev/null; then
        log_error "Failed to fetch version: $version"
        log_error "The version may not exist in the upstream repository"
        cd - >/dev/null
        exit 1
      fi
    fi

    # Checkout the fetched version
    if ! git checkout "$version" --quiet 2>/dev/null; then
      if ! git checkout "tags/$version" --quiet 2>/dev/null; then
        if ! git checkout FETCH_HEAD --quiet 2>/dev/null; then
          log_error "Failed to checkout version: $version"
          cd - >/dev/null
          exit 1
        fi
      fi
    fi
  fi

  # Configure sparse-checkout to only fetch template files
  git sparse-checkout init --cone --quiet 2>/dev/null || true
  git sparse-checkout set .github/templates --quiet 2>/dev/null || true

  cd - >/dev/null

  # Verify templates directory exists
  FETCHED_TEMPLATES_PATH="$work_dir/upstream/.github/templates"
  if [[ ! -d "$FETCHED_TEMPLATES_PATH" ]]; then
    log_error "Templates directory not found in upstream at version: $version"
    log_error "Expected path: .github/templates"
    exit 1
  fi

  log_success "Fetched templates from $upstream @ $version"
}

# =============================================================================
# Substitution Functions
# =============================================================================

# Escape special characters for sed replacement
# Usage: escaped=$(escape_sed_replacement "string with /special/ chars")
escape_sed_replacement() {
  local str="$1"
  # Escape: & \ / and newlines for sed replacement string
  printf '%s' "$str" | sed -e 's/[&\\/]/\\&/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

# Apply variable substitutions to fetched templates
# Usage: apply_substitutions "/path/to/templates" "/path/to/output"
# Mirrors the substitution logic from template-cleanup.sh
apply_substitutions() {
  local template_dir="$1"
  local output_dir="$2"

  log_step "Applying substitutions from manifest"

  # Copy templates to output directory (preserving permissions)
  mkdir -p "$output_dir"
  cp -rp "$template_dir"/* "$output_dir/"

  # Read all variables from manifest
  local project_name language cc_model
  local serena_prompt tm_custom tm_append tm_permission

  project_name=$(get_manifest_value '.variables.PROJECT_NAME')
  language=$(get_manifest_value '.variables.LANGUAGE')
  cc_model=$(get_manifest_value '.variables.CC_MODEL')
  serena_prompt=$(get_manifest_value '.variables.SERENA_INITIAL_PROMPT')
  tm_custom=$(get_manifest_value '.variables.TM_CUSTOM_SYSTEM_PROMPT')
  tm_append=$(get_manifest_value '.variables.TM_APPEND_SYSTEM_PROMPT')
  tm_permission=$(get_manifest_value '.variables.TM_PERMISSION_MODE')

  # --- Claude Code Settings (claude/settings.json) ---
  local cc_settings_file="$output_dir/claude/settings.json"
  if [[ -f "$cc_settings_file" ]]; then
    if [[ "$cc_model" == "default" ]]; then
      # Remove the model line entirely so Claude Code uses its built-in default
      sed -i '/"model":/d' "$cc_settings_file"
    else
      local escaped_model
      escaped_model=$(escape_sed_replacement "$cc_model")
      sed -i "s/\"model\": \".*\"/\"model\": \"$escaped_model\"/g" "$cc_settings_file"
    fi
    log_info "Applied Claude Code settings"
  fi

  # --- Serena Settings (serena/project.yml) ---
  local serena_settings_file="$output_dir/serena/project.yml"
  if [[ -f "$serena_settings_file" ]]; then
    # Project name - always substitute
    local escaped_project_name
    escaped_project_name=$(escape_sed_replacement "$project_name")
    sed -i "s/project_name: \".*\"/project_name: \"$escaped_project_name\"/g" "$serena_settings_file"

    # Language - only substitute if provided
    if [[ -n "$language" ]]; then
      local escaped_language
      escaped_language=$(escape_sed_replacement "$language")
      sed -i "s/language: \".*\"/language: \"$escaped_language\"/g" "$serena_settings_file"
    fi

    # Initial prompt - only substitute if provided
    if [[ -n "$serena_prompt" ]]; then
      local escaped_serena_prompt
      escaped_serena_prompt=$(escape_sed_replacement "$serena_prompt")
      sed -i "s/initial_prompt: \"\"/initial_prompt: \"$escaped_serena_prompt\"/g" "$serena_settings_file"
    fi
    log_info "Applied Serena settings"
  fi

  # --- TaskMaster Settings (taskmaster/config.json) ---
  local tm_settings_file="$output_dir/taskmaster/config.json"
  if [[ -f "$tm_settings_file" ]]; then
    # Project name - always substitute
    local escaped_project_name_tm
    escaped_project_name_tm=$(escape_sed_replacement "$project_name")
    sed -i "s/\"projectName\": \".*\"/\"projectName\": \"$escaped_project_name_tm\"/g" "$tm_settings_file"

    # Custom system prompt - only substitute if provided
    if [[ -n "$tm_custom" ]]; then
      local escaped_tm_custom
      escaped_tm_custom=$(escape_sed_replacement "$tm_custom")
      sed -i "s/\"customSystemPrompt\": \"\"/\"customSystemPrompt\": \"$escaped_tm_custom\"/g" "$tm_settings_file"
    fi

    # Append system prompt - only substitute if provided
    if [[ -n "$tm_append" ]]; then
      local escaped_tm_append
      escaped_tm_append=$(escape_sed_replacement "$tm_append")
      sed -i "s/\"appendSystemPrompt\": \"\"/\"appendSystemPrompt\": \"$escaped_tm_append\"/g" "$tm_settings_file"
    fi

    # Permission mode - only substitute if provided
    if [[ -n "$tm_permission" ]]; then
      local escaped_tm_permission
      escaped_tm_permission=$(escape_sed_replacement "$tm_permission")
      sed -i "s/\"permissionMode\": \"\"/\"permissionMode\": \"$escaped_tm_permission\"/g" "$tm_settings_file"
    fi
    log_info "Applied TaskMaster settings"
  fi

  log_success "Substitutions applied to $output_dir"
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

  # Get upstream repo from manifest
  local upstream_repo
  upstream_repo=$(get_manifest_value '.upstream_repo')

  # Resolve target version
  log_step "Resolving version: $TARGET_VERSION"
  local resolved_version
  resolved_version=$(resolve_version "$TARGET_VERSION" "$upstream_repo")
  log_info "Resolved version: $resolved_version"

  # Fetch upstream templates (sets FETCHED_TEMPLATES_PATH)
  fetch_upstream_templates "$resolved_version" "$upstream_repo" "$STAGING_DIR"

  # Display fetched templates info
  if ! $CI_MODE; then
    echo ""
    echo "  Templates path: $FETCHED_TEMPLATES_PATH"
    echo ""
  fi

  # Apply substitutions to fetched templates
  SUBSTITUTED_TEMPLATES_PATH="$STAGING_DIR/substituted"
  apply_substitutions "$FETCHED_TEMPLATES_PATH" "$SUBSTITUTED_TEMPLATES_PATH"

  # Display substituted templates info
  if ! $CI_MODE; then
    echo ""
    echo "  Substituted to: $SUBSTITUTED_TEMPLATES_PATH"
    echo ""
  fi

  # TODO: Implement comparison and diff report (Task 3.5+)
  log_info "Substitution complete - comparison logic to be implemented"
}

# Run main with all arguments
main "$@"
