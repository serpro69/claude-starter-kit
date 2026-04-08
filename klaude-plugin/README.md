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
| **analysis-process**       | Turns an idea into design docs, an implementation plan, and a task list in `docs/wip/`. Asks refinement questions, then documents everything a developer needs to start coding. |
| **implementation-process** | Executes a task list from `docs/wip/` with batched steps and code review checkpoints between batches. Updates task status as it goes.                                           |
| **testing-process**        | Generates tests following project conventions: table-driven, integration, mocking, property-based. Runs the full suite and reports coverage.                                    |
| **documentation-process**  | Updates ARCHITECTURE.md, TESTING.md, and records ADRs for non-obvious decisions made during implementation.                                                                     |
| **development-guidelines** | Enforces best practices during coding: latest deps, context7 for library docs, known project conventions from the knowledge base.                                               |
| **solid-code-review**      | Reviews git changes for SOLID violations, security risks, and code quality. Language-specific checklists for Go, Java, JS/TS, Kotlin, and Python. Standard and isolated modes.  |
| **implementation-review**  | Compares implemented code against design/implementation docs. Finds spec deviations, missing implementations, and outdated docs — in both directions.                           |
| **design-review**          | Pre-implementation review gate. Evaluates design docs for completeness, internal consistency, and technical soundness before code is written.                                    |
| **merge-docs**             | Merges two competing design docs for the same feature into one unified document, resolving conflicts and preserving the best of both.                                           |
| **cove**                   | Chain-of-Verification: makes Claude fact-check its own answers. Standard mode (prompt-based) or isolated mode (independent sub-agents). For high-stakes accuracy.               |

### Development Workflow

The skills are designed to work together in a pipeline:

```
analysis-process → design-review → implementation-process → solid-code-review → testing-process → documentation-process
```

1. **analysis-process** — design docs + implementation plan + task list
2. **design-review** — evaluate design docs for completeness and technical soundness before writing code
3. **implementation-process** — execute tasks with review checkpoints
4. **solid-code-review** — review code for SOLID violations, security risks, and quality issues
5. **testing-process** — verify and validate
6. **documentation-process** — update docs

**During implementation**, **development-guidelines** enforces best practices (latest deps, context7 for docs). **implementation-review** verifies code matches design/spec and detects deviations — use during or after implementation.

**Utilities**: **merge-docs** reconciles competing design docs into one unified document. **cove** (Chain-of-Verification) adds self-verification for high-stakes accuracy at any stage.

## Commands

| Command | Invocation | Description |
|---------|-----------|-------------|
| Code Review (isolated) | `/kk:solid-code-review:isolated` | SOLID code review with independent sub-agents |
| CoVe (standard) | `/kk:cove:cove [question]` | Chain-of-Verification with prompt-based isolation |
| CoVe (isolated) | `/kk:cove:cove-isolated [--explore] [--haiku] [question]` | CoVe with true sub-agent isolation |
| Implementation Review | `/kk:implementation-review:implementation-review [feature]` | Verify code matches design/implementation docs |
| Implementation Review (isolated) | `/kk:implementation-review:isolated [feature]` | Spec conformance review with independent sub-agent |
| Design Review | `/kk:design-review [feature] [scope]` | Review design docs for quality and technical soundness |
| Design Review (isolated) | `/kk:design-review:isolated [feature] [scope]` | Design review with independent sub-agents |
| Migrate from Task Master | `/kk:migrate-from-taskmaster:migrate` | One-time migration from Task Master MCP |
| Sync Workflow | `/kk:sync-workflow:sync-workflow [version]` | Update template-sync from upstream |

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| Bash validation | `PreToolUse` on `Bash` | Blocks commands touching `.env`, `.git/`, `node_modules`, `build/`, `dist/`, `venv/`, and other sensitive paths |

## Upgrading from Template-Managed Skills

If you're upgrading from a version before the plugin system (< v0.5.0):

- Skills remain unprefixed: `/analysis-process` (annotated with `(kk)` in the menu)
- Commands are now namespaced: `/project:cove` → `/kk:cove:cove`
- The template-sync workflow handles migration automatically on next sync
- After merging the sync PR, run `/plugin install kk@claude-toolbox`
