#!/usr/bin/env bash
#
# Template Cleanup Script
# Converts the claude-starter-kit template into a project-specific setup.
# Based on .github/workflows/template-cleanup.yml
#
# Usage:
#   ./.github/scripts/template-cleanup.sh                    # Interactive mode (recommended)
#   ./.github/scripts/template-cleanup.sh [options]          # Non-interactive with CLI options
#   ./.github/scripts/template-cleanup.sh -y [options]       # Skip confirmation prompt
#
# Options:
#   --model <model>           Claude Code model (default: default)
#   --languages <langs>       Programming languages for Serena (comma-separated, required)
#   --serena-prompt <prompt>  Initial prompt for Serena semantic analysis
#   --tm-system-prompt <p>    Custom system prompt for Task Master
#   --tm-append-prompt <p>    Additional content to append to Task Master prompt
#   --tm-permission <mode>    Task Master permission mode (default: default)
#   --no-commit               Skip git commit and push
#   --ci                      CI mode: read from env vars, skip interactive prompts
#   -y, --yes                 Skip confirmation prompt (for scripted use)
#   -h, --help                Show this help message

set -euo pipefail

# Default values
# Note: LANGUAGES is intentionally not initialized here to allow env var passthrough
# The actual default is handled in load_env_vars()
CC_MODEL="default"
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE="default"
NO_COMMIT=false
SKIP_CONFIRM=false
INTERACTIVE_MODE=false
HAS_CLI_ARGS=false
CI_MODE=false

# Load configuration from environment variables
# Called before CLI parsing so CLI args can override
load_env_vars() {
  CC_MODEL="${CC_MODEL:-default}"
  LANGUAGES="${LANGUAGES:-}"
  SERENA_INITIAL_PROMPT="${SERENA_INITIAL_PROMPT:-}"
  TM_CUSTOM_SYSTEM_PROMPT="${TM_CUSTOM_SYSTEM_PROMPT:-}"
  TM_APPEND_SYSTEM_PROMPT="${TM_APPEND_SYSTEM_PROMPT:-}"
  TM_PERMISSION_MODE="${TM_PERMISSION_MODE:-default}"
}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  echo -e "${CYAN}>>>${NC} $1"
}

# Convert comma-separated languages to YAML array format
format_languages_yaml() {
  local input="$1"
  local indent="${2:-  }" # default 2-space indent
  echo "languages:"
  IFS=',' read -ra langs <<<"$input"
  for lang in "${langs[@]}"; do
    lang=$(echo "$lang" | xargs) # trim whitespace
    echo "${indent}- $lang"
  done
}

# Check for required dependencies
if ! command -v jq &>/dev/null; then
  log_error "jq is required but not installed."
  echo "Please install jq:"
  echo "  macOS:  brew install jq"
  echo "  Linux:  apt-get install jq"
  exit 1
fi

show_help() {
  cat <<'EOF'
Template Cleanup Script
Converts the claude-starter-kit template into a project-specific setup.

Usage:
  ./.github/scripts/template-cleanup.sh                    # Interactive mode (recommended)
  ./.github/scripts/template-cleanup.sh [options]          # Non-interactive with CLI options
  ./.github/scripts/template-cleanup.sh -y [options]       # Skip confirmation prompt

Options:
  --model <model>           Claude Code model alias (default: default)
                            Options: default, sonnet, sonnet[1m], opus, opus[1m], opusplan, haiku
                            (See https://code.claude.com/docs/en/model-config#model-aliases for more details.)
  --languages <langs>       Programming languages for Serena semantic analysis (required)
                            Comma-separated list, e.g.: python,typescript or just: python
                            Primary: python, typescript, java, go, rust, csharp, cpp, ruby
                            Additional: bash, elixir, kotlin, scala, haskell, lua, php, swift, zig...
                            Note: For C use 'cpp', for JavaScript use 'typescript'
                            Docs: https://oraios.github.io/serena/01-about/020_programming-languages.html
  --serena-prompt <prompt>  Initial prompt/context for Serena semantic analysis
  --tm-system-prompt <p>    Custom system prompt to override Claude Code default behavior
  --tm-append-prompt <p>    Additional content to append to Claude Code system prompt
  --tm-permission <mode>    Task Master permission mode (default: default)
                            Options: default, acceptEdits, plan, bypassPermissions
  --no-commit               Skip git commit and push
  --ci                      CI mode: read config from environment variables,
                            skip interactive prompts and repo name check
  -y, --yes                 Skip confirmation prompt (for scripted use)
  -h, --help                Show this help message

Examples:
  # Interactive setup (recommended for first-time users)
  ./.github/scripts/template-cleanup.sh

  # Basic setup with TypeScript
  ./.github/scripts/template-cleanup.sh --languages typescript -y

  # Setup with multiple languages
  ./.github/scripts/template-cleanup.sh --languages python,typescript,bash -y

  # Full setup with custom prompts
  ./.github/scripts/template-cleanup.sh --model sonnet --languages python --tm-permission acceptEdits -y
EOF
}

# Prompt for input with default value
prompt_input() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local result

  if [[ -n "$default" ]]; then
    echo -ne "${BLUE}?${NC} ${prompt} ${CYAN}[$default]${NC}: "
  else
    echo -ne "${BLUE}?${NC} ${prompt}: "
  fi
  read -r result

  if [[ -z "$result" ]]; then
    result="$default"
  fi

  eval "$var_name=\"$result\""
}

