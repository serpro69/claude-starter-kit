# Design Review Skill Benchmark

**Date:** 2026-04-07
**Skill:** `kk:review-design` (standard mode)
**Model:** claude-opus-4-6 (1M context)
**Methodology:** skill-creator eval framework — 3 test cases, each run with-skill and without-skill (baseline)

## Summary

| Metric | With Skill | Without Skill | Delta |
|--------|-----------|--------------|-------|
| **Pass Rate (avg)** | 100% | 48% | **+52%** |
| **Time (avg)** | 268s | 222s | +45s |
| **Tokens (avg)** | 44,338 | 42,203 | +2,135 |

The skill achieves **perfect format compliance** across all 3 evals. Baselines detect substantive issues effectively but with freeform formatting. The skill's primary value is **structural consistency and thoroughness**, not raw issue detection — Claude already catches contradictions and gaps without guidance.

---

## Test Cases

### Eval 1: WIP Language-Specific Skills (Default Scope)

**Prompt:** `/kk:review-design language-specific-skills`
**Documents:** `docs/wip/language-specific-skills/design.md` + `implementation.md`
**Purpose:** Test the skill on a real, organic WIP feature with genuine codebase inconsistencies.

#### Scores

| Configuration | Pass Rate | Time | Tokens | Tool Calls |
|--------------|-----------|------|--------|------------|
| With Skill | **9/9 (100%)** | 248s | 49,118 | 19 |
| Without Skill | 2/9 (22%) | 162s | 44,494 | 20 |

#### Assertions

| # | Assertion | With Skill | Baseline |
|---|-----------|-----------|----------|
| 1 | Overall assessment uses SOUND/CONCERNS_FOUND/MAJOR_GAPS | PASS | FAIL — free-text verdict |
| 2 | Findings under P0/P1/P2/P3 severity headings | PASS | FAIL — Critical/Moderate/Minor |
| 3 | Finding type codes from taxonomy | PASS | FAIL — no codes |
| 4 | Confidence score out of 10 with reasoning | PASS | FAIL — no scores |
| 5 | Evidence field with specific doc text | PASS | FAIL — inline but unlabeled |
| 6 | Recommendation field | PASS | FAIL — Impact annotations instead |
| 7 | Summary count of findings by severity | PASS | FAIL — no structured count |
| 8 | Next Steps with numbered options | PASS | PASS — 7 numbered recommendations |
| 9 | Covers quality and technical soundness dimensions | PASS | PASS — separate analysis sections |

#### With-Skill Output

