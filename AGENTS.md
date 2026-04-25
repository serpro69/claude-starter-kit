# AGENTS.md

Provider: Codex (OpenAI). This file is the Codex equivalent of CLAUDE.md.

## Repository Overview

This is a starter template repository providing a complete development environment with pre-configured MCP servers and tools. It is a **configuration-only repository** with no application code.

## Architecture

Four integrated components:

1. **Codex config** (`.codex/`): Project settings (`config.toml`), hooks, rules, scripts, and sub-agent definitions
2. **kk plugin** (`kodex-plugin/`): Skills generated from `klaude-plugin/` — the canonical source of truth
3. **Claude Code** (`.claude/`): Claude-side settings, statusline, sync infrastructure
4. **Profiles and shared instructions** (`klaude-plugin/profiles/`, `klaude-plugin/skills/_shared/`): Referenced at runtime via absolute paths

### Generation Workflow

`klaude-plugin/` is canonical. After editing skills there, run `make generate-kodex` to regenerate `kodex-plugin/` and `.codex/agents/`. Hand-authored codex files: `config.toml`, `hooks.json`, `rules/default.rules`, `scripts/`, `AGENTS.extra.md`.

### Hook Enforcement Gap

Codex's PreToolUse hooks only intercept `shell` commands. `read_file`, `write_file`, `apply_patch`, `web_search`, and MCP calls cannot be hooked — advisory-only coverage via SessionStart context injection. See `docs/adr/0005-codex-hook-enforcement-gap.md`.

## Tool-Name Mapping

Skills reference Claude Code tool names. Apply this mapping:

| Skill references | Use instead |
|------------------|-------------|
| `Read` | `read_file` |
| `Write` | `write_file` |
| `Edit` | `apply_patch` |
| `Bash` | `shell` |
| `Grep` | `shell` with `grep` |
| `Glob` | `shell` with `find` |
| `WebSearch` | `web_search` |
| `WebFetch` | `capy_fetch_and_index` via MCP |
| `Agent` / `Task` | Spawn subagents via natural language |
| `Skill` | Use `$mention` or `/skills` |

## Sub-agents

Five custom agents are available in `.codex/agents/`:

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Reviews diffs for SOLID violations, security risks, code quality |
| `spec-reviewer` | Compares implementation against design docs |
| `design-reviewer` | Evaluates design docs for completeness and soundness |
| `eval-grader` | Grades skill eval assertions against reviewer output |
| `profile-resolver` | Resolves active profiles and checklist-load decisions for a diff |

All agents run in read-only sandbox mode.

## Testing

Tests are in `test/`. Run with:

```bash
for test in test/test-*.sh; do $test; done
```

Key suites: `test-plugin-structure.sh` (klaude-plugin + kodex-plugin), `test-codex-structure.sh` (codex config, hooks, agents, rules).

## Behavioral Instructions

### Independent Thinking

When discussing decisions, designs, trade-offs, or approaches:

- **Be direct.** If the user is wrong, say "no, that's wrong" and explain why. Don't soften with "have you considered" when you mean "that won't work."
- **Push back with reasoning.** Challenge assumptions, play devil's advocate, name blind spots. Give genuine opinions — don't default to agreement.
- **Call out patterns.** If the user is spiraling, overthinking, making excuses, or avoiding discomfort, name it directly and explain the cost.
- **Authenticity over contrarianism.** When you genuinely agree, just agree. The goal is honest signal, not reflexive disagreement.
- **Strategic mirror.** Look for what's being underestimated, where reasoning is weak, and where the user is playing small. Give precise, prioritized feedback.

When executing clear, specific tasks (write this function, fix this bug, run these tests): just execute. Save the pushback for decisions that warrant it.

### Exploration Phase

Always explore on your own to gain complete understanding. Only delegate to exploration agents if the user explicitly requests it.

### Assumptions & Fail-Loud

When writing or modifying code:

- **State assumptions explicitly.** If uncertain, ask. Don't guess silently.
- **Surface ambiguity.** If the request has multiple reasonable interpretations, present them and let the user choose — don't pick one silently.
- **Fail loud.** Flag errors explicitly. No softening, no silent corrections, no swallowed exceptions, no assertions you quietly relax to make a test pass.
- **Pre-existing dead code is not yours to delete.** If you notice unrelated dead code, mention it — don't remove it. Only remove orphans (imports, variables, helpers) that *your* changes made unused.

### Document Deferred Work Explicitly

Assume the codebase is touched by many contributors — humans and AI — who do not share your current session context. A "we'll fix it later" note that lives only in chat is lost the moment the session ends.

When you defer a fix, a partial implementation, or a known-but-unaddressed issue:

- **Write it down where the next contributor will find it.** Inline code comments at the affected site (`TODO:` / `FIXME:` with enough context to act), markdown notes in the relevant design/implementation doc under `docs/wip/<feature>/`, or an entry in `tasks.md` — not just a chat reply.
- **Be explicit, not handwavy.** "Skipped X because Y; to fix, do Z" beats "postponed — trivial." What seems trivial in-context is opaque without it. State the *what*, the *why it was deferred*, and the *concrete next step*.
- **Applies to review outputs too.** When a review skill identifies an issue that won't be fixed in the current task, the reviewer or the consumer must record it durably (task entry, doc note, inline TODO) — not leave it as a conversational aside.
- **Explicit partial > silent postpone.** A documented partial solution is honest and actionable. A silently deferred fix is invisible technical debt that the next session cannot see.

This is a corollary of Fail Loud: the codebase itself must fail loud about its own gaps.

## Task Tracking

Task tracking uses simple markdown files co-located with feature design docs:

- **Location:** `/docs/wip/[feature]/tasks.md` alongside `design.md` and `implementation.md`
- **Created by:** `design` skill (Step 6 of the idea workflow)
- **Consumed by:** `implement` skill (reads tasks, updates status/checkboxes during execution)
- **Format:** H2 headings per task, checkbox subtasks, bold key-value status/dependencies

The full workflow: `design` (design + create tasks) → `review-design` → `implement` (execute tasks + `review-code`/`test`/`document` at the end of each task) → `test` (verify) → `document` (document)

# capy — MANDATORY routing rules

You have capy MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any shell command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `capy_fetch_and_index(url, source)` to fetch and index web pages
- `capy_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any shell command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with shell.
Instead use:
- `capy_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

## REDIRECTED tools — use sandbox equivalents

### Shell (>20 lines output)
Shell is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `capy_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `capy_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### read_file vs capy_execute_file

**Default to `read_file`.** It's cheap for normal-sized files, shows you actual content, and is required if an `apply_patch` follows.

**Reach for `capy_execute_file` only when ALL of these hold:**
1. The file is genuinely large (10k+ lines), AND
2. You want a *derived answer* (count, stats, extracted pattern) — not the content itself, AND
3. You can write the exact grep/awk/script upfront.

## Tool selection hierarchy

1. **GATHER**: `capy_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results.
2. **FOLLOW-UP**: `capy_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `capy_execute(language, code)` | `capy_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `capy_fetch_and_index(url, source)` then `capy_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `capy_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `capy_search(source: "label")` later.

## capy commands

| Command | Action |
|---------|--------|
| `capy stats` | Call the `capy_stats` MCP tool and display the full output verbatim |
| `capy doctor` | Call the `capy_doctor` MCP tool and display as checklist |
