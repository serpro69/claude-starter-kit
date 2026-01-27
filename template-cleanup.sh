#!/usr/bin/env bash
#
# Template Cleanup Script
# Converts the claude-starter-kit template into a project-specific setup.
# Based on .github/workflows/template-cleanup.yml
#
# Usage:
#   ./template-cleanup.sh                    # Interactive mode (recommended)
#   ./template-cleanup.sh [options]          # Non-interactive with CLI options
#   ./template-cleanup.sh -y [options]       # Skip confirmation prompt
#
# Options:
#   --model <model>           Claude Code model (default: default)
#   --language <lang>         Primary programming language for Serena
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
LANGUAGE=""
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
  LANGUAGE="${LANGUAGE:-}"
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

show_help() {
  cat <<'EOF'
Template Cleanup Script
Converts the claude-starter-kit template into a project-specific setup.

Usage:
  ./template-cleanup.sh                    # Interactive mode (recommended)
  ./template-cleanup.sh [options]          # Non-interactive with CLI options
  ./template-cleanup.sh -y [options]       # Skip confirmation prompt

Options:
  --model <model>           Claude Code model alias (default: default)
                            Options: default, sonnet, sonnet[1m], opus, opusplan, haiku, claude-opus-4-5
  --language <lang>         Primary programming language for Serena semantic analysis
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
  ./template-cleanup.sh

  # Basic setup with TypeScript
  ./template-cleanup.sh --language typescript -y

  # Full setup with custom prompts
  ./template-cleanup.sh --model sonnet --language python --tm-permission acceptEdits -y
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
    "default" "sonnet" "sonnet[1m]" "opus" "opusplan" "haiku" "claude-opus-4-5"

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
  echo -e "    - Multi-language support is on the Serena roadmap"
  echo -e "  ${CYAN}Docs:${NC} https://oraios.github.io/serena/01-about/020_programming-languages.html"
  echo ""
  prompt_select "Select primary language for Serena" "" LANGUAGE \
    "python" "typescript" "java" "go" "rust" "csharp" "cpp" "ruby"

  # Allow custom language if user selected nothing or wants something else
  if [[ -z "$LANGUAGE" ]]; then
    prompt_input "Enter language identifier (or leave empty to skip)" "" LANGUAGE
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
  echo "  Language:           ${LANGUAGE:-<not set>}"
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
  echo "  5. Generate minimal README.md"
  if ! $NO_COMMIT; then
    echo "  6. Commit and push changes"
  fi
  echo ""
}

# Execute the cleanup
execute_cleanup() {
  local name="$1"

  log_step "Substituting template values..."
  # Note: Templates now use actual working values instead of placeholders

  # Claude Code Settings
  local cc_settings_file=".github/templates/claude/settings.json"
  # Claude Code model - always substitute (user selects from dropdown)
  sed -i "s/\"model\": \".*\"/\"model\": \"$CC_MODEL\"/g" "$cc_settings_file"

  # Serena MCP Settings
  local serena_settings_file=".github/templates/serena/project.yml"
  # Project name - always substitute with repo name
  sed -i "s/project_name: \".*\"/project_name: \"$name\"/g" "$serena_settings_file"
  # Language - only substitute if provided
  if [ -n "$LANGUAGE" ]; then
    sed -i "s/language: \".*\"/language: \"$LANGUAGE\"/g" "$serena_settings_file"
  fi
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
  if [[ -f .github/templates/bootstrap.sh ]]; then
    cp .github/templates/bootstrap.sh .
  fi

  log_step "Cleaning up template-specific files..."
  find . -mindepth 1 -maxdepth 1 \
    ! -name '.git' \
    ! -name '.gitignore' \
    ! -name '.claude' \
    ! -name '.serena' \
    ! -name '.taskmaster' \
    ! -name 'bootstrap.sh' \
    -exec rm -rf {} +

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
  --language)
    LANGUAGE="$2"
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
