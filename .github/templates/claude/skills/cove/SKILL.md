---
name: cove
description: Apply Chain-of-Verification (CoVe) prompting to improve response accuracy through self-verification. Use for complex questions requiring fact-checking, technical accuracy, or multi-step reasoning.
---

# Chain-of-Verification (CoVe)

CoVe is a verification technique that improves response accuracy by making the model fact-check its own answers. Instead of accepting an initial response at face value, CoVe instructs the model to generate verification questions, answer them independently, and revise the original answer based on findings.

## When to Use This Skill

- Complex factual questions (dates, statistics, specifications)
- Technical specifications and API behavior
- Multi-step reasoning chains
- Code generation requiring accuracy verification
- Any response where correctness is critical

## Process Overview

The CoVe workflow follows 4 steps:

1. **Initial Response** - Generate baseline answer
2. **Verification Questions** - Create 3-5 targeted questions to expose errors
3. **Independent Verification** - Answer questions without referencing the original
4. **Reconciliation** - Revise answer based on verification findings

See [cove-process.md](./cove-process.md) for the detailed verification workflow.

## Invocation

Use the `/cove` command followed by your question:

```
/cove What is the time complexity of Python's sorted() function?
```

Or invoke `/cove` after receiving a response to verify it.
