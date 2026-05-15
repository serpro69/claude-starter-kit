# Agent Skills — review checklists

Consumed by the `review-code` skill. When the `skill-md` profile is active, every checklist in **Always load** is applied to the diff. Conditional entries are loaded when their trigger matches.

## Always load

- [skill-quality-checklist.md](skill-quality-checklist.md) — Universal skill quality checks: workflow ordering compliance, progressive disclosure, description quality, resource separation, instruction clarity, eval coverage.

## Conditional

- [claude-code-checklist.md](claude-code-checklist.md) — Claude Code-specific review checks: `${CLAUDE_PLUGIN_ROOT}` usage correctness, hook script well-formedness, command variant naming. **Load if:** diff contains `${CLAUDE_PLUGIN_ROOT}` or `CLAUDE_PLUGIN_ROOT`, or the plugin root contains `hooks/`, `commands/`, or `agents/` directories alongside `skills/`.
- [kk-plugin-checklist.md](kk-plugin-checklist.md) — kk-plugin-specific review checks: shared symlink correctness, bidirectional index invariant, naming conventions, test registration, Codex generation. **Load if:** files are within a `klaude-plugin/` directory, or diff touches files under `_shared/`.
