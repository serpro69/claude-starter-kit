#!/usr/bin/env bash
#
# template-sync.sh - Synchronize configuration from upstream claude-starter-kit template
#
# This script fetches template updates from the upstream repository and applies
# project-specific substitutions using values stored in the state manifest.
#
# USAGE:
#   ./template-sync.sh                      # Sync to latest release
#   ./template-sync.sh --version v1.2.0     # Sync to specific version
#   ./template-sync.sh --dry-run            # Preview what would change
#   ./template-sync.sh --ci                 # CI mode for GitHub Actions
#
# OPTIONS:
#   --version VERSION     Target version to sync (default: latest)
#                         - "latest": Most recent tagged release
#                         - "main": Latest from main branch
#                         - "v1.2.3": Specific tag
#   --dry-run             Preview changes without applying them
#   --ci                  CI mode for GitHub Actions (structured output)
#   --output-dir DIR      Directory for staged changes (default: temp)
#   -h, --help            Show this help message
#
# REQUIRES:
#   - jq (for JSON parsing)
#   - git
#   - curl
#
# EXIT CODES:
#   0 - Success (with or without changes)
#   1 - Operational error (missing manifest, network failure, invalid JSON)
#   2 - Invalid CLI arguments
#
# TROUBLESHOOTING:
#   "Manifest not found":
#     - Ensure .github/template-state.json exists
#     - For repos created before sync feature, create manifest manually (see README)
#
#   "Version not found":
#     - Check available tags: git ls-remote --tags https://github.com/serpro69/claude-starter-kit
#     - Use 'latest' for most recent release or 'main' for bleeding edge
#
#   "Network error":
#     - Verify internet connectivity
#     - Check if upstream repo is accessible
#     - Script will retry 3 times with 5s delay
#
#   "Invalid JSON in manifest":
#     - Check manifest file for syntax errors
#     - Restore from version control if corrupted

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

# Temp directory for cleanup tracking (set when using auto-generated staging dir)
TEMP_DIR=""

# File change tracking arrays
ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()
UNCHANGED_FILES=()

# Exclusion tracking arrays
EXCLUDED_FILES=()
SYNC_EXCLUSIONS=()

# Resolved version (for reporting)
RESOLVED_VERSION=""

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
# Cleanup Functions
# =============================================================================

# Cleanup handler that preserves exit code
# Called on EXIT, INT, TERM signals
cleanup_on_exit() {
  local exit_code=$?

  # Only clean up if TEMP_DIR is set and exists
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
    if ! $CI_MODE; then
      log_info "Cleaned up temporary directory"
    fi
  fi

  exit $exit_code
}

# =============================================================================
# Helper Functions
# =============================================================================

# Convert comma-separated languages to YAML array format
format_languages_yaml() {
  local input="$1"
  local indent="${2:-  }"  # default 2-space indent
  echo "languages:"
  IFS=',' read -ra langs <<< "$input"
  for lang in "${langs[@]}"; do
    lang=$(echo "$lang" | xargs)  # trim whitespace
    echo "${indent}- $lang"
  done
}

