# Design Review v2: Isolated Review Agents

**Spec reviewed:** `docs/wip/isolated-review-agents/design.md`
**Prior review:** `design-review-v1.md` — this review supersedes it
**Date:** 2026-04-03
**Verdict:** Conditionally approve — architecture is sound, reconciliation model needs rework, several design gaps to fill.

---

## Context

The feature adds isolated sub-agent review modes to `solid-code-review` and `implementation-review` skills. Sub-agents spawned via Claude Code's Agent tool review code/spec conformance without access to the implementation session's conversation history, then findings are presented to the user in a consolidated report.

**Key constraint:** The entire implement-test-review cycle runs within a single session (context window). Starting a new session just to do a review, then passing those results back to the first session to fix, is terrible UX. Sub-agents are the only mechanism that provides review isolation without breaking the session.

---

## Approved Aspects

These are sound and should not change:

- **Sub-agent architecture** is the right call given the single-session constraint.
- **Dual-provider code review** (`code-reviewer` Claude sub-agent + `pal codereview` external model) gives statistically independent perspectives with zero shared token cost. Different model families have uncorrelated blind spots.
- **Invariant #1 (no silent drops)** — every sub-agent finding must appear in the final report. Correct.
- **Finding type taxonomy** (`MISSING_IMPL` / `EXTRA_IMPL` / `SPEC_DEV` / `DOC_INCON` / `OUTDATED_DOC` / `AMBIGUOUS`) is comprehensive and actionable.
- **Isolation boundary definition** — authorship and session context, not knowledge. Sub-agents get full design rationale. This is the right distinction.
- **Opt-in, not default** — isolated review costs more. Users choose when extra rigor is worth it.

---

## Issues and Recommended Changes

### 1. Reconciliation Model: User Reconciles, Agent Annotates

**Severity:** P0 — architectural change to the reconciliation flow

**Problem:** The design has the main agent (the code author) assign dispositions to every sub-agent finding. This isn't a fatal flaw — author-reconciles-reviewer-findings is how real code review works (author responds to PR comments, reviewer validates the response, repeat). The problem is that the design makes it **one-shot**: the sub-agent makes its case, the main agent assigns a disposition, and there's no reviewer follow-up. In a real PR, the reviewer can push back on the author's pushback.

More concretely, the concern is **presentation bias**: if the main agent marks 8 of 10 findings as "Disputed — Intentional" with plausible-sounding justifications, the user reads a report already framed as "mostly false positives." That framing influences how critically the user evaluates each finding — they're in confirmation mode rather than evaluation mode.

The user IS the final arbiter either way. But presenting findings neutrally with the agent's context as a separate annotation (rather than a disposition) puts the user in a better position to judge.

**Recommended change:**

Remove the disposition system. Replace reconciliation with **annotation**:

1. Present findings from all reviewers directly to the user, organized by agreement level:
   - **Both reviewers flagged** (highest signal)
   - **Single reviewer flagged** (evaluate individually)
2. For each finding, the main agent may add a **context annotation** — implementation context that explains the decision ("I chose bcrypt cost 10 instead of 12 because the auth service benchmarks showed cost 12 added 400ms to login latency"). This is clearly labeled as author context, not a judgment.
3. The user reads: finding, reviewer attribution, optional author context note, and decides what to do.

This is simpler (no disposition categories, no disposition rules, no "Disputed" reasoning), more honest (no author pre-filtering), and still lets the agent provide its implementation context where relevant.

**What this removes:**
- The four disposition categories (Confirmed, Disputed — Intentional, Disputed — False Positive, Duplicate)
- The disposition rules and required evidence table
- The "main agent reconciles" phase as currently designed

**What this keeps:**
- Duplicate merging (when both reviewers flag the same logical issue, merge into one entry and note agreement)
- Author context annotations (the agent's implementation knowledge is valuable — it just shouldn't be a judgment)
- The user as final arbiter

**Impact on shared reconciliation protocol:** The `review-reconciliation-protocol.md` needs significant rework. See issue #6 below.

