---
name: chain-of-verification
description: |
  Apply Chain-of-Verification (CoVe) prompting to improve response accuracy through self-verification.
  Use when complex questions require fact-checking, technical accuracy, or multi-step reasoning.
---

# Chain-of-Verification (CoVe)

CoVe is a verification technique that improves response accuracy by making the model fact-check its own answers. Instead of accepting an initial response at face value, CoVe instructs the model to generate verification questions, answer them independently, and revise the original answer based on findings.

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

**Capy restriction:** CoVe is a read-only verification tool. Do NOT call `capy_index` or `capy_fetch_and_index` during this workflow. Use `capy_search` only. If corrections reveal knowledge worth persisting, the calling agent handles indexing after CoVe completes.

## When to Use This Skill

CoVe adds the most value in these scenarios:

**Precision-required questions:**

- Questions containing precision language ("exactly", "precisely", "specific")
- Complex factual questions (dates, statistics, specifications)

**Complex reasoning:**

- Multi-step reasoning chains (3+ logical dependencies)
- Technical claims about APIs, libraries, or version-specific behavior

**Fact-checking scenarios:**

- Historical facts, statistics, or quantitative data
- Technical specifications and API behavior

**High-stakes accuracy:**

- Security-critical code paths or analysis
- Code generation requiring accuracy verification
- Any response where correctness is critical

**Self-correction triggers:**

- When initial response contains hedging language ("I think", "probably", "might be")

> **Note:** These heuristics can be copied to your project's CLAUDE.md if you want Claude to auto-invoke CoVe for matching scenarios. By default, CoVe requires manual invocation to give you control over when to invest additional tokens/time for verification.

## Verification Modes

CoVe offers two verification modes to balance accuracy vs. cost:

### Standard Mode (`/chain-of-verification`)

Uses prompt-based isolation within a single conversation turn.

- **Token cost:** ~3-5x base tokens
- **Isolation:** Best-effort (mental reset instructions)
- **Speed:** Faster, single context
- **Best for:** Quick fact-checking, cost-sensitive scenarios

See [chain-of-verification-process.md](./chain-of-verification-process.md) for the standard workflow.

### Isolated Mode (`/kk:chain-of-verification:isolated`)

Uses Claude Code's Task tool to spawn isolated sub-agents for true factored verification.

- **Token cost:** ~8-15x base tokens
- **Isolation:** True (sub-agents have zero context about initial answer)
- **Speed:** Parallel execution minimizes latency
- **Best for:** High-stakes accuracy, codebase verification

**Sub-agent customization flags:**
| Flag | Effect |
|------|--------|
| `--explore` | Use Explore agent for codebase verification |
| `--haiku` | Use haiku model for faster/cheaper verification |
| `--agent=<name>` | Use custom agent type |

See [chain-of-verification-isolated.md](./chain-of-verification-isolated.md) for the isolated workflow.

### Mode Selection Guide

| Use Case                    | Recommended Mode                            |
| --------------------------- | ------------------------------------------- |
| Quick fact-checking         | `/chain-of-verification`                                     |
| High-stakes accuracy        | `/kk:chain-of-verification:isolated`                    |
| Codebase verification       | `/kk:chain-of-verification:isolated --explore`          |
| Cost-sensitive verification | `/chain-of-verification` or `/kk:chain-of-verification:isolated --haiku` |

## Workflow

**Mandatory order — questions before verification.** The flow below is strictly sequential. Do not answer verification questions, consult external sources, or revise the original response until you have generated the full initial response and formulated all verification questions. Jumping to verification before questions are fully formed collapses the independence that makes CoVe effective. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

1. **Generate initial response.** Produce a baseline answer to the user's question. This is the subject matter — it exists in context but is not yet verified.
2. **Formulate verification questions.** Create 3–5 targeted questions designed to expose errors in the initial response. The questions must be formulated without consulting external sources — they probe the response's own claims.
3. **Independent verification.** Answer each question independently, without referencing the initial response. Use `capy_search` if needed. In isolated mode, sub-agents handle this step.
4. **Reconciliation.** Compare verification answers against the initial response. Revise where discrepancies are found.

See the Process Overview below and the mode-specific process files for detailed steps.

## Process Overview

The CoVe workflow follows 4 steps:

1. **Initial Response** - Generate baseline answer
2. **Verification Questions** - Create 3-5 targeted questions to expose errors
3. **Independent Verification** - Answer questions without referencing the original
4. **Reconciliation** - Revise answer based on verification findings

See [chain-of-verification-process.md](./chain-of-verification-process.md) for the standard workflow, or [chain-of-verification-isolated.md](./chain-of-verification-isolated.md) for the isolated sub-agent workflow.

## Invocation

Use the `/chain-of-verification` skill followed by your question:

```
/chain-of-verification What is the time complexity of Python's sorted() function?
```

Or invoke `/chain-of-verification` after receiving a response to verify it.

For isolated verification with sub-agents:

```
/kk:chain-of-verification:isolated What is the time complexity of Python's sorted() function?
```

With flags:

```
/kk:chain-of-verification:isolated --explore How does the auth system work?
/kk:chain-of-verification:isolated --haiku What year was TCP standardized?
```

## Natural Language Invocation

Claude should recognize these phrases as requests to invoke the CoVe skill:

- "verify this using chain of verification"
- "use CoVe to answer"
- "fact-check your response"
- "double-check this with verification"
- "use self-verification for this"
- "apply chain of verification"
- "verify this answer"

For isolated mode:

- "use isolated verification"
- "verify with sub-agents"
- "use factored verification with isolation"

> **Important:** This is guidance for manual recognition only. Auto-trigger is NOT implemented by default per design goals. Users who want automatic CoVe invocation for certain scenarios can add the heuristics from "When to Use This Skill" to their project's CLAUDE.md.
