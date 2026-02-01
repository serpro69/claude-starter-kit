# Chain-of-Verification (CoVe) Skill Design

## Overview

Chain-of-Verification (CoVe) is a prompting technique that improves LLM response accuracy by making the model fact-check its own answers. Research from Meta AI (Dhuliawala et al., 2023) demonstrates significant hallucination reduction: 23% F1 improvement on closed-book QA, 30% accuracy gain on list-based questions, and 50-70% reduction in hallucinations across benchmarks.

**Core principle:** Instead of answering once and accepting the result, CoVe instructs the LLM to:
1. Provide an initial answer
2. Generate verification questions that would expose errors
3. Answer those questions independently (avoiding confirmation bias)
4. Revise the original answer based on verification findings

## Design Goals

1. **Improve accuracy** - Reduce hallucinations and factual errors in complex responses
2. **Transparency** - Show the full verification process to users
3. **User control** - Manual invocation by default, with optional auto-trigger guidance
4. **Self-contained** - No modifications to existing skills or configuration
5. **Broad applicability** - Works for factual questions, technical explanations, and code generation

## Architecture

### Component Overview

```
.claude/
├── skills/
│   └── cove/
│       ├── SKILL.md           # Skill metadata and entry point
│       └── cove-process.md    # Detailed verification workflow
└── commands/
    └── cove/
        └── cove.md            # Slash command for invocation
```

### Skill Structure

**SKILL.md** - Entry point containing:
- Skill name and description (YAML frontmatter)
- Brief overview of when to use CoVe
- Reference to the detailed process file

**cove-process.md** - Complete workflow containing:
- Step-by-step verification process
- Output format template
- Verification question guidelines
- Domain-specific examples
- Tool usage guidance during verification

### Slash Command

**cove.md** - Invocation command containing:
- Skill invocation instructions
- Argument handling (question to verify)
- Support for verifying previous responses

## Verification Process

### Step 1: Initial Response

Generate the initial answer to the user's question. This establishes a baseline that will be verified.

**Requirements:**
- Clearly mark as "Initial Answer"
- Provide a complete response (not abbreviated)
- Note any areas of uncertainty

### Step 2: Generate Verification Questions

Create 3-5 targeted questions designed to expose potential errors.

**Question categories:**
| Category | Purpose | Example |
|----------|---------|---------|
| Factual | Verify specific claims | "What is the exact release date of X?" |
| Logical | Check reasoning consistency | "Does conclusion Y follow from premise X?" |
| Edge cases | Find exceptions | "What happens when input is empty/null?" |
| Assumptions | Challenge implicit beliefs | "Is it true that all X have property Y?" |
| Technical | Verify specifications | "What does the official documentation say about X?" |

**Guidelines for effective verification questions:**
- Target the most critical or uncertain claims
- Phrase questions to be answerable independently
- Avoid leading questions that assume the initial answer is correct
- Include at least one question that challenges a core assumption

### Step 3: Independent Verification (Factored)

This step implements **factored verification**—the most effective variant from the Meta AI research. The key insight: if the model can see its initial answer while verifying, it may unconsciously repeat the same hallucination.

**Verification execution methods (from research):**

| Method | Approach | Effectiveness |
|--------|----------|---------------|
| Joint | All steps in one prompt | Lowest - repeats hallucinations |
| 2-Step | Separate planning from execution | Medium |
| **Factored** | Each question answered in complete isolation | High |
| **Factor+Revise** | Factored + structured reconciliation | Highest |

**Factored verification protocol:**

For each verification question:
1. **Mental reset** - Treat as a brand new question from an unknown user
2. **Tool-first verification** - Prioritize external sources (WebSearch, context7, Read) over internal knowledge
3. **Answer in isolation** - Do NOT reference the initial answer or other verification answers
4. **Cite sources** - Note where each answer came from

**Why factored works:** Research shows that when the model sees its draft while answering verification questions, it copies the same hallucination. Factored verification eliminates this by treating each question as completely independent.

### Step 4: Reconciliation & Final Answer (Factor+Revise)

The Factor+Revise pattern systematically compares each verification answer against the corresponding claim.

**Structured reconciliation process:**

1. **Claim-by-claim comparison** - For each verification Q&A:
   - Identify the specific claim it verifies
   - Compare verification answer to that claim
   - Mark as: ✓ Confirmed, ✗ Contradicted, or ? Inconclusive

