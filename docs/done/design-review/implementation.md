# Implementation Plan: design-review Skill

> Design: [./design.md](./design.md)
> Issue: [#52](https://github.com/serpro69/claude-toolbox/issues/52)

## Files to Create

| File | Purpose |
|------|---------|
| `klaude-plugin/skills/design-review/SKILL.md` | Skill entry point with frontmatter, overview, modes, invocation |
| `klaude-plugin/skills/design-review/review-process.md` | Standard mode workflow (6 phases) |
| `klaude-plugin/skills/design-review/review-isolated.md` | Isolated mode workflow (4 steps) |
| `klaude-plugin/agents/design-reviewer.md` | Sub-agent definition for isolated mode |

No existing files need modification. The skill is self-contained and follows the same directory/file conventions as `solid-code-review` and `implementation-review`.

---

## SKILL.md — Skill Entry Point

### Frontmatter

```yaml
name: design-review
description: |
  Review design and implementation docs produced by analysis-process. Evaluates document quality, internal consistency, and technical soundness.
  Use after analysis-process completes and before starting implementation-process.
```

### Content Structure

Follow the pattern of `solid-code-review/SKILL.md` and `implementation-review/SKILL.md`:

1. **Overview** — one paragraph describing purpose (pre-implementation review gate)
2. **Review Modes** section — standard and isolated, with brief descriptions and links to workflow files
3. **Finding Types** table — the 6-type taxonomy (INCOMPLETE, INCONSISTENT, TECH_RISK, MISSING, AMBIGUOUS, STRUCTURE)
4. **Severity Levels** table — P0-P3 adapted for design review
5. **Workflow** section — phase list with link to `review-process.md`
6. **Invocation** section — command examples for both modes, with scope argument explanation

---

## review-process.md — Standard Mode Workflow

### Structure

Follow the pattern of `solid-code-review/review-process.md`: a checklist at the top, then detailed step descriptions.

### Checklist

```
Design Review Progress:
- [ ] Step 1: Load documents
- [ ] Step 2: Capy search for prior context
- [ ] Step 3: Document quality review
- [ ] Step 4: Technical soundness review
- [ ] Step 5: Self-check and confidence assessment
- [ ] Step 6: Present findings
```

### Step 1: Load Documents

- Parse the invocation arguments: extract feature name and optional scope argument
- Scope resolution:
  - No scope arg → `design.md` + `implementation.md`
  - `design` → `design.md` only
  - `implementation` → `implementation.md` only
  - `tasks` → `tasks.md` only
  - `all` → `design.md` + `implementation.md` + `tasks.md`
- Argument disambiguation: if the first argument matches a directory in `/docs/wip/`, treat it as the feature name. If it matches a scope keyword (`design`, `implementation`, `tasks`, `all`) and no such feature directory exists, treat it as the scope and prompt the user for the feature name.
- Locate `/docs/wip/[feature-name]/` directory
- If feature name not provided or ambiguous, list `/docs/wip/` contents and ask user
- If a requested doc is missing, inform the user and proceed with available docs (do NOT stop)
- Read the in-scope documents

### Step 2: Capy Search for Prior Context

- Search `kk:arch-decisions` for prior design rationale related to the feature area
- Search `kk:review-findings` for patterns from prior reviews that may apply to this design

### Step 3: Document Quality Review

Evaluate each in-scope document against analysis-process expectations:

- **Completeness** — Is the design detailed enough for an experienced developer with zero codebase context? Are file paths, function names, and components explicitly named where appropriate?
- **Clarity** — Are requirements unambiguous? Could a developer follow the plan without needing to ask clarifying questions?
- **Internal consistency** — Does each document agree with itself? (e.g., a design.md that says "3 endpoints" then only describes 2)
- **Cross-document consistency** — Do design.md and implementation.md agree? (only when both are in scope)
- **Convention adherence** — Does the document structure follow the analysis-process output conventions? Are tasks (if in scope) concrete and actionable with named files/functions?
- **Subtask quality** (only when tasks.md is in scope) — Are subtasks specific enough? Do they name the file/function/component being touched?

### Step 4: Technical Soundness Review

Evaluate the proposed architecture:

- **Viability** — Will this design actually work? Are there logical flaws in the approach?
- **Edge cases and failure modes** — What unaddressed scenarios could break the implementation?
- **Trade-offs** — Are trade-offs explicitly stated? Are they well-reasoned? Are there simpler alternatives not considered?
- **Scalability** — Does the design consider growth? Are there bottlenecks?
- **Testing strategy** — Does the plan account for how the feature will be tested?
- **Migration and rollback** — If the feature changes existing behavior, is there a migration path? Can it be rolled back?
- **Cross-reference with codebase** — When the design references existing code, patterns, or files, verify they exist and the references are accurate. Use Grep/Glob for this.

### Step 5: Self-Check and Confidence Assessment

For each finding:
1. Re-read the relevant doc section
2. Ask: "Could I be misreading the docs?" — check for context from other sections
3. Ask: "Is this genuinely a problem, or just a different-but-valid approach?"
4. Assign confidence score (1-10) with explicit reasoning
5. Drop findings that don't survive the self-check

### Step 6: Present Findings

#### Output Format

```markdown
## Design Review: [Feature Name]

**Scope:** [docs reviewed]
**Overall assessment:** [SOUND / CONCERNS_FOUND / MAJOR_GAPS]
**Documents:**
- Design: [path] (if in scope)
- Implementation: [path] (if in scope)
- Tasks: [path] (if in scope)

**Summary:** [X findings: N critical, N high, N medium, N low]

---

## Findings

### P0 - Critical

- **[finding_type]** Brief title
  - **Section:** [doc:section reference]
  - **Confidence:** N/10 — [reasoning]
  - **Description:** [what the issue is]
  - **Evidence:** [specific doc text or cross-reference supporting the finding]
  - **Recommendation:** [what to do]

### P1 - High

{same format}

### P2 - Medium

{same format}

### P3 - Low

{same format}

---

## Clean Areas

[List sections/aspects that passed review — confirms what was checked.]
```

Use `(none)` under severity sections with no findings.

#### Next Steps

```markdown
---

## Next Steps

I found X issues (P0: ..., P1: ..., P2: ..., P3: ...).

**How would you like to proceed?**

1. **Update docs** — I'll revise the design docs to address all findings
2. **Update high severity only** — Address P0/P1 issues
3. **Discuss specific items** — Let's talk through particular findings
4. **Proceed to implementation** — Findings are acceptable, move forward
5. **No changes** — Review complete, no action needed

Please choose an option or provide specific instructions.
```

Do NOT update any documents until the user explicitly confirms.

**Capy index:** Index any confirmed `TECH_RISK` findings that reveal non-obvious architectural constraints as `kk:arch-decisions`. Index confirmed P0/P1 findings that reveal recurring design patterns (not one-off issues) as `kk:review-findings`.

---

## review-isolated.md — Isolated Mode Workflow

### Structure

Follow the pattern of `solid-code-review/review-isolated.md`: checklist, then 4 detailed steps.

### Checklist

```
Isolated Design Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Annotate findings
- [ ] Step 4: Present report
```

### Step 1: Prepare Artifacts

#### 1a) Read documents

Parse scope argument (same logic as standard mode Step 1). Read the in-scope documents from `/docs/wip/[feature]/`.

#### 1b) Resolve pal model

Call `pal` `listmodels` to get available models. Select the most capable model (prefer latest generation with thinking/reasoning support) for the `pal codereview` call in Step 2.

#### 1c) Prepare document content for pal

Since `pal codereview` cannot read files itself, prepare the document contents as a single text block to pass as input. Include clear headers separating each document.

**Important:** `pal codereview` is optimized for source code and diffs. When passing design documents, wrap the content with an explicit framing instruction: "The following is a design document (markdown), not source code. Review it for technical soundness, completeness, internal consistency, and whether it provides sufficient detail for implementation." This prevents the model from applying code-specific heuristics to prose.

### Step 2: Spawn Reviewers (Parallel)

Launch both reviewers in a **single message** so they execute in parallel.

#### Reviewer A — `design-reviewer` sub-agent

Spawn using the Agent tool:

| Parameter | Value |
|---|---|
| `subagent_type` | `kk:design-reviewer` |
| `description` | `Isolated design review` |
| `prompt` | See template below |

**Sub-agent prompt template:**

```
You are reviewing the design documents for the "{feature_name}" feature. Apply your full review workflow.

## Feature Directory

{absolute path to /docs/wip/[feature]/}

## Documents to Review

- Design: {absolute path to design.md} (if in scope, otherwise "Not in scope")
- Implementation: {absolute path to implementation.md} (if in scope, otherwise "Not in scope")
- Tasks: {absolute path to tasks.md} (if in scope, otherwise "Not in scope")

Read the documents yourself using the Read tool. Produce your findings in the output format specified in your agent definition.
```

#### Reviewer B — `pal codereview`

Follow the invocation protocol in `_shared/pal-codereview-invocation.md` (skill runtime path). For the `step` parameter in step 1, use the document contents prepared in Step 1c. For the `model` parameter, use the model resolved in Step 1b. Set `focus_on` to `"technical soundness, completeness, internal consistency, edge cases, failure modes"`.

#### Parallel execution

Issue the pal step 1 call and the Agent tool call (Reviewer A) in the **same message** so they execute in parallel. When both return, make the pal step 2 continuation call using the `continuation_id` from step 1.

#### Error handling

- **`pal` failure**: Note failure, proceed to Step 3 with design-reviewer findings only
- **`design-reviewer` sub-agent failure**: Note failure, proceed to Step 3 with pal findings only. Suggest `/kk:design-review` (standard mode) as supplement
- **Both fail**: Abort isolated mode. Suggest fallback to `/kk:design-review` (standard mode)
- **Malformed output**: Attempt best-effort parsing. If unparseable, treat as failure

### Step 3: Annotate Findings

The main agent annotates — providing context, not judgment. Do NOT assign dispositions.

#### 3a) Duplicate merging

Compare findings from both reviewers by document section and issue description:
- When both flag the same logical issue: merge, tag as **"corroborated"**
- Severity stays as the design-reviewer assessed it. If pal's native output implies a different level of urgency, note both perspectives side by side. Do NOT map pal's output to P0-P3 — describe the implied urgency in prose.
- If only one reviewer flagged an issue, keep as-is with reviewer attribution

#### 3b) Author context annotations

For each finding, consider whether the analysis-process session context adds relevant information:
- If yes: add clearly-labeled **"Author context"** annotation (e.g., "We discussed this trade-off in Step 3 and chose X because Y")
- If no: leave as-is
- Annotations are context, not judgments

#### 3c) Author-sourced findings

If the close reading during annotation triggers new observations:
- Tag as **"author-sourced"**
- Clearly distinct from sub-agent findings

#### 3d) pal follow-up (optional)

If a pal finding is ambiguous, the main agent MAY use pal's follow-up capability to clarify.

### Step 4: Present Report

#### Report template

```markdown
## Design Review Summary (Isolated Mode)

**Reviewers**: design-reviewer (Claude sub-agent), pal codereview ([model name])
**Documents reviewed**: [list]

---

### Corroborated Findings
(Both reviewers flagged — highest signal)

- **[doc:section]** Brief title ⟨corroborated⟩
  - Type: [finding_type] | Severity: P[0-3] | Confidence: [N]/10 — [reasoning]
  - **Description:** [description]
  - **Evidence:** [doc references]
  - **Recommendation:** [recommendation]
  - design-reviewer: [description in structured format]
  - pal: [description in native format]
  - Author context: [optional annotation]

### Design Reviewer Findings
(design-reviewer sub-agent only — P0-P3 format)

- **[doc:section]** Brief title
  - Type: [finding_type] | Severity: P[0-3] | Confidence: [N]/10 — [reasoning]
  - **Description:** [description]
  - **Evidence:** [doc references]
  - **Recommendation:** [recommendation]
  - Author context: [optional annotation]

### External Review Findings
(pal codereview — native format)

- [pal output in native format]
  - Author context: [optional annotation]

### Author-Sourced Findings
(Main agent observations during annotation — weight accordingly)

- **[doc:section]** Brief title {author-sourced}
  - [description]
```

Omit any section with no findings. If a reviewer failed, note the failure at the top.

#### Next steps

```markdown
---

## Next Steps

I found X issues (corroborated: ..., design-reviewer: ..., pal: ..., author-sourced: ...).

**How would you like to proceed?**

1. **Update docs** — I'll revise the design docs to address all findings
2. **Update corroborated + high severity** — Address corroborated findings and P0/P1 issues
3. **Update specific items** — Tell me which findings to address
4. **Proceed to implementation** — Findings are acceptable, move forward
5. **No changes** — Review complete, no action needed

Please choose an option or provide specific instructions.
```

Do NOT update any documents until the user explicitly confirms.

---

## design-reviewer Agent Definition

### File: `klaude-plugin/agents/design-reviewer.md`

### Frontmatter

```yaml
name: design-reviewer
description: |
  Independent design document reviewer with no authorship attachment. Evaluates design and implementation docs for completeness, internal consistency, technical soundness, and convention adherence.
tools:
  - Read
  - Grep
  - Glob
  - mcp__capy__capy_search
```

### Content Structure

Follow the pattern of `code-reviewer.md` and `spec-reviewer.md`:

1. **Identity** — independent design reviewer, did not write these docs, zero session context
2. **What You Receive** — document paths, review scope
3. **What You Do NOT Have** — conversation history, design rationale discussions, alternatives considered
4. **Tool Access** — restricted allowlist explanation, usage guidance
5. **Finding Type Taxonomy** — the 6-type table from design.md
6. **Severity Levels** — P0-P3 table adapted for design review
7. **Confidence Levels** — 1-10 scale with meanings
8. **Review Workflow** — 7 steps:
   1. Read provided documents
   2. Capy search for prior arch decisions and review findings
   3. Document quality pass
   4. Technical soundness pass
   5. Cross-document consistency (when multiple docs in scope)
   6. Self-check and confidence assessment
   7. Output structured findings
9. **Output Format** — structured markdown contract:
   - Header with feature name, docs reviewed, scope, overall assessment (SOUND / CONCERNS_FOUND / MAJOR_GAPS)
   - Findings grouped by P0-P3, each with: finding type code, doc:section reference, confidence with reasoning, description, evidence, recommendation
   - "Areas Not Covered" section for anything not verifiable
   - No "next steps" section
10. **Output Rules** — every finding must include type, location, severity, confidence with reasoning, description, evidence, and recommendation. Use `(none)` under empty severity sections. The agent omits a "next steps" section because the orchestrating workflow (standard mode or isolated mode annotation phase) handles user interaction.
