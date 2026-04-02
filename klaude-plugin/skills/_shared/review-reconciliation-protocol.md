# Review Reconciliation Protocol

Shared protocol for isolated review workflows. Both `solid-code-review:isolated` and `implementation-review:isolated` reference this document during their reconciliation phase.

## Disposition Categories

Every sub-agent finding MUST be assigned exactly one disposition during reconciliation.

| Disposition | Definition | Required Evidence |
|---|---|---|
| **Confirmed** | Finding is valid regardless of session context | None — the finding stands as-is |
| **Disputed — Intentional** | The flagged behavior was a deliberate decision during implementation | You MUST state the specific reason the deviation was chosen and why it is correct |
| **Disputed — False Positive** | Finding is incorrect given broader context the reviewer lacked | You MUST cite specific evidence (code path, test, spec section, or constraint) that invalidates the finding |
| **Duplicate** | Same issue flagged by multiple reviewers independently | Merge the findings into one entry, note which reviewers agreed, and apply the severity escalation rule below |

### Disposition rules

- You MUST NOT assign "Disputed" without evidence. "I disagree" is not a disposition.
- When two reviewers flag the same logical issue (even with different descriptions or file locations), assign **Duplicate** and merge into the higher-quality description.
- If you are uncertain whether a finding is valid, assign **Confirmed** and let the user decide. Err toward surfacing, not suppressing.

## Invariants

These rules are non-negotiable. Violating any of them invalidates the review.

1. **No silent drops.** Every sub-agent finding MUST appear in the consolidated report with a disposition. You MUST NOT omit, skip, or summarize away any finding.
2. **No new findings from the main agent.** You already had your chance during implementation. The reconciliation phase is for evaluating sub-agent findings, not adding your own.
3. **Disputed findings are still shown.** A "Disputed" disposition does not remove the finding from the report. The user sees it with your reasoning and makes the final call.
4. **Agreement escalates severity.** When independent reviewers flag the same issue (disposition: Duplicate), increase the effective severity by one level (e.g., P2 becomes recommended-P1). Note the original severity and the escalated severity in the report.

## Consolidated Report Template

Use this template for the final report. Replace `{finding_format}` sections with the appropriate format for the review type (code review uses file:line + confidence%, spec review uses finding type + confidence 1-10).

```markdown
## Review Summary (Isolated Mode)

**Reviewers**: {list each reviewer with type, e.g., "code-reviewer (sub-agent), pal codereview (external model)"}
**Files reviewed**: {X} files, {Y} lines changed
**Scope**: {what was reviewed — diff range, feature area, task set}
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical

{For each finding:}
- **{location}** {Brief title}
  - **Flagged by**: {reviewer name(s)}
  - **Disposition**: {disposition with reasoning if Disputed}
  {finding_format — severity, confidence, description, suggested fix}

### P1 - High

{same format}

### P2 - Medium

{same format}

### P3 - Low

{same format}

---

## Reconciliation Summary

| # | Finding | Reviewers | Original Severity | Disposition | Effective Severity | Action |
|---|---------|-----------|-------------------|-------------|--------------------|--------|
| 1 | {title} | A, B | P2 | Duplicate (merged) | P1 (escalated) | Fix |
| 2 | {title} | A | P1 | Confirmed | P1 | Fix |
| 3 | {title} | B | P2 | Disputed — Intentional | P2 | User decides |

## Reviewer Disagreements

{If reviewers produced contradictory findings on the same code (one says X is wrong, the other says X is correct), surface both perspectives here with the evidence from each side. If no disagreements, omit this section.}
```

### Template notes

- **Code review findings** use: `file:line`, severity (P0-P3), confidence (percentage with reasoning), description, suggested fix.
- **Spec conformance findings** use: finding type (`MISSING_IMPL`, `SPEC_DEV`, etc.), severity (P0-P3), confidence (1-10 with mandatory reasoning), description, evidence from spec and code.
- The `{finding_format}` placeholder is not literal — adapt the bullet structure to the review type while keeping the outer template (summary, sections by severity, reconciliation table) consistent.

## Trust Level Guidance

### Code review findings

Code review findings use **uniform trust**: treat sub-agent and external model findings with equal weight. Neither has inherently more reliable judgment for code quality issues — cross-reference and reconcile on the merits of each finding.

### Spec conformance findings

Spec conformance findings use **type-specific trust levels** because some finding types are more objective than others, and the main agent's session context is more relevant for some types.

| Finding Type | Trust Level | Reasoning | Reconciliation Guidance |
|---|---|---|---|
| `MISSING_IMPL` | **High trust in sub-agent** | "I forgot to implement it" is a real possibility for the author | Accept unless you can point to the specific code that implements it |
| `AMBIGUOUS` | **High trust in sub-agent** | If an independent reader found the spec ambiguous, that is a real signal regardless of author intent | Accept — the spec needs clarification even if you know what was intended |
| `DOC_INCON` | **High trust in sub-agent** | Internal contradictions in documentation are objective | Accept unless the cited sections do not actually contradict |
| `OUTDATED_DOC` | **High trust in sub-agent** | Doc staleness is objective and verifiable | Accept unless the doc already reflects current state |
| `SPEC_DEV` | **Medium trust** | May be an intentional deviation made during implementation | You MUST state why the deviation was chosen. If intentional, suggest updating the spec to reflect reality |
| `EXTRA_IMPL` | **Medium trust** | May be a legitimate addition discovered during implementation | You MUST state why the extra code exists. If intentional, suggest updating the spec to document it |

### Applying trust levels

- **High trust**: Default to **Confirmed**. Only dispute with specific counter-evidence.
- **Medium trust**: Evaluate against session context. If the deviation was intentional, use **Disputed — Intentional** and recommend a spec update so the deviation is documented. If unintentional, use **Confirmed**.
