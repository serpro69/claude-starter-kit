Verify implemented code against design and implementation documentation, detecting spec deviations, missing implementations, and outdated docs.

Arguments: $ARGUMENTS

## Invocation

**If $ARGUMENTS is provided:**
Treat `$ARGUMENTS` as the feature name. Look for documentation in `/docs/wip/$ARGUMENTS/` and run the implementation review process against it.

**If $ARGUMENTS is empty:**
List the contents of `/docs/wip/` and ask the user which feature to review. If only one feature exists, use it automatically.

## Process

Invoke the `kk:review-spec` skill and follow the workflow in `review-process.md`:

1. Load feature documents (design.md, implementation.md, tasks.md)
2. Determine review scope (mid-implementation vs post-implementation)
3. Per-task verification against spec
4. Cross-cutting concern check
5. Self-check and confidence assessment (1–10 scale with reasoning)
6. Present findings with next steps

## Examples

Review a specific feature:
```
/kk:review-spec jwt-auth
```

Review when only one WIP feature exists:
```
/kk:review-spec
```
