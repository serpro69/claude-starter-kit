## pal codereview invocation

`pal codereview` is a **multi-turn** tool. Step 1 outlines the review strategy; the expert analysis that produces actual findings runs as a follow-up. A single-step call returns zero findings.

### Step 1 — initial call

Use these parameters:

| Parameter | Value |
|---|---|
| `model` | The most capable model from `pal listmodels` |
| `step` | The content to review (document text or git diff), prefixed with a framing instruction |
| `step_number` | `1` |
| `total_steps` | `2` |
| `next_step_required` | `true` |
| `review_validation_type` | `"external"` (enables expert follow-up that produces findings) |
| `thinking_mode` | `"max"` |
| `review_type` | `"full"` |
| `findings` | `"Initial submission for review. No findings yet."` |
| `relevant_files` | Absolute paths of the files being reviewed |
| `confidence` | `"exploring"` |

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
