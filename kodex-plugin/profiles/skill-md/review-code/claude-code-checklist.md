# Claude Code review checklist

Review checks specific to skills targeting the Claude Code harness.

## `${CLAUDE_PLUGIN_ROOT}` usage

- [ ] Is `${CLAUDE_PLUGIN_ROOT}` (brace form) used only in plugin-load files (SKILL.md, `agents/*.md`, `hooks/*.json`, MCP configs)?
- [ ] Do runtime-read files (under `skills/_shared/`, `profiles/`, or referenced content) avoid forwarding the literal `${CLAUDE_PLUGIN_ROOT}` token into tool calls?
- [ ] Where runtime-read files need a plugin-root path, do they instruct the agent to construct it from the resolved prefix known from SKILL.md?
- [ ] Is bare `$CLAUDE_PLUGIN_ROOT` (no braces) used only for literal prose references, never as a runtime path?
- [ ] If the brace shape must appear in rendered output, is the HTML entity `&#36;{CLAUDE_PLUGIN_ROOT}` used?

## Hook well-formedness

- [ ] Do hook scripts read JSON from stdin (`tool_input` object)?
- [ ] Do deny decisions use the nested structure: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}`?
- [ ] Do hook scripts always exit 0? (Non-zero = hook failure, not tool denial.)

## Command variant naming

- [ ] For skills with standard + isolated modes: are commands named `default.md` and `isolated.md`?
- [ ] Is stuttering avoided? (`/kk:chain-of-verification:default` not `/kk:cove:cove`)
