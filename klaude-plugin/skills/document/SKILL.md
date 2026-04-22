---
name: document
description: |
  After implementing a new feature or fixing a bug, make sure to document the changes.
  Use when writing documentation, after finishing the implementation phase for a feature or a bug-fix.
---

# Documentation Process

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection is delegated to [shared-profile-detection.md](shared-profile-detection.md). When an active profile contributes a `document/` subdirectory (e.g., `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/document/`), its `index.md` lists a doc rubric — required topics the documentation for that artifact type must cover. See Step 2 of the Workflow.

## Workflow

**Mandatory order — instructions before action.** The flow below is strictly sequential. Do not write or edit documentation files until profile detection has completed and all resolved profile content is in context. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

1. **Detect active profiles.** Run the shared profile-detection procedure against the changed files or the feature directory.
2. **Load profile content.** For each active profile that contributes a `document/` subdirectory, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/document/index.md` and read its always-load + any matching conditional content. The rubric named there specifies topics the documentation must cover for that profile's artifacts.
3. **Apply the doc guidelines below.** With the per-profile rubric now loaded, write or update documentation and apply the rubric's required topics where applicable.

## Guidelines

**Capy search:** Before writing docs, search `kk:arch-decisions` and `kk:project-conventions` for decisions that should be reflected in documentation — decisions not obvious from code alone.

1. After completing a new feature, always see if you need to update the Architecture documentation at `/docs/contributing/ARCHITECTURE.md` and Test documentation in `/docs/contributing/TESTING.md` for other developers, so anyone could easily pick up the work and understand the project and the feature that was added.
2. If the code change included prior decision-making out of several alternatives, document an ADR at `/docs/adr` for any non-trivial/non-obvious decisions that should be preserved.
3. **Profile-aware rubric.** Apply the doc rubric the active profile's `document/index.md` specifies (loaded in Step 2 of the Workflow). Each required topic the rubric names must be addressed in the documentation for that profile's artifacts — either by writing the topic or by explicitly noting why it is inapplicable.