# is_excluded()
# Checks if a file path matches any exclusion pattern.
#
# Args:
#   $1 - Project-relative file path (e.g., ".claude/commands/cove/cove.md")
#
# Returns:
#   0 if path matches an exclusion pattern (excluded)
#   1 if path does not match any pattern (not excluded)
#
# Note: Uses bash case statement glob matching where * matches any characters including /
is_excluded() {
  local path="$1"

  # If no exclusions configured, nothing is excluded
  if [[ ${#SYNC_EXCLUSIONS[@]} -eq 0 ]]; then
    return 1
  fi

  local pattern
  for pattern in "${SYNC_EXCLUSIONS[@]}"; do
    # IMPORTANT: pattern must be unquoted for glob expansion in case
    case "$path" in
      $pattern)
        return 0  # Excluded
        ;;
    esac
  done

  return 1  # Not excluded
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

# get_manifest_value()
# Extracts a value from the manifest file using a jq expression.
#
# Args:
#   $1 - jq expression to evaluate (e.g., '.variables.PROJECT_NAME')
#
# Returns:
#   Extracted value via stdout, or empty string if not found
#
# Example:
#   project_name=$(get_manifest_value '.variables.PROJECT_NAME')
get_manifest_value() {
  local jq_expr="$1"
  jq -r "$jq_expr" "$MANIFEST_PATH"
}

# read_manifest()
# Reads and validates the manifest file exists and contains valid JSON.
# Verifies required top-level fields (schema_version, upstream_repo, template_version, variables).
#
# Returns:
#   0 on success (manifest loaded)
#   Exits with 1 if manifest missing, invalid JSON, or missing required fields
#
# Side effects:
#   Logs info/error messages
read_manifest() {
  # Check if manifest file exists
  if [[ ! -f "$MANIFEST_PATH" ]]; then
    log_error "Manifest file not found: $MANIFEST_PATH"
    log_error ""
    log_error "This repository doesn't have a template state manifest."
    log_error "Possible reasons:"
    log_error "  - The repository was created before the sync feature was available"
    log_error "  - The cleanup script was run with an older version"
    log_error "  - The manifest file was accidentally deleted"
    log_error ""
    log_error "To create a manifest manually, see the template documentation."
    exit 1
  fi

  # Validate JSON syntax
  if ! jq -e '.' "$MANIFEST_PATH" &>/dev/null; then
    log_error "Invalid JSON in manifest file: $MANIFEST_PATH"
    log_error "The manifest file is not valid JSON. It may be corrupted."
    log_error "Please check the file for syntax errors or restore it from version control."
    exit 1
  fi

  # Verify required top-level fields exist
  local required_fields=("schema_version" "upstream_repo" "template_version" "variables")
  for field in "${required_fields[@]}"; do
    if [[ "$(get_manifest_value ".$field // empty")" == "" ]]; then
      log_error "Missing required field in manifest: $field"
      log_error "The manifest file may be incomplete or corrupted."
      exit 1
    fi
  done

  log_info "Manifest loaded: $MANIFEST_PATH"

  # Load sync exclusions if present (optional field)
  if jq -e '.sync_exclusions' "$MANIFEST_PATH" &>/dev/null; then
    mapfile -t SYNC_EXCLUSIONS < <(jq -r '.sync_exclusions[]' "$MANIFEST_PATH")
    if [[ ${#SYNC_EXCLUSIONS[@]} -gt 0 ]]; then
      log_info "Loaded ${#SYNC_EXCLUSIONS[@]} sync exclusion pattern(s)"
    fi
  fi
}

# validate_manifest()
# Validates manifest schema version and all required variables.
# Checks schema_version is supported (currently: "1") and validates
# upstream_repo format and required variable presence.
#
# Returns:
#   0 on success (manifest valid)
#   Exits with 1 if validation fails
#
# Side effects:
#   Logs success/error messages
validate_manifest() {
  # Check schema version
  local schema_version
  schema_version=$(get_manifest_value '.schema_version // empty')

  if [[ -z "$schema_version" ]]; then
    log_error "Invalid manifest: missing schema_version"
    log_error "The manifest file may be corrupted or from an incompatible version."
    exit 1
  fi

  if [[ "$schema_version" != "1" ]]; then
    log_error "Manifest schema version $schema_version is not supported"
    log_error "This sync script supports schema version 1."
    log_error "Please update the template-sync script or migrate your manifest."
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
  local required_vars=("PROJECT_NAME" "LANGUAGES" "CC_MODEL" "SERENA_INITIAL_PROMPT" "TM_CUSTOM_SYSTEM_PROMPT" "TM_APPEND_SYSTEM_PROMPT" "TM_PERMISSION_MODE")
  for var in "${required_vars[@]}"; do
    if [[ "$(get_manifest_value ".variables.$var // \"__MISSING__\"")" == "__MISSING__" ]]; then
      log_error "Missing required variable in manifest: $var"
      exit 1
    fi
  done

  # Validate LANGUAGES is not empty
  local languages
  languages=$(get_manifest_value '.variables.LANGUAGES')
  if [[ -z "$languages" ]]; then
    log_error "LANGUAGES variable cannot be empty in manifest"
    exit 1
  fi

  # Validate sync_exclusions if present (optional field)
  if jq -e '.sync_exclusions' "$MANIFEST_PATH" &>/dev/null; then
    # Must be an array
    if ! jq -e '.sync_exclusions | type == "array"' "$MANIFEST_PATH" &>/dev/null; then
      log_error "sync_exclusions must be an array"
      exit 1
    fi
    # All elements must be strings
    if ! jq -e '.sync_exclusions | all(type == "string")' "$MANIFEST_PATH" &>/dev/null; then
      log_error "All sync_exclusions elements must be strings"
      exit 1
    fi
  fi

  log_success "Manifest validation passed"
}

# =============================================================================
# Version Resolution and Template Fetching
# =============================================================================

# resolve_version()
# Resolves target version string to a concrete git ref or SHA.
#
# Args:
#   $1 - Target version ("latest", "main", "master", "HEAD", or specific tag/SHA)
#   $2 - Upstream repository (owner/repo format)
#
# Returns:
#   Resolved version string via stdout:
#   - For "latest": returns tag name (e.g., "v1.0.0") or SHA if no tags
#   - For "main"/"master"/"HEAD": returns actual commit SHA
#   - For specific tag/SHA: returns as-is
#   Exits with 1 if resolution fails
#
# Note: All logging goes to stderr to keep stdout clean for return value
resolve_version() {
  local target="$1"
  local upstream="$2"
  local resolved=""
  local repo_url="https://github.com/$upstream.git"

  case "$target" in
    latest)
      # Get the most recent tag sorted by version
      # Note: Use 'grep ... || true' to handle case when no tags exist (grep returns 1 for no matches)
      resolved=$(git ls-remote --tags --sort=-v:refname "$repo_url" 2>/dev/null \
        | { grep -v '\^{}' || true; } \
        | head -1 \
        | sed 's/.*refs\/tags\///')

      # If no tags exist, resolve default branch to SHA
      if [[ -z "$resolved" ]]; then
        log_warn "No tags found in upstream repository, using default branch" >&2
        resolved=$(git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1)
        if [[ -z "$resolved" ]]; then
          log_error "Failed to resolve default branch SHA for upstream" >&2
          exit 1
        fi
      fi
      ;;
    main|master)
      # Resolve branch name to actual commit SHA
      resolved=$(git ls-remote "$repo_url" "refs/heads/$target" 2>/dev/null | cut -f1)
      if [[ -z "$resolved" ]]; then
        log_error "Branch '$target' not found in upstream repository" >&2
        exit 1
      fi
      ;;
    HEAD)
      # Resolve HEAD (default branch) to actual commit SHA
      resolved=$(git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1)
      if [[ -z "$resolved" ]]; then
        log_error "Failed to resolve HEAD for upstream repository" >&2
        exit 1
      fi
      ;;
    *)
      # Assume specific tag or SHA - return as-is
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

# fetch_upstream_templates()
# Fetches templates from upstream repository using git sparse-checkout.
# Implements retry logic for network failures (3 attempts, 5s delay).
#
# Args:
#   $1 - Version to fetch (tag, branch, or SHA)
#   $2 - Upstream repository (owner/repo format)
#   $3 - Working directory for clone operation
#
# Returns:
#   0 on success
#   Exits with 1 if fetch fails after retries or templates not found
#
# Side effects:
#   Sets global FETCHED_TEMPLATES_PATH to the path of fetched templates
#   Creates directories in work_dir
#   Logs progress/error messages
fetch_upstream_templates() {
  local version="$1"
  local upstream="$2"
  local work_dir="$3"
  local repo_url="https://github.com/$upstream.git"

  # Retry configuration
  local max_retries=3
  local retry_delay=5
  local attempt

  log_step "Fetching templates from $upstream @ $version"

  # Create work directory
  mkdir -p "$work_dir"

  # Clone with blob filter for efficiency (with retry logic)
  for ((attempt=1; attempt<=max_retries; attempt++)); do
    if git clone --depth 1 --filter=blob:none \
      "$repo_url" "$work_dir/upstream" --quiet 2>/dev/null; then
      break
    fi

    if ((attempt < max_retries)); then
      log_warn "Clone failed, retrying in ${retry_delay}s (attempt $attempt/$max_retries)"
      sleep "$retry_delay"
      rm -rf "$work_dir/upstream" 2>/dev/null || true
    else
      log_error "Failed to fetch upstream after $max_retries attempts"
      log_error "Unable to reach GitHub. Please check your network connection and try again."
      log_error "Repository URL: $repo_url"
      exit 1
    fi
  done

  cd "$work_dir/upstream"

  # For non-default branches/tags, we need to fetch explicitly since we used --depth 1
  # HEAD means use whatever was cloned (default branch)
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  if [[ "$version" != "HEAD" && "$version" != "$current_branch" ]]; then
    # Fetch the specific version (try branch first, then tag)
    if ! git fetch --depth 1 origin "$version" --quiet 2>/dev/null; then
      # Try as a tag
      if ! git fetch --depth 1 origin "refs/tags/$version:refs/tags/$version" --quiet 2>/dev/null; then
        log_error "Invalid version: $version"
        log_error "The specified version does not exist in the upstream repository."
        log_error "Use 'latest' for the most recent release, 'main' for bleeding edge,"
        log_error "or specify a valid tag like 'v1.0.0'."
        cd - >/dev/null
        exit 1
      fi
    fi

    # Checkout the fetched version (try branch, then tag, then FETCH_HEAD)
    if ! git checkout "$version" --quiet 2>/dev/null; then
      if ! git checkout "tags/$version" --quiet 2>/dev/null; then
        if ! git checkout FETCH_HEAD --quiet 2>/dev/null; then
          log_error "Failed to checkout version: $version"
          log_error "The version was fetched but checkout failed unexpectedly."
          cd - >/dev/null
          exit 1
        fi
      fi
    fi
  fi

  # Configure sparse-checkout to fetch template files and sync infrastructure
  if ! git sparse-checkout init --cone --quiet 2>/dev/null; then
    log_warn "Sparse-checkout init failed, continuing with full checkout"
  fi
  if ! git sparse-checkout set .github/templates .github/workflows/template-sync.yml .github/scripts/template-sync.sh --quiet 2>/dev/null; then
    log_warn "Sparse-checkout set failed, templates may not exist at this version"
  fi

  cd - >/dev/null

  # Verify templates directory exists
  FETCHED_TEMPLATES_PATH="$work_dir/upstream/.github/templates"
  if [[ ! -d "$FETCHED_TEMPLATES_PATH" ]]; then
    log_error "Templates directory not found in upstream at version: $version"
    log_error "Expected path: .github/templates"
    log_error "The upstream repository may not have templates at this version,"
    log_error "or the repository structure has changed."
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

# apply_substitutions()
# Applies project-specific variable substitutions to fetched template files.
# Mirrors the substitution logic from template-cleanup.sh for consistency.
#
# Args:
#   $1 - Source template directory (raw fetched templates)
#   $2 - Output directory for substituted templates
#
# Returns:
#   0 on success
#
# Substitutions applied:
#   - Claude Code settings: CC_MODEL
#   - Serena settings: PROJECT_NAME, LANGUAGES, SERENA_INITIAL_PROMPT
#   - TaskMaster settings: PROJECT_NAME, TM_CUSTOM_SYSTEM_PROMPT,
#                          TM_APPEND_SYSTEM_PROMPT, TM_PERMISSION_MODE
#
# Side effects:
#   Creates output directory and copies/modifies template files
#   Logs progress messages
apply_substitutions() {
  local template_dir="$1"
  local output_dir="$2"

  log_step "Applying substitutions from manifest"

  # Copy templates to output directory (preserving permissions)
  mkdir -p "$output_dir"
  cp -rp "$template_dir"/* "$output_dir/"

  # Read all variables from manifest
  local project_name languages cc_model
  local serena_prompt tm_custom tm_append tm_permission

  project_name=$(get_manifest_value '.variables.PROJECT_NAME')
  languages=$(get_manifest_value '.variables.LANGUAGES')
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

    # Languages - use awk to replace the entire languages block (multi-line YAML array)
    local languages_yaml
    languages_yaml=$(format_languages_yaml "$languages")
    awk -v new="$languages_yaml" '
      /^languages:/ { print new; skip=1; next }
      skip && /^[[:space:]]*-/ { next }
      skip && /^[^[:space:]]/ { skip=0 }
      !skip { print }
    ' "$serena_settings_file" > "$serena_settings_file.tmp" && mv "$serena_settings_file.tmp" "$serena_settings_file"

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

# copy_sync_files()
# Copies sync infrastructure files (workflow and script) from upstream to staging.
# These files are synced as-is without variable substitution.
#
# Args:
#   $1 - Upstream directory (parent of .github/)
#   $2 - Output directory for staged files
#
# Returns:
#   0 on success
#
# Side effects:
#   Creates workflows/ and scripts/ subdirectories in output_dir
#   Copies template-sync.yml and template-sync.sh if they exist
copy_sync_files() {
  local upstream_dir="$1"
  local output_dir="$2"

  log_step "Copying sync infrastructure files"

  # Create staging subdirectories
  mkdir -p "$output_dir/workflows" "$output_dir/scripts"

  local copied=0

  # Copy workflow if it exists
  if [[ -f "$upstream_dir/.github/workflows/template-sync.yml" ]]; then
    cp "$upstream_dir/.github/workflows/template-sync.yml" "$output_dir/workflows/"
    log_info "Copied template-sync.yml"
    copied=$((copied + 1))
  fi

  # Copy script if it exists
  if [[ -f "$upstream_dir/.github/scripts/template-sync.sh" ]]; then
    cp "$upstream_dir/.github/scripts/template-sync.sh" "$output_dir/scripts/"
    log_info "Copied template-sync.sh"
    copied=$((copied + 1))
  fi

  if ((copied > 0)); then
    log_success "Copied $copied sync infrastructure file(s)"
  else
    log_info "No sync infrastructure files found in upstream"
  fi
}

# =============================================================================
# File Comparison Functions
# =============================================================================

# compare_files()
# Compares staging directory against current project directories.
# Detects added, modified, deleted, and unchanged files.
#
# Args:
#   $1 - Staging directory containing substituted templates
#
# Returns:
#   0 on success
#
# Side effects:
#   Populates global arrays: ADDED_FILES, MODIFIED_FILES, DELETED_FILES, UNCHANGED_FILES
#   Logs comparison summary
#
# Directories compared:
#   staging/claude    -> .claude/
#   staging/serena    -> .serena/
#   staging/taskmaster -> .taskmaster/
compare_files() {
  local staging_dir="$1"

  log_step "Comparing files with current project"

  # Reset arrays
  ADDED_FILES=()
  MODIFIED_FILES=()
  DELETED_FILES=()
  UNCHANGED_FILES=()
  EXCLUDED_FILES=()

  # Directories to compare (staging subdir -> project dir)
  local -A dir_map=(
    ["claude"]=".claude"
    ["serena"]=".serena"
    ["taskmaster"]=".taskmaster"
    ["workflows"]=".github/workflows"
    ["scripts"]=".github/scripts"
  )

  for staging_subdir in "${!dir_map[@]}"; do
    local project_dir="${dir_map[$staging_subdir]}"
    local staging_path="$staging_dir/$staging_subdir"

    # Skip if staging subdir doesn't exist
    [[ ! -d "$staging_path" ]] && continue

    # Build find command with exclusions for user-scoped directories in .taskmaster/
    local staging_find_args=("$staging_path" -type f)
    if [[ "$staging_subdir" == "taskmaster" ]]; then
      staging_find_args+=(-not -path "$staging_path/tasks/*")
      staging_find_args+=(-not -path "$staging_path/docs/*")
      staging_find_args+=(-not -path "$staging_path/reports/*")
    fi
    staging_find_args+=(-print0)

    # Find all files in staging (excluding user-scoped directories)
    while IFS= read -r -d '' staging_file; do
      local relative_path="${staging_file#$staging_path/}"
      local project_file="$project_dir/$relative_path"
      local display_path="$project_dir/$relative_path"

      # Check exclusion before categorization
      if is_excluded "$display_path"; then
        EXCLUDED_FILES+=("$display_path")
        continue
      fi

      if [[ ! -f "$project_file" ]]; then
        # File exists in staging but not in project -> Added
        ADDED_FILES+=("$display_path")
      elif ! diff -q "$staging_file" "$project_file" &>/dev/null; then
        # Files differ -> Modified
        MODIFIED_FILES+=("$display_path")
      else
        # Files are identical -> Unchanged
        UNCHANGED_FILES+=("$display_path")
      fi
    done < <(find "${staging_find_args[@]}" 2>/dev/null)

    # Find deleted files (exist in project but not in staging)
    # Skip for sync infrastructure directories - we only sync specific files, not entire dirs
    # (scripts/ only syncs template-sync.sh, workflows/ only syncs template-sync.yml)
    if [[ -d "$project_dir" && "$staging_subdir" != "scripts" && "$staging_subdir" != "workflows" ]]; then
      # Build find command with exclusions for user-scoped directories
      local find_args=("$project_dir" -type f)

      # Exclude user-scoped directories in .taskmaster/ (tasks, docs, reports)
      if [[ "$staging_subdir" == "taskmaster" ]]; then
        find_args+=(-not -path "$project_dir/tasks/*")
        find_args+=(-not -path "$project_dir/docs/*")
        find_args+=(-not -path "$project_dir/reports/*")
      fi

      find_args+=(-print0)

      while IFS= read -r -d '' project_file; do
        local relative_path="${project_file#$project_dir/}"
        local staging_file="$staging_path/$relative_path"
        local display_path="$project_dir/$relative_path"

        # Skip excluded files in deletion detection (don't add to EXCLUDED_FILES to avoid double-counting)
        if is_excluded "$display_path"; then
          continue
        fi

        if [[ ! -f "$staging_file" ]]; then
          # File exists in project but not in staging -> Deleted
          DELETED_FILES+=("$display_path")
        fi
      done < <(find "${find_args[@]}" 2>/dev/null)
    fi
  done

  log_success "Comparison complete: ${#ADDED_FILES[@]} added, ${#MODIFIED_FILES[@]} modified, ${#DELETED_FILES[@]} deleted, ${#UNCHANGED_FILES[@]} unchanged, ${#EXCLUDED_FILES[@]} excluded"
}

# generate_diff_report()
# Generates a human-readable diff report showing all changes.
# In CI mode, also outputs GitHub Actions compatible format.
#
# Args:
#   $1 - Staging directory containing substituted templates
#
# Returns:
#   0 on success
#
# Output:
#   - Human-readable report to stdout with colored output
#   - In CI mode: writes to GITHUB_OUTPUT file for workflow consumption
#   - Shows version transition, change summary, and file diffs
#
# Side effects:
#   Reads from global arrays (ADDED_FILES, MODIFIED_FILES, etc.)
#   Reads RESOLVED_VERSION global variable
generate_diff_report() {
  local staging_dir="$1"
  local total_changes=$((${#ADDED_FILES[@]} + ${#MODIFIED_FILES[@]} + ${#DELETED_FILES[@]}))
  local has_changes=false
  [[ $total_changes -gt 0 ]] && has_changes=true

  # CI mode: output GitHub Actions format
  if $CI_MODE; then
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      # Write to GITHUB_OUTPUT file
      {
        echo "has_changes=$has_changes"
        echo "added_count=${#ADDED_FILES[@]}"
        echo "modified_count=${#MODIFIED_FILES[@]}"
        echo "deleted_count=${#DELETED_FILES[@]}"
        echo "unchanged_count=${#UNCHANGED_FILES[@]}"
        echo "excluded_count=${#EXCLUDED_FILES[@]}"
        echo "total_changes=$total_changes"
        echo "resolved_version=$RESOLVED_VERSION"
        echo "diff_summary<<EOF"
        generate_markdown_summary "$staging_dir"
        echo "EOF"
      } >> "$GITHUB_OUTPUT"
    else
      # Output to stdout for local testing
      echo "::group::GitHub Actions Outputs"
      echo "has_changes=$has_changes"
      echo "added_count=${#ADDED_FILES[@]}"
      echo "modified_count=${#MODIFIED_FILES[@]}"
      echo "deleted_count=${#DELETED_FILES[@]}"
      echo "unchanged_count=${#UNCHANGED_FILES[@]}"
      echo "excluded_count=${#EXCLUDED_FILES[@]}"
      echo "total_changes=$total_changes"
      echo "resolved_version=$RESOLVED_VERSION"
      echo "::endgroup::"
    fi
  fi

  # Human-readable output
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}                    Template Sync Report                        ${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  local current_version
  current_version=$(get_manifest_value '.template_version')
  echo -e "  ${CYAN}From:${NC} $current_version"
  echo -e "  ${CYAN}To:${NC}   $RESOLVED_VERSION"
  echo ""

  if ! $has_changes; then
    echo -e "  ${GREEN}No changes detected - templates are up to date${NC}"
    echo ""
    return
  fi

  echo -e "  ${CYAN}Summary:${NC}"
  echo -e "    Added:     ${GREEN}${#ADDED_FILES[@]}${NC}"
  echo -e "    Modified:  ${YELLOW}${#MODIFIED_FILES[@]}${NC}"
  echo -e "    Deleted:   ${RED}${#DELETED_FILES[@]}${NC}"
  echo -e "    Unchanged: ${#UNCHANGED_FILES[@]}"
  echo -e "    Excluded:  ${#EXCLUDED_FILES[@]}"
  echo ""

  # List added files
  if [[ ${#ADDED_FILES[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}Added files:${NC}"
    for file in "${ADDED_FILES[@]}"; do
      echo -e "    ${GREEN}+${NC} $file"
    done
    echo ""
  fi

  # List modified files with inline diffs
  if [[ ${#MODIFIED_FILES[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}Modified files:${NC}"
    for file in "${MODIFIED_FILES[@]}"; do
      echo -e "    ${YELLOW}~${NC} $file"
    done
    echo ""

    # Show diffs for modified files (limited to first 20 lines each)
    if ! $CI_MODE; then
      echo -e "  ${CYAN}Diffs:${NC}"
      for file in "${MODIFIED_FILES[@]}"; do
        local staging_file
        # Map project path back to staging path
        if [[ "$file" == ".claude/"* ]]; then
          staging_file="$staging_dir/claude/${file#.claude/}"
        elif [[ "$file" == ".serena/"* ]]; then
          staging_file="$staging_dir/serena/${file#.serena/}"
        elif [[ "$file" == ".taskmaster/"* ]]; then
          staging_file="$staging_dir/taskmaster/${file#.taskmaster/}"
        else
          staging_file="$staging_dir/$file"
        fi

        if [[ -f "$staging_file" && -f "$file" ]]; then
          echo ""
          echo -e "    ${BOLD}--- $file${NC}"
          diff -u "$file" "$staging_file" 2>/dev/null | head -30 | sed 's/^/    /' || true
        fi
      done
      echo ""
    fi
  fi

  # List deleted files
  if [[ ${#DELETED_FILES[@]} -gt 0 ]]; then
    echo -e "  ${RED}Deleted files:${NC}"
    for file in "${DELETED_FILES[@]}"; do
      echo -e "    ${RED}-${NC} $file"
    done
    echo ""
  fi

  # List excluded files
  if [[ ${#EXCLUDED_FILES[@]} -gt 0 ]]; then
    echo -e "  ${CYAN}Excluded files (via sync_exclusions):${NC}"
    for file in "${EXCLUDED_FILES[@]}"; do
      echo -e "    ${CYAN}○${NC} $file"
    done
    echo ""
  fi

  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  if $DRY_RUN; then
    echo -e "  ${YELLOW}Dry run mode - no changes applied${NC}"
    echo -e "  Run without --dry-run to apply these changes"
    echo ""
  fi
}

# Generate markdown summary for PR body
generate_markdown_summary() {
  local staging_dir="$1"
  local current_version
  current_version=$(get_manifest_value '.template_version')

  echo "## Template Sync Summary"
  echo ""
  echo "**From:** \`$current_version\`"
  echo "**To:** \`$RESOLVED_VERSION\`"
  echo ""
  echo "### Changes"
  echo ""
  echo "| Type | Count |"
  echo "|------|-------|"
  echo "| Added | ${#ADDED_FILES[@]} |"
  echo "| Modified | ${#MODIFIED_FILES[@]} |"
  echo "| Deleted | ${#DELETED_FILES[@]} |"
  echo "| Excluded | ${#EXCLUDED_FILES[@]} |"
  echo ""

  if [[ ${#ADDED_FILES[@]} -gt 0 ]]; then
    echo "### Added Files"
    echo ""
    for file in "${ADDED_FILES[@]}"; do
      echo "- \`$file\`"
    done
    echo ""
  fi

  if [[ ${#MODIFIED_FILES[@]} -gt 0 ]]; then
    echo "### Modified Files"
    echo ""
    for file in "${MODIFIED_FILES[@]}"; do
      echo "- \`$file\`"
    done
    echo ""
  fi

  if [[ ${#DELETED_FILES[@]} -gt 0 ]]; then
    echo "### Deleted Files"
    echo ""
    for file in "${DELETED_FILES[@]}"; do
      echo "- \`$file\`"
    done
    echo ""
  fi

  if [[ ${#EXCLUDED_FILES[@]} -gt 0 ]]; then
    echo "### Excluded Files"
    echo ""
    echo "_These files were skipped due to \`sync_exclusions\` patterns in the manifest:_"
    echo ""
    for file in "${EXCLUDED_FILES[@]}"; do
      echo "- \`$file\`"
    done
    echo ""
  fi
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
  # Register cleanup trap early for signal handling
  trap cleanup_on_exit EXIT INT TERM

  # Check dependencies first
  check_dependencies

  # Parse CLI arguments
  parse_arguments "$@"

  # Set default staging directory if not provided
  if [[ -z "$STAGING_DIR" ]]; then
    STAGING_DIR=$(mktemp -d "/tmp/template-sync.XXXXXX")
    # Track temp directory for cleanup
    TEMP_DIR="$STAGING_DIR"
    if [[ ! -d "$STAGING_DIR" ]]; then
      log_error "Failed to create temporary directory"
      exit 1
    fi
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
  RESOLVED_VERSION=$(resolve_version "$TARGET_VERSION" "$upstream_repo")
  log_info "Resolved version: $RESOLVED_VERSION"

  # Fetch upstream templates (sets FETCHED_TEMPLATES_PATH)
  fetch_upstream_templates "$RESOLVED_VERSION" "$upstream_repo" "$STAGING_DIR"

  # Display fetched templates info
  if ! $CI_MODE; then
    echo ""
    echo "  Templates path: $FETCHED_TEMPLATES_PATH"
    echo ""
  fi

  # Apply substitutions to fetched templates
  SUBSTITUTED_TEMPLATES_PATH="$STAGING_DIR/substituted"
  apply_substitutions "$FETCHED_TEMPLATES_PATH" "$SUBSTITUTED_TEMPLATES_PATH"

  # Copy sync infrastructure files (no substitution needed)
  copy_sync_files "$STAGING_DIR/upstream" "$SUBSTITUTED_TEMPLATES_PATH"

  # Display substituted templates info
  if ! $CI_MODE; then
    echo ""
    echo "  Substituted to: $SUBSTITUTED_TEMPLATES_PATH"
    echo ""
  fi

  # Compare files and generate report
  compare_files "$SUBSTITUTED_TEMPLATES_PATH"
  generate_diff_report "$SUBSTITUTED_TEMPLATES_PATH"

  # Summary
  local total_changes=$((${#ADDED_FILES[@]} + ${#MODIFIED_FILES[@]} + ${#DELETED_FILES[@]}))
  if [[ $total_changes -eq 0 ]]; then
    log_success "Templates are up to date - no changes needed"
  elif $DRY_RUN; then
    log_info "Dry run complete - $total_changes file(s) would be changed"
  else
    log_info "Sync complete - $total_changes file(s) identified for update"
    log_info "Review the changes above and apply manually or via PR"
  fi
}

# Run main with all arguments only if script is executed directly (not sourced)
# This allows tests to source the file and access functions without running main()
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
  main "$@"
fi
