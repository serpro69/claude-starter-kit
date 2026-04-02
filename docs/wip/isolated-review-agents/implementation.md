# Implementation Plan: Isolated Review Agents

> Design: [./design.md](./design.md)
> Created: 2026-04-02

## Overview

This plan adds isolated review variants to `solid-code-review` and `implementation-review` skills. The work is structured bottom-up: shared infrastructure first, then agent definitions, then skill workflows, then integration.

The developer implementing this is expected to be familiar with Claude Code's plugin system (skills, agents, commands) and the existing skill structure in `klaude-plugin/`. All existing skills in this repo serve as reference implementations.

## Task 1: Shared Review Reconciliation Protocol

**File**: `klaude-plugin/skills/_shared/review-reconciliation-protocol.md`

Create the shared protocol document that both isolated workflows reference. This is analogous to `capy-knowledge-protocol.md` — a shared reference, not a skill.

### Contents

The protocol defines:

1. **Disposition categories**: Confirmed, Disputed — Intentional, Disputed — False Positive, Duplicate. Each with a one-line definition and what evidence the main agent must provide.

2. **Invariants**:
   - Every sub-agent finding must appear in the consolidated report
   - Main agent cannot add new findings (it already had its chance during implementation)
   - Disputed findings still appear — the user decides
   - Agreement between independent reviewers increases effective severity by one level

3. **Consolidated report template**: The markdown format from the design doc's "Consolidated Report Format" section. Parameterized so both code review and spec review can use it with their own finding formats.

