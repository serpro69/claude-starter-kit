## pal codereview invocation

`pal codereview` is a **multi-turn** tool. Step 1 outlines the review strategy; the expert analysis that produces actual findings runs as a follow-up. A single-step call returns zero findings.

### Step 1 — initial call

Use these parameters:

| Parameter | Value |
|---|---|
| `model` | The most capable model from `pal listmodels` |
| `step` | Framing instruction + task scope + spec context summary (see §`step` content below). Keep it lean — file contents belong in `relevant_files`, not here |
| `step_number` | `1` |
| `total_steps` | `2` |
| `next_step_required` | `true` |
| `review_validation_type` | `"external"` (enables expert follow-up that produces findings) |
| `thinking_mode` | `"max"` |
| `review_type` | `"full"` |
| `findings` | `"Initial submission for review. No findings yet."` |
| `relevant_files` | Absolute paths — see §Assembling `relevant_files` below |
| `confidence` | `"exploring"` |

#### `step` content

The `step` field carries the review framing — not the diff or file contents. Structure it as:

1. **Framing instruction** — what kind of review this is and what to focus on.
2. **Task scope block** — in-scope vs out-of-scope tasks (prevents false positives on pending work).
3. **Spec context summary** — one-paragraph design intent if available ("No spec context available" otherwise).
4. **File manifest** — a categorized list of the paths in `relevant_files`, explaining each file's role. Paths only, no contents. Example:

   ```
   Files provided via relevant_files:
   - Diff: /tmp/kk-review-code-a1b2c3d4.patch
   - Changed: src/service.go, src/handler.go
   - Surrounding: src/types.go, src/middleware.go
   - Review checklists: .../profiles/go/review-code/solid-checklist.md
   - Design: docs/wip/auth-refactor/design.md, implementation.md
   ```

   This tells pal which files are code under review, which are review criteria to apply, and which provide design intent. Without it, pal may treat checklists as code to review rather than guidance to follow.

Do NOT inline file contents into `step`. These are passed via `relevant_files` — pal reads them with proper token budgeting and deduplication.

#### Assembling `relevant_files`

The caller assembles this list from artifacts gathered during preparation. All paths must be absolute. Categories, in order:

1. **Diff file** — the git diff written to a temp file via `mktemp` (e.g., `/tmp/kk-review-code-XXXXXXXX.patch`). The caller writes this file; pal reads it. Clean up after the review completes.
2. **Changed source files** — every file touched by the diff. These give pal the full file context around each change.
3. **Surrounding code files** — direct imports, callers, interfaces, and type definitions referenced by the changed code. These enable cross-file reasoning (e.g., verifying a called function's signature, checking convention consistency with adjacent files). The caller identifies these by scanning imports and references in the diff.
4. **Profile checklist files** — resolved `(profile, checklist)` file paths from profile detection (e.g., `<plugin_root>/profiles/go/review-code/solid-checklist.md`). These give pal the same domain-specific review criteria as the sub-agent reviewer.
5. **Design/implementation docs** — `design.md` and `implementation.md` from the feature's `docs/wip/<feature>/` directory, when available. These enable pal to flag spec deviations, not just code smells.

The caller is responsible for collecting these paths during its preparation steps and passing the assembled list here. pal handles file reading, token budgeting, and cross-turn deduplication internally.

### Step 2 — continuation call

After step 1 returns, make a follow-up call using the `continuation_id` from the step 1 response:

| Parameter | Value |
|---|---|
| `model` | Same model as step 1 |
| `continuation_id` | From step 1 response |
| `step` | `"Produce the expert analysis and final findings based on the review in step 1."` |
| `step_number` | `2` |
| `total_steps` | `2` |
| `next_step_required` | `false` |
| `findings` | Copy `findings` from step 1 response (or summarize if too large) |
| `confidence` | `"high"` |

### Parallel execution with sub-agents

The step 1 call can be issued in the same message as the sub-agent (Agent tool) call — they execute in parallel. When both return, make the pal step 2 continuation call. The sub-agent typically takes longer than pal step 1, so the continuation call adds minimal wall-clock time.

### Failure modes

- `listmodels` returns no models → skip pal, proceed with sub-agent findings only
- Step 1 succeeds but step 2 fails → use any findings from step 1 response
- Both steps return zero issues → treat as a soft failure (pal produced no signal); note in the report and proceed with sub-agent findings

`pal` is an external model with no conversation context — naturally isolated. Its output stays in **native format** — do NOT map it to the skill's finding types or severity levels.
