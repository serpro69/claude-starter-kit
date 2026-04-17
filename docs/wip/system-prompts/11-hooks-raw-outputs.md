# Raw hook outputs

Captured by invoking `capy hook <event>` directly with representative JSON payloads on stdin. This is the authoritative surface — what Claude actually sees when each hook fires.

Hook config (from `.claude/settings.local.json`): all six events dispatch to the same wrapper, `bash $CLAUDE_PROJECT_DIR/.claude/scripts/capy.sh hook <type>`, which shells out to `capy hook <type>`.

Hook-output JSON is interpreted by Claude Code:
- `hookSpecificOutput.additionalContext` → injected as `<system-reminder>` text into my context for that turn.
- `hookSpecificOutput.permissionDecision = "deny"` + reason → the tool call is denied; I see only the reason.
- `hookSpecificOutput.permissionDecision = "allow"` + `updatedInput` → the tool input is silently rewritten before execution.

---

## SessionStart

**Trigger:** on session start.
**Output:** 2.3 KB context window protection block (identical to what landed in `01-sessionstart-capy.md`).

```json
{
  "hookSpecificOutput": {
    "additionalContext": "<context_window_protection>\n  <priority_instructions>\n    Raw tool output floods your context window. You MUST use capy\n    MCP tools to keep raw data in the sandbox.\n  </priority_instructions>\n\n  <tool_selection_hierarchy>\n    1. GATHER: capy_batch_execute(commands, queries)\n       - Primary tool for research. Runs all commands, auto-indexes, and searches.\n       - ONE call replaces many individual steps.\n    2. FOLLOW-UP: capy_search(queries: [\"q1\", \"q2\", ...])\n       - Use for all follow-up questions. ONE call, many queries.\n    3. PROCESSING: capy_execute(language, code) | capy_execute_file(path, language, code)\n       - Use for API calls, log analysis, and data processing.\n  </tool_selection_hierarchy>\n\n  <forbidden_actions>\n    - DO NOT use Bash for commands producing >20 lines of output.\n    - DO NOT use Read for analysis (use execute_file). Read IS correct for files you intend to Edit.\n    - DO NOT use WebFetch (use capy_fetch_and_index instead).\n    - Bash is ONLY for git/mkdir/rm/mv/navigation.\n  </forbidden_actions>\n\n  <output_constraints>...[truncated — see 01-sessionstart-capy.md for the full text]",
    "hookEventName": "SessionStart"
  }
}
```

---

## UserPromptSubmit

**Trigger:** every user prompt.
**Output:** empty. The hook runs silently — probably used for logging/indexing, not context injection.

```
(empty)
```

---

## PreToolUse — matcher `Bash|WebFetch|Read|Grep|Agent|Task|mcp__*capy*`

This hook has behaviour branches keyed on `tool_name`. Six observed variants:

### PreToolUse — Bash (generic)

**Input:** `{"tool_name":"Bash","tool_input":{"command":"ls","description":"list"}}`

```json
{
  "hookSpecificOutput": {
    "additionalContext": "<context_guidance>\n  <tip>\n    This Bash command may produce large output. To stay efficient:\n    - Use capy_batch_execute(commands, queries) for multiple commands\n    - Use capy_execute(language: \"shell\", code: \"...\") to run in sandbox\n    - Only your final printed summary will enter the context.\n    - Bash is best for: git, mkdir, rm, mv, navigation, and short-output commands only.\n  </tip>\n</context_guidance>",
    "hookEventName": "PreToolUse"
  }
}
```

### PreToolUse — Bash containing curl/wget

**Input:** `{"tool_name":"Bash","tool_input":{"command":"wget https://example.com","description":"fetch"}}`