### 2. Agreement Increases Confidence, Not Severity

**Severity:** P1 — incorrect escalation rule

**Problem:** Invariant 4 states: "Agreement between independent reviewers increases effective severity by one level (e.g., P2 flagged by both becomes recommended-P1)."

Severity is determined by impact — how bad is this issue if it ships? Two reviewers both noticing a naming inconsistency (P3) doesn't make it a code smell (P2). The issue's impact hasn't changed. What agreement increases is **confidence** — you're more sure the finding is real, not that it's more important.

This rule systematically inflates severity on easy-to-spot issues (which both reviewers will find) while leaving genuinely subtle high-severity issues (which only one reviewer catches) at their original level. It's backwards.

**Recommended change:**

- Agreement adds a **"corroborated"** tag to the finding, indicating independent confirmation.
- Severity stays as the reviewer(s) assessed it.
- If reviewers disagree on severity for the same finding, show both assessments and let the user judge.

### 3. Allow Main Agent Findings, Tagged as Author-Sourced

**Severity:** P1 — invariant #2 is counterproductive

**Problem:** Invariant 2 states: "The main agent cannot add new findings that weren't flagged by any reviewer (it already had its chance during implementation)."

Review is a different cognitive mode than implementation. Reading someone else's review frequently triggers "oh, they found X — and now that I look at it, Y is a related issue they missed." This is normal and valuable in human code review. The justification "you already had your chance" assumes implementation and review are the same task. The entire design document argues they're different — that's why isolated reviewers exist.

**Recommended change:**

- Remove invariant #2.
- The main agent MAY add findings during annotation, but they MUST be clearly tagged as **"author-sourced"** (distinct from sub-agent findings).
- This is transparent — the user knows these come from the author and can weight them accordingly.

### 4. Add Error Handling

**Severity:** P1 — completely absent, will cause failures in production

**Problem:** The `cove-isolated` workflow (which this design cites as a pattern) has explicit handling for sub-agent timeout, single sub-agent failure (fallback), and all sub-agents failing (abort). The review isolated workflows have **none of this**.

What happens when:
- The `code-reviewer` sub-agent times out?
- `pal` is unavailable or rate-limited?
- The diff is too large for the sub-agent's context window?
- The sub-agent produces malformed output that doesn't match the expected P0-P3 structure?

**Recommended change:**

Add error handling to both `review-isolated.md` workflows, modeled on `cove-isolated.md`:

**Sub-agent timeout or failure:**
- If one reviewer fails but the other succeeds: present the successful reviewer's findings. Note the failure and suggest the user run the standard (non-isolated) review as a supplement if they want a second opinion.
- If both reviewers fail (code review only): abort isolated mode. Display a message suggesting the user fall back to `/kk:solid-code-review` (standard mode).

**pal unavailable:**
- If `pal listmodels` returns no models or `pal codereview` fails: proceed with the `code-reviewer` sub-agent findings only. Note that the external model review was unavailable.

**Malformed output:**
- If the sub-agent's output doesn't match the expected structure: attempt best-effort parsing. If completely unparseable, treat as a failure (see above).

**Large diff:**
- The sub-agent handles batching internally (already noted in the design). No additional handling needed, but document the context window limit and what happens when it's exceeded.

### 5. Define pal codereview Output Mapping

**Severity:** P1 — hand-waved in the design, will cause inconsistent reconciliation

**Problem:** Step 3a of `review-isolated.md` says: "Parse the pal codereview output and map its findings to P0-P3 severity levels." But pal codereview has its own format, its own severity concepts, and its own output structure. The mapping is non-trivial and lossy. The design provides zero guidance.

Additionally, pal codereview supports follow-up interactions — the main agent could ask clarifying questions about unclear findings. This capability isn't leveraged.

**Recommended change — choose one:**

**Option A (preferred): Present pal findings in their native format.** Don't force-fit into P0-P3. The user sees two distinct review sections: one from the `code-reviewer` sub-agent (P0-P3 structured), one from `pal codereview` (native format). Duplicate detection still works by comparing file locations and issue descriptions across both sections.

