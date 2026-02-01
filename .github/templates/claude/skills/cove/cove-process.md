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

## Step 3: Independent Verification

**CRITICAL: Answer each verification question WITHOUT referencing the initial answer.**

This step is the key mechanism for catching errors. You must:

1. **Treat each question as a fresh, standalone question** from a new user who has never seen the initial answer
2. **Do NOT look back** at what you wrote in Step 1
3. **Research independently** using available tools

### Why Independence Matters

This independence prevents **confirmation bias** - the tendency to validate your own previous statements rather than objectively evaluate them. By answering verification questions without referencing the initial answer, you are more likely to catch genuine errors.

### Tool Usage During Verification

Use available tools to verify claims:

| Tool | Use Case |
|------|----------|
| WebSearch | Current facts, recent changes |
| context7 | Library docs, API references |
| Read | Verify code claims |
| Grep/Glob | Search codebase patterns |

---

## Step 4: Reconciliation & Final Answer

Compare verification answers against the initial response and produce a final verified answer.

### Process

1. **Identify discrepancies** between initial answer and verification findings
2. **Determine correctness** - verification answers take precedence when conflicts arise
3. **Produce revised answer** incorporating corrections
4. **Note what was changed** and why

### If No Errors Found

- Confirm the original answer
- Note that verification supports the initial response
- This adds confidence to the answer

---

## Output Format Template

Use this format for CoVe responses:

```markdown
## Initial Answer
[Complete initial response to the question]

## Verification

### Q1: [First verification question]
**A1:** [Independent answer to Q1]

### Q2: [Second verification question]
**A2:** [Independent answer to Q2]

### Q3: [Third verification question]
**A3:** [Independent answer to Q3]

[Additional questions as needed...]

## Final Verified Answer
[Revised response incorporating verification findings]

**Verification notes:**
- [List any corrections made]
- [Or note "No corrections needed - verification confirms initial answer"]
```
