Update the local template-sync workflow and script from the upstream template repository.

Arguments: $ARGUMENTS

## Bootstrap the sync script if missing

If `.claude/scripts/sync-workflow.sh` does not exist, fetch it first:

```bash
mkdir -p .claude/scripts
curl -fsSL "https://raw.githubusercontent.com/serpro69/claude-starter-kit/master/.github/templates/claude/scripts/sync-workflow.sh" \
  -o .claude/scripts/sync-workflow.sh
chmod +x .claude/scripts/sync-workflow.sh
```

## Run the sync

Run the sync script, passing `$ARGUMENTS` as the version (defaults to `latest` if empty):

```bash
bash .claude/scripts/sync-workflow.sh $ARGUMENTS
```

Supported versions: `latest` (default, resolves the most recent tag), `master`, or a specific tag (e.g. `v0.3.0`).

After the script completes, show the user the output. If it failed, suggest they check network connectivity or try a specific version tag.
