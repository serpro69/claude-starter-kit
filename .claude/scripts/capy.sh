#!/usr/bin/env bash

set -euo pipefail

for p in $(which capy 2>/dev/null) $HOME/.local/bin/capy /opt/homebrew/bin/capy /usr/local/bin/capy capy; do
  [ -x "$p" ] && exec "$p" "$@"
done

echo 'capy not found' >&2
exit 1
