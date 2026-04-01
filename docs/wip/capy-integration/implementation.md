# Implementation Plan: Capy Knowledge Base Integration

> Design: [./design.md](./design.md)
> Status: draft
> Created: 2026-04-01

## Overview

This plan adds capy knowledge base integration to the kk plugin. The work breaks into three layers: a shared protocol file, per-skill modifications, and infrastructure updates (bootstrap + README).

## File Inventory

### New Files

| File | Purpose |
|---|---|
| `klaude-plugin/skills/_shared/capy-knowledge-protocol.md` | Shared taxonomy, search/index conventions |

### Modified Files — Skills

| File | Change |
|---|---|
| `klaude-plugin/skills/analysis-process/idea-process.md` | Add search before Step 3, index after Step 5 |
| `klaude-plugin/skills/analysis-process/existing-task-process.md` | Add search during plan review |
| `klaude-plugin/skills/implementation-process/SKILL.md` | Add search in Step 1, index in Step 3 |
| `klaude-plugin/skills/solid-code-review/SKILL.md` | Add search in Step 1, index after Step 7, fetch-and-index for missing lang idioms |
| `klaude-plugin/skills/testing-process/SKILL.md` | Add search before guidelines, index for novel patterns |
| `klaude-plugin/skills/development-guidelines/SKILL.md` | Add search before context7, index for best-practice findings |
| `klaude-plugin/skills/implementation-review/SKILL.md` | Add search during document loading, index for confirmed deviations |
| `klaude-plugin/skills/documentation-process/SKILL.md` | Add search before writing docs |
| `klaude-plugin/skills/merge-docs/SKILL.md` | Add search before merging, index for conflict resolutions |
| `klaude-plugin/skills/cove/cove-process.md` | Add search during verification step |
| `klaude-plugin/skills/cove/cove-isolated.md` | Add search during verification step |

### Modified Files — Infrastructure

| File | Change |
|---|---|
| `bootstrap.sh` | Add capy setup step with opt-out and warning |
| `README.md` | Add capy to MCP servers table, add knowledge base section |

## Implementation Details

### 1. Shared Protocol File {#protocol}

Create `klaude-plugin/skills/_shared/capy-knowledge-protocol.md`.

This file is referenced by skills for label naming and conventions. It should contain:

