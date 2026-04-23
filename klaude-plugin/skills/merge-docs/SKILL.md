---
name: merge-docs
description: |
  Compare and merge two design docs for the same feature into a single source of truth.
  Use when you have competing or complementary design/implementation docs (e.g. from separate design runs) that need reconciling into one unified document.
---

# Merge Design Documents

**Goal: Produce a single, unified set of feature docs from two separate designs for the same feature.**

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## When to Use

You have two feature directories under `/docs/wip/` for the same feature — each with its own design, implementation plan, and task list — and you need to combine them into one coherent set of docs.

## Workflow

**Mandatory order — grounding before merging.** The flow below is strictly sequential. Do not categorize sections, surface contradictions, or write merged content until you have read both feature directories fully and built a codebase-grounded mental model. Merging without grounding produces decisions based on prose clarity rather than codebase reality — the wrong tiebreaker. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

See [merge-process.md](./merge-process.md) for the detailed steps.
