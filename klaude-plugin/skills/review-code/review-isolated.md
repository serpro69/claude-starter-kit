### Workflow

Copy this checklist and check off items as you complete them:

```
Isolated Code Review Progress:
- [ ] Step 1: Prepare artifacts (1a–1g)
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Annotate findings
- [ ] Step 4: Index findings
- [ ] Step 5: Present report
- [ ] Step 6: Verify outputs
```

## Contents

- **Step 1: Prepare Artifacts** — 1a) Capture diff, 1b) Locate spec context, 1c) Detect active profiles and resolve checklists, 1d) Resolve pal model, 1e) Curate rejected approaches, 1f) Determine task scope, 1g) Collect context files for pal
- **Step 2: Spawn Reviewers** — Reviewer A (code-reviewer sub-agent), Reviewer B (pal codereview), error handling
- **Step 3: Annotate Findings** — 3a) Duplicate merging, 3b) Author context, 3c) Author-sourced findings, 3d) pal follow-up
- **Step 4: Index Findings**
- **Step 5: Present Report** — Report template, next steps
- **Step 6: Verify Outputs**

---

## Step 1: Prepare Artifacts

Gather the artifacts that will be passed to the sub-agents.

### 1a) Capture the diff

Run `git diff --stat` and `git diff` to capture the changes under review. If there are no unstaged changes, check for staged changes with `git diff --cached`. If the user specified a commit range, use that instead.

Write the diff to a temp file for pal consumption:

```bash
diff_file=$(mktemp /tmp/kk-review-code-XXXXXXXX.patch)
git diff > "$diff_file"
```

Adjust the `git diff` command to match the actual scope (staged, unstaged, or commit range). The temp file is passed to pal via `relevant_files` in Step 2 and should be cleaned up after the review completes (`rm "$diff_file"`).

**Edge cases:**

- **No changes**: Inform the user and stop.
- **Large diff (>500 lines)**: Proceed — the sub-agent handles batching internally. If the diff exceeds the sub-agent's context window, note the limitation and suggest the user scope the review to specific files or tasks.

### 1b) Locate spec context

Spec context is optional but improves review quality:

1. If this review is happening within `/kk:implement`, locate the relevant `design.md` section and task description from `tasks.md` in the feature's `/docs/wip/[feature]/` directory.
2. If standalone, check if the user provided context or if design docs exist in `/docs/wip/` that relate to the changed files.
3. If no spec context is found, that's fine — the sub-agent works without it.

Capture the relevant spec excerpt (design rationale, task description, documented decisions) as text to inject into the sub-agent prompt.

### 1c) Detect active profiles and resolve checklists

Delegate to [shared-profile-detection.md](shared-profile-detection.md) with the diff from Step 1a as input. The procedure returns a list of records — one per matched profile — each naming the trigger signal and the files that activated it.

For each active profile, resolve the checklists to apply:

1. Read `<plugin_root>/profiles/<profile>/review-code/index.md` — where `<plugin_root>` is the absolute plugin-root path known from SKILL.md context.
2. Collect every entry under **Always load**.
3. For every **Load if:** conditional entry, evaluate the predicate against the diff; collect the entry when it matches.

Accumulate a flat list of `(profile, checklist, triggered_by)` records — carry the `triggered_by` signal from each detection record through to every checklist resolved for that profile. This list — not any hardcoded category sequence — is what the sub-agent and pal prompts will receive in Step 2. If no profile matched, the list is empty; both reviewers fall back to general guidance.

### 1d) Resolve pal model

Call `pal` `listmodels` to get available models. Select the most capable model (prefer latest generation with thinking/reasoning support) for the `pal` codereview call in Step 2.

### 1e) Curate rejected approaches

Before spawning sub-agents, prepare a brief summary of approaches that were tried and failed during implementation. Keep it to concrete facts ("approach X caused regression Y"), not the full debugging narrative. If no approaches were rejected, skip this.

### 1f) Determine task scope

