Apply Chain-of-Verification (CoVe) prompting to improve response accuracy through self-verification.

Arguments: $ARGUMENTS

## Invocation

**If $ARGUMENTS is provided:**
Apply the CoVe verification process to answer the given question with systematic fact-checking.

**If $ARGUMENTS is empty:**
Apply CoVe to verify the previous response in the conversation, generating verification questions and reconciling any errors found.

## Process

Invoke the `cove` skill and follow the 4-step workflow in `cove-process.md`:

1. Generate Initial Answer (or use previous response if verifying)
2. Create 3-5 Verification Questions targeting potential errors
3. Answer questions independently without referencing the initial answer
4. Reconcile findings and produce the final verified answer

## Examples

```
/cove What is the time complexity of Python's sorted()?
```

```
/cove
```
(Use after receiving a response to verify it)
