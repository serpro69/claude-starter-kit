Run SOLID code review in isolated mode with independent sub-agents that have zero authorship bias.

Two parallel reviewers: a `code-reviewer` sub-agent and `pal codereview` (external model). Produces a report organized by agreement level with corroborated findings highlighted.

Arguments: $ARGUMENTS

## Invocation

**If $ARGUMENTS is provided:**
Treat `$ARGUMENTS` as a commit range or file scope for the review.

**If $ARGUMENTS is empty:**
Review current unstaged changes (falling back to staged changes if no unstaged changes exist).

## Process

Invoke the `kk:review-code` skill using the `review-isolated.md` workflow:

1. **Prepare Artifacts** — Capture diff, locate spec context, detect language, resolve pal model, curate rejected approaches
2. **Spawn Reviewers (Parallel)** — Launch `code-reviewer` sub-agent and `pal codereview` in a single message
3. **Annotate Findings** — Merge duplicates, add author context annotations, note author-sourced observations
4. **Present Report** — Organized by agreement level (corroborated → single-reviewer → author-sourced), ask user how to proceed

## Examples

Review current changes:
```
/kk:review-code:isolated
```

Review a specific commit range:
```
/kk:review-code:isolated HEAD~3..HEAD
```
