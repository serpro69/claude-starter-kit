# Design Review: Isolated Review Agents

**Spec reviewed:** `docs/wip/isolated-review-agents/design.md`
**Date:** 2026-04-03
**Verdict:** Conditionally approve — architecture is sound, several design-level issues to address before implementation is complete.

---

## Context

The feature adds isolated sub-agent review modes to `solid-code-review` and `implementation-review` skills. Sub-agents spawned via Claude Code's Agent tool review code/spec conformance without access to the implementation session's conversation history, then findings are reconciled into a consolidated report.

**Key constraint:** The entire implement-test-review cycle runs within a single session (context window). A fresh-context review in a separate session would require pausing, spawning a new session, reviewing there, passing findings back, and resuming — worse UX than sub-agents. This constraint is the strongest justification for the feature and should lead the design doc.

---

## Approved Aspects

### Sub-agent architecture is the right call
Within a single session, Agent tool sub-agents are the only mechanism that provides context isolation. The design correctly identifies that the implementing agent cannot objectively review its own work mid-session.

### Dual-provider code review is genuinely valuable
`code-reviewer` (Claude sub-agent) + `pal codereview` (external LLM provider) gives statistically independent review perspectives with zero shared token cost. Different model families have uncorrelated blind spots. This makes the severity-escalation-on-agreement rule sound for this specific cross-provider pairing.

### Invariant #1 (no silent drops) is correct
Every sub-agent finding must appear in the final report. This is the right guardrail.

### Finding type taxonomy is well-designed
The `MISSING_IMPL` / `EXTRA_IMPL` / `SPEC_DEV` / `DOC_INCON` / `OUTDATED_DOC` / `AMBIGUOUS` classification for spec review is comprehensive and actionable.

---

## Issues to Address

### P0 — Author-Reconciliation Conflict of Interest

**Problem:** The main agent — which wrote the code — performs reconciliation and assigns dispositions to every finding. After a long implementation session, this agent is maximally biased. "Cannot silently drop findings" doesn't prevent persuasive "Disputed — Intentional" justifications that lead users to dismiss valid issues.

**Recommendation:** Either:
1. Pass sub-agent findings directly to the user without author mediation (simplest)
2. Spawn a third reconciler agent that receives sub-agent findings + diff + session context summary, but authored neither the code nor the reviews

### P1 — Invariant #2 Is Actively Harmful

**Problem:** "The main agent cannot add new findings during reconciliation" muzzles observations that naturally emerge during the close re-reading that reconciliation requires. Prioritizing process purity over finding real issues is backwards.

**Recommendation:** Remove this invariant. If the reconciler spots something new, it should flag it — clearly attributed as a reconciliation-phase finding, not a sub-agent finding. More findings is better than fewer findings.

### P1 — `pal codereview` Format Mismatch Is Unaddressed

**Problem:** The design acknowledges `pal` "produces findings in its own format" but doesn't specify how to normalize them before cross-referencing with `code-reviewer` output. Reconciliation quality will be inconsistent — sometimes `pal` returns something easy to map, sometimes a wall of prose.

**Recommendation:** Either:
1. Add an explicit normalization step — after `pal` returns, map its output to P0-P3 format with confidence scores before cross-referencing
2. Constrain the `pal` prompt to request output in a compatible format

### P1 — Report Verbosity Wastes Context Window

**Problem:** The consolidated report includes findings (with attribution and dispositions), a reconciliation summary table repeating everything, and a separate "Reviewer Disagreements" section. In a single-session workflow where the agent must still apply fixes and continue to the next task, this ~3x report size consumes context window needed downstream.

**Recommendation:** One findings list with inline attribution and dispositions. No summary table. No separate disagreements section — disputes are inline with the finding they concern.

### P2 — Severity Escalation Needs a Caveat

**Problem:** Agreement-based severity escalation is sound for cross-provider agreement (Claude + external model) but NOT for same-provider agreement (e.g., two Claude sub-agents, if ever used). The design doesn't distinguish these cases.

**Recommendation:** Note explicitly that the escalation rule depends on reviewer independence, which is achieved here via different model providers. If the architecture ever changes to two same-provider agents, this rule should be revisited.

### P2 — Spec Review Trust Levels Are Unjustified

**Problem:** `MISSING_IMPL` gets "high trust in sub-agent" and `SPEC_DEV` gets "medium trust," but the reasoning ("I forgot is a real possibility") doesn't account for the sub-agent misreading the spec and flagging false `MISSING_IMPL` findings. These calibrations are assertions without evidence.

**Recommendation:** Either provide empirical basis for these trust levels or remove them and let the reconciler (or user) judge each finding on its merits.

### P2 — Design Should Lead with the Session Constraint

**Problem:** The motivation section cites Huang et al. (ICLR 2024) about self-correction failure but buries the practical constraint: the implement-test-review cycle must complete in one session. The academic citation is weaker motivation than the concrete workflow requirement.

**Recommendation:** Lead with: "Within the implementation-process workflow, a single session handles implement → test → review → fix. Sub-agents are the only mechanism that provides review isolation without breaking the session." Then cite the research as supporting evidence.

### P3 — Isolation Framing is Overstated

**Problem:** The design presents context isolation as an architectural achievement, but Agent tool sub-agents inherently lack parent conversation history. The "Isolation Boundary" table restates platform behavior as design work.

**Recommendation:** Acknowledge the platform provides the isolation mechanism. The design's contribution is *choosing to exploit it* for review quality and curating what context (spec, diff, checklists) the sub-agent receives. Frame it that way.

### P3 — No Success Criteria

**Problem:** No defined way to measure whether isolated review outperforms standard review. "Opt-in because it costs more" isn't validation.

**Recommendation:** After shipping, run both modes on 10 real task reviews. Compare: unique findings per mode, false positive rates, user acceptance rates. Decide whether the feature is earning its keep.

### P3 — CoVe Pattern Analogy is Misleading

**Problem:** The design claims to follow the cove-isolated pattern, but CoVe does per-question factual verification while review-isolated does per-domain quality evaluation. These are structurally different. The analogy sets wrong expectations.

**Recommendation:** Acknowledge the inspiration but note the structural differences. Don't claim it "follows" the pattern — it was *inspired by* it and adapted significantly.

---

## Summary

| Severity | Count | Issues |
|----------|-------|--------|
| P0 | 1 | Author-reconciliation conflict of interest |
| P1 | 3 | Invariant #2 harmful; `pal` format mismatch; report verbosity |
| P2 | 3 | Escalation caveat; trust levels unjustified; session constraint framing |
| P3 | 3 | Isolation overstated; no success criteria; CoVe analogy misleading |
