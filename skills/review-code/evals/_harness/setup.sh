#!/usr/bin/env bash
# Stage each review-code eval's test-files/ as a real staged git diff in a
# temporary worktree, so reviewer sub-agents discover scope via `git diff`
# instead of accepting enumerated paths.
#
# Usage:
#   ./setup.sh                # creates a fresh temp stage dir, prints its path
#   ./setup.sh <stage-dir>    # uses the given dir (created if missing, reused if empty)
#
# Output: the absolute path of the stage dir on stdout. Pass that path to
# teardown.sh when the harness run is complete.

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(dirname "$HARNESS_DIR")"

if [[ $# -ge 1 ]]; then
  STAGE_DIR="$1"
  mkdir -p "$STAGE_DIR"
  STAGE_DIR="$(cd "$STAGE_DIR" && pwd)"
else
  STAGE_DIR="$(mktemp -d -t review-code-evals.XXXXXX)"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "setup.sh: git is required" >&2
  exit 1
fi

stage_count=0
for eval_dir in "$EVALS_DIR"/*/; do
  name="$(basename "$eval_dir")"

  # Skip harness dir and any dir without an eval.json / test-files pair
  [[ "$name" == "_harness" ]] && continue
  [[ -f "$eval_dir/eval.json" ]] || continue
  [[ -d "$eval_dir/test-files" ]] || continue

  worktree="$STAGE_DIR/$name"
  rm -rf "$worktree"
  mkdir -p "$worktree"

  (
    cd "$worktree"
    git init -q -b main
    git config user.email "eval-harness@local"
    git config user.name "Eval Harness"
    git commit --allow-empty -q -m "empty base"
  )

  # Copy fixture preserving subdir structure (patches/, templates/, docs/templates/, ...)
  (cd "$eval_dir/test-files" && tar cf - .) | (cd "$worktree" && tar xf -)

  (
    cd "$worktree"
    git add -A
  )

  stage_count=$((stage_count + 1))
done

if [[ $stage_count -eq 0 ]]; then
  echo "setup.sh: no evals staged under $EVALS_DIR" >&2
  exit 1
fi

echo "$STAGE_DIR"