- **Preamble:** One sentence explaining that capy integration is conditional — if capy MCP tools are not available, skip all search/index steps and proceed normally.
- **Source label taxonomy table:** The 6 `kk:*` labels with descriptions (see [design.md](./design.md#source-label-taxonomy)).
- **Search conventions:**
  - 2-4 specific terms per query
  - Use `source` filter to scope to relevant labels
  - Use `source: "kk:"` for broad cross-domain searches
  - Default `limit: 3` per query
  - If no results, proceed with standard guidelines (cold-start fallback)
- **Index conventions:**
  - Only index non-obvious learnings not derivable from reading the code
  - Keep content concise — summarize, don't dump raw output
  - Always use a `kk:` prefixed label from the taxonomy
  - One concept per index call

The file should be ~30-50 lines. Lean and direct.

### 2. Skill Modifications {#skills}

Each skill modification follows the same pattern:

1. Add a reference to the protocol file at the top of the workflow section (e.g., "For capy knowledge base conventions, see [capy-knowledge-protocol.md](../_shared/capy-knowledge-protocol.md)")
2. Add a **search step** at the appropriate point in the workflow — explicit queries with specific source labels
3. Add an **index step** at the appropriate point — explicit about what to index and which label to use
4. Both steps are conditional on capy availability (inherited from the protocol preamble)

#### analysis-process (idea-process.md) {#analysis-idea}

- Insert search step before Step 3 (Help refine the idea):
  - Search `kk:arch-decisions` and `kk:project-conventions` for prior design context related to the feature area being discussed
- Insert index step after Step 5 (Document the design):
  - Index key architecture decisions and trade-offs from the documented design as `kk:arch-decisions`

#### analysis-process (existing-task-process.md) {#analysis-existing}

- Insert search step during the plan review phase:
  - Search `kk:arch-decisions` and `kk:project-conventions` for context relevant to the feature being resumed

#### implementation-process {#implementation}

- Extend Step 1 (Load and Review Plan):
  - After reading design/implementation docs, search `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, and `kk:review-findings` for context relevant to the next task
- Extend Step 3 (Report):
  - If a non-obvious pattern or convention was established during implementation, index it as `kk:project-conventions`

#### solid-code-review {#code-review}

- Extend Step 1 (Preflight context):
  - Search `kk:review-findings` for prior findings in the same files/modules
  - Search `kk:lang-idioms` for best practices in the detected language
  - If `kk:lang-idioms` returns no results for the detected language, optionally use `capy_fetch_and_index` to fetch a well-known idioms resource (e.g., Effective Go for `.go` files) and label it `kk:lang-idioms`
- Insert index step after Step 7 (Self-check):
  - Index any P0/P1 findings that reveal recurring patterns (not one-off typos) as `kk:review-findings`

#### testing-process {#testing}

- Insert search step before applying test guidelines:
  - Search `kk:test-patterns` for project-specific testing approaches and known edge cases
- Insert index step at the end:
  - If a novel testing approach or tricky edge case was discovered, index as `kk:test-patterns`

#### development-guidelines {#dev-guidelines}

- Insert search step before consulting context7:
  - Search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency in question
- Insert index step after resolving a dependency question:
  - If context7 or web search yields a valuable best-practice nugget not obvious from docs, index as `kk:lang-idioms`

#### implementation-review {#impl-review}

- Extend Phase 1 (Load feature documents):
  - Search `kk:arch-decisions` for design rationale that may explain intentional spec deviations
  - Search `kk:review-findings` for known patterns from prior reviews
- Insert index step after presenting findings:
  - Index any `SPEC_DEV` or `EXTRA_IMPL` findings confirmed by the user as intentional as `kk:arch-decisions`

#### documentation-process {#docs}

- Insert search step before writing docs:
  - Search `kk:arch-decisions` and `kk:project-conventions` for decisions that should be reflected in documentation
- No index step.

#### merge-docs {#merge}

- Insert search step before merging:
  - Search `kk:arch-decisions` for prior decisions relevant to the competing approaches
- Insert index step after merge:
  - If the merge resolved a genuine architectural conflict, index the resolution rationale as `kk:arch-decisions`

#### cove (cove-process.md and cove-isolated.md) {#cove}

- **Standard mode (`cove-process.md`):**
  - Insert search in Step 3 (Independent Verification): search `kk:` broadly as another tool source alongside WebSearch/context7
  - Insert search in Step 4 (Reconciliation): search `kk:` broadly to adjudicate contradicted or inconclusive claims
- **Isolated mode (`cove-isolated.md`):**
  - Do NOT inject capy results into sub-agent prompts — this leaks the main agent's framing and compromises factored verification. Sub-agents may independently query capy as part of their own tool-first research (capy is project state, not context).
  - Insert search in Step 4 (Reconciliation): same as standard mode — verification is complete, no isolation concern
- No index step.

### 3. Bootstrap Integration {#bootstrap}

Modify `bootstrap.sh` to add a capy setup step:

- Check for `SKIP_CAPY` environment variable or `--no-capy` CLI flag — if set, skip entirely
- Check if `capy` binary exists on PATH using `command -v capy`
- If found: run `capy setup` in the project directory
- If not found: print warning to stderr — `"⚠ capy not found on PATH — skipping knowledge base setup. Install: https://github.com/serpro69/capy"`

The step should be added after the existing plugin installation step, since capy is a supplementary tool.

### 4. README Updates {#readme}

**MCP Servers table:** Add a row for capy:

| Server | Purpose |
|---|---|
| **[Capy](https://github.com/serpro69/capy)** | Persistent knowledge base — cross-session project memory with FTS5 search |

**New section** (after MCP Servers, before kk Plugin): Brief "Knowledge Base" section explaining:
- What capy provides (persistent cross-session knowledge)
- How skills use it (search before executing, index after producing output)
- Installation: `brew install serpro69/tap/capy` then `capy setup`
- The kk plugin works fully without capy — skills gracefully degrade

## Testing Considerations

- Each skill modification is a markdown change — no code to unit test
- Verify that all skill files reference the protocol file correctly (relative paths)
- Verify `bootstrap.sh` handles all three cases: capy present, capy absent (warning), opt-out (skip)
- Manual verification: run a skill in a project with capy configured and verify search/index steps execute