**Option B: Define explicit mapping rules.** If normalization is required, specify:
- How pal severity levels map to P0-P3
- How to extract file:line references from pal prose output
- How to assign confidence scores to pal findings
- What to do when pal output is unstructured prose with no clear finding boundaries

**Either way, add:** A note that pal codereview supports follow-up interactions. During annotation, the main agent MAY use pal follow-up to clarify ambiguous findings before presenting them to the user.

### 6. Inline Reconciliation Logic Per Workflow

**Severity:** P2 — over-abstraction creates indirection without meaningful reuse

**Problem:** The shared `review-reconciliation-protocol.md` serves two very different processes:
- **Code review**: two reviewers, uniform trust, all findings are code quality
- **Spec review**: one reviewer, type-specific trust, findings are structural (MISSING_IMPL vs SPEC_DEV)

These have fundamentally different dynamics. The trust level table only applies to spec review. Duplicate merging and severity escalation only make sense with two reviewers. The shared protocol forces awkward abstractions — it's generic in a way that serves neither workflow well.

With the reconciliation model changing to user-reconciles-agent-annotates (issue #1), the shared protocol needs significant rework anyway.

**Recommended change:**

- Dissolve `review-reconciliation-protocol.md` as a shared component.
- Inline the relevant annotation logic into each `review-isolated.md` workflow:
  - `solid-code-review/review-isolated.md`: duplicate merging across two reviewers, corroboration tagging, author context annotations, pal follow-up
  - `implementation-review/review-isolated.md`: type-specific annotation guidance (high-value context for SPEC_DEV/EXTRA_IMPL, less needed for MISSING_IMPL/DOC_INCON), author context annotations
- Keep the **report template** as a shared component if the output format is truly identical. But if the code review report has a "pal findings" section and the spec review report has a "doc issues" section, they're different enough to warrant separate templates.

### 7. Choose Isolated Mode at Implementation-Process Start

**Severity:** P2 — unnecessary decision point at every review checkpoint

**Problem:** The `implementation-process` Step 3 says: "Prompt user for code-review (mention isolated mode as an option)." This means the user makes a decision at every review checkpoint about whether to use isolated mode. For a multi-task implementation session, this is repetitive friction.

**Recommended change:**

- Add an isolated review flag at the `implementation-process` session level, chosen once at the start (or in `tasks.md` metadata).
- If set, all review checkpoints within that session use isolated mode automatically.
- The user can still override per-checkpoint if needed ("use standard review for this one").

### 8. Spec Review Trust Levels Need Grounding

**Severity:** P2 — assertions without evidence

**Problem:** The trust level table assigns "high trust in sub-agent" for `MISSING_IMPL` (reasoning: "I forgot is a real possibility") and "medium trust" for `SPEC_DEV`. But the sub-agent can also misread the spec and flag false `MISSING_IMPL` findings. These calibrations are intuitive assertions, not empirically grounded.

**Recommended change — under the new model:**

With user-reconciles (issue #1), trust levels don't drive disposition assignment anymore. Instead, reframe them as **annotation guidance** — they tell the main agent when its context is more vs. less useful for the annotation:

- `MISSING_IMPL`, `DOC_INCON`, `OUTDATED_DOC`, `AMBIGUOUS`: The main agent's session context is less relevant. These are objective or spec-clarity issues. Keep author annotations brief — point to the implementing code if it exists, otherwise acknowledge the gap.
- `SPEC_DEV`, `EXTRA_IMPL`: The main agent's session context IS relevant. These may be intentional deviations. Author annotations should explain the decision and suggest a spec update if the deviation was deliberate.

This preserves the useful insight (some finding types benefit more from author context) without pretending to calibrate trust levels.

### 9. Add Success Criteria

**Severity:** P3 — no way to evaluate whether the feature works

**Problem:** "Opt-in because it costs more" isn't validation. Without metrics, you'll never know if isolated review actually catches more issues than standard review, or if the extra cost is justified.

**Recommended change:**

After shipping, run both modes on 5-10 real task reviews. Compare:
- **Unique findings per mode** — does isolated review surface issues that standard review misses?
- **False positive rate** — what fraction of findings does the user reject? Is it lower for isolated mode?
- **User acceptance rate** — what fraction of findings does the user act on?
- **Corroboration rate** — how often do both reviewers flag the same issue? (Measures reviewer independence)

This doesn't need to be in the design doc as a formal experiment. A "Validation Plan" section with these questions and a commitment to evaluate after ~10 uses is sufficient.

### 10. Minor Issues

**P3 — Isolation framing is overstated:** The "Isolation Boundary" table largely restates platform behavior (Agent tool sub-agents inherently lack parent conversation history). Acknowledge the platform provides the mechanism. The design's contribution is choosing to exploit it and curating what context the sub-agent receives. Frame it that way.

**P3 — CoVe pattern analogy is misleading:** CoVe does per-question factual verification while review-isolated does per-domain quality evaluation. These are structurally different. Say "inspired by" rather than "follows the pattern of."

**P3 — "Alternatives considered but not taken" is valuable context:** The isolation boundary table excludes this, but knowing "approach X was tried and caused regression Y" prevents reviewers from suggesting the exact same broken approach. Consider including a curated "rejected approaches" summary (not the full debugging narrative) in the sub-agent context.

**P3 — Session constraint should lead the motivation:** The problem section cites Huang et al. (ICLR 2024) but buries the practical constraint. Lead with: "Within implementation-process, a single session handles implement-test-review-fix. Sub-agents are the only mechanism that provides review isolation without breaking the session." Then cite the research as supporting evidence.

---

## Summary of Recommended Changes

| # | Severity | Issue | Change |
|---|----------|-------|--------|
| 1 | P0 | Author reconciliation bias | User reconciles; agent annotates with context, doesn't assign dispositions |
| 2 | P1 | Severity escalation on agreement | Agreement = confidence ("corroborated" tag), not severity bump |
| 3 | P1 | No new findings from main agent | Allow author-sourced findings, clearly tagged |
| 4 | P1 | Zero error handling | Add timeout/failure/fallback handling per cove-isolated pattern |
| 5 | P1 | pal output mapping hand-waved | Present pal findings natively (preferred) or define explicit mapping; leverage pal follow-ups |
| 6 | P2 | Over-abstracted shared protocol | Inline reconciliation/annotation logic per workflow |
| 7 | P2 | Isolated mode chosen per-checkpoint | Choose once at implementation-process start |
| 8 | P2 | Trust levels are assertions | Reframe as annotation guidance (when author context is useful) |
| 9 | P3 | No success criteria | Add validation plan: compare modes after ~10 real uses |
| 10 | P3 | Minor framing issues | Isolation framing, CoVe analogy, rejected approaches, session constraint ordering |

---

## Impact on Implementation

The changes above affect these components:

| Component | Impact |
|---|---|
| `_shared/review-reconciliation-protocol.md` | **Major rework or dissolution.** Remove disposition system, replace with annotation model and report template. Consider inlining per workflow. |
| `solid-code-review/review-isolated.md` | **Rework Phase 2-3.** Reconciliation becomes annotation. Add error handling. Add pal follow-up step. |
| `implementation-review/review-isolated.md` | **Rework Phase 2-3.** Reconciliation becomes annotation with type-specific guidance. Add error handling. |
| `agents/code-reviewer.md` | **No change.** Sub-agent definition is unaffected — it produces findings, doesn't reconcile. |
| `agents/spec-reviewer.md` | **No change.** Same reasoning. |
| `solid-code-review/SKILL.md` | **Minor update.** Reflect new annotation model in isolated mode description. |
| `implementation-review/SKILL.md` | **Minor update.** Same. |
| `implementation-process/SKILL.md` | **Minor update.** Add session-level isolated review flag. Remove per-checkpoint mode selection. |
| `design.md` | **Update motivation, reconciliation section, invariants, report format, and add validation plan.** |
