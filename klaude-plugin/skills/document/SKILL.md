---
name: document
description: |
  After implementing a new feature or fixing a bug, make sure to document the changes.
  Use when writing documentation, after finishing the implementation phase for a feature or a bug-fix.
---

# Documentation Process

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection is delegated to [shared-profile-detection.md](shared-profile-detection.md). When an active profile contributes a `document/` subdirectory (e.g., `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/document/`), its `index.md` lists a doc rubric — required topics the documentation for that artifact type must cover. See the Workflow below for the load order.

## Workflow

**Mandatory order — instructions before action.** The flow below is strictly sequential. Do not read feature-tree content, write, or edit documentation files until profile detection has completed and all resolved profile content is in context. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

1. **Minimal-scope listing.** List the feature directory (filenames and metadata only — no file-content reads). This is the input profile detection needs, and nothing more; content-level reading happens after profile content is loaded.
2. **Detect active profiles.** Run the shared profile-detection procedure against the filename list from Step 1.
3. **Load profile content.** For each active profile that contributes a `document/` subdirectory, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/document/index.md` and read its always-load + any matching conditional content. The rubric named there specifies topics the documentation must cover for that profile's artifacts.
4. **Read the feature-tree content** the documentation will cover. This is the first step that touches subject-matter content; the profile rubric is now loaded and frames what to look for.
5. **Apply the doc guidelines below.** Write or update documentation applying the rubric's required topics where applicable.

## Guidelines

1. After completing a new feature, always see if you need to update the Architecture documentation at `/docs/contributing/ARCHITECTURE.md` and Test documentation in `/docs/contributing/TESTING.md` for other developers, so anyone could easily pick up the work and understand the project and the feature that was added.
2. If the code change included prior decision-making out of several alternatives, document an ADR at `/docs/adr` for any non-trivial/non-obvious decisions that should be preserved.
3. **Profile-aware rubric.** For each active profile, apply the doc rubric its `document/index.md` specifies (loaded in Step 3 of the Workflow). Each required topic must be addressed in one of three ways: (a) write the topic if the feature touches it, (b) state `N/A — <reason>` in a single line if the feature does not touch the topic, or (c) cite the inherited source explicitly if the feature assumes the topic but inherits it from elsewhere (e.g., NetworkPolicy defined in a platform repo). Silent omission is the failure mode — an explicit `N/A` communicates consideration; an absent heading communicates nothing.

**Capy search:** Before writing docs, search `kk:arch-decisions` and `kk:project-conventions` for decisions that should be reflected in documentation — decisions not obvious from code alone.