# Prompt for selection from options
prompt_select() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  shift 3
  local options=("$@")
  local result

  echo -e "${BLUE}?${NC} ${prompt}"
  local i=1
  for opt in "${options[@]}"; do
    if [[ "$opt" == "$default" ]]; then
      echo -e "  ${CYAN}$i)${NC} $opt ${GREEN}(default)${NC}"
    else
      echo -e "  ${CYAN}$i)${NC} $opt"
    fi
    ((i++))
  done
  echo -ne "  Enter choice [1-${#options[@]}] or value: "
  read -r result

  if [[ -z "$result" ]]; then
    result="$default"
  elif [[ "$result" =~ ^[0-9]+$ ]] && ((result >= 1 && result <= ${#options[@]})); then
    result="${options[$((result - 1))]}"
  fi

  eval "$var_name=\"$result\""
}

# Prompt for yes/no
prompt_confirm() {
  local prompt="$1"
  local default="${2:-y}"
  local result

  if [[ "$default" == "y" ]]; then
    echo -ne "${BLUE}?${NC} ${prompt} ${CYAN}[Y/n]${NC}: "
  else
    echo -ne "${BLUE}?${NC} ${prompt} ${CYAN}[y/N]${NC}: "
  fi
  read -r result

  if [[ -z "$result" ]]; then
    result="$default"
  fi

  [[ "${result,,}" == "y" || "${result,,}" == "yes" ]]
}

# Interactive configuration
run_interactive() {
  echo ""
  echo -e "${BOLD}Claude Starter Kit - Template Cleanup${NC}"
  echo -e "This will configure your project from the template."
  echo ""

  # Model selection
  prompt_select "Select Claude Code model" "default" CC_MODEL \
    "default" "sonnet" "sonnet[1m]" "opus" "opus[1m]" "opusplan" "haiku"

  echo ""

  # Language selection
  # Sources:
  #   https://oraios.github.io/serena/01-about/020_programming-languages.html
  #   https://github.com/oraios/serena/blob/main/.serena/project.yml
  echo -e "${YELLOW}Serena Language Support:${NC}"
  echo -e "  Primary languages: python, typescript, java, go, rust, csharp, cpp, ruby"
  echo -e "  40+ additional: bash, elixir, kotlin, scala, haskell, lua, php, swift, zig..."
  echo -e "  ${CYAN}Notes:${NC}"
  echo -e "    - For C, use 'cpp'. For JavaScript, use 'typescript'"
  echo -e "    - csharp requires a .sln file in the project"
  echo -e "    - Multiple languages supported (comma-separated)"
  echo -e "  ${CYAN}Docs:${NC} https://oraios.github.io/serena/01-about/020_programming-languages.html"
  echo ""
  prompt_select "Select primary language for Serena (required)" "" LANGUAGES \
    "python" "typescript" "java" "go" "rust" "csharp" "cpp" "ruby"

  # Allow custom/additional languages
  if [[ -z "$LANGUAGES" ]]; then
    prompt_input "Enter language(s) - comma-separated (required)" "" LANGUAGES
  else
    local additional_langs
    prompt_input "Add more languages? (comma-separated, or leave empty)" "" additional_langs
    if [[ -n "$additional_langs" ]]; then
      LANGUAGES="${LANGUAGES},${additional_langs}"
    fi
  fi

  # Validate LANGUAGES is not empty
  if [[ -z "$LANGUAGES" ]]; then
    log_error "At least one language is required for Serena"
    exit 1
  fi

  echo ""

  # Advanced options
  if prompt_confirm "Configure advanced options?" "n"; then
    echo ""
    prompt_input "Serena initial prompt/context" "" SERENA_INITIAL_PROMPT
    prompt_input "Task Master custom system prompt" "" TM_CUSTOM_SYSTEM_PROMPT
    prompt_input "Task Master append system prompt" "" TM_APPEND_SYSTEM_PROMPT
    prompt_select "Task Master permission mode" "default" TM_PERMISSION_MODE \
      "default" "acceptEdits" "plan" "bypassPermissions"
  fi

  echo ""

  # Commit option
  if ! prompt_confirm "Commit and push changes after cleanup?" "y"; then
    NO_COMMIT=true
  fi

  echo ""
}

# Show configuration summary
show_config_summary() {
  local name="$1"

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}                    Configuration Summary                       ${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${CYAN}Project:${NC}"
  echo "  Name:        $name"
  echo ""
  echo -e "${CYAN}Configuration:${NC}"
  echo "  Claude Model:       $CC_MODEL"
  echo "  Languages:          $LANGUAGES"
  echo "  TM Permission Mode: $TM_PERMISSION_MODE"
  if [[ -n "$SERENA_INITIAL_PROMPT" ]]; then
    echo "  Serena Prompt:      $SERENA_INITIAL_PROMPT"
  fi
  if [[ -n "$TM_CUSTOM_SYSTEM_PROMPT" ]]; then
    echo "  TM System Prompt:   $TM_CUSTOM_SYSTEM_PROMPT"
  fi
  if [[ -n "$TM_APPEND_SYSTEM_PROMPT" ]]; then
    echo "  TM Append Prompt:   $TM_APPEND_SYSTEM_PROMPT"
  fi
  echo ""
  echo -e "${CYAN}Options:${NC}"
  echo "  Commit changes:     $(if $NO_COMMIT; then echo "No"; else echo "Yes"; fi)"
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}Actions that will be performed:${NC}"
  echo "  1. Substitute template values with project-specific configuration"
  echo "  2. Remove existing .claude/, .serena/, .taskmaster/ directories"
  echo "  3. Deploy configured templates to project root"
  echo "  4. Remove all template-specific files (README, docs, workflows, etc.)"
  echo "  5. Generate template state manifest (.github/template-state.json)"
  echo "  6. Generate minimal README.md"
  if ! $NO_COMMIT; then
    echo "  7. Commit and push changes"
  fi
  echo ""
}

# Generate state manifest for template sync
generate_manifest() {
  local project_name="$1"
  local upstream_repo="${UPSTREAM_REPO:-serpro69/claude-starter-kit}"
  local template_version
  local repo_url="https://github.com/$upstream_repo.git"

  # Fetch template version from upstream repository (not the current downstream repo)
  # Try to get the latest tag first, fall back to HEAD SHA
  # Note: Use 'grep ... || true' to handle case when no tags exist (grep returns 1 for no matches)
  # GIT_TERMINAL_PROMPT=0 prevents git from prompting for credentials on invalid repos
  # Use '|| true' to prevent set -e from exiting on git errors (e.g., network issues, invalid repo)
  template_version=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags --sort=-v:refname "$repo_url" 2>/dev/null |
    { grep -v '\^{}' || true; } |
    head -1 |
    sed 's/.*refs\/tags\///' || true)

  if [[ -z "$template_version" ]]; then
    # No tags exist, use HEAD SHA from upstream
    template_version=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1 || true)
    if [[ -z "$template_version" ]]; then
      log_warn "Could not fetch upstream version, using 'initial'"
      template_version="initial"
    fi
  fi

  # Ensure .github directory exists
  mkdir -p .github

  # Generate manifest using jq for safe JSON escaping
  jq -n \
    --arg schema_version "1" \
    --arg upstream_repo "$upstream_repo" \
    --arg template_version "$template_version" \
    --arg synced_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg PROJECT_NAME "$project_name" \
    --arg LANGUAGES "$LANGUAGES" \
    --arg CC_MODEL "$CC_MODEL" \
    --arg SERENA_INITIAL_PROMPT "$SERENA_INITIAL_PROMPT" \
    --arg TM_CUSTOM_SYSTEM_PROMPT "$TM_CUSTOM_SYSTEM_PROMPT" \
    --arg TM_APPEND_SYSTEM_PROMPT "$TM_APPEND_SYSTEM_PROMPT" \
    --arg TM_PERMISSION_MODE "$TM_PERMISSION_MODE" \
    '{
      schema_version: $schema_version,
      upstream_repo: $upstream_repo,
      template_version: $template_version,
      synced_at: $synced_at,
      variables: {
        PROJECT_NAME: $PROJECT_NAME,
        LANGUAGES: $LANGUAGES,
        CC_MODEL: $CC_MODEL,
        SERENA_INITIAL_PROMPT: $SERENA_INITIAL_PROMPT,
        TM_CUSTOM_SYSTEM_PROMPT: $TM_CUSTOM_SYSTEM_PROMPT,
        TM_APPEND_SYSTEM_PROMPT: $TM_APPEND_SYSTEM_PROMPT,
        TM_PERMISSION_MODE: $TM_PERMISSION_MODE
      }
    }' >.github/template-state.json

  log_info "Generated state manifest: .github/template-state.json"
}

