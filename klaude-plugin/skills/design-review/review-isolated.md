### Workflow

Copy this checklist and check off items as you complete them:

```
Isolated Design Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
```

---

## Step 1: Prepare Artifacts

### 1a) Read documents

Parse the invocation arguments using the same logic as standard mode Step 1:
- Extract feature name and optional scope argument
- **Argument disambiguation:** if the first argument matches a directory in `/docs/wip/`, treat it as the feature name. If it matches a scope keyword (`design`, `implementation`, `tasks`, `all`) and no such feature directory exists, treat it as the scope and prompt the user for the feature name.
- Locate `/docs/wip/[feature-name]/` directory
- If feature name is not provided or ambiguous, list `/docs/wip/` contents and ask the user

Scope resolution:

| Scope arg | Documents to load |
|-----------|-------------------|
| _(none)_ | `design.md` + `implementation.md` |
| `design` | `design.md` only |
| `implementation` | `implementation.md` only |
| `tasks` | `tasks.md` only |
| `all` | `design.md` + `implementation.md` + `tasks.md` |

If a requested document is missing, inform the user and proceed with available docs.

Read the in-scope documents from `/docs/wip/[feature]/`.

### 1b) Resolve pal model

Call `pal` `listmodels` to get available models. Select the most capable model (prefer latest generation with thinking/reasoning support) for the `pal codereview` call in Step 2.

### 1c) Prepare document content for pal

Since `pal codereview` cannot read files itself, prepare the document contents as a single text block to pass as input. Include clear headers separating each document.

**Important:** `pal codereview` is optimized for source code and diffs. When passing design documents, wrap the content with an explicit framing instruction:

> The following is a design document (markdown), not source code. Review it for technical soundness, completeness, internal consistency, and whether it provides sufficient detail for implementation.

This prevents the model from applying code-specific heuristics to prose.

---

## Step 2: Spawn Reviewers (Parallel)

Launch both reviewers in a **single message** so they execute in parallel.

### Reviewer A — `design-reviewer` sub-agent

Spawn using the Agent tool:

| Parameter | Value |
|---|---|
| `subagent_type` | `kk:design-reviewer` |
| `description` | `Isolated design review` |
| `prompt` | See prompt template below |

**Sub-agent prompt template:**

```
You are reviewing the design documents for the "{feature_name}" feature. Apply your full review workflow.

## Feature Directory

{absolute path to /docs/wip/[feature]/}

## Documents to Review

- Design: {absolute path to design.md} (if in scope, otherwise "Not in scope")
- Implementation: {absolute path to implementation.md} (if in scope, otherwise "Not in scope")
- Tasks: {absolute path to tasks.md} (if in scope, otherwise "Not in scope")

Read the documents yourself using the Read tool. Produce your findings in the output format specified in your agent definition.
```

### Reviewer B — `pal codereview`

Follow the invocation protocol in [pal-codereview-invocation.md](../_shared/pal-codereview-invocation.md).

For the `step` parameter in step 1, use the document contents prepared in Step 1c. For the `model` parameter, use the model resolved in Step 1b. Set `focus_on` to `"technical soundness, completeness, internal consistency, edge cases, failure modes"`.

### Parallel execution

Issue the pal step 1 call and the Agent tool call (Reviewer A) in the **same message** so they execute in parallel. When both return, make the pal step 2 continuation call using the `continuation_id` from step 1.

### Error handling

Handle reviewer failures inline as they occur:

- **`pal` failure** (listmodels returns no models, or codereview step 1/2 fails): Note the failure, proceed to Step 3 with design-reviewer findings only.
- **`design-reviewer` sub-agent failure** (timeout or error): Note the failure, proceed to Step 3 with pal findings only. Suggest `/kk:design-review` (standard mode) as supplement.
- **Both reviewers fail**: Abort isolated mode. Display message suggesting fallback to `/kk:design-review` (standard mode). Do not proceed to Step 3.
- **Malformed output**: Attempt best-effort parsing. If completely unparseable, treat as a failure and apply the rules above.

