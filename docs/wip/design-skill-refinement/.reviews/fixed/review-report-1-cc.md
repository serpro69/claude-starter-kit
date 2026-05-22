# Design Skill Refinement — Review Report

**Branch:** `feat/design_improvements`
**Date:** 2026-05-22
**Reviewers:** kk:review-code (standard), kk:review-spec (isolated sub-agent), skill-quality analysis (general agent)
**Files reviewed:** 15 files, 537 lines added / 86 removed

---

## Overall Assessment

The implementation is solid. The sub-phases (3a-3e), reference files, vertical slicing mandate, and review-design additions are genuine improvements. The main issues are stale spec docs that didn't keep pace with a scope evolution decision, an undocumented assumption categorization enrichment, and skill complexity concerns around CoVe and multi-turn state tracking.

---

## Corroborated Findings

Flagged independently by two or more review passes. Highest signal.

### C1. Scope evolution left docs stale

**Severity:** P1 — High
**Sources:** Code review, Spec review (P1 + P2 + Doc Issues)

The implementation correctly evolved the default `review-design` scope to include `tasks.md`, removing the `all` keyword entirely. But the spec docs weren't updated to match:

- `design.md:131` still says `review-design <feature> all`
- `design.md:130` still says "The default review scope (`design.md + implementation.md`) does not include tasks.md"
- `implementation.md` Task 3.2 / subtask 4.8 still specifies `all`
- `review-design/SKILL.md` has no explicit post-design gate recommendation (the spec required one per design.md §review-design Changes and implementation.md §Task 6.3)

The code is internally consistent — `review-process.md`, `review-isolated.md`, and `review-design/SKILL.md` all agree that the default scope includes `tasks.md`. This is a docs-haven't-caught-up problem, not a broken feature.

**Recommendation:** Update `design.md` and `implementation.md` to reflect default-includes-tasks.md. Add a one-line post-design gate note to `review-design/SKILL.md` Invocation section.

### C2. Assumption categorization introduced without spec or downstream validation

**Severity:** P1 — High
**Sources:** Code review, Spec review (P3)

`idea-process.md:69` (Step 3e) instructs the agent to categorize assumptions using `refinement-criteria.md §Assumption Audit`: Must Be True (dealbreakers), Should Be True (important), Might Be True (nice to have).

This was not specified in `design.md` §3e (which says only "Each assumption should be specific enough to be testable or falsifiable"). Nothing downstream validates or preserves the categorization:

- Step 5 says "Include an Assumptions section — carried from Step 3e. Each specific enough to be validated or invalidated."
- `review-process.md` checks only "are assumptions specific and testable"
- `design-reviewer.md` checks only "are assumptions specific and testable"

This creates work with no visible benefit: the agent produces categorized assumptions in 3e, but no subsequent step validates, references, or enforces the categories.

**Recommendation:** Either remove the Must/Should/Might reference from 3e (simpler — just require "specific and testable" throughout), or add the categorization requirement to Step 5 and to the review-design checks (more work, higher fidelity).

### C3. Framework count: design says 6, implementation has 7

**Severity:** P2 — Medium
**Sources:** Code review, Spec review (P2)

`frameworks.md` has seven frameworks: SCAMPER, HMW, First Principles, JTBD, Constraint Mapping, Pre-mortem, and Analogous Inspiration. `design.md:86` lists only the first six (omits Analogous Inspiration). `tasks.md` subtask 1.3 correctly says "all seven frameworks."

Note: the spec reviewer incorrectly claimed Constraint Mapping was missing from `frameworks.md` — it is present at line 68. The actual gap is that Analogous Inspiration was added from upstream but not reflected in the design doc's framework list.

**Recommendation:** Add Analogous Inspiration to the design.md framework list, or document it as an intentional deviation from the original six.

---

## Code Review Findings

Profile: `skill-md` (triggered by SKILL.md ancestry for all `klaude-plugin/skills/` files)
Checklists applied: `skill-quality-checklist.md`, `claude-code-checklist.md`, `kk-plugin-checklist.md`

### P2 — Medium

#### CR-1. design-reviewer.md Assumptions check wording weaker than review-process.md

- **File:** `klaude-plugin/agents/design-reviewer.md:100`
- **Checklist:** skill-quality-checklist.md (instruction clarity)
- **Confidence:** 60%

`review-process.md:51` says "not vague hedges like 'the API is fast enough'" — providing a concrete calibration example. `design-reviewer.md:100` says only "Are assumptions specific and testable?" without the example.