# Execute the cleanup
execute_cleanup() {
  local name="$1"

  log_step "Substituting template values..."
  # Note: Templates now use actual working values instead of placeholders

  # Claude Code Settings
  local cc_settings_file=".github/templates/claude/settings.json"
  # Claude Code model - remove line for "default" (uses Claude Code's default), otherwise substitute
  if [[ "$CC_MODEL" == "default" ]]; then
    # Remove the model line entirely so Claude Code uses its built-in default
    sed -i '/"model":/d' "$cc_settings_file"
  else
    sed -i "s/\"model\": \".*\"/\"model\": \"$CC_MODEL\"/g" "$cc_settings_file"
  fi

  # Serena MCP Settings
  local serena_settings_file=".github/templates/serena/project.yml"
  # Project name - always substitute with repo name
  sed -i "s/project_name: \".*\"/project_name: \"$name\"/g" "$serena_settings_file"
  # Languages - use awk to replace the entire languages block (multi-line YAML array)
  local languages_yaml
  languages_yaml=$(format_languages_yaml "$LANGUAGES")
  awk -v new="$languages_yaml" '
    /^languages:/ { print new; skip=1; next }
    skip && /^[[:space:]]*-/ { next }
    skip && /^[^[:space:]]/ { skip=0 }
    !skip { print }
  ' "$serena_settings_file" >"$serena_settings_file.tmp" && mv "$serena_settings_file.tmp" "$serena_settings_file"
  # Serena initial prompt - only substitute if provided
  if [ -n "$SERENA_INITIAL_PROMPT" ]; then
    sed -i "s/initial_prompt: \"\"/initial_prompt: \"$SERENA_INITIAL_PROMPT\"/g" "$serena_settings_file"
  fi

  # TaskMaster MCP Settings
  local tm_settings_file=".github/templates/taskmaster/config.json"
  # Project name - always substitute with repo name
  sed -i "s/\"projectName\": \".*\"/\"projectName\": \"$name\"/g" "$tm_settings_file"
  # Task Master prompts - only substitute if provided
  if [ -n "$TM_CUSTOM_SYSTEM_PROMPT" ]; then
    sed -i "s/\"customSystemPrompt\": \"\"/\"customSystemPrompt\": \"$TM_CUSTOM_SYSTEM_PROMPT\"/g" "$tm_settings_file"
  fi
  if [ -n "$TM_APPEND_SYSTEM_PROMPT" ]; then
    sed -i "s/\"appendSystemPrompt\": \"\"/\"appendSystemPrompt\": \"$TM_APPEND_SYSTEM_PROMPT\"/g" "$tm_settings_file"
  fi
  if [ -n "$TM_PERMISSION_MODE" ]; then
    sed -i "s/\"permissionMode\": \"\"/\"permissionMode\": \"$TM_PERMISSION_MODE\"/g" "$tm_settings_file"
  fi

  log_step "Removing existing configuration directories..."
  rm -rf .claude .serena .taskmaster

  log_step "Deploying templates to destination locations..."
  cp -r .github/templates/claude ./.claude
  cp -r .github/templates/serena ./.serena
  cp -r .github/templates/taskmaster ./.taskmaster
  if [[ -f .github/scripts/bootstrap.sh ]]; then
    cp .github/scripts/bootstrap.sh .
  fi

  log_step "Cleaning up .github/ (preserving sync infrastructure)..."
  rm -rf .github/templates
  rm -f .github/scripts/template-cleanup.sh
  rm -f .github/workflows/template-cleanup.yml

  log_step "Cleaning up template-specific files..."
  find . -mindepth 1 -maxdepth 1 \
    ! -name '.git' \
    ! -name '.gitignore' \
    ! -name '.github' \
    ! -name '.claude' \
    ! -name '.serena' \
    ! -name '.taskmaster' \
    ! -name 'bootstrap.sh' \
    -exec rm -rf {} +

  log_step "Generating template state manifest..."
  generate_manifest "$name"

  log_step "Generating minimal README..."
  echo "# $name" >README.md

  if $NO_COMMIT; then
    log_info "Skipping git commit (--no-commit specified)"
  else
    log_step "Committing changes..."
    git add .
    git commit -m "Template cleanup"

    log_step "Pushing changes..."
    local branch
    branch=$(git branch --show-current)
    git push origin "$branch"
  fi

  echo ""
  log_info "Template cleanup complete!"
  echo ""
  echo -e "${GREEN}Next steps:${NC}"
  echo "  1. Run 'claude' to start Claude Code"
  echo "  2. Run '/mcp' to verify MCP servers are connected"
  echo "  3. Run '/init' to initialize project-specific CLAUDE.md"
  echo ""
}

