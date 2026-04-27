# kk — Codex Plugin

Development workflow skills generated from [klaude-plugin/](../klaude-plugin/) (the Claude Code source of truth).

## What's Included

The Codex plugin packages **skills and profile content**:

- **10 workflow skills** — the same pipeline as the Claude Code plugin (`design` → `implement` → `review-code` → `test` → `document` and utilities)
- **Language-specific profiles** — review checklists, implementation gotchas, design prompts, test validators, and doc rubrics for Go, Java, JS/TS, Kotlin, Kubernetes, and Python

The plugin does **not** include hooks, sub-agents, Starlark rules, or project configuration (`.codex/config.toml`, `AGENTS.md`, etc.). For the full Codex experience, use the [template setup](../README.md#template-setup) or [adopt into an existing repo](../README.md#adopting-into-existing-repositories).

## Installation

```bash
codex plugin marketplace add serpro69/claude-toolbox
```

Then open `/plugins` in the Codex TUI, select the **Claude Toolbox** marketplace, and install `kk`.

> **Note:** Sparse checkout is not supported. The full repository must be cloned.

## Available Skills

| Skill | Description |
|-------|-------------|
| `chain-of-verification` | Apply CoVe prompting for self-verified accuracy |
| `dependency-handling` | Look up dependencies before writing calls |
| `design` | Turn ideas into design docs and implementation plans |
| `document` | Document changes after implementation |
| `implement` | Execute tasks from plans or standalone changes |
| `merge-docs` | Merge competing design docs into one |
| `review-code` | Code review with SOLID methodology |
| `review-design` | Review design docs for completeness and soundness |
| `review-spec` | Compare implementation against design docs |
| `test` | Write and run tests |

## Updating

```bash
codex plugin marketplace upgrade claude-toolbox
```

## How It Works

Skills are authored once in `klaude-plugin/skills/` and generated into this directory by `cmd/generate-kodex/`. The generation tool resolves `${CLAUDE_PLUGIN_ROOT}` references and copies auxiliary files (including profiles). Run `make generate-kodex` after editing source skills to regenerate.

## Troubleshooting

- **Skills not appearing:** Ensure the plugin is installed via the marketplace browser, not manually copied.
- **Stale output:** Run `make generate-kodex` and check `git diff kodex-plugin/` to see if regeneration is needed.
