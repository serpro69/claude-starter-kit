### Workflow

Copy this checklist and check off items as you complete them:

```
Isolated Implementation Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn spec reviewer
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
- [ ] Step 5: Index confirmed deviations
- [ ] Step 6: Verify outputs
```

## Contents

- **Step 1: Prepare Artifacts** — 1a) Locate feature directory, 1b) Verify docs exist, 1c) Determine review scope, 1d) Prepare sub-agent context
- **Step 2: Spawn Spec Reviewer** — Sub-agent prompt template, error handling
- **Step 3: Annotate Findings** — 3a) Parse findings, 3b) Type-specific annotation guidance, 3c) Author-sourced findings
- **Step 4: Present Report** — Report template, integration with implementation-process, standalone mode
- **Step 5: Index Confirmed Deviations**
- **Step 6: Verify Outputs**

---

## Step 1: Prepare Artifacts

### 1a) Locate feature directory

Find the feature directory in `/docs/wip/[feature]/`. If the user specified a feature name, use it directly. If invoked from `implementation-process`, the feature directory is already known.

### 1b) Verify docs exist

Confirm that the following files exist in the feature directory:
- `design.md` — feature design and architecture
- `implementation.md` — implementation plan with task-level details
- `tasks.md` — task statuses and subtask checklists

If any are missing, inform the user and stop.

### 1c) Determine review scope

Read `tasks.md` to classify each task:
- **Done**: task is completed and should be reviewed
- **Pending/In-progress**: task is not yet complete and should be skipped

Determine the review mode:
- **Mid-implementation**: some tasks are pending — review only completed tasks
- **Post-implementation**: all tasks are done — review everything

### 1d) Prepare sub-agent context

Collect the absolute paths to `design.md`, `implementation.md`, and `tasks.md`. The sub-agent reads these files itself — do NOT inline their contents into the prompt.

---

## Step 2: Spawn Spec Reviewer

Spawn a single `spec-reviewer` sub-agent using the Agent tool:

| Parameter | Value |
|---|---|
| `subagent_type` | `kk:spec-reviewer` |
| `description` | `Isolated spec conformance review` |
| `prompt` | See prompt template below |

**Sub-agent prompt template:**

```
You are reviewing the implementation of the "{feature_name}" feature against its specification. Apply your full review workflow.

## Feature Directory

{absolute path to /docs/wip/[feature]/}

## Documents

- Design: {absolute path to design.md}
- Implementation plan: {absolute path to implementation.md}
- Tasks: {absolute path to tasks.md}

## Review Scope

{mid-implementation | post-implementation}

Tasks to review: {list of completed task names/numbers}
Tasks to skip: {list of pending task names/numbers, or "none — all tasks complete"}

Read the documents yourself using the Read tool. Produce your findings in the output format specified in your agent definition.
```

This is a single sub-agent, not parallel. Wait for it to complete before proceeding.

### Error handling

- **Sub-agent timeout or failure**: Abort isolated mode. Suggest fallback to `/kk:implementation-review` (standard mode).
- **Malformed output**: Attempt best-effort parsing. If completely unparseable, treat as failure and abort with the fallback suggestion above.

---

## Step 3: Annotate Findings

The main agent annotates findings using type-specific guidance — providing context, not judgment. Do NOT assign dispositions (Confirmed, Disputed, etc.). The user is the final arbiter.

### 3a) Parse findings

Parse the `spec-reviewer` sub-agent's structured output (finding type, severity, confidence, spec-vs-code evidence).

### 3b) Apply type-specific annotation guidance

Each finding type has different relevance for author context annotations:

**Low author-context-relevance types** (MISSING_IMPL, DOC_INCON, OUTDATED_DOC, AMBIGUOUS):
- These are objective or spec-clarity issues. The main agent's session context is less relevant.
- Keep annotations **brief**: point to implementing code if it exists, confirm/deny inconsistencies, clarify intent if known.

**High author-context-relevance types** (SPEC_DEV, EXTRA_IMPL):
- These may be intentional deviations. The main agent's session context IS relevant.
- Annotations should **explain the decision** and suggest a spec update if the deviation was deliberate.