---

## Step 3: Annotate Findings

The main agent performs annotation — providing context, not judgment. Do NOT assign dispositions (Confirmed, Disputed, etc.). The user is the final arbiter.

### 3a) Duplicate merging

Compare findings from both reviewers by document section and issue description:

- When both flag the same logical issue: merge into one entry, tag as **"corroborated"** — independent confirmation from different models is high signal.
- Severity stays as the design-reviewer assessed it. If pal's native output implies a different level of urgency, note both perspectives side by side. Do NOT map pal's output to P0-P3 — describe the implied urgency in prose.
- If only one reviewer flagged an issue, keep it as-is with reviewer attribution.

### 3b) Author context annotations

For each finding, consider whether the analysis-process session context adds relevant information:

- If yes: add a clearly-labeled **"Author context"** annotation (e.g., "We discussed this trade-off in Step 3 and chose X because Y").
- If no: leave the finding as-is — not every finding needs an annotation.
- Annotations are context, not judgments. "We chose X because Y" is correct. "This finding is invalid" is **not**.

### 3c) Author-sourced findings

If the close re-reading during annotation triggers new observations, add them:

- Tag as **"author-sourced"** — clearly distinct from sub-agent findings.
- The user knows these come from the author and can weight accordingly.

### 3d) pal follow-up (optional)

If a pal finding is ambiguous or unclear, the main agent MAY use pal's follow-up interaction capability to clarify before presenting to the user.

### 3e) Capy index

**Capy index:** Index any confirmed `TECH_RISK` findings that reveal non-obvious architectural constraints as `kk:arch-decisions`. Index confirmed P0/P1 findings that suggest a systemic or structural design pattern (not isolated one-off issues) as `kk:review-findings`. Index on first encounter — recurrence detection happens on the search side in future reviews. This applies to findings from any source — corroborated, single-reviewer, or author-sourced.

---

## Step 4: Present Report

Use this report template, organized by agreement level:

```markdown
## Design Review Summary (Isolated Mode)

**Reviewers**: design-reviewer (Claude sub-agent), pal codereview ([model name])
**Documents reviewed**: [list]

---

### Corroborated Findings
(Both reviewers flagged — highest signal)

- **[doc:section]** Brief title ⟨corroborated⟩
  - Type: [finding_type] | Severity: P[0-3] | Confidence: [N]/10 — [reasoning]
  - **Description:** [description]
  - **Evidence:** [doc references]
  - **Recommendation:** [recommendation]
  - design-reviewer: [description in structured format]
  - pal: [description in native format]
  - Author context: [optional annotation]

### Design Reviewer Findings
(design-reviewer sub-agent only — P0-P3 format)

- **[doc:section]** Brief title
  - Type: [finding_type] | Severity: P[0-3] | Confidence: [N]/10 — [reasoning]
  - **Description:** [description]
  - **Evidence:** [doc references]
  - **Recommendation:** [recommendation]
  - Author context: [optional annotation]

### External Review Findings
(pal codereview — native format)

- [pal output in native format]
  - Author context: [optional annotation]

### Author-Sourced Findings
(Main agent observations during annotation — weight accordingly)

- **[doc:section]** Brief title ⟨author-sourced⟩
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

I found X issues (corroborated: ..., design-reviewer: ..., pal: ..., author-sourced: ...).

**How would you like to proceed?**

1. **Update docs** — I'll revise the design docs to address all findings
2. **Update corroborated + high severity** — Address corroborated findings and P0/P1 issues
3. **Update specific items** — Tell me which findings to address
4. **Proceed to implementation** — Findings are acceptable, move forward
5. **No changes** — Review complete, no action needed

Please choose an option or provide specific instructions.
```

**Important:** Do NOT update any documents until the user explicitly confirms.
