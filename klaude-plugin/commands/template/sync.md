Sync this repository with the upstream claude-toolbox template.

Fetches the latest template version, compares files, and applies updates locally.

Arguments: $ARGUMENTS

## Process

Run the template-sync script with `--local` to fetch, compare, and apply in a single invocation:

```bash
.claude/toolbox/scripts/template-sync.sh --local $ARGUMENTS
```

`$ARGUMENTS` is forwarded as-is. Common usage:

- `/kk:template:sync` — sync to latest release
- `/kk:template:sync --version v1.0.0` — sync to a specific version
- `/kk:template:sync --dry-run` — preview changes without applying

## Prerequisites

Requires `jq`, `git`, `curl`, and `yq` (mikefarah/yq). If any are missing the script will report which ones to install.

The repository must have a `.github/template-state.json` manifest — created automatically when the repo was set up from the template.

## After sync

Show the user the script output. If changes were applied, suggest reviewing with `git diff` before committing. If it failed, surface the error message from the script.
