# CoVe Isolated Mode PRD

## Overview

Extend the existing Chain-of-Verification (CoVe) skill with a new "isolated mode" that implements true factored verification using Claude Code's Task tool to spawn isolated sub-agents. This addresses the limitation that standard mode cannot achieve true context isolation since the model can still "see" its initial answer when answering verification questions.

## Problem Statement

The current CoVe implementation uses prompt-based isolation ("mental reset" instructions) which is best-effort only. Research shows that when a model can see its initial answer while verifying, it may unconsciously repeat the same hallucinations. True factored verification requires each verification question to be answered in complete isolation with zero context about the initial answer.

## Goals

1. Implement true factored verification using sub-agents that have no access to the initial answer
2. Create a new `/cove-isolated` command separate from the existing `/cove` command
3. Support sub-agent customization via flags (`--explore`, `--haiku`, `--agent=<name>`)
4. Run verification sub-agents in parallel to minimize latency
5. Gracefully handle sub-agent failures

## Non-Goals

1. Modifying the existing `/cove` standard mode behavior
2. Auto-triggering isolated mode (user must explicitly choose it)
3. Creating new MCP tools or external dependencies

## Technical Requirements

### New Files

1. `.claude/skills/cove/cove-isolated.md` - Isolated mode workflow
2. `.claude/commands/cove/cove-isolated.md` - Isolated mode command

### Modified Files

1. `.claude/skills/cove/SKILL.md` - Add documentation for both modes

### Workflow

The isolated mode workflow:

1. **Step 1-2**: Same as standard mode (generate initial answer, generate verification questions)
2. **Step 3**: Spawn isolated sub-agents via Task tool
   - Parse flags from arguments
   - For each verification question, create a Task call with minimal prompt (question only)
   - Run all sub-agents in parallel (single message with multiple Task calls)
   - Collect responses
3. **Step 4**: Reconcile and produce final answer with agent metadata

### Flag Support

| Flag | Effect |
|------|--------|
| `--explore` | Use `Explore` sub-agent type |
| `--haiku` | Use haiku model |
| `--agent=<name>` | Use custom sub-agent type |

Flags can be combined and must appear before the question.

### Sub-Agent Prompt Template

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

### Error Handling

- Sub-agent timeout: Mark verification as "Inconclusive"
- Sub-agent failure: Fall back to standard mode for that question
- All sub-agents fail: Abort and suggest using `/cove` instead

## Success Criteria

1. `/cove-isolated` command is recognized and invokes the isolated workflow
2. Sub-agents receive only the verification question (no initial answer context)
3. Sub-agents run in parallel
4. Output includes agent metadata and source citations
5. Flags are parsed correctly and affect sub-agent behavior
6. Errors are handled gracefully without crashing

## Design Documents

- Design specification: `docs/cove/design.md` (Verification Modes section)
- Implementation plan: `docs/cove/implementation.md` (Tasks 6-9)