Build the Task Scope artifact following [shared-review-scope-protocol.md](shared-review-scope-protocol.md). This is what prevents reviewers from flagging pending tasks as missing functionality — it is not optional when a feature directory is present.

- **Invoked from `/kk:implement`**: the feature directory and current task are known. Read `tasks.md`, list the current task (plus any other `done` tasks) as in-scope and any `pending`/`in-progress` tasks as out-of-scope. Use mode `mid-implementation` unless all tasks are `done`.
- **Invoked directly inside a feature**: locate the relevant `/docs/wip/[feature]/tasks.md`. Classify by status field. Use `post-implementation` only when every task is `done`.
- **No feature directory relates to the diff**: emit the "No task scope available" variant from the shared protocol and proceed.

The resulting block is inlined into both reviewer prompts in Step 2.

### 1g) Collect context files for pal

Assemble the file list that will be passed to pal codereview via `relevant_files`. All paths must be absolute.

1. **Diff file** — the temp file written in Step 1a.
2. **Changed source files** — every file touched by the diff (from `git diff --stat`).
3. **Surrounding code files** — for each changed file, identify direct imports, callers, interfaces, and type definitions referenced in the diff. Use `grep`/`rg` to locate these. Include files that a reviewer would need to verify cross-file correctness (e.g., checking a function signature, confirming an interface contract, comparing with adjacent module conventions). Keep this bounded — aim for the immediate dependency ring, not transitive closure.
4. **Profile checklist files** — the absolute paths of every resolved `(profile, checklist)` file from Step 1c. These give pal the same domain-specific review criteria as Reviewer A.
5. **Design/implementation docs** — if spec context was located in Step 1b, include the full `design.md` and `implementation.md` file paths (not excerpts). These enable pal to flag spec deviations.

Store this list for use in Step 2 (Reviewer B).

---

## Step 2: Spawn Reviewers (Parallel)

Launch both reviewers in a **single message** so they execute in parallel.

### Reviewer A — `code-reviewer` sub-agent

Spawn using the Agent tool with:

| Parameter       | Value                     |
| --------------- | ------------------------- |
| `subagent_type` | `kk:code-reviewer`        |
| `description`   | `Isolated code review`    |
| `prompt`        | See prompt template below |

**Sub-agent prompt template:**

```
You are reviewing the following code changes. Apply your full review workflow.

## Git Diff

{paste the full git diff output here}

## Active Profiles and Resolved Checklists

{list of (profile, checklist, triggered_by) records from Step 1c, formatted as a flat tuple list — one record per line:
- profile: <name>, checklist: <checklist_filename>, triggered_by: <signal_type> — <signal_description>
- profile: <name>, checklist: <checklist_filename>, triggered_by: <signal_type> — <signal_description>
...
}

For each record, read the checklist at `<plugin_root>/profiles/<profile>/review-code/<checklist>` and apply it to the diff — `<plugin_root>` is the absolute plugin-root path the spawning skill substitutes into this prompt before sending it to you. If no profiles are active (empty list), fall back to general review guidance without profile-specific checklists.

## Spec Context

{spec excerpt from Step 1b, or "No spec context available — review based on code quality alone."}

{Task Scope block from Step 1f — either the populated scope artifact or the "No task scope available" variant}

## Rejected Approaches

{curated rejected approaches from Step 1e, or "No rejected approaches to note."}

Produce your findings in the output format specified in your agent definition.
```

### Reviewer B — `pal` codereview

Follow the invocation protocol in [shared-pal-codereview-invocation.md](shared-pal-codereview-invocation.md).

**`step` parameter (step 1):** Keep lean — framing + scope + spec summary + file manifest:

1. Framing: "Review the following code changes for correctness, security, architecture, and adherence to design intent. The diff, source files, review checklists, and design docs are provided as files."
2. Task Scope block from Step 1f.
3. One-paragraph spec context summary from Step 1b (or "No spec context available — review based on code quality alone.").
4. File manifest — categorized list of the paths in `relevant_files` so pal knows each file's role (see [shared-pal-codereview-invocation.md](shared-pal-codereview-invocation.md) §`step` content for format).