```markdown
## Design Review: Language-Specific Skills

**Scope:** design.md + implementation.md (default)
**Overall assessment:** CONCERNS_FOUND
**Documents:**

- Design: `/docs/wip/language-specific-skills/design.md` (224 lines)
- Implementation: `/docs/wip/language-specific-skills/implementation.md` (829 lines)

**Summary:** 9 findings: 2 critical, 3 high, 3 medium, 1 low

---

## Findings

### P0 - Critical

- **[INCONSISTENT]** Wrong directory path throughout both documents
  - **Section:** design.md:Architecture > Directory Structure; implementation.md:throughout
  - **Confidence:** 10/10 -- The design shows `.claude/skills/` as the skill directory
    (e.g., `.claude/skills/lang-go/`). The actual repository stores all skills under
    `skills/`. There is no `.claude/skills/` directory in the repository.
    Every path reference in both documents is wrong.
  - **Evidence:** design.md line 43 shows `.claude/skills/` tree; implementation.md lines
    26, 401-402, 423-424, 464, 470, 535, 564, 697, 701-702 all reference `.claude/skills/`.
    Actual skill location: `skills/`.
  - **Recommendation:** Replace all `.claude/skills/` references with the correct path. If
    the intent is that downstream template-created repos will have `.claude/skills/` (after
    plugin installation), this must be explicitly stated as an assumption in the design.

- **[INCONSISTENT]** LANGUAGE (singular) vs LANGUAGES (plural) mismatch with existing workflow
  - **Section:** design.md:Architecture > Template Cleanup Workflow; implementation.md:Phase 3
  - **Confidence:** 9/10 -- Both documents assume the workflow has a singular `LANGUAGE`
    input. The actual `template-cleanup.yml` workflow defines `LANGUAGES` (plural) as a
    comma-separated string input.
  - **Evidence:** Workflow file defines `LANGUAGES` (plural). Design doc line 111:
    "Accept LANGUAGE input". Implementation doc lines 393, 459, 489, 495: all reference
    `${{ inputs.LANGUAGE }}`.
  - **Recommendation:** Redesign the pruning logic to handle the existing `LANGUAGES`
    multi-value input.

### P1 - High

- **[INCONSISTENT]** References to non-existent `development-process` skill
  - **Section:** design.md:Architecture > Integration with Process Skills; implementation.md:Tasks 3.3, 4.2
  - **Confidence:** 9/10 -- The actual skill is named `development-guidelines`.
  - **Evidence:** implementation.md lines 424, 470, 564, 702 reference `development-process/SKILL.md`.
  - **Recommendation:** Replace all `development-process` references with `development-guidelines`.

- **[TECH_RISK]** Workflow modification approach is fragile -- inline YAML in implementation doc
  - **Section:** implementation.md:Task 3.2, 3.3, 3.4
  - **Confidence:** 8/10 -- Existing workflow delegates all logic to `template-cleanup.sh`.
  - **Evidence:** Workflow step: `run: chmod +x .github/scripts/template-cleanup.sh && ...`
  - **Recommendation:** Modify `template-cleanup.sh` instead of adding YAML steps.

- **[MISSING]** No consideration of the `klaude-plugin` distribution mechanism
  - **Section:** design.md (absent); implementation.md (absent)
  - **Confidence:** 8/10 -- Skills are distributed via the `klaude-plugin` package system.
  - **Evidence:** `settings.json` shows marketplace plugin configuration.
  - **Recommendation:** Add a section addressing distribution.

### P2 - Medium

- **[INCOMPLETE]** Template cleanup workflow logic does not handle multi-language projects
  - **Confidence:** 7/10
- **[INCOMPLETE]** Content depth guidelines are vague for topic files
  - **Confidence:** 6/10
- **[AMBIGUOUS]** Unclear relationship between `%LANGUAGE%` and `%LANGUAGE_LOWER%` placeholders
  - **Confidence:** 7/10

### P3 - Low

- **[STRUCTURE]** Typo in implementation doc ("well-establised")
  - **Confidence:** 10/10

---

## Clean Areas

- Design principles, language selection, topic file structure, non-goals,
  framework extensibility, phase structure, rollout strategy — all solid.

---

## Next Steps

I found 9 issues (P0: 2, P1: 3, P2: 3, P3: 1).

**How would you like to proceed?**

1. **Update docs** -- I'll revise the design docs to address all findings
2. **Update high severity only** -- Address P0/P1 issues
3. **Discuss specific items** -- Let's talk through particular findings
4. **Proceed to implementation** -- Findings are acceptable, move forward
5. **No changes** -- Review complete, no action needed
```

#### Baseline Output

