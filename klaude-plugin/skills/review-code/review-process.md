### Workflow

**Read [SKILL.md §Mandatory ordering — methodology before evidence](./SKILL.md#mandatory-ordering--methodology-before-evidence) before executing this file.** The steps below are strictly sequential. Do not read diff content, re-read changed files, or run `capy_search` before Step 5. Until then, `git diff --stat` (filenames only) is the only contact you have with the changes.

Copy this checklist and check off items as you complete them:

```
Code Review Progress:
- [ ] Step 1: Scope (filenames only)
- [ ] Step 2: Detect active profiles
- [ ] Step 3: Load profile review indexes (filename-evaluable entries)
- [ ] Step 4: Read resolved checklists
- [ ] Step 5: Read diff + re-read changed files + capy search
- [ ] Step 6: Resolve content-evaluable conditional entries
- [ ] Step 7: Apply checklists
- [ ] Step 8: Self-check and confidence assessment
- [ ] Step 9: Index findings
- [ ] Step 10: Present results
- [ ] Step 11: Next steps confirmation
- [ ] Step 12: Verify outputs
```

---

### 1) Scope (filenames only)

Run `git status -sb` and `git diff --stat` to get the list of touched files. **Do not run `git diff` yet** — the full diff enters context in Step 5, after methodology is loaded.

**Edge cases:**

- **No changes**: If `git diff --stat` is empty, inform user and ask if they want to review staged changes or a specific commit range.
- **Large diff (>500 lines)**: Proceed through Steps 2–4 normally; Step 5 covers batching.
- **Mixed concerns**: Note the spread for Step 9 output; grouping happens at findings-emit time.

### 2) Detect active profiles

Delegate to [shared-profile-detection.md](shared-profile-detection.md). Input: the filename list from Step 1. The shared procedure iterates its own §Known profiles list and reads each profile's `DETECTION.md` via the `Read` tool — no filesystem enumeration, no `Glob`.

The shared procedure returns a list of records:

```
[{ profile: "<name>", triggered_by: [...], files: [...] }, ...]
```

Hold this list for Step 3. There is no single "primary language"; any number of profiles can be active on the same diff (e.g., `go` + `k8s` when a Go service ships a Helm chart).

If the list is empty (no profile matched), skip Steps 3–4's profile-specific loading and proceed to Step 5 with general guidance only.

### 3) Load profile review indexes

For each active profile record from Step 2:

1. Read `<plugin_root>/profiles/<profile>/review-code/index.md`, where `<plugin_root>` is the absolute plugin-root path you already know from SKILL.md context.
2. Collect every entry under **Always load**.
3. For every conditional entry (**Load if:** predicate), classify the predicate:
   - **Filename-evaluable** — the predicate is satisfied by filenames, extensions, or directory names alone (e.g., "diff contains `Chart.yaml`", "file under `bases/` or `overlays/`"). Evaluate now against the filename list from Step 1. If it matches, collect the entry into the `(profile, checklist)` list.
   - **Content-evaluable** — the predicate requires inspecting file bytes (e.g., YAML `kind:` field values, `apiVersion:` keys, specific string anchors). Do **not** read file content here. Instead, append the entry to a **deferred list** keyed by `(profile, checklist, predicate)` — Step 6 resolves this list after Step 5 reads content.
4. Append the collected filename-evaluable entries to the flat `(profile, checklist)` list.

Do NOT hardcode checklist names — the index is authoritative, and new profiles or new conditional entries take effect without edits to this file.

### 4) Read resolved checklists

For each `(profile, checklist)` record from Step 3, use the `Read` tool on `<plugin_root>/profiles/<profile>/review-code/<checklist>`. Every checklist file enters context now, before any diff content does. The review that follows in Step 6 reads *through* these checklists; if they are not loaded, the review cannot happen.

This is the single load-bearing gate of the workflow. If a checklist read fails (file missing, path unresolved), stop and surface the error — do not proceed with partial methodology.

### 5) Read the diff, re-read changed files, run capy search

Now, with every checklist in context, read the content:

- Run `git diff` (full output) to capture the changes.
- **Re-read every changed file** using the Read tool. Do NOT rely on file contents read earlier in the conversation — code may have changed since (e.g., fixes applied between reviews in the same session).
- If needed, use `serena` mcp, `rg`, or `grep` to find related modules, usages, and contracts.
- Identify entry points, ownership boundaries, and critical paths (auth, payments, data writes, network).
- **Capy search:** Search `kk:review-findings` for prior findings in the same files/modules. For each programming-language profile active (from Step 2), search `kk:lang-idioms` for best practices. If `kk:lang-idioms` returns no results for a language, optionally use `capy_fetch_and_index` to fetch a canonical idioms resource (e.g., Effective Go for `go`) and label it `kk:lang-idioms`. Skip the lookup for non-language profiles (e.g., `k8s`) — `kk:lang-idioms` is a programming-language idiom store.

This is the only step that reads artifact content. It appears once, by design. Do not repeat `git diff` or file re-reads in later steps.

### 6) Resolve content-evaluable conditional entries

For every `(profile, checklist, predicate)` record on the deferred list from Step 3:

1. Evaluate the predicate against the file content now available from Step 5. Apply the same bounded-inspection rules as the shared profile-detection procedure — ~16 KB per file; multi-document YAML inspected per `---`-separated block.
2. If the predicate matches, use the `Read` tool on `<plugin_root>/profiles/<profile>/review-code/<checklist>` to load the checklist into context, then append `(profile, checklist)` to the flat list that Step 7 iterates.
3. If the predicate does not match, drop the entry silently — no checklist is loaded for it.

If the deferred list is empty (no profile contributed a content-evaluable conditional), this step is a no-op. Proceed to Step 7.

The deferred list exists so Step 3 can remain a filenames-only step (per the mandatory ordering in SKILL.md) while conditionals that genuinely require content — e.g., loading `reliability-checklist.md` on diffs that contain a `kind: Deployment` YAML document — still reach Step 7. Content-evaluable conditionals that bypass this step will be silently dropped.

### 7) Apply checklists

Iterate the flat `(profile, checklist, triggered_by)` list — the union of Step 3's filename-evaluable entries (whose checklists were read in Step 4) and Step 6's content-evaluable entries (whose checklists were read in Step 6 itself). For each record, apply the checklist (already in context) to the diff (in context from Step 5). A checklist may cover SOLID/architecture, security, quality, removal, or a profile-specific concern (e.g., Helm template correctness, RBAC least privilege) — the checklist itself states what to look for.

Tag each finding with its `(profile, checklist)` origin and the `triggered_by` signal from Step 2's detection output. These materialize as per-finding sub-labels inside the severity-major template in Step 10 — not as separate profile-grouped sections. For generic findings (SOLID, security, code quality, removal) not sourced from a profile checklist, use `Profile: generic · Checklist: —` and `Triggered by: —`.

General guidance that applies regardless of profile — apply these categories on every diff, whether or not a profile-specific checklist covered them:

- **SOLID / architecture:** SRP violations (overloaded modules with unrelated responsibilities), OCP (frequent edits to add behavior instead of extension points), LSP (subclasses that break expectations or require type checks), ISP (wide interfaces with unused methods), DIP (high-level logic tied to low-level implementations). When you propose a refactor, explain _why_ it improves cohesion/coupling and outline a minimal, safe split. If refactor is non-trivial, propose an incremental plan instead of a large rewrite.
- **Security / reliability:** XSS, injection (SQL/NoSQL/command), SSRF, path traversal; AuthZ/AuthN gaps, missing tenancy checks; secret leakage or API keys in logs/env/files; rate limits, unbounded loops, CPU/memory hotspots; unsafe deserialization, weak crypto, insecure defaults; race conditions, check-then-act, TOCTOU, missing locks. Call out both **exploitability** and **impact**.
- **Code quality:** error handling (swallowed exceptions, overly broad catch, missing handling, async errors); performance (N+1 queries, CPU-intensive ops in hot paths, missing cache, unbounded memory); boundary conditions (null/undefined, empty collections, numeric boundaries, off-by-one). Flag issues that may cause silent failures or production incidents.
- **Removal candidates:** unused, redundant, or feature-flagged-off code. Distinguish **safe delete now** vs **defer with plan**; provide concrete follow-up steps with checkpoints (tests/metrics).

### 8) Self-check and confidence assessment

For **each finding** from Step 7:

1. Re-read the relevant code and surrounding context independently.
2. Ask: **"Could I be misreading the code?"** — trace execution paths, check for runtime behavior, configuration, or framework conventions that might make this correct.
3. Ask: **"Is this a real issue or a style preference?"** — distinguish between bugs/risks and subjective choices that don't affect correctness or security.
4. Ask: **"What's the actual impact?"** — verify that the severity matches the real-world consequence, not just the theoretical violation.
5. Assign final confidence score (1–100%) with **explicit reasoning** documenting:
   - What was verified
   - What evidence supports the finding
   - What uncertainty remains
6. Downgrade or **remove** findings that don't survive the self-check.

### 9) Index findings

Index any P0/P1 findings that suggest a systemic or structural pattern (not isolated typos or one-off mistakes) as `kk:review-findings`. Index on first encounter — recurrence detection happens on the search side in future reviews.

- If no P0/P1 systemic findings exist, explicitly note "No findings to index" and move on.
- This step is mandatory — do not skip it even if the review found no issues.

### 10) Present results

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
  - Profile: {profile_name} · Checklist: {checklist_filename}
  - Triggered by: {signal_type} — {signal_description}
  - Description of issue
  - Confidence: 90% - reasoning behind the confidence level
  - Suggested fix

- **[another_file:line]** Brief title
  - Profile: generic · Checklist: —
  - Triggered by: —
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

### 11) Next steps confirmation

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

### 12) Verify outputs

Before declaring the review complete, check each item in the **Required Outputs** section of SKILL.md:

- [ ] Review report presented to user
- [ ] P0/P1 systemic findings indexed as `kk:review-findings` (or explicitly noted "No findings to index")
- [ ] Next steps confirmation from user

If any item is unchecked, go back and complete it before proceeding.
