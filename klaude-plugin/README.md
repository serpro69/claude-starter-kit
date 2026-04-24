# kk — Claude Code Plugin

A development workflow plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that gives your AI assistant a structured pipeline — from idea through design, implementation, code review, testing, to documentation. Part of the [claude-toolbox](https://github.com/serpro69/claude-toolbox) project.

Why `kk`? I have `jj` and `kk` mappings in nvim to go back to normal mode, and it seemed like a low-conflict/easy-to-type option for a plugin-prefixed skill names. We can also pretend it's an acronym for "klaude kode", if you need a better reason for the plugin naming.

## Installation

The plugin is installed automatically when using the claude-toolbox template. To install manually:

```
/plugin install kk@claude-toolbox
```

All skills appear as `/skill-name` in the slash command menu (annotated with `(kk)`). No additional configuration needed.

## Skills

| Skill                      | What it does                                                                                                                                                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **design**       | Turns an idea into design docs, an implementation plan, and a task list in `docs/wip/`. Asks refinement questions, then documents everything a developer needs to start coding. |
| **implement** | Executes a task list from `docs/wip/` with batched steps and code review checkpoints between batches. Updates task status as it goes.                                           |
| **test**        | Generates tests following project conventions: table-driven, integration, mocking, property-based. Runs the full suite and reports coverage.                                    |
| **document**  | Updates ARCHITECTURE.md, TESTING.md, and records ADRs for non-obvious decisions made during implementation.                                                                     |
| **dependency-handling**    | Fires before calling a library/SDK/API or adding a dependency. Forces a capy/context7 lookup instead of guessing signatures or behavior.                                         |
| **review-code**      | Reviews git changes for SOLID violations, security risks, and code quality. Language-specific checklists for Go, Java, JS/TS, Kotlin, and Python. Standard and isolated modes.  |
| **review-spec**  | Compares implemented code against design/implementation docs. Finds spec deviations, missing implementations, and outdated docs — in both directions.                           |
| **review-design**          | Pre-implementation review gate. Evaluates design docs for completeness, internal consistency, and technical soundness before code is written.                                    |
| **merge-docs**             | Merges two competing design docs for the same feature into one unified document, resolving conflicts and preserving the best of both.                                           |
| **chain-of-verification**  | Makes Claude fact-check its own answers. Standard mode (prompt-based) or isolated mode (independent sub-agents). For high-stakes accuracy.               |

### Development Workflow

The skills are designed to work together in a pipeline:

```
design → review-design → implement → review-code → test → document
```

1. **design** — design docs + implementation plan + task list
2. **review-design** — evaluate design docs for completeness and technical soundness before writing code
3. **implement** — execute tasks with review checkpoints
4. **review-code** — review code for SOLID violations, security risks, and quality issues
5. **test** — verify and validate
6. **document** — update docs

**During implementation**, **dependency-handling** is pulled in whenever you touch an external library, SDK, or API — it routes you through capy/context7 instead of letting you guess. **review-spec** verifies code matches design/spec and detects deviations — use during or after implementation.

**Utilities**: **merge-docs** reconciles competing design docs into one unified document. **chain-of-verification** adds self-verification for high-stakes accuracy at any stage.

## Commands

| Command | Invocation | Description |
|---------|-----------|-------------|
| Code Review (isolated) | `/kk:review-code:isolated` | SOLID code review with independent sub-agents |
| CoVe (standard) | `/kk:chain-of-verification:default [question]` | Chain-of-Verification with prompt-based isolation |
| CoVe (isolated) | `/kk:chain-of-verification:isolated [--explore] [--haiku] [question]` | CoVe with true sub-agent isolation |
| Implementation Review | `/kk:review-spec:default [feature]` | Verify code matches design/implementation docs |
| Implementation Review (isolated) | `/kk:review-spec:isolated [feature]` | Spec conformance review with independent sub-agent |
| Design Review | `/kk:review-design [feature] [scope]` | Review design docs for quality and technical soundness |
| Design Review (isolated) | `/kk:review-design:isolated [feature] [scope]` | Design review with independent sub-agents |
| Migrate from Task Master | `/kk:migrate-from-taskmaster:migrate` | One-time migration from Task Master MCP |
| Sync Workflow | `/kk:sync-workflow:sync-workflow [version]` | Update template-sync from upstream |

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| Bash validation | `PreToolUse` on `Bash` | Blocks commands touching `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`, and other sensitive paths |

## Profiles

The plugin ships per-domain profiles under `profiles/` (e.g., `go`, `k8s`, `python`). Profiles provide language- and framework-specific content to every workflow skill — review checklists, implementation gotchas, design prompts, test validators, and doc rubrics.

Some profiles vendor content from external upstream repositories. The Go profile, for example, vendors from [samber/cc-skills-golang](https://github.com/samber/cc-skills-golang) via a manifest-driven pipeline (`make vendor-go`). See the **Vendored profile content** section of [`CLAUDE.md`](../CLAUDE.md) for the workflow, and the **Profile Conventions** section for the full authoring contract.

## Upgrading from Template-Managed Skills

If you're upgrading from a version before the plugin system (< v0.5.0):

- Skills remain unprefixed: `/design` (annotated with `(kk)` in the menu)
- Commands are now namespaced: `/project:chain-of-verification` → `/kk:chain-of-verification:default`
- The template-sync workflow handles migration automatically on next sync
- After merging the sync PR, run `/plugin install kk@claude-toolbox`