```markdown
# Design Review: Language-Specific Skills

**Documents reviewed:**
- `docs/wip/language-specific-skills/design.md`
- `docs/wip/language-specific-skills/implementation.md`

**Reviewer:** Claude (no skill guidance, natural review)

## Overall Assessment

The design is well-structured and clearly thought through. However, there are several
significant issues that need resolution before implementation, mostly stemming from
inconsistencies between the design docs and the actual codebase.

**Verdict:** Needs revision before implementation.

## Critical Issues

### 1. Wrong directory structure -- skills live in `skills/`, not `.claude/skills/`

The design repeatedly references `.claude/skills/` as the location for language skills.
In the actual repository, all skills live under `skills/`.

**Impact:** High. Must be corrected throughout both documents.

### 2. Workflow input mismatch: `LANGUAGE` (singular) vs `LANGUAGES` (plural)

The design assumes a `LANGUAGE` (singular) input parameter. The actual workflow uses
`LANGUAGES` (plural) and accepts comma-separated lists.

**Impact:** High. The entire template-cleanup integration needs redesign.

### 3. The `development-process` skill does not exist

The actual skill is called `development-guidelines`.

**Impact:** Medium. Easy to fix.

### 4. `%LANGUAGE%` placeholder handling is incomplete

**Impact:** Medium. Needs rethinking for multi-language.

## Moderate Issues

5. No consideration of the plugin distribution model
6. The cleanup script deletes everything outside specific directories
7. Implementation plan references a Phase 5 not mentioned in the phase list
8. Content depth estimates may be insufficient

## Minor Issues

9-12. Typo, inconsistent naming, optional migration guide, unmeasurable success metrics

## Recommendations

1. Fix all path references to use `skills/`
2. Redesign the multi-language story
3. Rename `development-process` to `development-guidelines`
4-7. Address distribution model, cleanup behavior, effort estimates, capy integration
```

#### Analysis

Both reviews caught the same critical issues (wrong paths, LANGUAGE/LANGUAGES mismatch, wrong skill name). The with-skill review adds:
- Structured severity classification with type codes
- Confidence scores with explicit reasoning for each finding
- Labeled Evidence and Recommendation fields
- Clean Areas section confirming what passed review
- Standardized Next Steps with 5 options

The baseline found 2 additional issues the skill missed (cleanup script deletion behavior, Phase 5 mismatch), suggesting the skill's structured workflow may cause slight tunnel vision. However, the baseline's free-form output lacks the consistency needed for programmatic consumption or cross-review comparison.

---

### Eval 2: Synthetic Flawed Design (Issue Detection)

**Prompt:** `/kk:review-design synthetic-flawed-feature`
**Documents:** `docs/wip/synthetic-flawed-feature/design.md` + `implementation.md`
**Purpose:** Objective test with 6 planted flaws — measures detection accuracy rather than format compliance.

#### Planted Flaws

| # | Flaw | Type | Severity |
|---|------|------|----------|
| 1 | Design says REST + FCM; implementation says WebSocket (and claims design agrees) | INCONSISTENT | P0 |
| 2 | Design says PostgreSQL; implementation uses MongoDB (mongoose) | INCONSISTENT | P0/P1 |
| 3 | Design claims "3 endpoints" but only describes 2; implementation defines 4 | INCOMPLETE | P0 |
| 4 | Filtering section: "supports filtering" with zero specifics | AMBIGUOUS | P2 |
| 5 | No error handling strategy for API layer | MISSING | P1 |
| 6 | Testing section is one sentence | INCOMPLETE | P2 |

#### Scores

| Configuration | Pass Rate | Time | Tokens | Tool Calls |
|--------------|-----------|------|--------|------------|
| With Skill | **9/9 (100%)** | 223s | 31,215 | 16 |
| Without Skill | 7/9 (78%) | 101s | 20,812 | 11 |

#### Assertions

| # | Assertion | With Skill | Baseline |
|---|-----------|-----------|----------|
| 1 | Detects REST vs WebSocket inconsistency | PASS | PASS |
| 2 | Detects PostgreSQL vs MongoDB inconsistency | PASS | PASS |
| 3 | Detects "3 endpoints" but only 2 described | PASS | PASS |
| 4 | Flags filtering as ambiguous/incomplete | PASS | PASS |
| 5 | Flags missing error handling | PASS | PASS |
| 6 | Flags testing section as incomplete | PASS | PASS |
| 7 | Overall assessment is not SOUND | PASS | PASS |
| 8 | At least one P0/P1 severity rating | PASS | FAIL — Critical/Major/Minor tiers |
| 9 | Structured format (type code, confidence, evidence, recommendation) | PASS | FAIL — narrative prose |

