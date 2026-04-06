### Workflow

For capy knowledge base conventions, see [capy-knowledge-protocol.md](../_shared/capy-knowledge-protocol.md).

Copy this checklist and check off items as you complete them:

```
Design Review Progress:
- [ ] Step 1: Load documents
- [ ] Step 2: Capy search for prior context
- [ ] Step 3: Document quality review
- [ ] Step 4: Technical soundness review
- [ ] Step 5: Self-check and confidence assessment
- [ ] Step 6: Present findings
```

---

### 1) Load Documents

- Parse the invocation arguments: extract feature name and optional scope argument
- **Argument disambiguation:** if the first argument matches a directory in `/docs/wip/`, treat it as the feature name. If it matches a scope keyword (`design`, `implementation`, `tasks`, `all`) and no such feature directory exists, treat it as the scope and prompt the user for the feature name.
- Locate `/docs/wip/[feature-name]/` directory
- If feature name is not provided or ambiguous, list `/docs/wip/` contents and ask the user
- Scope resolution:

| Scope arg | Documents to load |
|-----------|-------------------|
| _(none)_ | `design.md` + `implementation.md` |
| `design` | `design.md` only |
| `implementation` | `implementation.md` only |
| `tasks` | `tasks.md` only |
| `all` | `design.md` + `implementation.md` + `tasks.md` |

- If a requested document is missing, inform the user and proceed with available docs (do NOT stop — reviewing a single doc is a valid use case)
- Read all in-scope documents

### 2) Capy Search for Prior Context

- Search `kk:arch-decisions` for prior design rationale related to the feature area
- Search `kk:review-findings` for patterns from prior reviews that may apply to this design

### 3) Document Quality Review

Evaluate each in-scope document against analysis-process expectations:

- **Completeness** — Is the design detailed enough for an experienced developer with zero codebase context? Are file paths, function names, and components explicitly named where appropriate?
- **Clarity** — Are requirements unambiguous? Could a developer follow the plan without needing to ask clarifying questions?
- **Internal consistency** — Does each document agree with itself? (e.g., a design.md that says "3 endpoints" then only describes 2)
- **Cross-document consistency** — Do design.md and implementation.md agree? (only when both are in scope)
- **Convention adherence** — Does the document structure follow the analysis-process output conventions? Are sections well-organized with appropriate headings?
- **Subtask quality** (only when tasks.md is in scope) — Are subtasks specific enough? Do they name the file/function/component being touched? Are dependencies between tasks correct?

### 4) Technical Soundness Review

Evaluate the proposed architecture:

- **Viability** — Will this design actually work? Are there logical flaws in the approach?
- **Edge cases and failure modes** — What unaddressed scenarios could break the implementation?
- **Trade-offs** — Are trade-offs explicitly stated? Are they well-reasoned? Are there simpler alternatives not considered?
- **Scalability** — Does the design consider growth? Are there bottlenecks?
- **Testing strategy** — Does the plan account for how the feature will be tested?
- **Migration and rollback** — If the feature changes existing behavior, is there a migration path? Can it be rolled back?
- **Cross-reference with codebase** — When the design references existing code, patterns, or files, verify they exist and the references are accurate. Use Grep/Glob for this.

### 5) Self-Check and Confidence Assessment

For each finding:

1. Re-read the relevant doc section
2. Ask: **"Could I be misreading the docs?"** — check for context from other sections that might address the concern
3. Ask: **"Is this genuinely a problem, or just a different-but-valid approach?"**
4. Assign confidence score (1-10) with explicit reasoning
5. Drop findings that don't survive the self-check

### 6) Present Findings

#### Output format

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

- **[FINDING_TYPE]** Brief title
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

**Capy index:** Index any confirmed `TECH_RISK` findings that reveal non-obvious architectural constraints as `kk:arch-decisions`. Index confirmed P0/P1 findings that reveal recurring design patterns (not one-off issues) as `kk:review-findings`.

#### Next steps

After presenting findings, ask the user how to proceed:

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

**Important:** Do NOT update any documents until the user explicitly confirms.
