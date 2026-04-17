## Review scope protocol

Isolated reviewers see the diff and the design docs but have zero visibility into which tasks are done versus pending. Without scope, they flag code-that-isn't-written-yet as `MISSING_IMPL` (spec review) or as missing functionality (code review). This protocol defines a scope artifact both skills inject into their sub-agent and external-reviewer prompts.

### Input shapes

The review workflow must handle three invocation shapes:

1. **Invoked from `implement`** — `/docs/wip/[feature]/` exists with `design.md`, `implementation.md`, `tasks.md`. The current task id is known (the one just finished). Use full scope filtering.
2. **Invoked directly inside a feature** — `/docs/wip/[feature]/` exists but no current task is explicitly supplied. Derive scope from `tasks.md` status fields (`done` = in scope, `pending`/`in-progress` = out of scope).
3. **Invoked on an arbitrary diff** — no `/docs/wip/` directory relates to the diff. Skip the scope artifact entirely and note "No task scope available" in the reviewer prompt.

### Scope artifact format

When shape 1 or 2 applies, build this block and inject it into every reviewer prompt (sub-agent prompt template and the external-reviewer `step` framing):

```
## Task Scope

Review mode: {mid-implementation | post-implementation}

In scope (review these):
- Task {id}: {title} — status: done
- [...more done tasks if applicable]

Out of scope (pending — DO NOT flag as missing):
- Task {id}: {title} — status: {pending|in-progress}
- [...more pending tasks]

The feature's design docs describe the full end state. Pending tasks are expected gaps in the current diff — treat their absence from the code as intentional, not as a finding. You may still flag issues within the in-scope tasks even if they reference pending tasks (e.g., a broken interface contract).
```

When shape 3 applies, use:

```
## Task Scope

No task scope available — review the diff on its own merits without assuming any feature-level design doc.
```

### Determining mode

- **mid-implementation** — at least one task in `tasks.md` has status `pending` or `in-progress`.
- **post-implementation** — all tasks are `done`.

In shape 1, the invoking workflow (`implement`) may pass the current task id directly; that task is automatically in scope even if `tasks.md` hasn't been updated yet.

### Interpretation guidance for reviewers

The reviewer prompt must also carry this instruction (agent definitions should state it; the workflow relays it implicitly via the scope block):

- Do **not** report missing-implementation findings for items covered only by out-of-scope tasks.
- Do still report real issues *within* the in-scope tasks, including ones that affect future pending work (e.g., a public API the pending task will depend on is shaped wrongly).
- If a finding would be valid *only* after pending work lands, mention it under "Areas Not Covered" instead of the P0–P3 sections.