#### With-Skill Output

```markdown
## Design Review: synthetic-flawed-feature

**Scope:** design.md + implementation.md (default)
**Overall assessment:** MAJOR_GAPS

**Summary:** 11 findings: 2 critical, 4 high, 3 medium, 2 low

### P0 - Critical

- **[INCONSISTENT]** Endpoint count mismatch between design and implementation
  - **Confidence:** 10/10 -- Design says "3 REST API endpoints" in overview, defines 2.
    Implementation defines 4. All three numbers disagree.
  - **Evidence:** design.md overview: "3 REST API endpoints"; body defines POST /send and
    GET /preferences; implementation Step 5 lists 4 endpoints.

- **[INCONSISTENT]** Push notification technology contradicts between documents
  - **Confidence:** 10/10 -- design.md specifies FCM. implementation.md says
    "WebSocket for push (replacing FCM as noted in the design)" -- but the design says
    no such thing.

### P1 - High

- **[INCONSISTENT]** Database technology contradicts (PostgreSQL vs MongoDB)
  - **Confidence:** 10/10

- **[INCOMPLETE]** Missing endpoint definitions in design.md
  - **Confidence:** 9/10

- **[MISSING]** No error handling or failure response specification
  - **Confidence:** 8/10

- **[TECH_RISK]** WebSocket push has unaddressed offline delivery gap
  - **Confidence:** 8/10

### P2 - Medium

- **[AMBIGUOUS]** Filtering section references undefined endpoint
- **[INCOMPLETE]** Rate limiting lacks specification
- **[INCOMPLETE]** Testing strategy is a single sentence

### P3 - Low

- **[STRUCTURE]** Implementation overview contradicts its own content
- **[MISSING]** No monitoring or observability mentioned

## Clean Areas

- Security model, async delivery architecture, component separation, file structure,
  external service selection -- all sound.
```

#### Baseline Output

```markdown
# Design Review: Notification Service

The documents contain multiple significant inconsistencies, gaps, and underspecified
areas that would block a clean implementation.

## Critical Issues

1. Push notification technology contradiction (FCM vs WebSocket)
2. Database technology contradiction (PostgreSQL vs MongoDB)
3. Missing API endpoint in design (2 of 3 documented)
4. Endpoint count mismatch (3 vs 2 vs 4)

## Major Issues

5. WebSocket infrastructure appears only in implementation
6. Notification history endpoint is underspecified
7. Dead letter queue mentioned but not designed
8. Rate limiting is vague

## Minor Issues

9-14. No response schemas, no error handling, opaque payload, minimal testing,
no deployment details, thin security

## Document Quality Assessment

| Criterion | Rating |
|-----------|--------|
| Completeness | Poor |
| Internal consistency | Poor |
| Cross-doc consistency | Poor |
| Technical soundness | Fair |
| Implementability | Poor |
```

#### Analysis

**Both reviews detected all 6 planted flaws.** The baseline found 14 issues vs the skill's 11, including extras the skill missed (dead letter queue design gap, no response schemas, opaque payload field, no deployment details, thin security). The baseline is slightly more thorough on content.

The +22% delta is the smallest across all evals because this eval's assertions are weighted toward content detection (6 of 9 assertions). The 2 format-only assertions (P0/P1 labels, structured fields) account for the entire gap.

**Key insight:** For issue detection, the skill provides no meaningful advantage over baseline Claude. Its value is entirely in standardized output structure.

---

### Eval 3: Completed Capy-Integration (All Scope)

**Prompt:** `Review the design docs for the capy-integration feature. The docs are at docs/done/capy-integration/. Review all documents including tasks.`
**Documents:** `docs/done/capy-integration/design.md` + `implementation.md` + `tasks.md`
**Purpose:** Test multi-document review (all scope) on completed, higher-quality docs. Tests cross-document consistency analysis and codebase cross-referencing.

#### Scores

