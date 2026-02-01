# Chain-of-Verification (CoVe) Skill PRD

## Overview

Implement a new Claude Code skill that introduces the Chain-of-Verification (CoVe) prompting technique to improve LLM response accuracy. CoVe makes Claude fact-check its own answers by generating verification questions and answering them independently before producing a final revised answer.

## Problem Statement

LLMs hallucinate and can produce inaccurate responses, especially for complex questions involving facts, technical specifications, or multi-step reasoning. Traditional prompting accepts the first answer without validation. CoVe addresses this by adding a self-verification step. Research from Meta AI (Dhuliawala et al., 2023) demonstrates significant improvements: 23% F1 improvement on closed-book QA, 30% accuracy gain on list-based questions, and 50-70% hallucination reduction across benchmarks.

## Goals

1. Create a new skill in `.claude/skills/cove/` implementing the CoVe technique
2. Provide a `/cove` slash command for manual invocation
3. Make the verification process transparent to users
4. Support all complex response types: factual, technical, and code generation

## Non-Goals

1. Auto-trigger by default (manual invocation preferred)
2. Modifications to existing skills
3. Changes to CLAUDE.md or settings.json

## Technical Requirements

### Skill Structure

Create the following files:

1. `.claude/skills/cove/SKILL.md` - Skill definition with metadata
2. `.claude/skills/cove/cove-process.md` - Detailed verification workflow
3. `.claude/commands/cove/cove.md` - Slash command for invocation

### Verification Workflow

The skill must implement a 4-step process:

1. **Initial Response** - Provide the initial answer, marked clearly
2. **Generate Verification Questions** - Create 3-5 targeted questions to expose errors
3. **Independent Verification** - Answer questions without referencing initial answer
4. **Reconciliation** - Produce final verified answer with corrections noted

### Output Format

Responses must follow this structure:
- Initial Answer section
- Verification section with numbered Q&A pairs
- Final Verified Answer section with verification notes

### Invocation Methods

1. `/cove [question]` - Apply CoVe to a new question
2. `/cove` (no args) - Apply CoVe to verify previous response
3. Natural language: "verify this", "use chain of verification"

## Success Criteria

1. Skill appears in Claude's skill list
2. `/cove` command invokes the skill correctly
3. All four verification steps appear in output
4. Verification questions are relevant and targeted
5. Final answer incorporates corrections when errors are found

## Design Documents

- Design specification: `docs/cove/design.md`
- Implementation plan: `docs/cove/implementation.md`

## Dependencies

None - this is a configuration-only feature using existing Claude Code skill infrastructure.
