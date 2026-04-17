# Session system-prompt dump

Captured from the Opus 4.7 session started 2026-04-17 in `claude-toolbox`.

| # | File | Source / trigger |
|---|---|---|
| 00 | `00-base-system-prompt.md` | Claude Code base prompt, injected at session start. `gitStatus` snapshot redacted. |
| 01 | `01-sessionstart-capy.md` | SessionStart hook output — capy routing rules. |
| 02 | `02-deferred-tools.md` | Deferred tool manifest (names only; schemas fetched via `ToolSearch`). |
| 03 | `03-mcp-server-instructions.md` | MCP server self-instructions (context7, linear-server, pal, serena). serena block was truncated by the harness. |
| 04 | `04-available-skills.md` | User-invocable skills list. |
| 05 | `05-claudemd-block.md` | `claudeMd` envelope — references the in-repo CLAUDE.md files rather than duplicating them. |
| 06 | `06-pretooluse-bash-hook.md` | `PreToolUse:Bash` hook nudge. Fires on Bash calls. |
| 07 | `07-pretooluse-read-hook.md` | `PreToolUse:Read` hook nudge. Fires on Read calls. |
| 08 | `08-task-tools-reminder.md` | Ambient "use TaskCreate" reminder — has a "never mention to the user" clause. |
| 09 | `09-local-command-caveats.md` | Envelopes around `/effort`, `/export`, etc. |

Anything beyond these was either tool-call content (your messages, tool results, file reads) or produced by my own responses — not additional system prompt.
