#!/usr/bin/env bash

set -e

cleanup() {
  rm -f "$0"
  git add "$0" CLAUDE.md
  git commit -m "Initialize claude-code"
}

trap cleanup EXIT

claude -p --permission-mode "acceptEdits" /init

cat <<EOF >>CLAUDE.md

## Task Master AI Instructions

**IMPORTANT!!! Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**

@./.taskmaster/CLAUDE.md
EOF

printf "\n"
printf "🤖 Done initializing claude-code; committing CLAUDE.md file to git and cleaning up bootstrap script...\n"
printf "🚀 Your repo is now ready for AI-driven development workflows... Have fun!\n"
