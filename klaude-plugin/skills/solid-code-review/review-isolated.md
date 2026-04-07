### Workflow

Copy this checklist and check off items as you complete them:

```
Isolated Code Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
```

---

## Step 1: Prepare Artifacts

Gather the artifacts that will be passed to the sub-agents.

### 1a) Capture the diff

Run `git diff --stat` and `git diff` to capture the changes under review. If there are no unstaged changes, check for staged changes with `git diff --cached`. If the user specified a commit range, use that instead.

**Edge cases:**
- **No changes**: Inform the user and stop.
- **Large diff (>500 lines)**: Proceed — the sub-agent handles batching internally. If the diff exceeds the sub-agent's context window, note the limitation and suggest the user scope the review to specific files or tasks.

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

### 1e) Curate rejected approaches

Before spawning sub-agents, prepare a brief summary of approaches that were tried and failed during implementation. Keep it to concrete facts ("approach X caused regression Y"), not the full debugging narrative. If no approaches were rejected, skip this.

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

## Rejected Approaches

{curated rejected approaches from Step 1e, or "No rejected approaches to note."}

Produce your findings in the output format specified in your agent definition.
```

### Reviewer B — `pal` codereview

Follow the invocation protocol in [pal-codereview-invocation.md](../_shared/pal-codereview-invocation.md).

For the `step` parameter in step 1, use the git diff prepared in Step 1c. For the `model` parameter, use the model resolved in Step 1d.

### Parallel execution

Issue the pal step 1 call and the Agent tool call (Reviewer A) in the **same message** so they execute in parallel. When both return, make the pal step 2 continuation call using the `continuation_id` from step 1.

### Error handling

Handle reviewer failures inline as they occur:

- **`pal` failure** (listmodels returns no models, or codereview step 1/2 fails): Note the failure, proceed to Step 3 with code-reviewer findings only.
- **`code-reviewer` sub-agent failure** (timeout or error): Note the failure, proceed to Step 3 with pal findings only. Suggest `/kk:solid-code-review` (standard mode) as supplement.
- **Both reviewers fail**: Abort isolated mode. Display message suggesting fallback to `/kk:solid-code-review` (standard mode). Do not proceed to Step 3.
- **Malformed output**: Attempt best-effort parsing. If completely unparseable, treat as a failure and apply the rules above.

---

## Step 3: Annotate Findings

The main agent performs annotation — providing context, not judgment. Do NOT assign dispositions (Confirmed, Disputed, etc.). The user is the final arbiter.

### 3a) Duplicate merging

Compare findings from both reviewers by file location and issue description:

- When both flag the same logical issue: merge into one entry, tag as **"corroborated"** — independent confirmation from different models is high signal.
- Severity stays as each reviewer assessed it. If they disagree on severity, show both assessments side by side.
- If only one reviewer flagged an issue, keep it as-is with reviewer attribution.

### 3b) Author context annotations

For each finding, consider whether the implementation session context adds relevant information:

- If yes: add a clearly-labeled **"Author context"** annotation explaining the decision (e.g., "I chose bcrypt cost 10 because benchmarks showed cost 12 added 400ms").
- If no: leave the finding as-is — not every finding needs an annotation.
- Annotations are context, not judgments. "I chose X because Y" is correct. "This finding is invalid" is **not**.

### 3c) Author-sourced findings

If the close re-reading during annotation triggers new observations, add them:

- Tag as **"author-sourced"** — clearly distinct from sub-agent findings.
- The user knows these come from the author and can weight accordingly.

### 3d) pal follow-up (optional)

If a pal finding is ambiguous or unclear, the main agent MAY use pal's follow-up interaction capability to clarify before presenting to the user.

### 3e) Capy index

**Capy index:** Index any P0/P1 findings that reveal recurring patterns (not one-off typos) as `kk:review-findings`. This applies to findings from any source — corroborated, single-reviewer, or author-sourced.

---

## Step 4: Present Report

Use this report template, organized by agreement level:

```markdown
## Review Summary (Isolated Mode)

**Reviewers**: code-reviewer (Claude sub-agent), pal codereview ([model name])
**Files reviewed**: X files, Y lines changed

---

### Corroborated Findings
(Both reviewers flagged — highest signal)

- **[file:line]** Brief title ⟨corroborated⟩
  - code-reviewer: [severity] — [description]
  - pal: [description in native format]
  - Author context: [optional annotation]

### Code Reviewer Findings
(code-reviewer sub-agent only — P0-P3 format)

- **[file:line]** Brief title
  - Severity: P[0-3] | Confidence: [X]%
  - [description and suggested fix]
  - Author context: [optional annotation]

### External Review Findings
(pal codereview — native format)

- [pal output presented in its native format]
  - Author context: [optional annotation]

### Author-Sourced Findings
(Main agent observations during annotation — weight accordingly)

- **[file:line]** Brief title ⟨author-sourced⟩
  - [description]
```

**Section rules:**
- Omit any section that has no findings (e.g., if no corroborated findings, skip that section).
- If a reviewer failed and only one reviewer's findings are present, note the failure at the top and present the available findings under the appropriate section.

### Next steps

After presenting the report, ask the user how to proceed:

```markdown
---

## Next Steps

I found X issues (corroborated: ..., code-reviewer: ..., pal: ..., author-sourced: ...).

**How would you like to proceed?**

1. **Fix all** — I'll implement all suggested fixes
2. **Fix corroborated + high severity** — Address corroborated findings and P0/P1 issues
3. **Fix specific items** — Tell me which issues to fix
4. **No changes** — Review complete, no implementation needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until the user explicitly confirms. This is a review-first workflow.
