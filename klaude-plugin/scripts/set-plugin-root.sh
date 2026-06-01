#!/bin/bash

# SessionStart hook — exports TOOLBOX_PLUGIN_ROOT for the session.
#
# Uses cpr.py (reads installed_plugins.json) as the primary resolver.
# The harness-substituted ${CLAUDE_PLUGIN_ROOT} ($1) is unreliable —
# it resolves to marketplaces/ instead of the versioned cache/ path.
# See anthropics/claude-code#64461

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT=$(python3 "$SCRIPT_DIR/cpr.py" kk 2>/dev/null)

if [ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ]; then
  PLUGIN_ROOT="${1:-}"
fi

if [ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ]; then
  exit 0
fi

echo "export TOOLBOX_PLUGIN_ROOT=\"$PLUGIN_ROOT\"" >> "$CLAUDE_ENV_FILE"
