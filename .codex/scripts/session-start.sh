#!/usr/bin/env bash
# SessionStart hook for Codex — injects provider context into the session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

read -r -d '' CONTEXT <<'CONTEXT_EOF' || true
Provider: Codex (OpenAI).

## Tool-Name Mapping

Skills reference Claude Code tool names. Apply this mapping:
- Read → read_file
- Write → write_file
- Edit → apply_patch
- Bash → shell
- Grep → use shell with grep
- Glob → use shell with find
- WebSearch → web_search
- WebFetch → no equivalent; use capy_fetch_and_index via MCP
- Agent/Task → spawn subagents via natural language
- Skill → use $mention or /skills
CONTEXT_EOF

# copy-paste verbatim from ${REPO_ROOT}/.claude/CLAUDE.extra.md
read -r -d '' AGENTS_EXTRA_MD <<'EOF' || true
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
<!-- Why: Claude tends to first spawn exploration agents,
     and then re-reads all the files on its own...
     resulting in double token consumption -->

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
- **Applies to review outputs too.** When `review-code`, `review-design`, or `review-spec` identifies an issue that won't be fixed in the current task, the reviewer or the consumer must record it durably (task entry, doc note, inline TODO) — not leave it as a conversational aside.
- **Explicit partial > silent postpone.** A documented partial solution is honest and actionable. A silently deferred fix is invisible technical debt that the next session cannot see.

This is a corollary of Fail Loud: the codebase itself must fail loud about its own gaps.

## Serena Best Practices

Serena provides semantic code analysis — use it efficiently:

### Intelligent Code Reading Strategy

1. **Start with overview**: Use `get_symbols_overview` to see top-level structure
2. **Target specific symbols**: Use `find_symbol` with `include_body=true` only for symbols you need to understand or edit
3. **Pattern search**: Use `search_for_pattern` for flexible regex-based discovery
4. **Reference tracking**: Use `find_referencing_symbols` to understand usage
5. **Read full files only as a last resort** when symbolic tools cannot provide what you need

### Symbol Navigation

Symbols are identified by `name_path` and `relative_path`:

- Top-level: `ClassName` or `function_name`
- Methods: `ClassName/method_name`
- Nested: `OuterClass/InnerClass/method`
- Python constructors: `ClassName/__init__`

### Efficiency Principles

- Read symbol bodies only when you need to understand or edit them
- Use `depth` parameter to get method lists without bodies: `find_symbol("Foo", depth=1, include_body=False)`
- Track which symbols you've read and reuse that context
- Use symbolic tools before reading full files

## Task Tracking

Task tracking uses simple markdown files co-located with feature design docs:

- **Location:** `/docs/wip/[feature]/tasks.md` alongside `design.md` and `implementation.md`
- **Created by:** `design` skill (Step 6 of the idea workflow)
- **Consumed by:** `implement` skill (reads tasks, updates status/checkboxes during execution)
- **Format:** H2 headings per task, checkbox subtasks, bold key-value status/dependencies

The full workflow: `design` (design + create tasks) → `review-design` → `implement` (execute tasks + `review-code`/`test`/`document` at the end of each task) → `test` (verify) → `document` (document)
EOF

AGENTS_CAPY_MD=$(cat "${REPO_ROOT}/.claude/capy/CLAUDE.md")

CONTEXT="${CONTEXT}

${AGENTS_EXTRA_MD}

${AGENTS_CAPY_MD}"

# Emit the JSON structure codex expects
printf '%s\n' "$(jq -n \
  --arg ctx "$CONTEXT" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }')"