| Configuration | Pass Rate | Time | Tokens | Tool Calls |
|--------------|-----------|------|--------|------------|
| With Skill | **7/7 (100%)** | 333s | 52,680 | 58 |
| Without Skill | 3/7 (43%) | 405s* | 61,303 | 30 |

*Baseline duration inflated by permission retry issues; true execution time likely lower.

#### Assertions

| # | Assertion | With Skill | Baseline |
|---|-----------|-----------|----------|
| 1 | Overall assessment uses SOUND/CONCERNS_FOUND/MAJOR_GAPS | PASS | FAIL — "Needs minor revision" |
| 2 | Findings under P0/P1/P2/P3 severity headings | PASS | FAIL — Important/Minor |
| 3 | Finding type codes from taxonomy | PASS | FAIL — no codes |
| 4 | Covers all three documents | PASS | PASS |
| 5 | Cross-document consistency evaluated | PASS | PASS |
| 6 | Next Steps section or summary | PASS | PASS |
| 7 | Clean Areas or Areas Not Covered section | PASS | FAIL — no such section |

#### With-Skill Output

```markdown
## Design Review: Capy Knowledge Base Integration

**Scope:** design.md, implementation.md, tasks.md (all)
**Overall assessment:** CONCERNS_FOUND

**Summary:** 7 findings: 0 critical, 1 high, 4 medium, 2 low

### P1 - High

- **[MISSING]** `review-design` skill omitted from design and implementation docs
  - **Confidence:** 9/10 -- Verified by searching all three docs. Zero matches. Yet the
    codebase shows `review-design/SKILL.md` and `review-process.md` both have full capy
    integration. The design docs are incomplete -- they don't document a feature that was
    actually shipped.
  - **Evidence:** `review-design/SKILL.md` line 12: protocol reference present.
    `review-process.md` line 36: capy search in Step 2. Line 125: capy index in Step 6.

### P2 - Medium

- **[MISSING]** `kk:debug-context` label defined but never consumed by any skill
  - **Confidence:** 8/10 -- `grep -r "debug-context"` returns only the protocol file.

- **[INCONSISTENT]** Protocol reference placement deviates from implementation plan
  - **Confidence:** 6/10

- **[AMBIGUOUS]** `capy_fetch_and_index` auto-fetch lacks specificity
  - **Confidence:** 7/10

- **[INCOMPLETE]** Testing strategy minimal for bootstrap code paths
  - **Confidence:** 7/10

### P3 - Low

- **[STRUCTURE]** Status fields still say "draft" in done docs
- **[STRUCTURE]** Task 9.1 has hedging parenthetical

## Clean Areas

- Architecture pattern (Trigger vs. Taxonomy), graceful degradation, source label taxonomy,
  cross-document consistency, task decomposition, bootstrap integration, CoVe isolation design,
  static reference coexistence, index conventions -- 9 specific areas verified clean.
```

#### Baseline Output

```markdown
# Design Review: capy-integration (Baseline — No Skill)

**Overall verdict:** Needs minor revision -- no critical flaws, but consistency and
completeness gaps.
**Findings:** 9 total (0 critical, 3 important, 6 minor)

## Important Findings

1. Status metadata inconsistency (draft vs done)
2. `kk:debug-context` label defined but unused
3. No data lifecycle/cleanup strategy

## Minor Findings

4-9. Bootstrap error handling, auto-fetch vagueness, task 9.1 hedge,
task 13 missing outcomes, missing per-skill rollback, unspecified relative paths

## Cross-Document Consistency

- design.md and implementation.md broadly aligned
- tasks.md accurately reflects implementation.md
- Status field discrepancy noted
```

#### Analysis

The with-skill review is dramatically more thorough:
- **58 tool calls** vs 30 — the skill drove extensive codebase cross-referencing, verifying which skills actually have capy integration vs what the docs claim
- Found a **P1 finding the baseline missed entirely**: the `review-design` skill was shipped with capy integration but never documented in the design/implementation docs — a real undocumented feature
- **9 specific Clean Areas** vs none — the skill explicitly confirms what passed review, providing positive signal
- The baseline found 3 issues the skill didn't flag (data lifecycle/cleanup, task 13 outcomes, per-skill rollback), showing breadth but less depth

