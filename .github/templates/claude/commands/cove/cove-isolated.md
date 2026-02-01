Apply Chain-of-Verification (CoVe) with true factored verification using isolated sub-agents.

This mode spawns separate sub-agents for each verification question, ensuring they have
zero context about the initial answer. Use when maximum accuracy is required.

Arguments: $ARGUMENTS

## Flags

| Flag | Effect | Use Case |
|------|--------|----------|
| (none) | `general-purpose` agent | Default, full tool access |
| `--explore` | `Explore` agent | Codebase-related verification |
| `--haiku` | Use haiku model | Faster/cheaper verification |
| `--agent=<name>` | Custom agent type | User-defined agents |

**Flag Parsing Rules:**
- Flags must appear before the question
- Flags start with `--`
- `--agent=value` format for custom agents
- Unknown flags are treated as part of the question
- Flags can be combined in any order

## Invocation

**If $ARGUMENTS is provided:**
1. Extract any flags from the beginning of $ARGUMENTS
2. Apply CoVe isolated verification to the remaining question
3. Pass extracted flags to the workflow

**If $ARGUMENTS is empty:**
Apply CoVe isolated verification to the previous response in the conversation.

## Process

Invoke the `cove` skill using the `cove-isolated.md` workflow:

1. Generate Initial Answer (or use previous response if verifying)
2. Create 3-5 Verification Questions targeting potential errors
3. Spawn isolated sub-agents to answer each question (parallel execution)
4. Reconcile findings and produce final verified answer with agent metadata

## Examples

Basic isolated verification:
```
/cove-isolated What is the default port for PostgreSQL?
```

Codebase verification with Explore agent:
```
/cove-isolated --explore How does the auth middleware work in this project?
```

Faster verification with haiku model:
```
/cove-isolated --haiku What is the speed of light in m/s?
```

Custom agent type:
```
/cove-isolated --agent=general-purpose What is the capital of France?
```

Combined flags:
```
/cove-isolated --haiku --explore What testing pattern does this codebase use?
```

Verify previous response:
```
/cove-isolated
```
(Use after receiving a response to verify it with isolated sub-agents)
