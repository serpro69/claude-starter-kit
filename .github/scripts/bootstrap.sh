#!/usr/bin/env bash

set -e

cleanup() {
  rm -f "$0"
  git add "$0" || true
  git add CLAUDE.md
  git commit -m "Initialize claude-code"
}

trap cleanup EXIT

# Append @import reference for extra instructions (synced from upstream template)
if ! grep -q '@.claude/CLAUDE.extra.md' CLAUDE.md 2>/dev/null; then
  printf '\n# Extra Instructions\n' >>CLAUDE.md
  printf '@.claude/CLAUDE.extra.md\n' >>CLAUDE.md
fi

# Install the kk plugin from the claude-toolbox marketplace
claude plugin install kk@claude-toolbox

printf "\n"
printf "Done initializing claude-code; committing CLAUDE.md file to git and cleaning up bootstrap script...\n"
printf "Your repo is now ready for AI-driven development workflows... Have fun!\n"