---

## Cross-Eval Analysis

### What the Skill Adds

1. **Perfect format compliance** (100% vs 48% baseline) — structured severity headings, type codes, confidence scores, evidence fields, recommendations, next steps, clean areas
2. **Deeper codebase cross-referencing** — eval 3 shows 58 vs 30 tool calls; the skill explicitly instructs verification of code references
3. **Self-check workflow** — confidence scores with explicit reasoning reduce false positives
4. **Positive signal** — Clean Areas section confirms what was reviewed and passed, not just what failed
5. **Actionable next steps** — standardized 5-option menu for user to choose how to proceed

### What the Skill Does NOT Add

1. **Issue detection accuracy** — baseline Claude catches the same substantive issues. Eval 2 proves this: 6/6 planted flaws detected by both
2. **Breadth of coverage** — baselines sometimes find issues the skill misses (eval 1: cleanup script deletion, Phase 5 mismatch; eval 2: DLQ design gap, no response schemas; eval 3: data lifecycle, rollback strategy)
3. **Speed** — skill runs are ~20% slower on average (+45s) due to the multi-phase workflow
4. **Token efficiency** — marginal increase (+2K tokens avg), not significant

### Assertion Quality Notes

The graders flagged an important eval design observation: **format-compliance assertions are non-discriminating within with-skill runs** (they always pass) but **strongly discriminating against baselines** (they mostly fail). This means:

- The +52% pass rate delta overstates the skill's value if you care about content quality
- The delta accurately reflects the skill's value if you care about output standardization
- Future evals should separate format assertions from content assertions for fairer comparison

### Timing Breakdown

| Eval | With Skill | Baseline | Overhead |
|------|-----------|----------|----------|
| 1. WIP language-skills | 248s | 162s | +86s (53%) |
| 2. Synthetic flawed | 223s | 101s | +122s (121%) |
| 3. Done capy-all | 333s | 405s* | -72s* |

*Eval 3 baseline inflated by permission retries. True overhead is likely +50-100s consistent with other evals.

The skill's multi-phase workflow (load → capy search → quality review → technical review → self-check → present) adds ~50-120s overhead per review.

### Token Breakdown

| Eval | With Skill | Baseline | Overhead |
|------|-----------|----------|----------|
| 1. WIP language-skills | 49,118 | 44,494 | +4,624 |
| 2. Synthetic flawed | 31,215 | 20,812 | +10,403 |
| 3. Done capy-all | 52,680 | 61,303* | -8,623* |

Token overhead is modest and inconsistent — likely within normal variance for a single run per configuration.

---

## Conclusions

The `kk:review-design` skill's value proposition is **output standardization, not issue detection**. Claude already catches design flaws effectively without skill guidance. The skill ensures:

1. Every review follows the same structured format (P0-P3, type codes, confidence, evidence, recommendations)
2. Reviews include explicit self-checks and confidence reasoning
3. Reviews confirm what passed (Clean Areas), not just what failed
4. Users get a standardized decision menu (Next Steps)
5. Codebase cross-referencing is driven by the workflow, not left to Claude's discretion

For teams that need consistent, comparable review outputs across features and reviewers, the skill provides clear value. For one-off reviews where content quality matters more than format, the baseline is equally effective and faster.

### Recommendations for Skill Improvement

1. **Add content-quality assertions** to future evals — current assertions are format-heavy
2. **Consider a "breadth checklist"** in the skill — baselines sometimes catch issues the skill's structured workflow misses (e.g., deployment concerns, rollback strategy)
3. **Reduce overhead** — the capy search step adds latency; consider making it conditional on capy availability
4. **Add a "document assumptions" prompt** — the skill should explicitly surface assumptions the design makes about existing code (e.g., "this design assumes skills live at X")
