---
name: design
description: |
  Use in pre-implementation (idea-to-design) stages to understand spec/requirements and create a correct implementation plan before writing actual code.
  Turns ideas into a fully-formed PRD/design/specification and implementation-plan. Creates design docs and task lists in docs/wip/.
---
<!-- codex: tool-name mapping applied. See .codex/scripts/session-start.sh -->

# Task Analysis Process

**Goal: Before writing any code, make sure you understand the requirements and have an implementation plan ready.**

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection is delegated to [shared-profile-detection.md](shared-profile-detection.md). When an active profile contributes a `design/` subdirectory (e.g., `../klaude-plugin/profiles/k8s/design/`), its `questions.md` feeds the idea-refinement question pool and its `sections.md` lists required sections the design document must cover. Both the idea-to-design and continue-WIP flows consult the shared procedure; see each flow's workflow file for the specific integration points.

## Workflow

**Mandatory order — understanding before engagement.** The flow below is strictly sequential. Do not engage with the idea prose beyond a keyword scan, ask refinement questions, or write design content until all instructions — this SKILL.md, the relevant process file, the shared profile-detection procedure, and every resolved profile's `design/` content — are fully loaded. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

The `design` skill has two entry points; each has its own process file with a detailed workflow. Both follow the same mandatory ordering:

1. **Keyword scan only.** The idea prose (or WIP feature directory) is scanned at the keyword/filename level — enough to drive profile detection, not enough to engage with the content.
2. **Load instructions.** Read the relevant process file ([idea-process.md](./idea-process.md) or [existing-task-process.md](./existing-task-process.md)) and the shared profile-detection procedure.
3. **Detect active profiles.** Delegate to [shared-profile-detection.md](shared-profile-detection.md). For fresh ideas, this uses the design interaction pattern (token matching against idea prose). For WIP features, this uses file-based detection with design-pattern fallback.
4. **Load profile content.** For each active profile contributing a `design/` subdirectory, read its `index.md` and all always-load entries (`questions.md`, `sections.md`). These feed the refinement question pool and required design sections.
5. **Engage with subject matter.** Only now: ask refinement questions, analyze the idea, write design content.

## Ideas and Prototypes

_Use this for ideas that are not fully thought out and do not have a fully-formed design/specification and/or implementation-plan._

**For example:** I've got an idea I want to talk through with you before we proceed with the implementation.

**Your job:** Help me turn it into a fully formed design, spec, implementation plan, and task list.

See [idea-process.md](./idea-process.md).

## Continue WIP Feature

_Use this to resume work on a feature that already has design docs and a task list in `/docs/wip/`._

**For example:** Let's continue working on the auth system.

**Your job:** Review the current state of the feature, understand what's been done and what's next, then proceed with implementation.

See [existing-task-process.md](./existing-task-process.md).
