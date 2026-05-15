# Claude Code provider gotchas

Applies when authoring skills for the Claude Code harness. Consult before writing or modifying skill files that use Claude Code-specific features.

## `${CLAUDE_PLUGIN_ROOT}` substitution boundary

The harness substitutes `${CLAUDE_PLUGIN_ROOT}` (with braces) at **plugin-load time** for files it loads directly:

- SKILL.md
- `agents/*.md`
- `hooks/*.json` command strings
- MCP config files

The brace form in these files reaches the agent as a resolved absolute path and can be used directly in tool arguments.

**The `Read` tool does NOT substitute.** Any `${CLAUDE_PLUGIN_ROOT}` inside a file an agent reads at runtime (everything under `skills/_shared/`, per-skill referenced content, everything under `profiles/`) reaches the agent as a literal token. Forwarding that literal into another tool call fails: `Bash` shell-expands against the usually-unset env var to empty; `Read` fails ENOENT.

**Practical rules:**

- Use `${CLAUDE_PLUGIN_ROOT}/…` freely in plugin-load files (SKILL.md, agent files, hook/MCP configs).
- In runtime-read files, prefer explicit content over tokens: hard-code names/paths the procedure needs. If the file must describe a plugin-root path, instruct the agent to construct it using the resolved prefix it already knows from the SKILL.md that invoked it.
- Brace form required: `${CLAUDE_PLUGIN_ROOT}` works, bare `$CLAUDE_PLUGIN_ROOT` does NOT get substituted.
- To reference the variable name literally in prose, use bare `$CLAUDE_PLUGIN_ROOT` or the HTML entity form `&#36;{CLAUDE_PLUGIN_ROOT}` (useful when the brace shape must appear in rendered output).

## Glob cwd-scoping

`Glob` is cwd-scoped and returns 0 matches for outside-cwd absolute paths. Never use `Glob` against `${CLAUDE_PLUGIN_ROOT}/…` patterns regardless of substitution. Use `Read` with the resolved path instead.

## Hook script contract

Hook scripts in `hooks/*.json` follow a strict contract:

- **Input:** read JSON from stdin (the `tool_input` object).
- **Output:** return structured JSON for deny decisions. To block a tool call, emit: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "<reason>"}}`.
- **Exit code:** always exit 0. Non-zero exits are treated as hook failures, not tool denials.

## Command variant naming

Commands live under `commands/<name>/`. For skills with standard + isolated modes:

- `default.md` — standard variant, invoked as `/kk:<name>:default`
- `isolated.md` — isolated sub-agent variant, invoked as `/kk:<name>:isolated`

Symmetric naming avoids stuttering (`/kk:cove:cove` is bad, `/kk:chain-of-verification:default` is good).
