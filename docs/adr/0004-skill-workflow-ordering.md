# ADR 0004 — Skill workflow ordering: instructions before action

- **Status:** Accepted
- **Date:** 2026-04-19
- **Originated in:** [docs/wip/kubernetes-support/tasks.md — Task 7 dry-run findings](../wip/kubernetes-support/tasks.md)
- **Related:** [ADR 0002](0002-profile-content-organization.md), [ADR 0003](0003-plugin-root-referenced-content.md)

## Context

Every plugin skill drives the agent through a workflow: `review-code` reviews a diff, `implement` executes a task plan, `design` turns an idea into a PRD, `document` writes docs, `test` writes/runs tests, and so on. Each skill's workflow has two components — the **instructions** (SKILL.md, referenced process files, shared protocols, and — for profile-driven skills — resolved profile content) and the **subject matter** (the diff, the code, the idea prose, the feature tree). An agent running the skill must read both; the ordering between the two determines whether the skill's structured work actually happens.

The `review-code` skill provided the canonical failure example. Empirical observation from three consecutive `/kk:review-code` runs on the same diff surfaced a repeatable failure mode:

- **Run 1.** Skill loaded, but the agent already had a diff dump on disk. It produced a review from the diff alone without loading profile checklists or re-reading changed files. When pressed, the agent admitted: "I had the full diff visible, recognized the changes as a clean source-kind refactor, and decided I could pattern-match a review from the diff alone. I took the shortcut." A transient DB error provided cover but was not the cause.
- **Run 2.** Fresh session. Skill loaded from scratch. Agent read one process file, ran `git diff`, and launched into findings — still bypassing profile detection and checklist loading.
- **Run 3.** User explicitly asked the agent to "follow the review process exactly." Agent loaded 28 files but still diffed first, then circled back to read checklists after findings were already forming.

The shared thread: the skill's own workflow told the agent to **start with** `git diff` + re-read changed files (as "Preflight context"). Profile detection and checklist loading came in later steps. Once the agent had diff content loaded, it had enough context to pattern-match findings without the methodology — and an LLM's efficiency bias favors the path of least resistance. The methodology became a ceremony the agent could optimize away.

This is a workflow-ordering bug, not an agent-discipline bug. "Tell the model to follow the process" (Run 3) does not fix it, because the process itself prescribes the failure-prone order.

**The same failure mode applies to every skill, not just `review-code`.** An `implement` run that reads the code to modify before loading the per-task gotchas produces edits that miss profile-specific pitfalls. A `design` run that engages the idea prose before loading the question bank skips the refinement step. A `document` run that reads the feature tree before loading the profile rubric produces generic prose. The subject matter differs, the subject-matter-first shortcut is the same. The canonical case surfaced in `review-code` only because the three consecutive runs made the pattern legible; other skills have the same latent risk.

## Decision

**Every plugin skill MUST fully load its instructions before taking any action on its subject matter.**

"Instructions" means: `SKILL.md`, every process/rubric/protocol file it links to, every per-skill symlinked shared instruction, and — for skills that run profile detection — every profile file the detection procedure resolves (index + always-load content + matching conditional content). "Action on subject matter" means: reading diff content, re-reading changed files, writing or editing code, engaging with idea prose beyond the minimum needed to drive profile detection, running tests, emitting documentation, producing findings. Filename-level or metadata-level scope sufficient to drive profile detection is permitted early; content-level reading is not.

Concretely, every skill's workflow follows this shape:

1. **Instructions load first.** `SKILL.md` is already in context when the skill is invoked. The skill's first workflow steps read every process/rubric file referenced by `SKILL.md` and every shared protocol it links.
2. **Minimal scope for profile detection.** If the skill runs profile detection, it gathers the filename-level or metadata-level input required (`git diff --stat`, feature-directory listing, idea-prose keyword scan) — enough to identify active profiles, not enough to pattern-match subject-matter findings.
3. **Profile content loads before action.** Every `(profile, <phase>/<content>)` pair the detection procedure resolves is read via the `Read` tool. Index entries alone are not enough — the actual content must be in context so the skill acts *through* it, not *alongside* it.
4. **Only then** does the skill read content, modify code, emit findings, or produce artifacts.
5. **Content-level read instructions appear exactly once** in the workflow, after steps 1–3. Restating them earlier — even as a "Preflight" step — re-creates the failure mode.

Every skill's `SKILL.md` MUST carry an explicit **mandatory-order directive** at the top of its Workflow section, naming the rule by intent: *the flow is strictly sequential; do not begin acting on the subject matter until all instructions (SKILL.md, referenced process files, resolved profile content) are loaded; this ordering is load-bearing, not stylistic.* The process file(s) that SKILL.md references must match the directive — no late "Preflight" step pulling subject-matter reading back to the front.