The design spec (`design.md:146-147`) states: "The new quality/soundness checks must be consistent across standard mode, isolated mode, and the sub-agent." The wording difference is acceptable functionally, but the vague-hedge example is a useful calibration signal the sub-agent lacks.

**Recommendation:** Add the vague-hedge example to the design-reviewer for calibration parity.

#### CR-2. review-design/SKILL.md missing post-design gate guidance

- **File:** `klaude-plugin/skills/review-design/SKILL.md` (Invocation section)
- **Checklist:** skill-quality-checklist.md (instruction clarity)
- **Confidence:** 55%

The design spec required explicit guidance noting that review-design is the recommended post-design gate after `/kk:design` completes. Functionally satisfied by the default scope change, but the explicit note was part of the spec.

Overlaps with C1.

### P3 — Low

#### CR-3. example-tasks.md blocked task with parallel markers

- **File:** `klaude-plugin/skills/design/example-tasks.md` (Task 4)
- **Confidence:** 40%

Task 4 (Password hashing migration) is blocked but lists `Can run in parallel with: Task 1, Task 2`. Pedagogically sound — a blocked task can conceptually run in parallel once unblocked. Not a bug.

#### CR-4. Step 6 recommendation technically correct but could be clearer

- **File:** `klaude-plugin/skills/design/idea-process.md:136`
- **Confidence:** 40%

The instruction says "recommend invoking `/kk:review-design <feature>` as the post-design gate" without explicitly noting the scope change. Correct as-is since the default now includes tasks.md.

### Clean Areas

- **Workflow ordering compliance:** SKILL.md mandatory-order directive correctly names `frameworks.md` and `refinement-criteria.md`. Content-level reads appear exactly once (Step 3, after instruction load in Step 2). No duplicate git diff / Read steps.
- **Progressive disclosure:** SKILL.md is well under 500 lines. Reference files loaded on-demand in Step 2 for fresh ideas only.
- **Description quality:** Triggers lead the description. Under character budget.
- **`${CLAUDE_PLUGIN_ROOT}` usage:** Brace form used only in SKILL.md (plugin-load file). Runtime-read files (`idea-process.md`) use relative links and `<plugin_root>` prose instruction.
- **Shared symlinks:** No new shared files introduced. Existing symlinks unchanged.
- **Naming conventions:** `/kk:` prefix used consistently. `/kk:review-design`, `/kk:chain-of-verification:isolated` referenced correctly.
- **Eval coverage:** Three evals with real filesystem fixtures. Trap fields present and well-targeted.
- **review-design scope tables:** Consistent across all three locations (`SKILL.md`, `review-process.md`, `review-isolated.md`).

---

## Spec Conformance Findings

### P1 — High

#### SC-1. review-design SKILL.md scope recommendation absent

- **Location:** `klaude-plugin/skills/review-design/SKILL.md` vs `design.md §review-design Changes`, `implementation.md §Task 6.3`
- **Confidence:** 10/10

Grep for every plausible phrase (`post-design gate`, `scope recommendation`, `after /kk:design`) returned zero matches in `review-design/SKILL.md`. Task 7.5 in tasks.md is checked done.

Overlaps with C1.

### P2 — Medium

#### SC-2. Step 6 review-scope recommendation uses default instead of `all`

- **Location:** `klaude-plugin/skills/design/idea-process.md:136` vs `design.md §Step 6 Changes`, `implementation.md §Task 3.2`
- **Confidence:** 9/10

The code says: "recommend invoking `/kk:review-design <feature>`". The spec says: "recommend invoking `/kk:review-design <feature> all`". The code is internally consistent (default scope now includes tasks.md) but the spec text was not updated. Overlaps with C1.

### Doc Issues (outdated spec text)

- `implementation.md §Task 3.2` subtask 4.8 specifies `all` but the default scope was broadened.
- `design.md §Step 6 Changes` states the default scope doesn't include tasks.md — no longer accurate.

---

## Skill Quality & Complexity Analysis

### Improvement Quality — Positive

- **Sub-phases 3a-3e** fix a real problem. The old "ask questions one at a time" was a blank invitation with no sequencing or forcing functions. The new structure imposes a coherent funnel: establish the problem frame before questioning, block divergence until foundations are confirmed, proportionally scale alternatives exploration, surface assumptions/scope as explicit outputs.
- **frameworks.md / refinement-criteria.md** are well-adapted from upstream. The "Best for" guidance turns a menu of techniques into a selection guide. The painkiller/vitamin framing and value/feasibility matrix are concrete enough for LLM application.
- **Vertical slicing mandate** will work because LLMs anchor heavily on the format they see. The updated example-tasks.md is a credible teaching vehicle.
- **review-design additions** map precisely to the new mandated outputs. No speculative additions.
- **Evals** test the right failure modes. Hard gate enforcement targets the exact temptation the Redis prompt creates. Proportional diverge routing targets over-engineering. The review-design eval targets silent omission of structural checks.