# Load environment variables as defaults (CLI args override)
load_env_vars

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  HAS_CLI_ARGS=true
  case $1 in
  --model)
    CC_MODEL="$2"
    shift 2
    ;;
  --languages)
    LANGUAGES="$2"
    shift 2
    ;;
  --serena-prompt)
    SERENA_INITIAL_PROMPT="$2"
    shift 2
    ;;
  --tm-system-prompt)
    TM_CUSTOM_SYSTEM_PROMPT="$2"
    shift 2
    ;;
  --tm-append-prompt)
    TM_APPEND_SYSTEM_PROMPT="$2"
    shift 2
    ;;
  --tm-permission)
    TM_PERMISSION_MODE="$2"
    shift 2
    ;;
  --no-commit)
    NO_COMMIT=true
    shift
    ;;
  -y | --yes)
    SKIP_CONFIRM=true
    shift
    ;;
  --ci)
    CI_MODE=true
    SKIP_CONFIRM=true
    shift
    ;;
  -h | --help)
    show_help
    exit 0
    ;;
  *)
    log_error "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# =============================================================================
# Main Execution (only when script is run directly, not sourced)
# =============================================================================

# Allow sourcing this file to access functions without running main logic
# This enables tests to source the file and call functions directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # If no CLI arguments provided and not in CI mode, run in interactive mode
  if ! $HAS_CLI_ARGS && ! $CI_MODE; then
    INTERACTIVE_MODE=true
  fi

  # Validate we're in a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not inside a git repository"
    exit 1
  fi

  # Get repository root
  REPO_ROOT=$(git rev-parse --show-toplevel)
  cd "$REPO_ROOT"

  # Check if templates directory exists
  if [[ ! -d ".github/templates" ]]; then
    log_error "Templates directory .github/templates not found"
    log_error "Are you sure this is a claude-starter-kit based repository?"
    exit 1
  fi

  # Prevent running on the original template repository (skip in CI mode)
  REPO_NAME=$(basename "$REPO_ROOT")
  if [[ "$REPO_NAME" == "claude-starter-kit" ]] && ! $CI_MODE; then
    log_error "This script should not be run on the original claude-starter-kit repository"
    exit 1
  fi

  # Set locale for consistent string handling
  export LC_CTYPE=C
  export LANG=C

  # Prepare repository-specific variables
  NAME="$REPO_NAME"

  # Run interactive mode if no CLI args
  if $INTERACTIVE_MODE; then
    run_interactive
  fi

  # Validate required parameters
  if [[ -z "$LANGUAGES" ]]; then
    log_error "LANGUAGES is required. Provide at least one language (e.g., --languages python)"
    exit 1
  fi

  # Show configuration summary
  show_config_summary "$NAME"

  # Confirm before proceeding
  if ! $SKIP_CONFIRM; then
    if ! prompt_confirm "Proceed with template cleanup?" "y"; then
      log_warn "Aborted by user"
      exit 0
    fi
    echo ""
  fi

  # Execute the cleanup
  execute_cleanup "$NAME"
fi