The subject matter varies per skill:

| Skill | Subject matter | Minimal early scope |
|---|---|---|
| `review-code` | the diff | `git diff --stat` (filenames) |
| `review-spec` | the implementation tree | feature-directory listing (filenames) |
| `review-design` | the design doc | doc file list |
| `test` | the code under test | `git diff --stat` or feature listing |
| `implement` | the code to modify | the current task's target filenames |
| `design` | the idea prose | keyword scan of idea prose for the auto-trigger set |
| `document` | the feature tree | feature-directory listing |
| `merge-docs` | the two docs to merge | file list |
| `dependency-handling` | the lookup target | the call being written — name + signature, not full implementation |
| `chain-of-verification` | the response being verified | the response text (already in context) |

The specialization — "profile checklists/gotchas/rubrics are part of instructions and must load before subject-matter content" — continues to apply for every skill that runs profile detection.

### Scope boundary — what this ADR does not decide

- **Per-skill adoption pace.** This ADR binds the convention. Applying the mandatory-order directive to every existing skill's `SKILL.md` is a follow-up sweep tracked separately.
- **Sub-agent workflows.** When a skill spawns a sub-agent (e.g., `code-reviewer`, `design-reviewer`, `spec-reviewer`), the sub-agent's own workflow applies the same rule internally: read the provided payload's instruction/checklist files before analyzing the attached subject matter. Payload delivery order (the spawning skill putting instructions and diff in the same prompt) is not sufficient — the sub-agent must read-before-apply on its own side too. This ADR extends to agent files (`plugins/claude/agents/*.md`) on the same terms as skill files.

## Consequences

### Positive

- **Consistent review quality regardless of priming.** Whether the user pre-stages a diff on disk, invokes fresh, or re-runs after a session reload, the agent produces the same structured output. The Run-1 shortcut mode is eliminated because the agent cannot reach findings without first loading the checklists.
- **Ordering becomes testable.** A review's "checklists loaded" step has a concrete artifact (Read calls on specific files) that can be audited post-hoc. Run 3 passed the "agent follows the process" test but failed methodology-loading; with this ADR, that gap closes.
- **Compounds across skills.** The same ordering shape applies to `review-spec`, `review-design`, and `test` as those skills absorb profile-aware behavior.

### Negative

- **Slightly higher up-front latency.** One extra filename-only pass before the agent can start reading content. In practice this is a single `git diff --stat` call plus reading ~1–7 small checklist files (~2–6 KB each).
- **Authoring discipline required.** Skill authors must resist the ergonomic temptation to put "read the diff" as Step 1 because that's what a human reviewer does first. The skill author is writing a protocol for an LLM, not a human; the orderings differ.
- **Enforcement is convention, not mechanism.** The plugin has no runtime guardrail preventing a skill from listing steps in the wrong order. Enforcement relies on:
  - The mandatory-order directive at the top of each applicable SKILL.md (human-reviewed at PR time),
  - The workflow-phase summary in SKILL.md matching the detailed process file (human-reviewed),
  - Periodic real-world dry-runs surfacing drift (like the one that produced this ADR).

### Neutral

- Documentation cost. Each skill that adopts this ordering carries the mandatory-order directive inline, so a reader of that SKILL.md understands the rule without needing to find this ADR. The ADR is the rationale record; the directive is the runtime reminder.

## Verification

The ordering change was applied to `review-code` concurrently with the acceptance of this ADR:

- `skills/review-code/SKILL.md` — added the mandatory-order directive at the top of the Workflow section.
- `skills/review-code/review-process.md` — reordered so Step 1 is filename-only scope, Step 2 is profile detection, Step 3 loads profile `review-code/index.md` files, Step 4 reads every resolved checklist, Step 5 (new dedicated step) reads the full diff + re-reads changed files + runs `capy_search`, Step 6 applies checklists. Content-level read instructions appear exactly once, at Step 5.
- `plugins/claude/agents/code-reviewer.md` — same ordering applied to the sub-agent: read provided checklists before analyzing the injected diff.

A follow-up dry-run (three consecutive invocations on the same diff, mirroring the Context section's experiment) confirms whether the failure mode reproduces. The result is recorded in `docs/wip/kubernetes-support/tasks.md` Task 7.

Applying the mandatory-order directive to the remaining nine skills (`review-spec`, `review-design`, `test`, `implement`, `design`, `document`, `merge-docs`, `dependency-handling`, `chain-of-verification`) is tracked as amendment A2 in `docs/wip/kubernetes-support/design.md §Amendments`. The per-skill sweep needs tailored wording since each skill's subject matter and minimal early scope differ; it is deliberately staged as its own review pass rather than bundled into this commit.