4. **Trust level guidance**: Per-finding-type trust levels for spec conformance review (from the design doc's trust level table). Code review findings use uniform trust since they don't have typed categories.

### Notes for implementer

- Reference the existing `capy-knowledge-protocol.md` for structure and tone
- The protocol should be prescriptive — "you MUST" not "you should"
- Keep it concise. Skills reference it; they don't re-read it every invocation

## Task 2: Code Reviewer Agent Definition

**File**: `klaude-plugin/agents/code-reviewer.md`

Create the agent definition markdown file. This is a fixed contract that defines what the agent is, what it receives, and how it behaves.

### Agent structure

The agent definition should include:

1. **Frontmatter**: Agent name, description (for agent selection/display)

2. **Role statement**: "You are an independent code reviewer. You did not write this code. Evaluate it on its merits — challenge the rationale if it doesn't hold up."

3. **What you receive** (explicit list):
   - Git diff of the changes under review
   - Spec context: relevant section from design.md, task description, documented design rationale
   - Language-specific checklists (SOLID, security, code quality, removal plan)
   - Capy read access for project-specific context

4. **What you do NOT have** (explicit list):
   - Conversation history from the implementation session
   - Debugging context, false starts, retries
   - Knowledge of alternatives considered but not taken

5. **Capy restriction**: You may call `capy_search` to query project-specific knowledge. You MUST NOT call `capy_index` or `capy_fetch_and_index`.

6. **Review workflow**: Reference the existing `solid-code-review` skill's workflow steps (preflight context, detect language, SOLID + architecture, removal candidates, security scan, code quality, self-check). The agent follows the same steps but operates on the artifacts it was given, not on conversation context.

7. **Output format**: Structured findings in P0-P3 format. Each finding must include: file:line, severity, confidence (1-10) with reasoning, description, and suggested fix. Use the same format as `solid-code-review`'s existing output template.

### Notes for implementer

- The agent needs access to Read, Grep, Glob, Bash (for git commands) tools to inspect the codebase
- The agent should load language-specific checklists from the `solid-code-review/reference/{lang}/` directory based on the file extensions in the diff
- The prompt that spawns this agent (from the isolated workflow) will inject the specific artifacts — the agent definition defines the contract, the workflow provides the payload

## Task 3: Spec Reviewer Agent Definition

**File**: `klaude-plugin/agents/spec-reviewer.md`

Create the agent definition for independent spec conformance review.

### Agent structure

1. **Frontmatter**: Agent name, description

2. **Role statement**: "You are an independent spec conformance reviewer. You did not write this code. Compare the implementation against the specification and report any deviations, gaps, or inconsistencies."

3. **What you receive**:
   - Design docs (design.md, implementation.md)
   - tasks.md with current task statuses (to determine review scope)
   - Read/Grep/Glob access to source files
   - Capy read access

4. **What you do NOT have**: Same exclusions as code-reviewer

5. **Capy restriction**: Same as code-reviewer

6. **Finding type taxonomy**: The full taxonomy from the existing `implementation-review` SKILL.md — MISSING_IMPL, EXTRA_IMPL, SPEC_DEV, DOC_INCON, OUTDATED_DOC, AMBIGUOUS. Include the description and example for each type.

7. **Severity levels**: P0-P3 adapted for spec conformance (from existing skill)

8. **Confidence levels**: 1-10 scale with mandatory reasoning (from existing skill)

9. **Review workflow**: Reference the existing `implementation-review` review-process steps: load docs, determine scope (mid-impl vs post-impl), per-task verification, cross-cutting concerns, self-check. The agent follows these steps independently.

10. **Output format**: Structured findings with finding type, severity, confidence with reasoning, description, and evidence.

### Notes for implementer

- The review scope determination is important: if tasks.md shows some tasks as pending, the agent should only review completed tasks (same as existing behavior)
- The agent needs to be able to read source files to compare against the spec — it needs Read, Grep, Glob, and Bash (for git) tool access
- The prompt that spawns this agent injects the file paths for design.md, implementation.md, and tasks.md

## Task 4: Isolated Code Review Workflow

**File**: `klaude-plugin/skills/solid-code-review/review-isolated.md`

Create the isolated variant workflow for `solid-code-review`.

### Workflow structure

The workflow is a checklist (matching the style of other skill workflows):

```
Isolated Code Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn reviewers (parallel)
- [ ] Step 3: Reconcile findings
- [ ] Step 4: Present consolidated report
```

#### Step 1: Prepare artifacts

Gather the artifacts that will be passed to sub-agents:
- Run `git diff --stat` and `git diff` to capture the diff
- Identify the spec context: if this review is happening within `implementation-process`, locate the relevant design.md section and task description from tasks.md. If standalone, check if the user provided context or if design docs exist in `/docs/wip/`.
- Detect the primary language from file extensions in the diff (same logic as existing skill's step 2)

#### Step 2: Spawn reviewers (parallel)

Spawn two reviewers in a single message for parallel execution:

**Sub-agent A** — `code-reviewer` agent:
- Prompt includes: the git diff, spec context (if available), path to language-specific checklists
- Agent type: `kk:code-reviewer`

**Sub-agent B** — `pal` codereview:
- Call `pal` codereview MCP tool with the git diff
- Model: gemini-3-pro (or as configured)

Both execute in parallel.

#### Step 3: Reconcile findings

Follow the shared reconciliation protocol (`_shared/review-reconciliation-protocol.md`):
- Collect findings from both reviewers
- Cross-reference: same issue from both reviewers → Duplicate (merge, note agreement, increase severity)
- For each finding, assign disposition using reconciliation rules
- Apply the trust level guidance

#### Step 4: Present consolidated report

Present using the consolidated report template from the shared protocol. Include:
- Reviewer attribution
- Disposition for each finding
- Agreement indicators
- Reviewer disagreements (if any)

Then follow the same next-steps flow as existing skill: ask user how to proceed (fix all, fix P0/P1, fix specific, no changes).

### Notes for implementer

- The sub-agent prompt must include enough artifact content for the agent to work independently — it cannot ask follow-up questions
- The `pal` codereview tool already produces structured output; map its format to P0-P3 for reconciliation
- If spec context is not available (standalone review, not within implementation-process), that's fine — the code-reviewer agent works with or without spec context, same as the existing skill

## Task 5: Isolated Spec Conformance Workflow

**File**: `klaude-plugin/skills/implementation-review/review-isolated.md`

Create the isolated variant workflow for `implementation-review`.

### Workflow structure

```
Isolated Implementation Review Progress:
- [ ] Step 1: Prepare artifacts
- [ ] Step 2: Spawn spec reviewer
- [ ] Step 3: Reconcile findings
- [ ] Step 4: Present consolidated report
```

#### Step 1: Prepare artifacts

- Locate the feature directory in `/docs/wip/[feature]/`
- Verify design.md, implementation.md, and tasks.md exist
- Determine review scope: read tasks.md to identify which tasks are done vs pending
- Prepare file paths to pass to the sub-agent

#### Step 2: Spawn spec reviewer

Spawn a single `spec-reviewer` sub-agent:
- Prompt includes: paths to design.md, implementation.md, tasks.md
- Prompt includes: review scope (which tasks to review)
- Agent type: `kk:spec-reviewer`

Single agent, not parallel.

#### Step 3: Reconcile findings

Follow the shared reconciliation protocol with type-specific trust levels:
- MISSING_IMPL, AMBIGUOUS, DOC_INCON, OUTDATED_DOC: High trust in sub-agent
- SPEC_DEV, EXTRA_IMPL: Medium trust — main agent may have intentional-deviation context

For disputed SPEC_DEV and EXTRA_IMPL findings: suggest updating the spec to reflect the deviation.

#### Step 4: Present consolidated report

Present using the consolidated report template. Include reconciliation summary.

If the review is happening within `implementation-process`, feed findings back into the task workflow. If standalone, present to user directly.

### Notes for implementer

- The sub-agent needs enough context in its prompt to locate and read all relevant files independently
- The sub-agent prompt should include the feature directory path, not inline file contents (the agent reads them itself)
- The capy search restriction should be stated in the sub-agent prompt even though it's in the agent definition — belt and suspenders

## Task 6: Update SKILL.md Routing

Two files need routing updates to support the new variants.

### `klaude-plugin/skills/solid-code-review/SKILL.md`

Add sub-skill routing similar to `cove/SKILL.md`. The SKILL.md should:
- Keep existing description and frontmatter
- Add an `isolated` sub-skill entry pointing to `review-isolated.md`
- Document the invocation pattern: `/kk:solid-code-review` (standard) vs `/kk:solid-code-review:isolated` (isolated)

### `klaude-plugin/skills/implementation-review/SKILL.md`

Same pattern:
- Keep existing content
- Add `isolated` sub-skill entry pointing to `review-isolated.md`
- Document invocation pattern

### Notes for implementer

- Reference `cove/SKILL.md` for the exact sub-skill routing syntax and frontmatter format
- The existing skill behavior must not change — the new variant is additive only

## Task 7: Update implementation-process Integration

**File**: `klaude-plugin/skills/implementation-process/SKILL.md`

Update Step 3 (Report) to support isolated review mode.

### Changes

The current Step 3 flow is:
1. Show what was implemented
2. Show verification output
3. Prompt user for code review
4. If yes: run `solid-code-review` + `pal` codereview, consolidate
5. Apply fixes, finalize

The updated Step 3 adds a note that when the user requests isolated review:
1. Show what was implemented
2. Show verification output
3. Prompt user for code review (mention isolated option)
4. If isolated: use `kk:solid-code-review:isolated` (which handles both sub-agents + reconciliation internally)
5. If standard: existing flow unchanged
6. Apply fixes, finalize

### Notes for implementer

- This is a minimal change — just adding the routing option in Step 3
- The `pal` codereview call currently in Step 3 moves inside `solid-code-review:isolated` when in isolated mode, so it's not duplicated
- The wording should make it clear that isolated mode is an option, not the default

## Task 8: Final Verification

Verify all components work together:
- Both agent definitions are valid and can be spawned
- Both isolated workflows complete their full checklist
- Reconciliation protocol is correctly applied
- SKILL.md routing works for both standard and isolated invocations
- `implementation-process` correctly routes to isolated variants when requested
- Existing (non-isolated) skill behavior is completely unchanged
