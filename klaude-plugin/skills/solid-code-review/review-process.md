### Workflow

Copy this checklist and check off items as you complete them:

```
Code Review Progress:
- [ ] Step 1: Preflight context
- [ ] Step 2: Detect primary language
- [ ] Step 3: SOLID + architecture smells
- [ ] Step 4: Removal candidates + iteration plan
- [ ] Step 5: Security and reliability scan
- [ ] Step 6: Code quality scan
- [ ] Step 7: Self-check and confidence assessment
- [ ] Step 8: Index findings
- [ ] Step 9: Present results
- [ ] Step 10: Next steps confirmation
- [ ] Step 11: Verify outputs
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

### 2) Detect primary language

From the `git diff --stat` output in step 1, identify the primary language of changed files by extension:

| Extensions                                   | Reference set       |
| -------------------------------------------- | ------------------- |
| `.go`                                        | `reference/go/`     |
| `.js`, `.ts`, `.jsx`, `.tsx`, `.mjs`, `.cjs` | `reference/js_ts/`  |
| `.py`, `.pyw`                                | `reference/python/` |
| `.java`                                      | `reference/java/`   |
| `.kt`, `.kts`                                | `reference/kotlin/` |

- **Single language**: Use that language's reference directory for all subsequent steps.
- **Mixed languages**: Load references from each relevant directory.
- **No match**: Skip language-specific reference loading; apply only the general guidance in each step.

Use `{lang}` below to refer to the detected reference directory.

### 3) SOLID + architecture smells

- Load [reference/{lang}/solid-checklist.md](./reference/{lang}/solid-checklist.md) for specific prompts.
- Look for:
  - **SRP**: Overloaded modules with unrelated responsibilities.
  - **OCP**: Frequent edits to add behavior instead of extension points.
  - **LSP**: Subclasses that break expectations or require type checks.
  - **ISP**: Wide interfaces with unused methods.
  - **DIP**: High-level logic tied to low-level implementations.
- When you propose a refactor, explain _why_ it improves cohesion/coupling and outline a minimal, safe split.
- If refactor is non-trivial, propose an incremental plan instead of a large rewrite.

### 4) Removal candidates + iteration plan

- Load [reference/{lang}/removal-plan.md](./reference/{lang}/removal-plan.md) for template.
- Identify code that is unused, redundant, or feature-flagged off.
- Distinguish **safe delete now** vs **defer with plan**.
- Provide a follow-up plan with concrete steps and checkpoints (tests/metrics).

### 5) Security and reliability scan

- Load [reference/{lang}/security-checklist.md](./reference/{lang}/security-checklist.md) for coverage.
- Check for:
  - XSS, injection (SQL/NoSQL/command), SSRF, path traversal
  - AuthZ/AuthN gaps, missing tenancy checks
  - Secret leakage or API keys in logs/env/files
  - Rate limits, unbounded loops, CPU/memory hotspots
  - Unsafe deserialization, weak crypto, insecure defaults
  - **Race conditions**: concurrent access, check-then-act, TOCTOU, missing locks
- Call out both **exploitability** and **impact**.

### 6) Code quality scan

- Load [reference/{lang}/code-quality-checklist.md](./reference/{lang}/code-quality-checklist.md) for coverage.
- Check for:
  - **Error handling**: swallowed exceptions, overly broad catch, missing error handling, async errors
  - **Performance**: N+1 queries, CPU-intensive ops in hot paths, missing cache, unbounded memory
  - **Boundary conditions**: null/undefined handling, empty collections, numeric boundaries, off-by-one
- Flag issues that may cause silent failures or production incidents.

### 7) Self-check and confidence assessment

This is the critical verification step. For **each finding** from Steps 3–6:

1. Re-read the relevant code and surrounding context independently
2. Ask: **"Could I be misreading the code?"** — trace execution paths, check for runtime behavior, configuration, or framework conventions that might make this correct
3. Ask: **"Is this a real issue or a style preference?"** — distinguish between bugs/risks and subjective choices that don't affect correctness or security
4. Ask: **"What's the actual impact?"** — verify that the severity matches the real-world consequence, not just the theoretical violation
5. Assign final confidence score (1–100%) with **explicit reasoning** documenting:
   - What was verified
   - What evidence supports the finding
   - What uncertainty remains
6. Downgrade or **remove** findings that don't survive the self-check

### 8) Index findings

Index any P0/P1 findings that suggest a systemic or structural pattern (not isolated typos or one-off mistakes) as `kk:review-findings`. Index on first encounter — recurrence detection happens on the search side in future reviews.

- If no P0/P1 systemic findings exist, explicitly note "No findings to index" and move on.
- This step is mandatory — do not skip it even if the review found no issues.

### 9) Present results

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

### 10) Next steps confirmation

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

### 11) Verify outputs

Before declaring the review complete, check each item in the **Required Outputs** section of SKILL.md:

- [ ] Review report presented to user
- [ ] P0/P1 systemic findings indexed as `kk:review-findings` (or explicitly noted "No findings to index")
- [ ] Next steps confirmation from user

If any item is unchecked, go back and complete it before proceeding.
