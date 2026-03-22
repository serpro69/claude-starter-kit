# kk — Claude Code Plugin

Development workflow skills, commands, and hooks from [claude-toolbox](https://github.com/serpro69/claude-toolbox).

## Installation

The plugin is installed automatically when using the claude-toolbox template. To install manually:

```
/plugin install kk@claude-toolbox
```

## Skills

Skills are invoked as `/skill-name` (no namespace prefix — annotated with `(kk)` in the menu):

| Skill                      | When to use                                                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **analysis-process**       | Pre-implementation. Turns ideas/specs into design docs, implementation plans, and task lists.                                                                            |
| **implementation-process** | Execute an implementation plan with batched steps and architect review checkpoints.                                                                                      |
| **testing-process**        | After writing code. Guidelines for test coverage — table-driven tests, mocking, integration, benchmarks.                                                                 |
| **documentation-process**  | Post-implementation. Updates ARCHITECTURE.md, TESTING.md, and records ADRs.                                                                                              |
| **development-guidelines** | During implementation. Enforces best practices like using latest deps and context7 for docs.                                                                             |
| **solid-code-review**      | Code review with a senior-engineer lens. Checks SOLID principles, security, code quality. Includes language-specific checklists for Go, Java, JS/TS, Kotlin, and Python. |
| **implementation-review**  | Verify implemented code matches design/implementation docs. Detects spec deviations, missing implementations, and outdated docs.                                         |
| **merge-docs**             | Semantically compare and merge two competing design docs for the same feature into one unified document.                                                                 |
| **cove**                   | Chain-of-Verification prompting. Two modes: standard (prompt-based) and isolated (sub-agent). For high-stakes accuracy and fact-checking.                                |

### Development Workflow

The skills are designed to work together in a pipeline:

```
analysis-process → implementation-process → testing-process → documentation-process
```

1. **analysis-process** — design docs + implementation plan + task list
2. **implementation-process** — execute tasks with review checkpoints
3. **testing-process** — verify and validate
4. **documentation-process** — update docs

Use **solid-code-review** and **implementation-review** at any point for quality gates.

## Commands

| Command | Invocation | Description |
|---------|-----------|-------------|
| CoVe (standard) | `/kk:cove:cove [question]` | Chain-of-Verification with prompt-based isolation |
| CoVe (isolated) | `/kk:cove:cove-isolated [--explore] [--haiku] [question]` | CoVe with true sub-agent isolation |
| Implementation Review | `/kk:implementation-review:implementation-review [feature]` | Verify code matches design/implementation docs |
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
