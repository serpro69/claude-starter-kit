# Design: Capy Knowledge Base Integration

> Issue: [serpro69/claude-toolbox#44](https://github.com/serpro69/claude-toolbox/issues/44)
> Status: draft
> Created: 2026-04-01

## Problem

The kk plugin's skills execute in isolated sessions with no cross-session memory. Architecture decisions made during `analysis-process`, review findings from `solid-code-review`, testing patterns discovered during `testing-process` — all lost when the conversation ends. Each new session starts from scratch.

## Solution

Integrate capy's persistent FTS5 knowledge base into the kk plugin's skill system. Skills become **knowledge-aware** — they search for relevant context before executing and index valuable learnings after producing output. Knowledge persists across sessions per-project.

## Architecture

### Trigger vs. Taxonomy Hybrid

The integration follows a **"Trigger vs. Taxonomy"** pattern that balances LLM prompt effectiveness with maintainability:

- **Taxonomy** (shared) — A single protocol file defines the namespaced source labels, search conventions, and indexing conventions. All skills reference this for consistency.
- **Triggers** (per-skill) — Each skill contains explicit, actionable steps — "search capy for X", "index this as Y". No vague indirection.

### Source Label Taxonomy

All plugin-managed labels use the `kk:` namespace prefix to separate from user-indexed content.

| Label | Contents | Producers | Consumers |
|---|---|---|---|
| `kk:arch-decisions` | Architecture decisions, design rationale, trade-offs | `analysis-process`, `implementation-review`, `merge-docs` | `implementation-process`, `solid-code-review`, `implementation-review`, `documentation-process`, `merge-docs` |
| `kk:review-findings` | Code review patterns, recurring issues, anti-patterns | `solid-code-review`, `implementation-review` | `solid-code-review`, `implementation-process`, `implementation-review` |
| `kk:lang-idioms` | Language best practices, idiomatic patterns from external sources | `development-guidelines`, `solid-code-review` | `solid-code-review`, `implementation-process`, `testing-process`, `development-guidelines` |
| `kk:project-conventions` | Discovered project patterns, naming conventions, structural decisions | `analysis-process`, `implementation-process` | All skills |
| `kk:test-patterns` | Testing approaches, edge cases, test infrastructure decisions | `testing-process` | `testing-process`, `implementation-process` |
| `kk:debug-context` | Root causes, tricky bugs and their fixes, environment gotchas | Any skill during debugging | Any skill |

### Relationship to Static References

The `solid-code-review` skill's existing static reference files (`reference/go/solid-checklist.md`, etc.) remain unchanged. They are curated, version-controlled, and always available with no cold-start problem. Capy provides a **supplementary dynamic layer** — project-specific learnings, accumulated findings, fetched external resources. The two complement each other.

### Graceful Degradation

Capy is not a hard dependency. All skill modifications are written so that if capy MCP is not available:

- Search triggers return nothing — the cold-start fallback kicks in ("if no results, proceed with standard guidelines")
- Index steps are simply skipped
- Skills work exactly as they do today

The shared protocol file states this principle once; skills inherit the behavior.

## Per-Skill Integration

Every skill gets a **search phase** (at workflow start) and an **index phase** (after producing valuable output).

### analysis-process

- **Search:** Before refining the idea (Step 3), search `kk:arch-decisions` and `kk:project-conventions` for prior design context relevant to the feature area.
- **Index:** After documenting the design (Step 5), index key architecture decisions and trade-offs as `kk:arch-decisions`.

### implementation-process

- **Search:** During plan review (Step 1), search `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, and `kk:review-findings` for context relevant to the task being implemented.
- **Index:** After completing a task (Step 3), if a non-obvious pattern or convention was established during implementation, index it as `kk:project-conventions`.

### solid-code-review

- **Search:** During preflight context (Step 1), search `kk:review-findings` for prior findings in the same area, and `kk:lang-idioms` for language-specific best practices. If `kk:lang-idioms` has no results for the detected language, optionally `capy_fetch_and_index` a well-known idioms resource (e.g., Effective Go) and label it `kk:lang-idioms`.
- **Index:** After self-check (Step 7), index any P0/P1 findings that reveal recurring patterns as `kk:review-findings`.

### testing-process

- **Search:** Before applying test guidelines, search `kk:test-patterns` for project-specific testing approaches and known edge cases.
- **Index:** If a novel testing approach or tricky edge case is discovered, index as `kk:test-patterns`.

### development-guidelines

- **Search:** Before consulting context7 for external dependency docs, search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency.
- **Index:** If context7 or web search yields a valuable best-practice nugget that isn't obvious from the docs themselves, index as `kk:lang-idioms`.

### implementation-review

- **Search:** During "Load feature documents" phase, search `kk:arch-decisions` for design rationale that may explain intentional spec deviations. Also search `kk:review-findings` for known patterns from prior reviews.
- **Index:** After presenting findings, index any `SPEC_DEV` or `EXTRA_IMPL` findings confirmed by the user as intentional — save as `kk:arch-decisions` to prevent the same deviation from being flagged again.

### documentation-process

- **Search:** Before writing docs, search `kk:arch-decisions` and `kk:project-conventions` for context that should be reflected in documentation — decisions not obvious from code alone.
- **Index:** None — this skill consumes knowledge but doesn't typically produce new knowledge worth persisting.

### merge-docs

- **Search:** Before merging competing design docs, search `kk:arch-decisions` for prior decisions that might inform which approach to favor.
- **Index:** After producing the merged document, if the merge resolved a genuine architectural conflict, index the resolution rationale as `kk:arch-decisions`.

### cove

- **Search:** During independent verification (Step 3), search `kk:` broadly for any indexed knowledge relevant to the verification questions.
- **Index:** None — CoVe is a verification technique, it doesn't produce persistent learnings.

## Bootstrapping

### bootstrap.sh Integration

The template's `bootstrap.sh` gains a capy setup step:

1. Check if `capy` binary is on PATH
2. If found: run `capy setup` to configure MCP server, hooks, and guidance files
3. If not found: print a warning — "capy not found on PATH, skipping knowledge base setup. Install from https://github.com/serpro69/capy"
4. Opt-out: `SKIP_CAPY=1 ./bootstrap.sh` or `--no-capy` flag skips the capy step entirely

### README Updates

Add capy to the MCP Servers table alongside Context7, Serena, and Pal. Add a brief section explaining the knowledge base integration — what it does, how skills use it, how to install.
