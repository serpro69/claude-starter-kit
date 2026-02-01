### Workflow

Copy this checklist and check off items as you complete them:

```
CoVe Isolated Progress:
- [ ] Step 1: Generate Initial Answer
- [ ] Step 2: Create Verification Questions
- [ ] Step 3: Isolated Verification (Sub-Agents)
- [ ] Step 4: Reconciliation & Final Answer
```

> **Note:** Step 3 uses isolated sub-agents for true factored verification. Each verification question is answered by a separate agent with zero context about the initial answer.

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

## Step 3: Isolated Verification with Sub-Agents

**CRITICAL: This step uses true factored verification by spawning isolated sub-agents.**

Each verification question is answered by a separate sub-agent that has ZERO context about the initial answer. This eliminates the risk of hallucination repetition that exists in standard mode.

### Flag Parsing

The following flags can be used with `/cove-isolated`:

| Flag | Effect | Default |
|------|--------|---------|
| `--explore` | Use `Explore` agent type | - |
| `--haiku` | Use haiku model for sub-agents | - |
| `--agent=<name>` | Use custom agent type | `general-purpose` |

**Flag parsing rules:**
1. Flags must appear before the question in `$ARGUMENTS`
2. `--explore` is shorthand for `--agent=Explore`
3. `--haiku` sets the `model` parameter to `haiku` on the Task tool
4. `--agent=<name>` uses the specified agent type (default: `general-purpose`)
5. Flags can be combined: `--haiku --explore`

### Sub-Agent Prompt Template

Use this template for each sub-agent. Replace `{verification_question}` with the actual question:

```
You are answering a factual question. Research thoroughly using available tools
before answering. Cite your sources.

Question: {verification_question}

Requirements:
1. Use WebSearch, context7, Read, or other tools to verify your answer
2. If you cannot find authoritative sources, state that clearly
3. Provide a concise, factual answer with source citations
4. Do NOT speculate - only report what you can verify
```

### Task Tool Usage

For EACH verification question, create a Task tool call with:

| Parameter | Value |
|-----------|-------|
| `subagent_type` | From `--agent` flag or default `general-purpose` |
| `model` | `haiku` if `--haiku` flag present, otherwise omit |
| `prompt` | Sub-agent prompt template with `{verification_question}` substituted |
| `description` | `CoVe Q{N}: {first 5 words of question}...` |

**CRITICAL: All Task calls must be in a SINGLE message for parallel execution.**

### Example: 3 Verification Questions

If you have these verification questions:
1. What is the exact time complexity of Python's sorted() function?
2. Does Python's sorted() use Timsort or another algorithm?
3. What is the space complexity of Python's sorted()?

You must spawn all three sub-agents in ONE message block. Each Task call should have:
- `subagent_type`: `general-purpose` (or from flags)
- `description`: `CoVe Q1: What is the exact...` (truncated)
- `prompt`: The sub-agent prompt template with the question substituted

Example Task tool parameters for Q1:
```json
{
  "subagent_type": "general-purpose",
  "description": "CoVe Q1: What is the exact...",
  "prompt": "You are answering a factual question. Research thoroughly using available tools before answering. Cite your sources.\n\nQuestion: What is the exact time complexity of Python's sorted() function?\n\nRequirements:\n1. Use WebSearch, context7, Read, or other tools to verify your answer\n2. If you cannot find authoritative sources, state that clearly\n3. Provide a concise, factual answer with source citations\n4. Do NOT speculate - only report what you can verify"
}
```

With `--haiku` flag, add `"model": "haiku"` to each Task call.
With `--explore` flag, use `"subagent_type": "Explore"` instead.

### Response Collection

After all sub-agents complete:

1. **Collect responses** from all sub-agents
2. **Record metadata** for each:
   - Agent type used (general-purpose, Explore, etc.)
   - Completion status (Completed, Failed, Timed out)
   - Source citations provided
3. **Note any failures** - these will be marked as "Inconclusive" in reconciliation

---

## Step 4: Reconciliation & Final Answer (Factor+Revise)

This step implements the "Factor+Revise" pattern—systematically comparing each sub-agent's verification answer against the corresponding claim in the initial answer.

### Structured Reconciliation Process

1. **Claim-by-claim comparison** - For each verification Q&A pair:
   - Identify the specific claim in the initial answer it verifies
   - Compare the sub-agent's verification answer to that claim
   - Mark as: ✓ Confirmed, ✗ Contradicted, or ? Inconclusive

2. **Resolution rules**:
   - **Contradicted claims**: Sub-agent verification answer takes precedence (used external sources in isolation)
   - **Inconclusive claims**: Mark as uncertain in final answer, or remove if not essential
   - **Confirmed claims**: Keep in final answer with increased confidence

3. **Produce revised answer**:
   - Incorporate all corrections from contradicted claims
   - Explicitly note uncertainties for inconclusive claims
   - Preserve confirmed claims

4. **Document changes** - List what was corrected and why, with agent attribution

### If No Errors Found

- Confirm the original answer is accurate
- Note that independent verification supports the initial response
- This adds confidence—the answer has been externally validated by isolated agents

---

## Output Format Template

Use this format for CoVe Isolated responses:

```markdown
## Initial Answer
[Complete initial response to the question]

## Verification (Isolated Mode)

### Q1: [First verification question]
**Agent:** general-purpose | **Status:** ✓ Completed
**A1:** [Sub-agent's independent answer]
**Source:** [Citation from sub-agent]

### Q2: [Second verification question]
**Agent:** general-purpose | **Status:** ✓ Completed
**A2:** [Sub-agent's independent answer]
**Source:** [Citation from sub-agent]

### Q3: [Third verification question]
**Agent:** Explore | **Status:** ✓ Completed
**A3:** [Sub-agent's independent answer]
**Source:** [Citation from sub-agent]

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
- Isolation method: Sub-agent (true factored verification)
- Agents used: [count]x [types] (e.g., "2x general-purpose, 1x Explore")
- Corrections: [List specific changes made]
- Confirmations: [List verified claims]
```

---

## Error Handling

### Sub-Agent Timeout

If a sub-agent times out, mark that verification as "Inconclusive":

```markdown
### Q2: [Question]
**Agent:** general-purpose | **Status:** ⏱ Timed out
**A2:** Inconclusive - sub-agent timeout
**Source:** N/A
```

In reconciliation, treat timed-out verifications as `? Inconclusive`.

### Sub-Agent Failure

If a single sub-agent fails (but others succeed):

1. Mark that verification as failed in the output
2. **Fall back to standard mode** for that question only
3. Note in the output that standard mode was used for fallback

```markdown
### Q3: [Question]
**Agent:** general-purpose | **Status:** ✗ Failed (fallback to standard)
**A3:** [Answer using standard mode - prompt-based isolation]
**Source:** [Citation] (Note: Standard mode fallback)
```

### All Sub-Agents Fail

If ALL sub-agents fail, abort isolated mode entirely:

1. Do NOT attempt standard mode fallback for all questions
2. Display this message to the user:

```
Isolated mode unavailable due to sub-agent failures.
Please use `/cove` for standard mode verification instead.
```

3. Suggest the user retry with `/cove` (standard mode)