### Complexity Concerns

#### SQ-1. CoVe pre/post-check is the worst complexity-to-reliability ratio

**Severity:** High (followability risk)

Step 3d contains two nested conditional gates:

1. **Pre-check:** "evaluate whether any alternative makes a specific verifiable claim." If no verifiable claims exist, skip CoVe entirely. If they exist, name them and ask user to confirm.
2. **Post-check:** "if CoVe's verification questions don't reference any specific technical constraint or trade-off from the alternatives, or if answers for all alternatives are substantively identical — skip the CoVe results."

Both gates require abstract judgment with no concrete test. The post-check is particularly unreliable — an agent that invoked CoVe is reluctant to discard its output. The pre-check's "do verifiable claims exist?" has no anchor for what counts as "verifiable."

**Recommendation:** Convert CoVe to a user-initiated decision: "If you want to stress-test alternatives before committing, I can invoke `/kk:chain-of-verification:isolated`. Otherwise I'll proceed with the criteria-based analysis." Move the gate to the user, not the agent.

#### SQ-2. No sub-phase state tracking mechanism

**Severity:** High (followability risk)

Steps 3a-3e span 5+ conversation turns (HMW confirmation, 3 gate questions, classification confirmation, alternatives, convergence, assumptions). The agent must not advance without completing the current sub-phase. The skill provides no mechanism for tracking sub-phase state across turns — it relies entirely on the agent remembering which sub-phase it's in and which conditions it has satisfied.

The top-level idea-process.md has a checklist for Steps 1-6, but no checklist for sub-phases 3a-3e.

**Recommendation:** Add a sub-phase progress tracker to Step 3, similar to the existing Step 1-6 checklist.

#### SQ-3. Five predicted failure modes

1. **Hard gate bypass in fast-moving conversations.** After 3b question 1 gets a solid answer, the agent treats the remaining 2 as confirmations and advances to 3c prematurely.
2. **Classification lock-in before user confirmation.** The agent classifies simple/non-trivial and immediately follows with alternatives, skipping the explicit confirmation step.
3. **Sub-phase blurring between 3c and 3d.** The agent generates alternatives (3c) and evaluates them (3d) in the same message, collapsing two sub-phases.
4. **Framework selection recency bias.** SCAMPER (first loaded) or Analogous Inspiration (last loaded) picked disproportionately when "Best for" is ambiguous.
5. **Assumption surfacing (3e) collapsed or skipped.** The last sub-phase before Step 4 — the agent produces a brief assumption sentence in the same message as "ready for Step 4" rather than presenting assumptions as a distinct artifact.

The evals partially cover predictions 1 and 2. Predictions 3-5 are not covered by existing evals.

#### SQ-4. Ambiguous judgment points without guardrails

- **Framework selection in 3c.** "Select frameworks that fit the idea" with "Best for" hints is the only guidance. No rule for what counts as "fitting."
- **Simple vs non-trivial classification in 3c.** "Multiple valid approaches, significant unknowns, architectural choices" vs "single-concern, low-uncertainty" are judgment calls with no concrete test. Real ideas will land in ambiguous territory more often than the eval scenarios suggest.

---

## Consolidated Action Items

| Priority | ID | Finding | Action |
|----------|----|---------|--------|
| **Must** | C1 | Stale scope references in design.md + implementation.md | Update both docs; add post-design gate note to review-design/SKILL.md |
| **Must** | C3 | Framework count 6 vs 7 | Add Analogous Inspiration to design.md framework list |
| **Should** | C2 | Assumption categorization scope creep | Remove Must/Should/Might from 3e, or propagate to spec + downstream checks |
| **Should** | SQ-1 | CoVe complexity | Simplify to user-initiated CoVe decision |
| **Consider** | SQ-2 | Sub-phase state tracking | Add 3a-3e checklist to Step 3 |
| **Consider** | CR-1 | design-reviewer calibration parity | Add vague-hedge example |
| **Consider** | SQ-3 | Uncovered failure modes | Add evals for predictions 3-5 |
| **Informational** | SQ-4 | Ambiguous judgment points | Inherent to LLM skill design; monitor via evals |
