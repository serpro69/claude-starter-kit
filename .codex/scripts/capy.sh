#!/usr/bin/env bash

# Wrapper that locates and runs the capy binary.
# Used as a Codex MCP server launcher — must always exit 0 to avoid phantom errors.

# NOTE: copied manually from .claude/scripts until capy adds support for codes
# after that 'capy setup' should handle the same
# TODO: !!! UPDATE THE TEMPLATE-SYNC.SH SCRIPT TO EXLUDE THIS FILE FROM SYNC ONCE CAPY HAS SUPPORT FOR CODEX AND GENERATES THIS FILE VIA 'CAPY SETUP'

set -uo pipefail

for p in "$(command -v capy 2>/dev/null || true)" "$HOME/.local/bin/capy" "/opt/homebrew/bin/capy" "/usr/local/bin/capy" "$HOME/go/bin/capy" "capy"; do
  if [ -n "$p" ] && [ -x "$p" ]; then
    "$p" "$@" || true
    exit 0
  fi
done

echo "capy binary not found" >&2
exit 1
