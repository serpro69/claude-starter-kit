# Tasks: Design Skill Refinement

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: done
> Created: 2026-05-21
> Not Doing: existing-task-process.md changes, implement skill changes, pal-based stress-testing, Mermaid graphs, design skill evals, skill-md profile design/ subdirectory

## Task 1: Create frameworks.md reference file
- **Status:** done
- **Depends on:** —
- **Size:** S
- **Can run in parallel with:** Task 2
- **Docs:** [implementation.md#task-11-create-frameworksmd](./implementation.md#task-11-create-frameworksmd)

### Subtasks
- [x] 1.1 Pin upstream commit SHA: `git ls-remote https://github.com/addyosmani/agent-skills.git HEAD`
- [x] 1.2 Fetch original from `https://raw.githubusercontent.com/addyosmani/agent-skills/<SHA>/skills/idea-refine/frameworks.md`
- [x] 1.3 Create `klaude-plugin/skills/design/frameworks.md` with license/attribution header (MIT, Copyright Addy Osmani, pinned SHA), all seven frameworks, each with description and "Best for" guidance
- [x] 1.4 Light adaptation: add SE-context framing note at top, replace consumer-product examples with SE equivalents, preserve structure and quality criteria

## Task 2: Create refinement-criteria.md reference file
- **Status:** done
- **Depends on:** —
- **Size:** S
- **Can run in parallel with:** Task 1
- **Docs:** [implementation.md#task-12-create-refinement-criteriamd](./implementation.md#task-12-create-refinement-criteriamd)

### Subtasks
- [x] 2.1 Fetch original from `https://raw.githubusercontent.com/addyosmani/agent-skills/<SHA>/skills/idea-refine/refinement-criteria.md` (same pinned SHA as Task 1)
- [x] 2.2 Create `klaude-plugin/skills/design/refinement-criteria.md` with license/attribution header, three evaluation dimensions (User Value, Feasibility, Differentiation) plus MVP Scoping section
- [x] 2.3 Light adaptation: add SE-context framing, remove consumer examples, preserve painkiller-vs-vitamin framing, differentiation ranking, value/feasibility matrix, and MVP rules

## Task 3: Rewrite idea-process.md Step 3
- **Status:** done
- **Depends on:** Task 1, Task 2
- **Size:** M
- **Can run in parallel with:** —
- **Docs:** [implementation.md#task-21-rewrite-idea-processmd-step-3](./implementation.md#task-21-rewrite-idea-processmd-step-3)

### Subtasks
- [x] 3.1 Replace current Step 3 body in `klaude-plugin/skills/design/idea-process.md` with five sub-phases (3a-3e)
- [x] 3.2 Preserve the profile detection block in its current position (before questions begin)
- [x] 3.3 Ensure Step 3 references frameworks.md and refinement-criteria.md as already-loaded (loaded during SKILL.md step 2, not re-loaded here)
- [x] 3.4 Write sub-phase 3a (HMW framing) with reference to frameworks.md §HMW
- [x] 3.5 Write sub-phase 3b (hard gate) with three explicit requirements: who, success, technical constraints
- [x] 3.6 Write sub-phase 3c (proportional diverge) with complexity classification confirmation, two paths (non-trivial: 2-3 alternatives, simple: direct + one alternative), and rejection loop
- [x] 3.7 Write sub-phase 3d (converge): manual criteria-based analysis as default, CoVe scoped to verifiable claims only, concrete fallback triggers
- [x] 3.8 Write sub-phase 3e (surface outputs) requiring Assumptions and Not Doing artifacts

## Task 4: Update idea-process.md Steps 5 and 6
- **Status:** done
- **Depends on:** Task 3
- **Size:** M
- **Can run in parallel with:** —
- **Docs:** [implementation.md#task-31-update-step-5-in-idea-processmd](./implementation.md#task-31-update-step-5-in-idea-processmd), [implementation.md#task-32-update-step-6-in-idea-processmd](./implementation.md#task-32-update-step-6-in-idea-processmd)

### Subtasks
- [x] 4.1 Add Assumptions and Not Doing section requirements to Step 5's documentation guidelines (before the DO NOT list)
- [x] 4.2 Add Not Doing header requirement to Step 6's key points
- [x] 4.3 Add vertical slicing mandate with explicit anti-pattern to Step 6
- [x] 4.4 Add Size tags (S/M/L) with L-forbidden rule to Step 6
- [x] 4.5 Add slicing strategy definitions (Vertical, Contract-First, Risk-First) to Step 6
- [x] 4.6 Add parallel markers requirement to Step 6
- [x] 4.7 Add ASCII dependency graph requirement to Step 6
- [x] 4.8 Add recommendation to invoke `/kk:review-design <feature> all` as the post-design gate at the end of Step 6

## Task 5: Rework example-tasks.md
- **Status:** done
- **Depends on:** Task 4
- **Size:** S
- **Can run in parallel with:** Task 6
- **Docs:** [implementation.md#task-41-rework-example-tasksmd](./implementation.md#task-41-rework-example-tasksmd)

### Subtasks
- [x] 5.1 Add `> Not Doing:` line to the header metadata block with realistic JWT-auth exclusions
- [x] 5.2 Add `**Size:**` and `**Can run in parallel with:**` fields to each task
- [x] 5.3 Reslice tasks to demonstrate vertical slices (e.g., "User login end-to-end" instead of "Token generation library")
- [x] 5.4 Add `## Dependency Graph` section at the bottom with ASCII format

## Task 6: Update SKILL.md conventions
- **Status:** done
- **Depends on:** Task 3
- **Size:** S
- **Can run in parallel with:** Task 5
- **Docs:** [implementation.md#task-51-reference-new-files-in-skillmd](./implementation.md#task-51-reference-new-files-in-skillmd)

### Subtasks
- [x] 6.1 Update mandatory-order directive in `klaude-plugin/skills/design/SKILL.md` §Workflow to name frameworks.md and refinement-criteria.md in the instruction enumeration
- [x] 6.2 Update Workflow step 2 to include frameworks.md and refinement-criteria.md in the instruction-load set for fresh ideas
- [x] 6.3 Add sentence to Conventions section mentioning frameworks.md and refinement-criteria.md as methodology/rubric reference files

## Task 7: Update review-design (all review paths)
- **Status:** done
- **Depends on:** Task 4
- **Size:** M
- **Can run in parallel with:** Task 5, Task 6
- **Docs:** [implementation.md#task-61-update-review-processmd-steps-3-and-4](./implementation.md#task-61-update-review-processmd-steps-3-and-4)

### Subtasks
- [x] 7.1 Add design.md checks to `review-process.md` Step 3: Assumptions section (present, testable), Not Doing section (present, justified). Finding type: `STRUCTURE`
- [x] 7.2 Add tasks.md checks to `review-process.md` Step 3: Not Doing in header, Size tags, no unbroken L tasks, vertical slicing (flag horizontal layers as `TECH_RISK`), parallel markers, dependency graph
- [x] 7.3 Add to `review-process.md` Step 4: assumptions testability check (vague → `AMBIGUOUS`), Not Doing validity check (disguised critical requirement → `TECH_RISK`)
- [x] 7.4 Add same quality/soundness checks to `klaude-plugin/agents/design-reviewer.md` §3 (Document Quality Pass) and §4 (Technical Soundness Pass)
- [x] 7.5 Add scope recommendation to `klaude-plugin/skills/review-design/SKILL.md`: note that `all` scope is recommended after `/kk:design` runs

## Task 8: Create spec-style evals
- **Status:** done
- **Depends on:** Task 3, Task 7
- **Size:** M
- **Can run in parallel with:** Task 5, Task 6
- **Docs:** [implementation.md#task-71-create-spec-style-evals-for-design-skill](./implementation.md#task-71-create-spec-style-evals-for-design-skill)

### Subtasks
- [x] 8.1 Create `klaude-plugin/skills/design/evals/hard-gate-enforcement/` with eval.json and test idea that invites skipping the gate
- [x] 8.2 Create `klaude-plugin/skills/design/evals/proportional-diverge-routing/` with eval.json and simple single-concern test idea
- [x] 8.3 Create `klaude-plugin/skills/design/evals/review-design-catches-missing-sections/` with eval.json and test-files/ containing a design.md missing Assumptions/Not Doing and a tasks.md with horizontal layers and no Size tags

## Task 9: Final verification
- **Status:** done
- **Depends on:** Task 5, Task 6, Task 7, Task 8
- **Size:** S
- **Can run in parallel with:** —

### Subtasks
- [x] 9.1 Run full test suite: `for test in test/test-*.sh; do $test; done` — all green
- [x] 9.2 Run `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/` — Codex plugin freshness check passes (7 files regenerated)
- [x] 9.3 Run `/kk:test` skill to verify all tasks
- [x] 9.4 Run `/kk:document` skill to update any relevant docs (no updates needed — changes are self-contained within skill files)
- [x] 9.5 Run `/kk:review-code` skill to review the implementation (one P3 fixed: stale framework count in design.md)
- [x] 9.6 Run `/kk:review-spec` skill to verify implementation matches design and implementation docs (2 OUTDATED_DOC fixed: framework count, scope description)

## Dependency Graph

```
Task 1 ──→ Task 3 ──→ Task 4 ──→ Task 5 ──→ Task 9
Task 2 ──→ Task 3     Task 3 ──→ Task 6 ──→ Task 9
                       Task 4 ──→ Task 7 ──→ Task 9
                       Task 3 ──→ Task 8 ──→ Task 9
                       Task 7 ──→ Task 8
```
