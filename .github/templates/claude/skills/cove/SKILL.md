---
name: cove
description: Apply Chain-of-Verification (CoVe) prompting to improve response accuracy through self-verification. Use for complex questions requiring fact-checking, technical accuracy, or multi-step reasoning.
---

# Chain-of-Verification (CoVe)

CoVe is a verification technique that improves response accuracy by making the model fact-check its own answers. Instead of accepting an initial response at face value, CoVe instructs the model to generate verification questions, answer them independently, and revise the original answer based on findings.

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

## Natural Language Invocation

Claude should recognize these phrases as requests to invoke the CoVe skill:

- "verify this using chain of verification"
- "use CoVe to answer"
- "fact-check your response"
- "double-check this with verification"
- "use self-verification for this"
- "apply chain of verification"
- "verify this answer"

> **Important:** This is guidance for manual recognition only. Auto-trigger is NOT implemented by default per design goals. Users who want automatic CoVe invocation for certain scenarios can add the heuristics from "When to Use This Skill" to their project's CLAUDE.md.
