# review-code eval harness — playbook

This playbook describes the orchestration an agent (typically the main Claude Code session) performs when the user asks to "run the review-code evals". It is the authoritative procedure — the scripts in this directory are only plumbing.

## Why this exists

The prior harness pattern (documented in `docs/wip/kubernetes-support/.sessions/task10-eval-runs.txt` and `rerun-eval-runs.txt`) had three structural weaknesses:

1. **Self-grading** — each reviewer sub-agent graded its own output.
2. **Rubric leakage** — reviewers saw the eval's `assertions` / `trap` while producing the review, which primes the model toward satisfying them.
3. **Fixture-only diff** — "diff scope" was enumerated in the prompt; no real `git diff` was performed, so scope-discovery was tested by instruction, not by git.

This playbook fixes all three. Multi-model sampling is deliberately deferred.

## Roles

This harness uses three sub-agents per eval, each with a narrowly scoped input, matching the real `/kk:review-code` invocation path:

- **Orchestrator** — the agent reading this playbook. Runs `setup.sh`, captures `git diff`, spawns the three sub-agents per eval, aggregates. Has full context (including assertions).
- **Profile resolver** — a `kk:profile-resolver` sub-agent, one per eval. Receives only the diff text + worktree root. Runs the shared profile-detection procedure. Emits a structured resolution (active profiles, per-file `triggered_by`, loaded/not-loaded checklists with Load-if reasoning). Does NOT see assertions, user intent, or fixture files beyond what the procedure inspects.
- **Reviewer** — a `kk:code-reviewer` sub-agent, one per eval. Receives exactly the contract it is designed for in isolated mode: the diff, the pre-resolved `(profile, checklist)` list from the profile resolver, and any spec context. Applies checklists, emits findings. Does NOT redo detection.
- **Grader** — a `kk:eval-grader` sub-agent, one per eval. Receives the profile resolver's output AND the reviewer's output, plus the eval's `assertions`. Grades each assertion against whichever artifact is relevant (routing assertions against resolver output; content/finding assertions against reviewer output). Does NOT see the fixture, the worktree, or any of the skill's source files.

**Why three agents.** Splitting detection from review mirrors the real isolated-mode invocation: the main session resolves profiles, then hands `kk:code-reviewer` a pre-resolved list (see `plugins/claude/agents/code-reviewer.md`'s "Active profiles and resolved checklists" contract). The orchestrator could resolve profiles inline, but doing so would (a) contaminate the orchestrator's context with every profile's `DETECTION.md` for every run, and (b) leak the orchestrator's knowledge of the eval assertions into the detection output. Delegating to `kk:profile-resolver` isolates detection structurally. The same agent is intended to be usable in production skill invocations that want to offload detection for context-management reasons.

## Procedure

### 1. Stage worktrees

```
skills/review-code/evals/_harness/setup.sh
```

Prints the absolute path of the stage dir on stdout. Capture it as `STAGE_DIR`. Under `STAGE_DIR` there is one git worktree per eval (`STAGE_DIR/<eval-name>/`) with the fixture files staged (`git diff --cached` shows them as added) on an empty base commit.

### 2. Capture the staged diff per eval

For each eval directory (siblings of `_harness/` that contain an `eval.json`), the orchestrator runs:

```
git -C <STAGE_DIR>/<eval-name> diff --cached
```

and captures the full output as `DIFF_TEXT`. Also capture `git diff --cached --name-only` as `FILE_LIST`. The orchestrator does this via `Bash`, inline — the sub-agents do not run git.

### 3. Spawn profile-resolver sub-agents (parallel)

Spawn one `kk:profile-resolver` sub-agent per eval, all in the same turn. Resolver prompt template:

```
Resolve profiles for the following staged diff. Follow your agent instructions.

Worktree root: <STAGE_DIR>/<eval-name>

Diff (git diff --cached):
---
<DIFF_TEXT>
---
```

Nothing else. No eval prompt, no assertions, no hints. Capture the resolver's output as `RESOLUTION` per eval.

### 4. Spawn kk:code-reviewer sub-agents (after resolver returns)

For each eval, once its resolver has returned, spawn `kk:code-reviewer` with the contract it expects in isolated mode. Reviewer prompt template:

```
Review the following staged diff against the resolved profiles + checklists.
Follow your agent instructions (isolated-mode contract).

Active profiles and resolved checklists (already resolved — do not re-detect):
---
<RESOLUTION>
---

Git diff (git diff --cached):
---
<DIFF_TEXT>
---
```

Do NOT inline assertions, `trap`, `description`, or the eval's user prompt. The `kk:code-reviewer` contract (see its `What You Receive` section) is exactly diff + resolved scope + optional spec/task-scope context — nothing else. Keep the harness faithful to that contract.

Reviewers can run in parallel across evals once each has its resolver output.

### 5. Spawn kk:eval-grader sub-agents (after reviewer returns)

For each eval, once its reviewer has returned, spawn `kk:eval-grader` with the resolver output, the reviewer output, and the eval's `assertions`. Grader prompt template:

```
Grade the following artifacts against the listed assertions. Follow your
agent instructions — you do not open fixture files or skill source to
verify claims. Routing assertions grade against the resolver output;
content and finding assertions grade against the reviewer output.

Assertions:
<JSON array of {id, text} copied from eval.assertions>

Profile-resolver output:
---
<RESOLUTION>
---

Reviewer output:
---
<REVIEWER_OUTPUT>
---
```

Graders can run in parallel across evals.

### 6. Aggregate

Collect the grader tables. Roll up into a single markdown table matching the format used by prior session notes:

```
| Eval | Assertions | Pass | Fail | Partial |
|---|---|---|---|---|
| k8s-workload-full | 1.1–1.8 (8) | N | M | K |
| ...
| **Total** | ... | ... | ... | ... |
```

Write a session note under `docs/wip/kubernetes-support/.sessions/` (filename pattern: `harness-<YYYY-MM-DD>-eval-runs.txt`) with: harness version reference (link back here), results table, per-eval highlights, and any new regressions vs prior runs.

### 7. (No teardown)

Stage dirs live under the OS temp root (`/tmp`, `/var/folders/.../T`, …). OS-level cleanup handles them — no manual teardown step.

## Remaining caveats

With this harness, caveats 1–3 from the prior session notes are resolved structurally. Remaining caveats to document on each run:

- **Single model** — still one model per sub-agent (default). Multi-model sampling is a separate, deferred improvement.
- **Grader scope** — graders judge from the resolver + reviewer output text; if a sub-agent produces confidently-wrong claims the assertions cannot cross-check, it's a known blind spot. Mitigation: when authoring new evals, prefer assertions whose satisfaction is observable in the captured outputs.
- **Rubric authoring discipline** — the assertion text IS the rubric the grader uses. Evals whose assertions quietly assume fixture knowledge produce noisy grades under this harness.
- **Assertion-to-artifact mapping** — routing assertions grade against resolver output; content assertions grade against reviewer output. If an assertion mixes concerns ("loaded checklist X and emitted finding Y under it"), the grader must inspect both artifacts. Author assertions to split cleanly when possible.

## Authoring notes

When adding a new eval under `skills/review-code/evals/`:

- The `test-files/` tree must be self-contained — `setup.sh` copies it verbatim into a fresh git repo, so any cross-reference (relative imports, file adjacency) must hold within `test-files/`.
- Keep `eval.prompt` natural — it reaches the reviewer only as framing context. Do not leak assertion language into it.
- Author assertions to be graded from captured output text (resolver or reviewer), not from fixture re-inspection.
