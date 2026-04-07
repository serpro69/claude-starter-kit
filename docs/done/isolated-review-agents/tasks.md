# Tasks: Isolated Review Agents

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-02

## Task 1: Shared review reconciliation protocol
- **Status:** done
- **Depends on:** —
- **Docs:** [implementation.md#task-1-shared-review-reconciliation-protocol](./implementation.md#task-1-shared-review-reconciliation-protocol)

### Subtasks
- [x] 1.1 Create `klaude-plugin/skills/_shared/review-reconciliation-protocol.md` with disposition categories (Confirmed, Disputed — Intentional, Disputed — False Positive, Duplicate) and required evidence for each
- [x] 1.2 Add invariants section: no silent drops, no new findings from main agent, disputed findings still shown, agreement increases severity
- [x] 1.3 Add consolidated report template (parameterized for both code review and spec review finding formats)
- [x] 1.4 Add trust level guidance table for spec conformance finding types (MISSING_IMPL, AMBIGUOUS, SPEC_DEV, EXTRA_IMPL, DOC_INCON, OUTDATED_DOC)

## Task 2: Code reviewer agent definition
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#task-2-code-reviewer-agent-definition](./implementation.md#task-2-code-reviewer-agent-definition)

### Subtasks
- [x] 2.1 Create `klaude-plugin/agents/` directory
- [x] 2.2 Create `klaude-plugin/agents/code-reviewer.md` with frontmatter (name, description)
- [x] 2.3 Write role statement, artifact contract (what is given vs excluded), and capy restriction (search only, no index)
- [x] 2.4 Define review workflow referencing `solid-code-review` steps (preflight, detect language, SOLID, removal, security, code quality, self-check)
- [x] 2.5 Define output format (P0-P3 findings with file:line, severity, confidence with reasoning, description, suggested fix)

## Task 3: Spec reviewer agent definition
- **Status:** done
- **Depends on:** Task 1
- **Docs:** [implementation.md#task-3-spec-reviewer-agent-definition](./implementation.md#task-3-spec-reviewer-agent-definition)

### Subtasks
- [x] 3.1 Create `klaude-plugin/agents/spec-reviewer.md` with frontmatter (name, description)
- [x] 3.2 Write role statement, artifact contract (what is given vs excluded), and capy restriction
- [x] 3.3 Include finding type taxonomy (MISSING_IMPL, EXTRA_IMPL, SPEC_DEV, DOC_INCON, OUTDATED_DOC, AMBIGUOUS) with descriptions and examples
- [x] 3.4 Include severity levels (P0-P3 adapted for spec conformance) and confidence scale (1-10 with mandatory reasoning)
- [x] 3.5 Define review workflow referencing `implementation-review` review-process steps (load docs, determine scope, per-task verification, cross-cutting, self-check)
- [x] 3.6 Define output format (structured findings with type, severity, confidence, description, evidence)

## Task 4: Isolated code review workflow
- **Status:** done
- **Depends on:** Task 1, Task 2
- **Docs:** [implementation.md#task-4-isolated-code-review-workflow](./implementation.md#task-4-isolated-code-review-workflow)

### Subtasks
- [x] 4.1 Create `klaude-plugin/skills/solid-code-review/review-isolated.md` with checklist structure
- [x] 4.2 Write Step 1 (Prepare artifacts): git diff capture, spec context location, language detection, `listmodels` call to resolve most capable `pal` model
- [x] 4.3 Write Step 2 (Spawn reviewers): `code-reviewer` sub-agent + main agent calling `pal` codereview directly — both in a single message for parallel execution
- [x] 4.4 Write Step 3 (Reconcile): cross-reference findings, assign dispositions per reconciliation protocol
- [x] 4.5 Write Step 4 (Report): consolidated report using shared template, next-steps prompt to user

## Task 5: Isolated spec conformance workflow
- **Status:** done
- **Depends on:** Task 1, Task 3
- **Docs:** [implementation.md#task-5-isolated-spec-conformance-workflow](./implementation.md#task-5-isolated-spec-conformance-workflow)

### Subtasks
- [x] 5.1 Create `klaude-plugin/skills/implementation-review/review-isolated.md` with checklist structure
- [x] 5.2 Write Step 1 (Prepare artifacts): locate feature directory, verify docs exist, determine review scope
- [x] 5.3 Write Step 2 (Spawn spec reviewer): single `spec-reviewer` agent with feature directory path and review scope
- [x] 5.4 Write Step 3 (Reconcile): apply type-specific trust levels, handle disputed SPEC_DEV/EXTRA_IMPL with spec update suggestions
- [x] 5.5 Write Step 4 (Report): consolidated report, feed back into task workflow if within implementation-process

## Task 6: Update SKILL.md routing
- **Status:** done
- **Depends on:** Task 4, Task 5
- **Docs:** [implementation.md#task-6-update-skillmd-routing](./implementation.md#task-6-update-skillmd-routing)

### Subtasks
- [x] 6.1 Update `klaude-plugin/skills/solid-code-review/SKILL.md` to add `isolated` sub-skill entry pointing to `review-isolated.md` — reference `cove/SKILL.md` for routing syntax
- [x] 6.2 Update `klaude-plugin/skills/implementation-review/SKILL.md` to add `isolated` sub-skill entry pointing to `review-isolated.md`
- [x] 6.3 Verify existing skill behavior is unchanged when invoked without `:isolated` suffix

## Task 7: Update implementation-process integration
- **Status:** done
- **Depends on:** Task 4, Task 5, Task 6
- **Docs:** [implementation.md#task-7-update-implementation-process-integration](./implementation.md#task-7-update-implementation-process-integration)

### Subtasks
- [x] 7.1 Update `klaude-plugin/skills/implementation-process/SKILL.md` Step 3 to mention isolated review as an option when prompting user for code review
- [x] 7.2 Add routing: if user requests isolated review, use `kk:solid-code-review:isolated` (which handles `pal` codereview internally) instead of separate calls
- [x] 7.3 Verify standard flow is unchanged when isolated mode is not requested

## Task 8: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7

### Subtasks
- [ ] 8.1 Run `testing-process` skill to verify all components — agent definitions are valid, workflows complete, routing works
- [ ] 8.2 Run `documentation-process` skill to update any relevant docs
- [ ] 8.3 Run `solid-code-review` skill to review the new files
- [ ] 8.4 Run `implementation-review` skill to verify implementation matches design and implementation docs
