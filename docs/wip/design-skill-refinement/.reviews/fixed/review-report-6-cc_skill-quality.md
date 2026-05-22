# Skill Quality Review: Design Skill Refinement

**Branch:** `feat/design_improvements`
**Date:** 2026-05-22
**Lenses:** Skill Improvement (does the skill improve over earlier implementation?) and Skill Complexity (is the skill too complex for an assistant to follow properly?)

---

## Skill Improvement Assessment

### What was broken before

The pre-change Step 3 was a single block: "ask questions one at a time to help refine the idea." This had three failure modes:

1. **No forcing functions.** The agent could ask about anything in any order — architecture before understanding the problem, edge cases before understanding the user, or jump straight to a solution when the idea named a technology ("add Redis caching"). No gate prevented advancing with incomplete understanding.
2. **No divergence.** Without explicit instruction to generate alternatives, the agent would latch onto the first viable approach (usually whatever the user's idea already implied) and refine it incrementally. Users never saw alternatives they didn't think to ask about.
3. **Implicit scope.** Assumptions stayed hidden until they broke during implementation. Scope exclusions were never named, so they surfaced as scope creep when someone asked "shouldn't it also do X?"

### What the changes fix

| Before | After | Why it matters |
|--------|-------|---------------|
| Unstructured "ask questions" | 5 sequential sub-phases with gates | Agent can't skip problem understanding to jump to solutions |
| No problem framing | 3a: HMW reframing | Forces clarity before architecture |
| No forcing function | 3b: Hard gate (who/success/constraints) | Blocks diverge until foundations confirmed |
| Single-path anchoring | 3c: Proportional diverge with classification | User always sees alternatives; simple ideas don't get over-explored |
| No evaluation rubric | 3d: Criteria-based converge from refinement-criteria.md | Structured comparison instead of gut feel |
| Implicit scope | 3e: Explicit Assumptions and Not Doing | Scope boundaries persist into design doc and tasks header |
| No task quality guidance | Step 6: Vertical slicing, Size tags, dependency graph | Tasks are implementable vertical slices, not horizontal layers |
| Review-design unaware | review-design checks new sections | Catches missing/weak outputs before implementation |

### Verdict: Genuine improvement

The sub-phases address real failure modes with concrete mechanisms. The forcing functions (hard gate, classification confirmation, assumption surfacing) make the skill more reliable across models and contexts. The framework/criteria reference files provide methodology without bloating the main process file — good progressive disclosure.

The vertical slicing mandate for Step 6 is the highest-value single change. Horizontal-layer tasks ("all database work, then all API") are the LLM default, and example-tasks.md anchors the agent's formatting on vertical slices. This will measurably improve task quality.

---

## Skill Complexity Assessment

### Complexity budget

A skill's effective complexity is bounded by the assistant's ability to track state across turns while following instructions. The design skill is interactive (multi-turn conversation), which compounds complexity — the assistant must hold sub-phase state across 8+ user messages while remembering which gates it has and hasn't cleared.

### Measured complexity

| Metric | Value | Concern level |
|--------|-------|---------------|
| Total sub-phases in Step 3 | 5 | Moderate |
| Hard gates (must-clear-before-advancing) | 2 (3b→3c, all of 3a-3e before Step 4) | Low — well-defined |
| Conversation turns for full Step 3 | 8-12 (HMW + 3 gate Qs + classification + alternatives + convergence + assumptions) | **High** — longest interactive sequence |
| Conditional branches in 3c | 2 (simple vs non-trivial) | Low — binary, explicit |
| Conditional branches in 3d | 1 (CoVe offer) | Low — user-decided |
| Reference files loaded | 2 (frameworks.md, refinement-criteria.md) | Low — loaded once, used as rubric |
| Checklist items in Step 3 Progress | 8 | Moderate — good state tracking aid |

### Complexity risks

#### RISK-1: Multi-turn state decay across 8-12 messages (HIGH)

This is the dominant risk. After 8 messages of interactive conversation, the sub-phase instructions from idea-process.md will have scrolled far enough up the context window that the model relies on its compressed understanding rather than re-reading the instructions.

**Mitigating factors:**
- Step 3 Progress checklist provides 8 anchoring checkpoints the assistant can reference.
- Sub-phases have clear "do this then ask user" structure — each turn has a single, defined action.
- The gates are named by what they check, not by step numbers: "who/persona confirmed," "success metric confirmed," "constraints confirmed."

**Residual risk:** After the user responds to the 3b constraints question, the agent must remember to classify complexity (3c) before generating alternatives. Without re-reading instructions, it may jump straight to generating alternatives. The Step 3 Progress checklist mitigates this but doesn't eliminate it.

#### RISK-2: Classification judgment in 3c (MODERATE)

"Non-trivial" vs "simple" is a judgment call with no concrete test. The criteria — "architectural choices, multiple valid implementation approaches, significant unknowns" vs "singular implementation path, parameter-level decisions" — are reasonable, but real ideas will cluster in the ambiguous middle more often than the evals suggest (the evals test clear extremes: Redis caching = non-trivial, health check = simple).

**Mitigating factor:** The explicit confirmation ("Want me to explore more broadly instead?") gives the user a correction opportunity.

**Residual risk:** The agent's classification will be biased toward "non-trivial" (more content = more helpful-seeming) unless the simplicity path is equally rewarding.

#### RISK-3: Framework selection in 3c (LOW)

"Select frameworks from frameworks.md that fit the idea — pick by 'Best for' guidance" is underspecified. The "Best for" annotations help, but the agent must judge which annotations apply. In practice, agents will likely pick 2-3 familiar frameworks (SCAMPER, First Principles, Pre-mortem) regardless of the idea.

**Mitigating factor:** Framework selection is advisory, not gate-keeping. If the agent picks suboptimal frameworks, the alternatives are slightly less varied but still functional.

**Residual risk:** Low. The user sees the alternatives and can redirect.

#### RISK-4: 3c/3d boundary blurring (MODERATE)

The agent generates alternatives in 3c, then evaluates them in 3d. In a single-message response, the agent is strongly tempted to present alternatives AND evaluate them simultaneously — collapsing two sub-phases into one. This reduces the user's opportunity to redirect or reject before evaluation begins.

**Mitigating factor:** The instructions say to "present each with a one-sentence trade-off summary" in 3c and "present a pros/cons matrix" in 3d — different output formats. The Step 3 Progress checklist has separate items for "alternatives presented" and "direction chosen."

**Residual risk:** The format difference may not be salient enough to prevent collapse. Consider whether 3c should end with an explicit user-facing question ("Which of these should I evaluate in detail?") to force a turn boundary.

#### RISK-5: Assumption surfacing skipped or collapsed (LOW-MODERATE)

3e is the last sub-phase before Step 4 ("Describe the design"). After convergence, the agent is eager to move forward. Assumptions and Not Doing may get produced as a brief sentence in the convergence message rather than as distinct, first-class artifacts.

**Mitigating factor:** The Step 3 Progress checklist has a dedicated item: "3e assumptions and Not Doing presented."

**Residual risk:** The checklist helps but doesn't force a turn boundary. The instructions say "Before moving to Step 4, produce and present to the user" — "present" implies a separate action, but the agent may interpret "present" as appending to the convergence message.

### Complexity verdict

The skill is at the **upper bound of manageable complexity** for a multi-turn interactive skill. It works because:

1. **Sub-phases have clear single actions.** Each phase is "do one thing, ask user, wait."
2. **The Step 3 Progress checklist anchors state.** 8 named checkpoints prevent the agent from losing its place.
3. **Gates are user-confirmed.** The user answers each gate question, creating natural turn boundaries.
4. **CoVe was simplified to user-initiated.** Removing agent-evaluated pre-check/post-check eliminated the worst complexity-to-reliability ratio (previous SQ-1).

The primary risk is multi-turn state decay (RISK-1). If this skill shows problems in practice, the first intervention should be adding explicit "stop and re-read Step 3" instructions at the 3b→3c and 3d→3e transitions.

---

## Predicted failure modes (for future eval coverage)

These are the behaviors most likely to go wrong in practice. The existing 3 evals cover the first two partially. The remainder are uncovered.

| # | Failure mode | Covered by eval? | Priority |
|---|-------------|-------------------|----------|
| 1 | Hard gate bypass: agent answers its own gate questions after getting a strong first answer | Partially (eval 1) | Already covered |
| 2 | Classification lock-in: agent classifies and generates alternatives without waiting for user confirmation | Partially (eval 2) | Already covered |
| 3 | 3c/3d collapse: alternatives and evaluation in one message | No | **High** — most likely real-world failure |
| 4 | Framework recency bias: SCAMPER (first) or Analogous Inspiration (last) picked disproportionately | No | Low — advisory, not gating |
| 5 | 3e skip/collapse: assumptions produced as an afterthought in convergence message | No | **Medium** — undermines a primary design goal |
| 6 | WIP-flow false activation: 3a-3e sub-phases triggered on existing-task-process.md | No | Low — separate process files prevent this |

---

## Summary

The skill improvement is genuine and addresses real failure modes. The complexity is at the upper bound of manageable — it works because of good state-tracking aids (Step 3 Progress checklist, named gates, user-confirmed turn boundaries). The primary risk is multi-turn state decay over 8-12 messages. If problems surface in practice, add re-read anchors at the 3b→3c and 3d→3e transitions before adding more structure.
