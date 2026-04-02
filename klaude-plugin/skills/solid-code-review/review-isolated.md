### Workflow

For capy knowledge base conventions, see [capy-knowledge-protocol.md](../_shared/capy-knowledge-protocol.md).
For reconciliation rules, see [review-reconciliation-protocol.md](../_shared/review-reconciliation-protocol.md).

Copy this checklist and check off items as you complete them:

```
Isolated Code Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Reconcile findings
- [ ] Step 4: Present consolidated report
```

---

## Step 1: Prepare Artifacts

Gather the artifacts that will be passed to the sub-agent.

### 1a) Capture the diff

Run `git diff --stat` and `git diff` to capture the changes under review. If there are no unstaged changes, check for staged changes with `git diff --cached`. If the user specified a commit range, use that instead.

**Edge cases:**
- **No changes**: Inform the user and stop.
- **Large diff (>500 lines)**: Proceed — the sub-agent handles batching internally.

### 1b) Locate spec context

Spec context is optional but improves review quality:

1. If this review is happening within `implementation-process`, locate the relevant `design.md` section and task description from `tasks.md` in the feature's `/docs/wip/[feature]/` directory.
2. If standalone, check if the user provided context or if design docs exist in `/docs/wip/` that relate to the changed files.
3. If no spec context is found, that's fine — the sub-agent works without it.

Capture the relevant spec excerpt (design rationale, task description, documented decisions) as text to inject into the sub-agent prompt.

### 1c) Detect primary language

From the `git diff --stat` output, identify the primary language by file extension:

| Extensions | Language key |
|---|---|
| `.go` | `go` |
| `.js`, `.ts`, `.jsx`, `.tsx`, `.mjs`, `.cjs` | `js_ts` |
| `.py`, `.pyw` | `python` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |

### 1d) Resolve pal model

Call `pal` `listmodels` to get available models. Select the most capable model (prefer latest generation with thinking/reasoning support) for the `pal` codereview call in Step 2.

---

## Step 2: Spawn Reviewers (Parallel)

Launch both reviewers in a **single message** so they execute in parallel.

### Reviewer A — `code-reviewer` sub-agent

Spawn using the Agent tool with:

| Parameter | Value |
|---|---|
| `subagent_type` | `kk:code-reviewer` |
| `description` | `Isolated code review` |
| `prompt` | See prompt template below |

**Sub-agent prompt template:**

```
You are reviewing the following code changes. Apply your full review workflow.

## Git Diff

{paste the full git diff output here}

## Primary Language

{language key from Step 1c} — load reference checklists from:
klaude-plugin/skills/solid-code-review/reference/{language_key}/

## Spec Context

{spec excerpt from Step 1b, or "No spec context available — review based on code quality alone."}

Produce your findings in the output format specified in your agent definition.
```

### Reviewer B — `pal` codereview

Call the `pal` `codereview` MCP tool directly with:
- The git diff as input
- The most capable model resolved in Step 1d

`pal` is an external model with no conversation context — naturally isolated without needing a sub-agent wrapper.

### Parallel execution

Both the Agent tool call (Reviewer A) and the `pal` `codereview` MCP call (Reviewer B) MUST appear in the same message to execute in parallel. Do NOT wait for one to finish before starting the other.

---

## Step 3: Reconcile Findings

Follow the [review-reconciliation-protocol.md](../_shared/review-reconciliation-protocol.md) strictly.

### 3a) Collect findings

- Parse the `code-reviewer` sub-agent's structured output (P0-P3 format with file:line, confidence, description)
- Parse the `pal` codereview output and map its findings to P0-P3 severity levels

### 3b) Cross-reference

Compare findings from both reviewers:
- **Same logical issue** (same file region, same class of problem): Mark as **Duplicate**, merge into the higher-quality description, apply severity escalation (one level up)
- **Unique to one reviewer**: Evaluate independently

### 3c) Assign dispositions

For every finding from both reviewers, assign exactly one disposition:

| Disposition | When to use |
|---|---|
| **Confirmed** | Finding is valid regardless of your session context |
| **Disputed — Intentional** | You made a deliberate decision during implementation that explains this. State the specific reason |
| **Disputed — False Positive** | Finding is incorrect. Cite specific evidence (code path, test, spec section, constraint) |
| **Duplicate** | Same issue from both reviewers. Merge and escalate severity |

**Invariants** — these are non-negotiable:
- Every finding MUST appear in the report with a disposition
- You MUST NOT add new findings (you already had your chance during implementation)
- Disputed findings still appear — the user decides
- Agreement escalates severity by one level

---

## Step 4: Present Consolidated Report

Use the consolidated report template from [review-reconciliation-protocol.md](../_shared/review-reconciliation-protocol.md).

### Report content

- **Reviewers**: `code-reviewer (sub-agent), pal codereview (external model — {model name})`
- **Files reviewed**: from `git diff --stat`
- **Findings**: grouped by effective severity (P0-P3), each with:
  - `file:line` location
  - Which reviewer(s) flagged it
  - Disposition and reasoning (if Disputed)
  - Confidence percentage with reasoning
  - Description and suggested fix
- **Reconciliation summary table**: all findings with original severity, disposition, effective severity, and action
- **Reviewer disagreements**: if reviewers contradicted each other on the same code

### Next steps

After presenting the report, ask the user how to proceed:

```markdown
---

## Next Steps

I found X issues (P0: ..., P1: ..., P2: ..., P3: ...).

**How would you like to proceed?**

1. **Fix all** — I'll implement all suggested fixes
2. **Fix P0/P1 only** — Address critical and high priority issues
3. **Fix specific items** — Tell me which issues to fix
4. **No changes** — Review complete, no implementation needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until the user explicitly confirms. This is a review-first workflow.