For each finding:
- Add a clearly-labeled **"Author context"** annotation where the main agent's session context is relevant.
- Leave findings as-is when the annotation would not add useful information.
- Annotations are context, not judgments. "I chose X because Y" is correct. "This finding is invalid" is **not**.

### 3c) Author-sourced findings

If the close re-reading during annotation triggers new observations, add them:

- Tag as **"author-sourced"** — clearly distinct from sub-agent findings.
- The user knows these come from the author and can weight accordingly.

---

## Step 4: Present Report

Use this report template, organized by finding type:

```markdown
## Spec Conformance Review (Isolated Mode)

**Reviewer**: spec-reviewer (Claude sub-agent)
**Scope**: [tasks reviewed]

---

### Findings by Type

#### MISSING_IMPL
- **[description]** — P[0-3]
  - Evidence: [spec reference vs implementation state]
  - Author context: [optional brief annotation]

#### SPEC_DEV
- **[description]** — P[0-3]
  - Evidence: [spec says X, implementation does Y]
  - Author context: [explain decision, suggest spec update if intentional]

#### EXTRA_IMPL
- **[description]** — P[0-3]
  - Evidence: [implementation has X, spec does not document it]
  - Author context: [explain why added, suggest spec update if intentional]

#### DOC_INCON
- **[description]** — P[0-3]
  - Evidence: [section A says X, section B says Y]
  - Author context: [optional brief annotation]

#### OUTDATED_DOC
- **[description]** — P[0-3]
  - Evidence: [doc says X, current state is Y]
  - Author context: [optional — note what changed and when]

#### AMBIGUOUS
- **[description]** — P[0-3]
  - Evidence: [ambiguous spec language]
  - Author context: [optional — clarify intent if known]

### Author-Sourced Findings

- **[description]** ⟨author-sourced⟩
  - [description]
```

**Section rules:**
- Omit any finding type section that has no findings.
- Each finding shows: type, severity, the finding, evidence, and author context annotation where relevant.

### Integration with implementation-process

If this review is happening within `implementation-process`:
- Feed `MISSING_IMPL` and `SPEC_DEV` findings back as implementation tasks
- Feed `DOC_INCON`, `OUTDATED_DOC`, and `AMBIGUOUS` findings back as doc-update tasks
- Present the combined list for user confirmation before proceeding

### Standalone mode

If invoked standalone, present the report and ask the user how to proceed:

```markdown
---

## Next Steps

I found X findings (MISSING_IMPL: ..., SPEC_DEV: ..., DOC_INCON: ..., etc.).

**How would you like to proceed?**

1. **Fix all** — I'll address all findings (code fixes + doc updates)
2. **Fix high severity only** — Address P0/P1 issues
3. **Fix specific items** — Tell me which findings to address
4. **Update docs only** — Apply spec update suggestions without code changes
5. **No changes** — Review complete, no changes needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until the user explicitly confirms.

---

## Step 5: Index Confirmed Deviations

After the user responds to the next steps prompt, index any `SPEC_DEV` or `EXTRA_IMPL` findings that the user confirms as intentional as `kk:arch-decisions`. This prevents the same deviation from being flagged in future reviews. This applies to findings from any source — sub-agent or author-sourced.

- For each confirmed intentional deviation: call `capy_index` with source `kk:arch-decisions` and a concise summary of the decision and rationale.
- If the user confirms no deviations as intentional, or there are no `SPEC_DEV`/`EXTRA_IMPL` findings, explicitly note "No deviations to index" and move on.
- This step is mandatory — do not skip it even if all findings are rejected.

---

## Step 6: Verify Outputs

Before declaring the review complete, check each item in the **Required Outputs** section of SKILL.md:

- [ ] Review report presented to user
- [ ] User-confirmed intentional `SPEC_DEV`/`EXTRA_IMPL` findings indexed as `kk:arch-decisions` (or explicitly noted "No deviations to index")
- [ ] Next steps confirmation from user

If any item is unchecked, go back and complete it before proceeding.
