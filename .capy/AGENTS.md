# capy — MANDATORY routing rules

You have capy MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `capy_fetch_and_index(url, source)` to fetch and index web pages
- `capy_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `capy_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `capy_fetch_and_index` instead.
Instead use:
- `capy_fetch_and_index(url, source)` then `capy_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `capy_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `capy_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read vs capy_execute_file

**Default to `Read`.** It's cheap for normal-sized files, shows you actual content (not just patterns you knew to grep for), and is required if an Edit follows. Use `offset`/`limit` to scope large files.

**Reach for `capy_execute_file` only when ALL of these hold:**
1. The file is genuinely large (10k+ lines, or measured >100 KB), AND
2. You want a *derived answer* (count, stats, extracted pattern, structural summary) — not the content itself, AND
3. You can write the exact grep/awk/script upfront. If you'd struggle to, you don't know enough yet — just `Read`.

**Anti-patterns — do NOT do this:**
- `capy_execute_file` to grep section headings, then `Read` the file anyway to Edit it. The Read makes the capy call pure overhead.
- `capy_execute_file` on a code file to "explore structure." Use Serena's `get_symbols_overview` / `find_symbol` — purpose-built and cheaper.
- `capy_execute_file` on a small/medium file (<2k lines) "to save context." The savings don't exist; you're adding latency.

**Rule of thumb:** capy saves context only when content would otherwise enter context. If you're going to `Read` it anyway (for Edit, for line citations, for follow-ups), capy adds nothing.

### Grep (large results)
Grep results can flood context. Use `capy_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `capy_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `capy_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `capy_execute(language, code)` | `capy_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `capy_fetch_and_index(url, source)` then `capy_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `capy_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about capy.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `capy_search(source: "label")` later.

## capy commands

| Command | Action |
|---------|--------|
| `capy stats` | Call the `capy_stats` MCP tool and display the full output verbatim |
| `capy doctor` | Call the `capy_doctor` MCP tool and display as checklist |
