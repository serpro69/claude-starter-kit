Run implementation review in isolated mode with an independent spec-reviewer sub-agent that has zero authorship bias.

Delegates detection to a `spec-reviewer` sub-agent, then annotates findings with type-specific author context. Low-relevance types (MISSING_IMPL, DOC_INCON, OUTDATED_DOC, AMBIGUOUS) get brief annotations; high-relevance types (SPEC_DEV, EXTRA_IMPL) get detailed annotations with spec update suggestions.

Arguments: $ARGUMENTS

## Invocation

**If $ARGUMENTS is provided:**
Treat `$ARGUMENTS` as the feature name. Look for documentation in `/docs/wip/$ARGUMENTS/` and run the isolated review against it.

**If $ARGUMENTS is empty:**
List the contents of `/docs/wip/` and ask the user which feature to review. If only one feature exists, use it automatically.

## Process

Invoke the `kk:review-spec` skill using the `review-isolated.md` workflow:

1. **Prepare Artifacts** — Locate feature directory, verify docs exist, determine review scope, prepare sub-agent context
2. **Spawn Spec Reviewer** — Launch `spec-reviewer` sub-agent with feature docs and review scope
3. **Annotate Findings** — Parse findings, apply type-specific annotation guidance, add author-sourced observations
4. **Present Report** — Organized by finding type, ask user how to proceed (or feed back into implement if mid-feature)

## Examples

Review a specific feature:
```
/kk:review-spec:isolated jwt-auth
```

Review when only one WIP feature exists:
```
/kk:review-spec:isolated
```
