#!/bin/bash

# SessionStart hook — exports TOOLBOX_PLUGIN_ROOT for the session.
#
# The hook command passes the harness-resolved ${CLAUDE_PLUGIN_ROOT} as $1.
# Falls back to cpr.py if not provided (e.g. manual invocation).

PLUGIN_ROOT="${1:-}"

if [ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PLUGIN_ROOT=$(python3 "$SCRIPT_DIR/../../.claude/toolbox/scripts/cpr.py" kk 2>/dev/null)
fi

if [ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ]; then
  exit 0
fi

echo "export TOOLBOX_PLUGIN_ROOT=\"$PLUGIN_ROOT\"" >> "$CLAUDE_ENV_FILE"
