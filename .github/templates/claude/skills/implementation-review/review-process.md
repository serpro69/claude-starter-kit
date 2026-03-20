### Workflow

Copy this checklist and check off items as you complete them:

```
Implementation Review Progress:
- [ ] Step 1: Load feature documents
- [ ] Step 2: Determine review scope
- [ ] Step 3: Per-task verification
- [ ] Step 4: Cross-cutting concerns
- [ ] Step 5: Self-check and confidence assessment
- [ ] Step 6: Present findings
```

**Step 1: Load feature documents**

- Read `tasks.md` from `/docs/wip/[feature-name]/`
- Read the linked `design.md` and `implementation.md`
- If the feature name is not provided or ambiguous, list `/docs/wip/` contents and ask the user which feature to review
- If no WIP docs exist, inform the user and ask if they want to point to alternative documentation

**Step 2: Determine review scope**

Parse `tasks.md` for task statuses and determine the review mode:

- **Mid-implementation mode:** Only review tasks with status `done` or `in-progress`. Note pending tasks as out-of-scope. Summarize what percentage of the feature is reviewable.
- **Post-implementation mode:** All tasks are `done`. Review everything.

Build and present a checklist of tasks that will be reviewed.

**Step 3: Per-task verification**

For each in-scope task:

1. **Read the spec section** — follow the `Docs:` link in the task to the specific section of `implementation.md` or `design.md`
2. **Read the code** — use `serena` MCP (semantic code analysis), `grep`, and `Read` to find and examine the implemented code. Follow file paths and function names mentioned in the task subtasks.
3. **Compare systematically:**
   - For each subtask marked `[x]`: verify the code actually does what the subtask describes
   - For each requirement in the linked doc section: verify code implements it
   - For each piece of code in the relevant area: check if it matches what the docs describe
4. **Record findings** — for each mismatch, capture:
   - Finding type (`MISSING_IMPL`, `EXTRA_IMPL`, `SPEC_DEV`, `DOC_INCON`, `OUTDATED_DOC`, `AMBIGUOUS`)
   - Severity (P0–P3)
   - Preliminary confidence score
   - File and line reference in code
   - Section reference in docs
   - Description of the mismatch

**Step 4: Cross-cutting concerns**

After per-task review, check for broader issues:

- **Doc consistency:** Does `design.md` align with `implementation.md`? Do task descriptions in `tasks.md` match both?
- **Completeness:** Are there design decisions or requirements in docs that don't map to any task?
- **Emergent gaps:** Did implementation introduce behavior or requirements not captured in docs?
- **Integration points:** Do the implemented tasks work together as the design intended?

**Step 5: Self-check and confidence assessment**

This is the critical verification step. For **each finding** from Steps 3–4:

1. Re-read the relevant spec section and code independently
2. Ask: **"Could I be misreading the spec?"** — check for implicit requirements, context from other sections, or alternative interpretations
3. Ask: **"Could I be misreading the code?"** — trace execution paths, check for configuration or runtime behavior that might satisfy the spec differently
4. Ask: **"Is the spec or the code more likely correct?"** — consider which direction the finding points (code bug vs doc bug)
5. Assign final confidence score (1–10) with **explicit reasoning** documenting:
   - What was verified
   - What evidence supports the finding
   - What uncertainty remains
6. Downgrade or **remove** findings that don't survive the self-check

**Step 6: Present findings**

Structure the output as follows:

```markdown
## Implementation Review: [Feature Name]

**Scope:** [X of Y tasks reviewed] | Mode: [mid-implementation / post-implementation]
**Documents reviewed:**
- Design: [path]
- Implementation: [path]
- Tasks: [path]

**Summary:** [X findings: N critical, N high, N medium, N low]

---

## Findings

### Missing Implementation (MISSING_IMPL)

- **[P1] Brief title**
  - **Spec says:** [quote or paraphrase from docs, with file:section reference]
  - **Code status:** [what was found or not found, with file:line reference]
  - **Confidence:** 8/10 — [reasoning: checked X, verified Y, uncertainty about Z]
  - **Recommendation:** [what to do]

### Spec Deviation (SPEC_DEV)

...

### Outdated Doc (OUTDATED_DOC)

- **[P2] Brief title**
  - **Code does:** [what the code actually does, with file:line]
  - **Doc says:** [what the doc says, with file:section]
  - **Confidence:** 9/10 — [reasoning]
  - **Recommendation:** Update [doc file] section [X] to reflect [Y]

### Doc Inconsistency (DOC_INCON)

...

### Ambiguous Spec (AMBIGUOUS)

...

### Extra Implementation (EXTRA_IMPL)

...

---

## Clean Areas

[List tasks/areas that passed verification with no findings — confirms what was checked.]

---

## Doc Update Suggestions

[Consolidated list of documentation changes needed, separate from code changes.]
```

After presenting findings, ask the user how to proceed:

```markdown
---

## Next Steps

Found X issues across Y tasks (P0: ..., P1: ..., P2: ..., P3: ...).

**How would you like to proceed?**

1. **Fix code issues** — Address findings where code doesn't match spec
2. **Fix doc issues** — Update documentation to match implementation reality
3. **Fix both** — Address all findings
4. **Fix P0/P1 only** — Address critical and high priority issues
5. **Fix specific items** — Tell me which findings to address
6. **No changes** — Review complete, no action needed

Please choose an option or provide specific instructions.
```

**Important:** Do NOT implement any changes until the user explicitly confirms.
