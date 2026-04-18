### Workflow

Copy this checklist and check off items as you complete them:

```
Code Review Progress:
- [ ] Step 1: Preflight context
- [ ] Step 2: Detect active profiles
- [ ] Step 3: Load profile review indexes
- [ ] Step 4: Apply checklists
- [ ] Step 5: Self-check and confidence assessment
- [ ] Step 6: Index findings
- [ ] Step 7: Present results
- [ ] Step 8: Next steps confirmation
- [ ] Step 9: Verify outputs
```

---

### 1) Preflight context

- Use `git status -sb`, `git diff --stat`, and `git diff` to scope changes.
- **Re-read every changed file** using the Read tool before reviewing. Do NOT rely on file contents read earlier in the conversation — code may have changed since (e.g., fixes applied between reviews in the same session).
- If needed, use `serena` mcp, `rg` or `grep` to find related modules, usages, and contracts.
- Identify entry points, ownership boundaries, and critical paths (auth, payments, data writes, network).
- **Capy search:** Search `kk:review-findings` for prior findings in the same files/modules. Search `kk:lang-idioms` for best practices in the detected language. If `kk:lang-idioms` returns no results for the detected language, optionally use `capy_fetch_and_index` to fetch a well-known idioms resource (e.g., Effective Go for `.go` files) and label it `kk:lang-idioms`.

**Edge cases:**

- **No changes**: If `git diff` is empty, inform user and ask if they want to review staged changes or a specific commit range.
- **Large diff (>500 lines)**: Summarize by file first, then review in batches by module/feature area.
- **Mixed concerns**: Group findings by logical feature, not just file order.

### 2) Detect active profiles

Delegate to [shared-profile-detection.md](shared-profile-detection.md). For `review-code`, the detection input is the git diff scoped to the set of touched files (captured in Step 1).

The shared procedure returns a list of records:

```
[{ profile: "<name>", triggered_by: [...], files: [...] }, ...]
```

Hold this list for Step 3. It replaces the former extension-table lookup: there is no single "primary language"; any number of profiles can be active on the same diff (e.g., `go` + `k8s` when a Go service ships a Helm chart).

If the list is empty (no profile matched), skip Steps 3–4's profile-specific loading and apply only the general guidance embedded in this file when reviewing.

### 3) Load profile review indexes

For each active profile record from Step 2:

1. Resolve `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>/review-code/index.md`.
2. Read the index. Collect every entry under **Always load**.
3. For every conditional entry (**Load if:** predicate), evaluate the predicate against the diff. If it matches, collect the entry.
4. Append the collected entries to a flat list keyed by `(profile, checklist filename)`.

The resulting list is the complete set of checklists to apply. Do NOT hardcode checklist names here — the index is authoritative, and new profiles (or new conditional entries added to existing profiles) take effect without edits to this file.

### 4) Apply checklists

Iterate the `(profile, checklist)` list from Step 3. For each pair:

1. Read the checklist file at `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>/review-code/<checklist>`.
2. Apply the checklist to the diff. A checklist may cover SOLID/architecture, security, quality, removal, or a profile-specific concern (e.g., Helm template correctness, RBAC least privilege) — the checklist itself states what to look for.
3. Emit findings using `(profile, checklist)` as the grouping key so the report in Step 7 can organize them.

General guidance that applies regardless of profile:

- When you propose a refactor, explain _why_ it improves cohesion/coupling and outline a minimal, safe split. If refactor is non-trivial, propose an incremental plan instead of a large rewrite.
- Call out both **exploitability** and **impact** on security findings.
- Flag issues that may cause silent failures or production incidents.
- Distinguish **safe delete now** vs **defer with plan** on removal findings; provide concrete follow-up steps with checkpoints (tests/metrics).

### 5) Self-check and confidence assessment

This is the critical verification step. For **each finding** from Step 4:

1. Re-read the relevant code and surrounding context independently
2. Ask: **"Could I be misreading the code?"** — trace execution paths, check for runtime behavior, configuration, or framework conventions that might make this correct
3. Ask: **"Is this a real issue or a style preference?"** — distinguish between bugs/risks and subjective choices that don't affect correctness or security
4. Ask: **"What's the actual impact?"** — verify that the severity matches the real-world consequence, not just the theoretical violation
5. Assign final confidence score (1–100%) with **explicit reasoning** documenting:
   - What was verified
   - What evidence supports the finding
   - What uncertainty remains
6. Downgrade or **remove** findings that don't survive the self-check

### 6) Index findings

Index any P0/P1 findings that suggest a systemic or structural pattern (not isolated typos or one-off mistakes) as `kk:review-findings`. Index on first encounter — recurrence detection happens on the search side in future reviews.

- If no P0/P1 systemic findings exist, explicitly note "No findings to index" and move on.
- This step is mandatory — do not skip it even if the review found no issues.

### 7) Present results

#### Output format

Structure your review as follows:

```markdown
## Code Review Summary

**Files reviewed**: X files, Y lines changed
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical

(none or list)

### P1 - High

- **[file:line]** Brief title
  - Description of issue
  - Confidence: 90% - reasoning behind the confidence level
  - Suggested fix

- **[another_file:line]** Brief title
  - Description of issue
  - Confidence: 60% - reasoning behind the confidence level
  - Suggested fix

### P2 - Medium

...

### P3 - Low

...

---

## Removal/Iteration Plan

(if applicable)

## Additional Suggestions

(optional improvements, not blocking)
```

**Inline comments**: Use this format for file-specific findings:

```
::code-comment{file="path/to/file" line="42" severity="P1"}
Description of the issue and suggested fix.
::
```

**Clean review**: If no issues found, explicitly state:

- What was checked
- Any areas not covered (e.g., "Did not verify database migrations")
- Residual risks or recommended follow-up tests

### 8) Next steps confirmation

After presenting findings, ask user how to proceed:

```markdown
---

## Next Steps

I found X issues (P0: ..., P1: ..., P2: ..., P3: ...).

**How would you like to proceed?**

1. **Fix all** - I'll implement all suggested fixes
2. **Fix P0/P1 only** - Address critical and high priority issues
3. **Fix specific items** - Tell me which issues to fix
4. **No changes** - Review complete, no implementation needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until user explicitly confirms. This is a review-first workflow.

### 9) Verify outputs

Before declaring the review complete, check each item in the **Required Outputs** section of SKILL.md:

- [ ] Review report presented to user
- [ ] P0/P1 systemic findings indexed as `kk:review-findings` (or explicitly noted "No findings to index")
- [ ] Next steps confirmation from user

If any item is unchecked, go back and complete it before proceeding.
