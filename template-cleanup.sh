#!/usr/bin/env bash
#
# Template Cleanup Script
# Converts the claude-starter-kit template into a project-specific setup.
# Based on .github/workflows/template-cleanup.yml
#
# Usage: ./template-cleanup.sh [options]
#
# Options:
#   --model <model>           Claude Code model (default: default)
#   --language <lang>         Primary programming language for Serena
#   --serena-prompt <prompt>  Initial prompt for Serena semantic analysis
#   --tm-system-prompt <p>    Custom system prompt for Task Master
#   --tm-append-prompt <p>    Additional content to append to Task Master prompt
#   --tm-permission <mode>    Task Master permission mode (default: default)
#   --no-commit               Skip git commit and push
#   --dry-run                 Show what would be done without making changes
#   -h, --help                Show this help message

set -euo pipefail

# Default values
CC_MODEL="default"
LANGUAGE=""
SERENA_INITIAL_PROMPT=""
TM_CUSTOM_SYSTEM_PROMPT=""
TM_APPEND_SYSTEM_PROMPT=""
TM_PERMISSION_MODE="default"
NO_COMMIT=false
DRY_RUN=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

show_help() {
    cat << 'EOF'
Template Cleanup Script
Converts the claude-starter-kit template into a project-specific setup.

Usage: ./template-cleanup.sh [options]

Options:
  --model <model>           Claude Code model alias (default: default)
                            Options: default, sonnet, sonnet[1m], opus, opusplan, haiku, claude-opus-4-5
  --language <lang>         Primary programming language for Serena semantic analysis
                            (e.g., "python", "typescript", "java")
  --serena-prompt <prompt>  Initial prompt/context for Serena semantic analysis
  --tm-system-prompt <p>    Custom system prompt to override Claude Code default behavior
  --tm-append-prompt <p>    Additional content to append to Claude Code system prompt
  --tm-permission <mode>    Task Master permission mode (default: default)
                            Options: default, acceptEdits, plan, bypassPermissions
  --no-commit               Skip git commit and push
  --dry-run                 Show what would be done without making changes
  -h, --help                Show this help message

Examples:
  # Basic setup with TypeScript
  ./template-cleanup.sh --language typescript

  # Full setup with custom prompts
  ./template-cleanup.sh --model sonnet --language python --tm-permission acceptEdits

  # Preview changes without applying
  ./template-cleanup.sh --language rust --dry-run
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
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

# Prevent running on the original template repository
REPO_NAME=$(basename "$REPO_ROOT")
if [[ "$REPO_NAME" == "claude-starter-kit" ]]; then
    log_error "This script should not be run on the original claude-starter-kit repository"
    exit 1
fi

# Set locale for consistent string handling
export LC_CTYPE=C
export LANG=C

# Prepare repository-specific variables
NAME="$REPO_NAME"
# Try to get actor from git config, fall back to username
ACTOR=$(git config user.name 2>/dev/null || whoami)
ACTOR=$(echo "$ACTOR" | tr '[:upper:]' '[:lower:]')

# Try to get repository path from remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$REMOTE_URL" ]]; then
    # Extract owner/repo from various URL formats
    REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')
else
    REPOSITORY="$ACTOR/$NAME"
fi

SAFE_NAME=$(echo "$NAME" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
SAFE_ACTOR=$(echo "$ACTOR" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
GROUP="com.github.$SAFE_ACTOR.$SAFE_NAME"

log_info "Configuration:"
echo "  Repository Name: $NAME"
echo "  Actor: $ACTOR"
echo "  Repository: $REPOSITORY"
echo "  Safe Name: $SAFE_NAME"
echo "  Safe Actor: $SAFE_ACTOR"
echo "  Group: $GROUP"
echo "  Claude Model: $CC_MODEL"
echo "  Language: ${LANGUAGE:-<not set>}"
echo "  TM Permission Mode: $TM_PERMISSION_MODE"
echo ""

if $DRY_RUN; then
    log_warn "DRY RUN - No changes will be made"
    echo ""
fi

# Function to execute or simulate commands
run_cmd() {
    if $DRY_RUN; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

log_info "Replacing placeholders in template files..."
if ! $DRY_RUN; then
    # Escape special characters for sed replacement
    REPOSITORY_ESCAPED=$(echo "$REPOSITORY" | sed 's/\//\\\//g')

    find .github/templates -type f -exec sed -i "s/%ACTOR%/$ACTOR/g" {} +
    find .github/templates -type f -exec sed -i "s/%NAME%/$NAME/g" {} +
    find .github/templates -type f -exec sed -i "s/%REPOSITORY%/$REPOSITORY_ESCAPED/g" {} +
    find .github/templates -type f -exec sed -i "s/%GROUP%/$GROUP/g" {} +
    find .github/templates -type f -exec sed -i "s/%SAFE_NAME%/$SAFE_NAME/g" {} +
    find .github/templates -type f -exec sed -i "s/%SAFE_ACTOR%/$SAFE_ACTOR/g" {} +
    find .github/templates -type f -exec sed -i "s/%CC_MODEL%/$CC_MODEL/g" {} +
    find .github/templates -type f -exec sed -i "s/%LANGUAGE%/$LANGUAGE/g" {} +
    find .github/templates -type f -exec sed -i "s/%SERENA_INITIAL_PROMPT%/$SERENA_INITIAL_PROMPT/g" {} +
    find .github/templates -type f -exec sed -i "s/%TM_CUSTOM_SYSTEM_PROMPT%/$TM_CUSTOM_SYSTEM_PROMPT/g" {} +
    find .github/templates -type f -exec sed -i "s/%TM_APPEND_SYSTEM_PROMPT%/$TM_APPEND_SYSTEM_PROMPT/g" {} +
    find .github/templates -type f -exec sed -i "s/%TM_PERMISSION_MODE%/$TM_PERMISSION_MODE/g" {} +
else
    echo "  [DRY-RUN] Would replace placeholders: %ACTOR%, %NAME%, %REPOSITORY%, etc."
fi

log_info "Removing existing configuration directories..."
run_cmd rm -rf .claude .serena .taskmaster

log_info "Deploying templates to destination locations..."
run_cmd cp -r .github/templates/claude ./.claude
run_cmd cp -r .github/templates/serena ./.serena
run_cmd cp -r .github/templates/taskmaster ./.taskmaster
if [[ -f .github/templates/bootstrap.sh ]]; then
    run_cmd cp .github/templates/bootstrap.sh .
fi

log_info "Cleaning up template-specific files..."
if ! $DRY_RUN; then
    # Complete cleanup - remove everything except preserved files/directories
    find . -mindepth 1 -maxdepth 1 \
        ! -name '.git' \
        ! -name '.gitignore' \
        ! -name '.claude' \
        ! -name '.serena' \
        ! -name '.taskmaster' \
        ! -name 'bootstrap.sh' \
        -exec rm -rf {} +
else
    echo "  [DRY-RUN] Would remove all files except: .git, .gitignore, .claude, .serena, .taskmaster, bootstrap.sh"
fi

log_info "Generating minimal README..."
if ! $DRY_RUN; then
    echo "# $NAME" > README.md
else
    echo "  [DRY-RUN] Would create README.md with: # $NAME"
fi

if $NO_COMMIT; then
    log_info "Skipping git commit (--no-commit specified)"
elif $DRY_RUN; then
    log_info "[DRY-RUN] Would commit and push changes"
else
    log_info "Committing changes..."
    git add .
    git commit -m "Template cleanup"

    log_info "Pushing changes..."
    BRANCH=$(git branch --show-current)
    git push origin "$BRANCH"
fi

log_info "Template cleanup complete!"
if $DRY_RUN; then
    echo ""
    log_warn "This was a dry run. Run without --dry-run to apply changes."
fi
