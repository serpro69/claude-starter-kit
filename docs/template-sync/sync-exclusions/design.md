# Sync Exclusions Feature - Design Document

## Problem Statement

When users create a repository from the `claude-starter-kit` template and delete files that are not relevant to their project (e.g., specific skills, commands, or configurations), the Template Sync feature re-adds those files in the next sync PR. There is currently no mechanism for users to tell sync "I intentionally removed this; don't bring it back."

This creates friction: users must either manually revert unwanted additions from every sync PR, or stop using sync entirely.

### Example Scenario

1. User creates repo from template
2. User deletes `.claude/commands/cove/` (CoVe skill not needed)
3. User runs Template Sync
4. Sync PR re-adds `.claude/commands/cove/` as "Added files"
5. User must manually remove it from the PR or close and cherry-pick

## Solution Overview

Add an optional `sync_exclusions` field to the existing state manifest (`.github/template-state.json`). This field contains an array of glob patterns representing project-relative paths that template-sync should completely ignore during file comparison.

Excluded files are:
- **Not added** if they exist upstream but not locally
- **Not updated** if they exist both upstream and locally
- **Not flagged as deleted** if they exist locally but not upstream
- **Reported as "Excluded"** in the sync report so users can verify their patterns work

## Architecture

### Data Flow

```
Manifest (.github/template-state.json)
  └── sync_exclusions: [".claude/commands/cove/*", ...]
         │
         ▼
  read_manifest() loads patterns into SYNC_EXCLUSIONS array
         │
         ▼
  compare_files() calls is_excluded() before categorizing each file
         │
         ├── Matches pattern → EXCLUDED_FILES array (skipped)
         └── No match → normal flow (ADDED/MODIFIED/DELETED/UNCHANGED)
         │
         ▼
  generate_diff_report() shows excluded files in report
```

### Manifest Schema Change

The `sync_exclusions` field is **optional** and added at the top level of the manifest, alongside `variables`. When absent, it defaults to an empty array (no exclusions).

```json
{
  "schema_version": "1",
  "upstream_repo": "serpro69/claude-starter-kit",
  "template_version": "v0.2.0",
  "synced_at": "2025-01-27T10:00:00Z",
  "sync_exclusions": [
    ".claude/commands/cove/*",
    ".claude/skills/cove/*",
    ".claude/commands/tm/workflows/auto-implement-tasks.md"
  ],
  "variables": { ... }
}
```

**Schema compatibility**: The `schema_version` stays at `"1"` since this is a backward-compatible, additive change. Existing manifests without `sync_exclusions` remain valid.

### Glob Pattern Matching

Patterns use bash `case` statement glob syntax:
- `*` matches any characters **including** directory separators (in bash `case`, unlike `find`)
- `?` matches a single character
- `[abc]` matches character classes

**Examples:**

| Pattern | Matches | Does NOT Match |
|---------|---------|----------------|
| `.claude/commands/cove/*` | `.claude/commands/cove/cove.md`, `.claude/commands/cove/cove-isolated.md` | `.claude/commands/tm/cove.md` |
| `.claude/skills/cove/*` | `.claude/skills/cove/cove.md` | `.claude/skills/other/cove.md` |
| `*.bak` | Would match nothing useful (no directory prefix) | `.claude/test.bak` |
| `.taskmaster/templates/*` | `.taskmaster/templates/example_prd.txt` | `.taskmaster/config.json` |

**Important**: Patterns are matched against **project-relative paths** (e.g., `.claude/commands/cove/cove.md`), not staging-relative paths. Users write patterns relative to their project root.

### Core Logic: `is_excluded()` Function

```
is_excluded(file_path):
    for each pattern in SYNC_EXCLUSIONS:
        if file_path matches pattern (glob):
            return true (excluded)
    return false (not excluded)
```

- Uses bash `case` statement for glob matching (idiomatic, handles slashes correctly)
- Accesses global `SYNC_EXCLUSIONS` array directly (avoids bash array-passing complexity)
- Placed in the Helper Functions section of `template-sync.sh`

### Integration Points in `compare_files()`

The exclusion check is injected at **two points** in `compare_files()`:

**1. Staging file walk** (detects ADDED/MODIFIED/UNCHANGED):
- After constructing `display_path` (the project-relative path)
- Before the `diff` comparison
- If `is_excluded "$display_path"` returns true: append to `EXCLUDED_FILES`, `continue`

**2. Project file walk** (detects DELETED):
- After constructing `display_path`
- Before checking if the staging file exists
- If `is_excluded "$display_path"` returns true: `continue` (skip, don't flag as deleted)

This placement is optimal because:
- Excluded files never trigger `diff` operations (performance)
- The check uses `display_path` which is already the project-relative path
- Both addition and deletion detection are covered

### Report Changes

**Human-readable report** (`generate_diff_report()`):
- New "Excluded (skipped)" section after the change summary
- Listed with a distinct marker
- Excluded files do NOT count toward `has_changes` (they're intentional)

**CI mode output**:
- New `excluded_count` output variable
- Does not affect `has_changes` calculation

**Markdown summary** (`generate_markdown_summary()`):
- New "Excluded Files" section in PR body
- Shows which files were skipped due to exclusion patterns

### Validation

The `validate_manifest()` function validates `sync_exclusions` only when present:
- Must be a JSON array
- Each element must be a string
- Empty array is valid
- Missing field is valid (treated as empty array)

### Scope & Interaction with Existing Exclusions

The `sync_exclusions` mechanism is **separate from** the existing hardcoded user-scoped directory exclusions (`.taskmaster/tasks/`, `.taskmaster/docs/`, `.taskmaster/reports/`). Those continue to work as before via `find` command flags.

`sync_exclusions` operates at a different layer - it filters the results of the file walk, not the walk itself. This means:
- User-scoped directories are excluded from the walk entirely (never seen)
- `sync_exclusions` patterns filter files that pass through the walk

There is no conflict between the two mechanisms.

## File Classification Update

The existing design document (`docs/template-sync/design.md`) classifies files into three categories. With sync exclusions, a fourth implicit category emerges:

| Category | Behavior | Controlled By |
|----------|----------|---------------|
| Template-managed | Updated by sync | Template structure |
| User-scoped | Never touched | Hardcoded in `compare_files()` |
| Project-specific | Preserved via substitution | Manifest `variables` |
| **User-excluded** | **Ignored by sync** | **Manifest `sync_exclusions`** |

## Limitations

1. **No wildcard-only patterns**: A pattern like `*` would exclude everything - there's no validation against overly broad patterns (user responsibility)
2. **No negation patterns**: Cannot write "exclude everything in cove/ EXCEPT cove.md" - must list individual exclusions
3. **Glob only**: No regex support; bash `case` glob syntax only
4. **Manual configuration**: Users must edit the manifest JSON directly to add exclusions

## Security Considerations

- Exclusions are local to the child repository (no upstream impact)
- The manifest is version-controlled, so exclusion changes are auditable
- Exclusions cannot expose files - they can only prevent sync from touching them
