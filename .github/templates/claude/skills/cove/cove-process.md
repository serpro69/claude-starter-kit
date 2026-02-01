### Workflow

Copy this checklist and check off items as you complete them:

```
CoVe Progress:
- [ ] Step 1: Generate Initial Answer
- [ ] Step 2: Create Verification Questions
- [ ] Step 3: Independent Verification
- [ ] Step 4: Reconciliation & Final Answer
```

---

## Step 1: Initial Response

Generate the initial answer to the user's question. This establishes a baseline that will be verified.

**Requirements:**
- Mark the response clearly as "Initial Answer"
- Provide a complete response (not abbreviated)
- Note any areas of uncertainty

---

## Step 2: Generate Verification Questions

Create 3-5 targeted questions designed to expose potential errors in the initial answer.

### Question Categories

| Category | Purpose | Example |
|----------|---------|---------|
| Factual | Verify specific claims | "What is the exact release date of X?" |
| Logical | Check reasoning consistency | "Does conclusion Y follow from premise X?" |
| Edge cases | Find exceptions | "What happens when input is empty/null?" |
| Assumptions | Challenge implicit beliefs | "Is it true that all X have property Y?" |
| Technical | Verify specifications | "What does the official documentation say about X?" |

### Guidelines for Effective Verification Questions

- Target the most critical or uncertain claims in the initial answer
- Phrase questions so they can be answered independently
- Avoid leading questions that assume the initial answer is correct
- Include at least one question that challenges a core assumption

---

## Step 3: Independent Verification (Factored)

**CRITICAL: Answer each verification question in complete isolation using the FACTORED approach.**

This step implements "factored verification" from the Meta AI research—the most effective method for catching errors. The key insight: if you can see your initial answer while verifying, you may unconsciously repeat the same hallucination.

### Factored Verification Protocol

For EACH verification question:

1. **Mental reset** - Before answering, mentally "forget" the initial answer. Treat this as a brand new question from a user you've never interacted with.

2. **Tool-first verification** - Prioritize external sources over your own knowledge:
   - Use `WebSearch` for facts, dates, statistics
   - Use `context7` for library/API documentation
   - Use `Read`/`Grep` for code verification
   - Only rely on internal knowledge if tools are unavailable or inappropriate

3. **Answer in isolation** - Do NOT:
   - Reference "my initial answer" or "I said earlier"
   - Look back at Step 1 while answering
   - Let other verification answers influence this one

4. **Cite your source** - Note where the answer came from (tool result, documentation, etc.)

### Why Factored Verification Works

Research shows that when the model can see its draft while answering verification questions, it copies the same hallucination. The factored approach eliminates this by:
- Treating each question as a completely independent query
- Prioritizing external tools over self-reference
- Preventing cross-contamination between verification answers

### Tool Usage Priority

| Priority | Tool | Use Case |
|----------|------|----------|
| 1st | WebSearch | Current facts, dates, statistics, recent changes |
| 2nd | context7 | Library docs, API references, technical specs |
| 3rd | Read/Grep | Code verification, codebase patterns |
| Last | Internal knowledge | Only when tools unavailable or not applicable |

---

## Step 4: Reconciliation & Final Answer (Factor+Revise)

This step implements the "Factor+Revise" pattern—systematically comparing each verification answer against the corresponding claim in the initial answer.

### Structured Reconciliation Process

1. **Claim-by-claim comparison** - For each verification Q&A pair:
   - Identify the specific claim in the initial answer it verifies
   - Compare the verification answer to that claim
   - Mark as: ✓ Confirmed, ✗ Contradicted, or ? Inconclusive

2. **Resolution rules**:
   - **Contradicted claims**: Verification answer takes precedence (it used external sources)
   - **Inconclusive claims**: Mark as uncertain in final answer, or remove if not essential
   - **Confirmed claims**: Keep in final answer with increased confidence

3. **Produce revised answer**:
   - Incorporate all corrections from contradicted claims
   - Explicitly note uncertainties for inconclusive claims
   - Preserve confirmed claims

4. **Document changes** - List what was corrected and why

### If No Errors Found

- Confirm the original answer is accurate
- Note that independent verification supports the initial response
- This adds confidence—the answer has been externally validated

---

## Output Format Template

Use this format for CoVe responses:

```markdown
## Initial Answer
[Complete initial response to the question]

## Verification

### Q1: [First verification question]
**A1:** [Independent answer - cite source: WebSearch/context7/docs/internal]

### Q2: [Second verification question]
**A2:** [Independent answer - cite source]

### Q3: [Third verification question]
**A3:** [Independent answer - cite source]

[Additional questions as needed...]

## Reconciliation

| Claim | Verification | Status | Action |
|-------|--------------|--------|--------|
| [Claim from initial answer] | Q1 | ✓ Confirmed | Keep |
| [Another claim] | Q2 | ✗ Contradicted | Correct to: [new value] |
| [Third claim] | Q3 | ? Inconclusive | Mark uncertain |

## Final Verified Answer
[Revised response incorporating all corrections from reconciliation]

**Verification notes:**
- [List corrections: "Changed X to Y based on Q2 verification"]
- [List confirmations: "Verified X is correct via WebSearch"]
- [List uncertainties: "Could not verify Y - marked as uncertain"]
```