2. **Resolution rules:**
   - Contradicted → Verification answer takes precedence (used external sources)
   - Inconclusive → Mark as uncertain or remove if not essential
   - Confirmed → Keep with increased confidence

3. **Produce revised answer** incorporating all corrections

4. **Document changes** with specific corrections and sources

**If no errors found:**
- Confirm the original answer is accurate
- Note that independent verification supports the initial response
- This adds confidence—the answer has been externally validated

## Output Format

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

## Invocation Methods

### Manual Invocation (Primary)

1. **Slash command with question:**
   ```
   /cove What is the time complexity of Python's sorted() function?
   ```

2. **Slash command for previous response:**
   ```
   User: What year was the TCP protocol standardized?
   Claude: [provides answer]
   User: /cove
   Claude: [verifies previous response using CoVe]
   ```

3. **Natural language:**
   - "Verify this using chain of verification"
   - "Use CoVe to answer this question"
   - "Fact-check your response"

### Auto-Trigger Guidance (Optional)

Users who want Claude to auto-invoke CoVe can add guidance to their project's CLAUDE.md. The skill includes heuristics for when auto-trigger may be appropriate:

**Suggested auto-trigger indicators:**
- Questions containing precision language ("exactly", "precisely", "specific")
- Multi-step reasoning chains (3+ logical dependencies)
- Technical claims about APIs, libraries, or version-specific behavior
- Historical facts, statistics, or quantitative data
- Security-critical code paths
- When hedging language appears in the initial response ("I think", "probably", "might be")

**Default:** Auto-trigger is disabled. Manual invocation gives users control over when to invest the additional tokens/time for verification.

## Scope of Application

CoVe is applicable to all complex response types:

### Factual/Research Questions
- Historical dates and events
- Statistics and measurements
- Technical specifications
- API behavior and parameters

### Technical Explanations
- Algorithm complexity analysis
- Architecture trade-offs
- Debugging hypotheses
- Performance characteristics

### Code Generation
- Logic correctness
- Edge case handling
- API usage accuracy
- Security considerations

## Integration Points

### With Existing Skills

CoVe is standalone but can be combined with other skills:

- **analysis-process** - Use CoVe to verify architectural decisions
- **implementation-process** - Verify technical approach before coding
- **testing-process** - Verify test coverage assumptions

### With MCP Tools

During verification (Step 3), Claude should use available tools:

| Tool | Use Case |
|------|----------|
| `WebSearch` | Current facts, recent changes, live documentation |
| `context7` | Library documentation, API references |
| `Read` | Verify code claims against actual implementation |
| `Grep`/`Glob` | Search codebase for usage patterns |

## Limitations

1. **Token cost** - CoVe uses 3-5x more tokens than a direct answer
2. **Latency** - Verification adds processing time
3. **Not for simple questions** - Overkill for straightforward queries
4. **Tool availability** - Verification quality depends on access to authoritative sources
5. **Self-verification limits** - Model may have consistent blind spots that verification doesn't catch
6. **Factual errors only** - CoVe is effective for factual inaccuracies but has limited ability to catch flawed logical reasoning that appears internally consistent
7. **Hallucination repetition risk** - If verification questions are not properly isolated from the initial answer, the model may repeat the same hallucinations (the "factored" verification variant mitigates this)
8. **Model capability ceiling** - Effectiveness is bounded by the underlying model's self-verification ability; research (Huang et al., 2024) shows LLMs have fundamental limits in detecting and correcting their own mistakes
9. **No external knowledge injection** - CoVe relies on the model's existing knowledge; it cannot catch errors in domains where the model lacks training data

## References

- Dhuliawala, S., Komeili, M., Xu, J., Raileanu, R., Li, X., Celikyilmaz, A., & Weston, J. (2023). Chain-of-Verification Reduces Hallucination in Large Language Models. [arXiv:2309.11495](https://arxiv.org/abs/2309.11495). Published in ACL 2024 Findings.
- Huang, J., et al. (2024). Large Language Models Cannot Self-Correct Reasoning Yet. ICLR 2024.

## Success Metrics

When evaluating CoVe effectiveness:

1. **Correction rate** - How often does verification find and fix errors?
2. **False positive rate** - How often does verification incorrectly "fix" correct answers?
3. **User satisfaction** - Do users find the transparency valuable?
4. **Accuracy improvement** - Measurable improvement on known-answer test cases
