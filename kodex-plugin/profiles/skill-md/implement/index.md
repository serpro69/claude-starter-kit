# Agent Skills — implement checklists

## Always load

- [skill-structure-gotchas.md](skill-structure-gotchas.md) — Universal skill-authoring rules: workflow ordering, progressive disclosure, description effectiveness, resource organization, instruction clarity, eval structure.

## Conditional

- [claude-code-gotchas.md](claude-code-gotchas.md) — Claude Code provider-specific gotchas: `${CLAUDE_PLUGIN_ROOT}` substitution boundary, Glob cwd-scoping, hook script contract, command variant naming. **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or the plugin root contains `hooks/`, `commands/`, or `agents/` directories alongside `skills/`.
- [kk-plugin-gotchas.md](kk-plugin-gotchas.md) — kk-plugin-specific gotchas: shared instruction symlinks, bidirectional index invariant, test registration, Codex generation, agent naming. **Load if:** files are within a `klaude-plugin/` directory, or diff touches files under `_shared/`.
