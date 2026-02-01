# Chain-of-Verification (CoVe) Skill Design

## Overview

Chain-of-Verification (CoVe) is a prompting technique that improves LLM response accuracy by making the model fact-check its own answers. Research shows this achieves ~94% accuracy on complex questions compared to a ~68% baseline.

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

### Step 3: Independent Verification

Answer each verification question as if it were a fresh, standalone question.

**Critical requirements:**
- Do NOT reference the initial answer when answering
- Treat each question as coming from a new user
- Use available tools when beneficial:
  - `WebSearch` for current facts and documentation
  - `context7` for library/API documentation
  - `Read` for code verification
  - `Grep`/`Glob` for codebase searches

**This independence is crucial** - it prevents confirmation bias where the model simply validates its own previous statements.

### Step 4: Reconciliation & Final Answer

Compare verification answers against the initial response and produce a final verified answer.

**Process:**
1. Identify discrepancies between initial answer and verification findings
2. Determine which version is correct (verification answers take precedence)
3. Produce revised answer incorporating corrections
4. Explicitly note what was changed and why

**If no errors found:**
- Confirm the original answer
- Note that verification supports the initial response
- This adds confidence to the answer

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

## Success Metrics

When evaluating CoVe effectiveness:

1. **Correction rate** - How often does verification find and fix errors?
2. **False positive rate** - How often does verification incorrectly "fix" correct answers?
3. **User satisfaction** - Do users find the transparency valuable?
4. **Accuracy improvement** - Measurable improvement on known-answer test cases