Do NOT inline the diff or file contents into `step`.

**`relevant_files` parameter:** Use the file list assembled in Step 1g.

**`model` parameter:** Use the model resolved in Step 1d.

### Parallel execution

Issue the pal step 1 call and the Agent tool call (Reviewer A) in the **same message** so they execute in parallel. When both return, make the pal step 2 continuation call using the `continuation_id` from step 1.

### Error handling

Handle reviewer failures inline as they occur:

- **`pal` failure** (listmodels returns no models, or codereview step 1/2 fails): Note the failure, proceed to Step 3 with code-reviewer findings only.
- **`code-reviewer` sub-agent failure** (timeout or error): Note the failure, proceed to Step 3 with pal findings only. Suggest `/kk:review-code` (standard mode) as supplement.
- **Both reviewers fail**: Abort isolated mode. Display message suggesting fallback to `/kk:review-code` (standard mode). Do not proceed to Step 3.
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

---

## Step 4: Index Findings

Index any P0/P1 findings that suggest a systemic or structural pattern (not isolated typos or one-off mistakes) as `kk:review-findings`. Index on first encounter — recurrence detection happens on the search side in future reviews. This applies to findings from any source — corroborated, single-reviewer, or author-sourced.

- If no P0/P1 systemic findings exist, explicitly note "No findings to index" and move on.
- This step is mandatory — do not skip it even if the review found no issues.

---

## Step 5: Present Report

Use this report template, organized by agreement level:

```markdown
## Review Summary (Isolated Mode)

**Reviewers**: code-reviewer (Claude sub-agent), pal codereview ([model name])
**Files reviewed**: X files, Y lines changed

---

### Corroborated Findings

(Both reviewers flagged — highest signal)

- **[file:line]** Brief title ⟨corroborated⟩
  - Profile: {profile_name} · Checklist: {checklist_filename}
  - Triggered by: {signal_type} — {signal_description}
  - code-reviewer: [severity] — [description]
  - pal: [description in native format]
  - Author context: [optional annotation]

### Code Reviewer Findings

(code-reviewer sub-agent only — P0-P3 format)

- **[file:line]** Brief title
  - Profile: {profile_name} · Checklist: {checklist_filename}
  - Triggered by: {signal_type} — {signal_description}
  - Severity: P[0-3] | Confidence: [X]%
  - [description and suggested fix]
  - Author context: [optional annotation]

### External Review Findings

(pal codereview — native format)

- [pal output presented in its native format]
  - Profile: {profile_name} · Checklist: {checklist_filename}
  - Triggered by: {signal_type} — {signal_description}
  - Author context: [optional annotation]

### Author-Sourced Findings

(Main agent observations during annotation — weight accordingly)

- **[file:line]** Brief title ⟨author-sourced⟩
  - Profile: generic · Checklist: —
  - Triggered by: —
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

The actionable items I recommend fixing:

1. P1 (corroborated) ...
2. P2 (code-reviewer) ...
3. P2 (pal) ...
4. P3 (corroborated) ...
5. P3 (author-sourced) ...

Items I recommend keeping as is:

- ...: the finding is a false-positive because ...
- ...: correct behavior because ...
- ...: mirrors production behavior of ...

**How would you like to proceed?**

1. **Fix all** — I'll implement all suggested fixes
2. **Fix corroborated + high severity** — Address corroborated findings and P0/P1 issues
3. **Fix specific items** — Tell me which issues to fix
4. **No changes** — Review complete, no implementation needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until the user explicitly confirms. This is a review-first workflow.

---

## Step 6: Verify Outputs

Before declaring the review complete, check each item in the **Required Outputs** section of SKILL.md:

- [ ] Review report presented to user
- [ ] P0/P1 systemic findings indexed as `kk:review-findings` (or explicitly noted "No findings to index")
- [ ] Next steps confirmation from user

If any item is unchecked, go back and complete it before proceeding.
