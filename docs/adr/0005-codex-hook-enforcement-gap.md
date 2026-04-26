# ADR 0005: Codex Hook Enforcement Gap

## Status

Accepted — partially superseded (see Update 2026-04-26)

## Update 2026-04-26

Codex PreToolUse now intercepts **Bash, `apply_patch`, and MCP tool calls**
(https://developers.openai.com/codex/hooks#pretooluse). Matchers for
`apply_patch` can use aliases `Edit` or `Write`. MCP tools are matched by
their `tool_name` (e.g., `mcp__fs__read`). `WebSearch` and `read_file` are
still NOT interceptable.

The original gap is narrower than described below. TODO: add `apply_patch`
and relevant MCP matchers to `.codex/hooks.json` with corresponding hook
scripts.

## Context

Claude Code enforces capy routing and file-path security policies via two
mechanisms: PreToolUse hooks (which intercept tool calls before execution)
and context injection (which provides advisory guidance). Both mechanisms
cover all tool types — Bash, Read, Write, Edit, WebFetch, etc.

Codex's hook system (behind `[features] codex_hooks = true`) supports
PreToolUse hooks with coverage for Bash, `apply_patch`, and MCP tool calls.
Remaining gaps:

- `read_file` and `web_search` **cannot be intercepted** by hooks.
- File-path denylist enforcement on `read_file` is not possible via hooks.
- The docs note this is "still a guardrail rather than a complete
  enforcement boundary because Codex can often perform equivalent work
  through another supported tool path."

## Decision

Accept the enforcement gap as a known limitation. Mitigate with a
two-layer approach:

1. **Hook enforcement (where available):** PreToolUse on Bash covers
   shell commands — curl/wget blocking, inline-HTTP patterns, and
   file-path denylist on shell commands (`cat .env`, `grep -r .terraform/`,
   etc.). This is the hard boundary.

2. **Advisory enforcement (everything else):** The SessionStart hook
   injects capy routing rules and file-path denylist guidance into the
   session context as `additionalContext`. The model is instructed to
   follow these rules. This is a soft boundary — the model may not
   always comply, but in practice LLM compliance with system-level
   instructions is high.

We do NOT:
- Build workarounds (e.g., wrapping `read_file` in a custom MCP tool
  that enforces the denylist). This adds complexity for a gap that codex
  itself will close.
- Block codex support on this gap. The advisory layer provides sufficient
  protection for the use cases we care about.
- Pretend the gap doesn't exist. It's documented in design.md §8.3,
  in the codex plugin README, and in this ADR.

## Consequences

- **Positive:** Codex support ships now rather than waiting for full hook
  coverage. Users get immediate value from skills, sub-agents, and capy
  MCP tools.
- **Positive:** The two-layer design is forward-compatible. When codex
  expands hook coverage, adding enforcement hooks for new tool types is
  additive — no architectural changes needed.
- **Negative:** A determined model (or a prompt injection) can bypass the
  advisory layer for non-Bash tools. This is the same risk profile as any
  system-prompt-based instruction.
- **Negative:** Parity gap with Claude's enforcement. Claude users have
  hard enforcement on all tools; codex users have hard enforcement on
  Bash only. This should be documented prominently so users understand
  the difference.
- **Action item (done for apply_patch/MCP):** Codex now covers `apply_patch`
  and MCP tools. Add hook entries for these to `.codex/hooks.json` with
  scripts that enforce file-path denylist on patches and capy routing on
  MCP calls.
- **Action item (pending):** When codex expands PreToolUse to cover
  `read_file` and `web_search`, add corresponding hook entries.