**Mutation path** — `permissionDecision: "allow"` plus `updatedInput` that replaces the command with a harmless `echo` that prints a warning. I never see the original command execute; I see only the echo output.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Routed to capy sandbox",
    "updatedInput": {
      "command": "echo \"capy: curl/wget blocked (stdout flood risk). Use capy_fetch_and_index(url, source) to fetch URLs, or capy_execute(language, code) to run HTTP calls in sandbox. File downloads with -o/--output are allowed.\""
    }
  }
}
```

**Inline-HTTP variant** — when the Bash command contains `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(`, capy emits the same allow/echo pattern with a different message: `capy: Inline HTTP blocked. Use capy_execute(language, code) ...`. (Observed directly this session — my own Bash command that *contained* the pattern in a test fixture string tripped it.)

### PreToolUse — Read

**Input:** `{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo.txt"}}`

```json
{
  "hookSpecificOutput": {
    "additionalContext": "<context_guidance>\n  <tip>\n    Read is the right default. Use offset/limit to scope large files.\n    Only reach for capy_execute_file when the file is genuinely large (10k+ lines)\n    AND you want a derived answer (count, stats, extracted pattern), not the content itself.\n    If an Edit will follow, just Read — capy_execute_file beforehand is pure overhead.\n  </tip>\n</context_guidance>",
    "hookEventName": "PreToolUse"
  }
}
```

### PreToolUse — Grep

**Input:** `{"tool_name":"Grep","tool_input":{"pattern":"foo"}}`

```json
{
  "hookSpecificOutput": {
    "additionalContext": "<context_guidance>\n  <tip>\n    This operation may flood your context window. To stay efficient:\n    - Use capy_execute(language: \"shell\", code: \"...\") to run searches in the sandbox.\n    - Only your final printed summary will enter the context.\n  </tip>\n</context_guidance>",
    "hookEventName": "PreToolUse"
  }
}
```

### PreToolUse — WebFetch

**Input:** `{"tool_name":"WebFetch","tool_input":{"url":"https://example.com","prompt":"x"}}`

**Denial path** — the tool is blocked entirely; I see only the reason string.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "capy: WebFetch blocked. Use capy_fetch_and_index(url: \"https://example.com\") to fetch this URL in sandbox. Then use capy_search(queries: [...]) to query results."
  }
}
```

### PreToolUse — Agent

**Input:** `{"tool_name":"Agent","tool_input":{"description":"test","prompt":"hi","subagent_type":"general-purpose"}}`

**Mutation path** — `permissionDecision: "allow"` plus `updatedInput.prompt` that appends the full `<context_window_protection>` block (same as SessionStart) to the end of the sub-agent prompt. This is how capy rules propagate to sub-agents.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Routed to capy sandbox",
    "updatedInput": {
      "description": "test",
      "prompt": "hi<context_window_protection>\n  ...[full SessionStart block appended verbatim]...\n</context_window_protection>",
      "subagent_type": "general-purpose"
    }
  }
}
```

### PreToolUse — Task / mcp__capy__*

**Input:** `{"tool_name":"mcp__capy__capy_search","tool_input":{"queries":["test"]}}`

**Output:** empty. The matcher includes these names but the capy binary emits no context for them — they're valid, silently allowed.

```
(empty)
```

---

## PostToolUse — matcher all

**Trigger:** after every tool call (all tools — matcher is `""`).
**Output:** empty across every combination I tried (Bash short, Bash large, Read). Side-effect only — likely auto-indexes output into the knowledge base without feeding anything back into my turn.

```
(empty)
```

---

## PreCompact

**Trigger:** before conversation compaction.
**Output:** empty.

```
(empty)
```

---

## SessionEnd

**Trigger:** when the session closes.
**Output:** empty. Claude doesn't have another turn after SessionEnd fires, so there's nothing to inject into anyway — the hook is for side effects (flush WAL, final indexing).

```
(empty)
```

---

## Summary — what each hook actually does

| Event | Injects context? | Mutates tool input? | Denies? | Notes |
|---|---|---|---|---|
| SessionStart | Yes (big) | — | — | The capy routing rules. |
| UserPromptSubmit | No | — | — | Silent. |
| PreToolUse (Bash) | Yes (tip) | Sometimes (curl/wget/inline HTTP → echo) | — | Generic tip for every Bash; mutation only on HTTP patterns. |
| PreToolUse (Read) | Yes (tip) | — | — | |
| PreToolUse (Grep) | Yes (tip) | — | — | |
| PreToolUse (WebFetch) | — | — | **Yes** | Full block. |
| PreToolUse (Agent) | — | **Yes** | — | Appends capy rules to sub-agent prompt. |
| PreToolUse (Task / mcp__capy__*) | No | No | No | Silently allowed. |
| PostToolUse | No | — | — | Side-effect only (probably auto-index). |
| PreCompact | No | — | — | Silent. |
| SessionEnd | No | — | — | Silent. |

---

## Reproduction

```
printf '{"tool_name":"<Name>","tool_input":{...}}' | capy hook pretooluse
printf '{"tool_name":"<Name>","tool_input":{...},"tool_response":{...}}' | capy hook posttooluse
printf '{}' | capy hook sessionstart
printf '{}' | capy hook sessionend
printf '{}' | capy hook precompact
printf '{"prompt":"..."}' | capy hook userpromptsubmit
```

The `capy` binary is what Claude Code actually invokes per hook event — everything above is ground truth.
