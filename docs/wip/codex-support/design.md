# Design: Codex Support

> Status: draft
> Created: 2026-04-24

## 1. Overview

Add first-class OpenAI Codex support to `claude-toolbox` with minimal repo
restructure. Today the repo is Claude-only; after this feature, Codex users
get the same skills, equivalent sub-agents, capy context-protection (within
codex's current hook limitations), MCP wiring, and template configs.

The approach avoids a full multi-provider rewrite (provider-neutral SKILL.md
files with `reference/<provider>.md`). Instead, skills are shared as-is and
a tool-name mapping table injected via Codex's `SessionStart` hook tells the
model how to translate Claude tool names it encounters in skill files.

## 2. Goals

1. A Codex user registers the marketplace via
   `codex plugin marketplace add serpro69/claude-toolbox`, then installs the
   `kk` plugin from the `/plugins` browser — all workflow skills are
   immediately available.
2. Skills are authored once and shared between Claude and Codex via a single
   canonical `skills/` directory at repo root.
3. Codex-specific artifacts (agents, hooks, config, rules) live under `.codex/`
   and `plugins/codex/` — isolated from Claude's side.
4. Template-sync distributes `.codex/` configs to downstream repos alongside
   `.claude/`.
5. Capy enforcement works via hooks where codex supports it (Bash interception),
   with advisory-only coverage documented for gaps.

## 3. Non-Goals

- **Not** rewriting SKILL.md files to be provider-neutral. Tool-name mapping
  and `${CLAUDE_PLUGIN_ROOT}` path resolution via SessionStart hook handle
  the provider-specific references (see §6.2).
- **Not** supporting codex's `--sparse` checkout for plugin installation. Our
  layout requires the full repo — the marketplace entry points at
  `./plugins/codex`, which is outside any sparse path.
- **Not** replacing Serena. Codex users can configure it as an MCP server if
  they want; we don't ship it as part of the codex plugin.
- **Not** shipping codex commands. Codex has no slash-command surface — skills
  serve that role, invoked via `/skills` or `$mention`.

## 4. Repository Layout

### 4.1 Restructure

Two directory moves and one rename:

- **Move** `klaude-plugin/skills/` → `skills/` (repo root). Every skill
  directory becomes a child of the new top-level `skills/`.
- **Move** `klaude-plugin/profiles/` → `profiles/` (repo root). Same
  pattern as skills — profiles are shared across providers. Six of ten
  skills reference profiles via `${CLAUDE_PLUGIN_ROOT}/profiles/...`;
  moving profiles to a canonical location eliminates cross-plugin path
  dependencies.
- **Rename** `klaude-plugin/` → `plugins/claude/`. Both providers live under
  `plugins/` for consistency.

The Claude plugin gets relative symlinks:
- `plugins/claude/skills` → `../../skills`
- `plugins/claude/profiles` → `../../profiles`

Existing Claude consumers see no change. `.claude-plugin/marketplace.json`
source path updates from `./klaude-plugin` to `./plugins/claude`.

### 4.1.1 `${CLAUDE_PLUGIN_ROOT}` path resolution

Six skills reference `${CLAUDE_PLUGIN_ROOT}` for profile paths, shared
instructions, and agent paths. Claude substitutes this variable at
plugin-load time. Codex has no equivalent substitution mechanism.

With profiles and skills at repo root, the SessionStart hook injects a
path-variable mapping (see §6.2) telling the model how to resolve
`${CLAUDE_PLUGIN_ROOT}` references. The script computes the absolute repo
root at runtime from its own location and constructs the equivalent path.

### 4.2 Target layout

```
claude-toolbox/
├── skills/                              # MOVED from klaude-plugin/skills/
│   └── <skill-name>/
│       └── SKILL.md
├── profiles/                            # MOVED from klaude-plugin/profiles/
│   └── <name>/
│       ├── DETECTION.md
│       ├── overview.md
│       └── <phase>/
├── plugins/
│   ├── claude/                          # RENAMED from klaude-plugin/
│   │   ├── skills → ../../skills        # symlink
│   │   ├── profiles → ../../profiles    # symlink
│   │   ├── commands/
│   │   ├── agents/
│   │   ├── hooks/
│   │   ├── scripts/
│   │   └── .claude-plugin/plugin.json
│   └── codex/                           # NEW
│       ├── .codex-plugin/plugin.json    # manifest
│       ├── skills → ../../skills        # symlink (copy fallback, see §4.3)
│       └── .mcp.json                    # capy MCP config
├── .agents/plugins/marketplace.json     # NEW — codex marketplace
├── .codex/                              # NEW — template configs
│   ├── config.toml
│   ├── hooks.json
│   ├── agents/
│   │   ├── code-reviewer.toml
│   │   ├── spec-reviewer.toml
│   │   ├── design-reviewer.toml
│   │   ├── eval-grader.toml
│   │   └── profile-resolver.toml
│   ├── rules/
│   │   └── default.rules
│   └── scripts/
│       ├── capy.sh
│       ├── statusline.sh
│       └── session-start.sh
├── .claude-plugin/marketplace.json      # UPDATED source → ./plugins/claude
├── .claude/                             # UNCHANGED
├── .serena/                             # UNCHANGED
├── AGENTS.md                            # NEW — codex project instructions
├── CLAUDE.md                            # UPDATED paths
├── docs/
├── test/
└── README.md
```

### 4.3 Symlink strategy for plugin skills

The manifest's `"skills": "./skills/"` points at a symlink
(`plugins/codex/skills/` → `../../skills/`). Two scenarios:

- **Primary (symlinks work):** Codex's plugin loader follows the symlink
  and discovers all SKILL.md files. No build step needed. Test this first
  during implementation.
- **Fallback (symlinks don't work):** A small script copies `skills/` into
  `plugins/codex/skills/` before distribution. This can be a pre-commit hook,
  a CI step, or a Makefile target. The copy is gitignored.

Implementation tests symlinks first. If they fail, the fallback is
implemented and the design is updated accordingly.

## 5. Plugin Distribution & Installation

### 5.1 Marketplace

The repo ships `.agents/plugins/marketplace.json` at root:

```json
{
  "name": "claude-toolbox",
  "interface": {
    "displayName": "Claude Toolbox"
  },
  "plugins": [
    {
      "name": "kk",
      "source": {
        "source": "local",
        "path": "./plugins/codex"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

### 5.2 Install flow

The install is a two-step process: register the marketplace source, then
install the plugin from the TUI browser.

1. `codex plugin marketplace add serpro69/claude-toolbox` — registers the
   repo as a marketplace source. Codex supports GitHub shorthand
   (`owner/repo`), full Git URLs, SSH URLs, and local paths as marketplace
   sources (documented in codex plugin build docs, "Add a marketplace from
   the CLI" section).
2. User opens `/plugins` in the codex TUI, selects the "Claude Toolbox"
   marketplace, and installs the `kk` plugin.
3. Plugin manifest at `plugins/codex/.codex-plugin/plugin.json` declares
   `"skills": "./skills/"` — codex discovers all SKILL.md files.
4. Plugin `.mcp.json` registers capy MCP server.

**Alternative for users working inside this repo:** The
`.agents/plugins/marketplace.json` is already present at the repo root.
They skip step 1 — the marketplace is auto-discovered. They open `/plugins`
and install directly.

### 5.3 No sparse checkout

`codex plugin marketplace add serpro69/claude-toolbox --sparse .agents/plugins`
would only checkout the marketplace JSON, missing the actual plugin directory
and skills. Users must install the full repo. Documented in the plugin README.

### 5.4 Update flow

`codex plugin marketplace upgrade claude-toolbox` pulls the latest from git.

## 6. Provider Bootstrap via SessionStart Hook

Instead of rewriting SKILL.md files, the `SessionStart` hook injects a
tool-name mapping table into the session context. Zero skill file changes.

### 6.1 Hook configuration

Lives at `.codex/hooks.json`. Fires on every session start. Runs
`.codex/scripts/session-start.sh`, which emits JSON with `additionalContext`.

### 6.2 Injected content

**Provider identity and tool-name mapping:**

```
Provider: Codex.
When skill instructions reference Claude Code tool names, apply this mapping:
- Read → read_file
- Write → write_file
- Edit → apply_patch
- Bash → shell
- Grep → use shell with grep
- Glob → use shell with find
- WebSearch → web_search
- WebFetch → no equivalent; use capy_fetch_and_index via MCP
- Agent/Task → spawn subagents via natural language
- Skill → use the skill tool ($mention or /skills)
```

**Capy routing rules** (condensed version of `.claude/capy/CLAUDE.md`):
- Blocked: curl/wget in shell, inline HTTP patterns
- Redirected: shell commands producing >20 lines of output → capy sandbox
- Tool hierarchy: `capy_batch_execute` → `capy_search` → `capy_execute` →
  `capy_fetch_and_index`

**Sub-agent roster:** Lists all five custom agents available:
`code-reviewer`, `spec-reviewer`, `design-reviewer`, `eval-grader`,
`profile-resolver`.

**`${CLAUDE_PLUGIN_ROOT}` path resolution:**

Six skills reference `${CLAUDE_PLUGIN_ROOT}` for profile paths, shared
instructions, and agent paths. Claude substitutes this at plugin-load time;
codex has no equivalent. The SessionStart hook injects the resolved path:

```
When skill instructions reference ${CLAUDE_PLUGIN_ROOT}, resolve it to:
<absolute-repo-root>/plugins/claude
Profiles are at: <absolute-repo-root>/profiles/
```

The `session-start.sh` script computes `<absolute-repo-root>` at runtime
from its own location (`.codex/scripts/session-start.sh` → walk up two
levels to repo root).

### 6.3 Implementation

The hook script at `.codex/scripts/session-start.sh` is a small shell script
that outputs the JSON structure codex expects:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<provider identity + mapping + capy rules + agent roster>"
  }
}
```

Content is static — no runtime discovery needed.

## 7. Capy Enforcement via PreToolUse Hooks

Two independent protection concerns, ported separately.

### 7.1 File-path denylist (port of `validate-bash.sh`)

The `PreToolUse` hook on `Bash` checks the command against forbidden patterns:
`.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`, `node_modules`,
`__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`.

On match, the hook script emits:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Access to '<pattern>' is blocked by security policy"
  }
}
```

### 7.2 Capy HTTP routing (replicated from `.claude/capy/CLAUDE.md`)

Capy's routing rules and hook configs on Claude are generated by capy's setup
command. Codex does not yet have native capy support, so we replicate the
equivalent rules manually in the `PreToolUse` hook:

- `curl`/`wget` in command → deny with redirect to `capy_fetch_and_index`
- Inline HTTP patterns (`fetch('http`, `requests.get(`, `requests.post(`,
  `http.get(`, `http.request(`) → deny with redirect to `capy_execute`

When capy ships native codex support, these manual entries will be replaced
by capy's own generated config.

### 7.3 Enforcement gap

Codex's `PreToolUse` currently only intercepts `Bash`/`shell`. It cannot
intercept `read_file`, `write_file`, `apply_patch`, `web_search`, or MCP
tool calls. This means:

- File-path denylist on `read_file` is advisory only (via SessionStart context)
- WebFetch-equivalent blocking is advisory only (codex has no `web_fetch`
  tool, but `web_search` can't be hooked)
- MCP tool interception is not possible

This is codex's current limitation (docs explicitly state "Work in progress").
See [ADR 0005](../../adr/0005-codex-hook-enforcement-gap.md) for the full
rationale and mitigation strategy.

## 8. Sub-agents

Claude ships five custom sub-agents as markdown files in `plugins/claude/agents/`.
Codex defines custom agents as TOML files at `.codex/agents/<name>.toml`.

### 8.1 Agent mapping

| Agent | `sandbox_mode` | Purpose |
|---|---|---|
| `code-reviewer.toml` | `read-only` | Reviews diffs for SOLID violations, security risks, code quality |
| `spec-reviewer.toml` | `read-only` | Compares implementation against design docs |
| `design-reviewer.toml` | `read-only` | Evaluates design docs for completeness and soundness |
| `eval-grader.toml` | `read-only` | Grades skill eval assertions against reviewer output |
| `profile-resolver.toml` | `read-only` | Resolves active profiles and checklist-load decisions for a diff |

All five are read-only. The `developer_instructions` field carries the prompt
body adapted from the Claude markdown agents with tool names adjusted per the
SessionStart mapping.

### 8.2 Spawning

Codex spawns sub-agents via natural-language prompting ("spawn the
code-reviewer agent"), not an explicit `spawn_agent` tool call. Skills that
reference sub-agents already use neutral phrasing — no skill changes needed.

### 8.3 MCP inheritance

Sub-agents inherit the parent's sandbox policy. If capy is configured at
session level, sub-agents can access capy MCP tools. Agents can also declare
their own `mcp_servers` block for additive configuration.

### 8.4 Concurrency

`agents.max_threads` (default 6) caps concurrent agents.
`agents.max_depth` (default 1) limits nesting.

## 9. Starlark Rules (Command Policies)

Claude uses flat allow/deny lists in `.claude/settings.json`. Codex uses
Starlark `.rules` files — more powerful, with pattern matching,
justifications, and inline test cases.

### 9.1 Port from Claude deny list

`.codex/rules/default.rules` translates Claude's denied commands into
`prefix_rule()` calls:

- `rm` → `decision = "deny"`
- `git push --force` → `decision = "deny"`
- `git reset --hard` → `decision = "deny"`
- Other destructive commands from `.claude/settings.json` deny list

Commands that Claude marks as "ask" map to `decision = "prompt"` — surfaces
an approval prompt in codex's UI.

### 9.2 Expansion opportunity

Starlark is more expressive than flat lists. Future enhancements can add
rules Claude can't express — e.g., denying `git push` to `main`/`master`
specifically while allowing pushes to other branches.

### 9.3 Testing

Rules are validated offline:
`codex execpolicy check --pretty --rules .codex/rules/default.rules -- <command>`

## 10. Template Configs & Template-Sync

### 10.1 Codex template configs

| File | Substitution | Notes |
|---|---|---|
| `.codex/config.toml` | `PROJECT_NAME`, model/effort variables | Model, approval policy, agent config, feature flags |
| `.codex/hooks.json` | None (static) | SessionStart + PreToolUse hook definitions |
| `.codex/agents/*.toml` | None (static) | All five sub-agent definitions |
| `.codex/rules/default.rules` | None (static) | Starlark command policies |
| `.codex/scripts/statusline.sh` | None (static) | Statusline port |
| `.codex/scripts/session-start.sh` | None (static) | SessionStart hook script |
| `AGENTS.md` | `PROJECT_NAME` | Provider identity + behavioral instructions |

### 10.2 Not synced (per-repo)

- `.codex/scripts/capy.sh` — generated by capy setup
- Capy-related hook entries in `hooks.json` — generated by capy setup.
  The synced `hooks.json` contains only the non-capy hooks (file-path
  denylist, session bootstrap). Capy's setup command appends its own entries.

### 10.3 Template-sync changes

`template-sync.sh` needs three modifications:

1. Add `.codex/` to the sparse-clone file list (alongside `.claude/` and
   `.serena/`).
2. Add `AGENTS.md` to the root-level files list.
3. Add variable substitution mappings for `.codex/config.toml` and `AGENTS.md`
   — reusing existing manifest variables where possible, adding
   codex-specific ones (e.g., `CODEX_MODEL`, `CODEX_APPROVAL_POLICY`) only
   where Claude equivalents don't map.

### 10.4 Downstream manifest

`.github/template-state.json` gains optional codex-specific variables.
Existing downstream repos that don't use codex simply don't set them — sync
skips codex files gracefully or uses sensible defaults.

## 11. Statusline

Claude's statusline is driven by shell scripts that read JSON from stdin,
extract model/context/usage data, and format with Catppuccin theming.

### 11.1 Port

`.codex/scripts/statusline.sh` replicates the logic:

1. Read codex's status input format
2. Extract equivalent fields: model, context usage, token counts
3. Format using the same Catppuccin theming logic
4. Output compact status string

`config.toml` wires it via the `tui` section. Env vars mapped:
`CLAUDE_STATUSLINE_MODE` → `CODEX_STATUSLINE_MODE`,
`CLAUDE_STATUSLINE_THEME` → `CODEX_STATUSLINE_THEME`.

### 11.2 Implementation risk

Codex's statusline input format isn't fully documented. The implementation
task needs to investigate what data codex passes to the statusline command.
If the format is incompatible or undocumented, the statusline port starts
minimal and expands as codex documents the interface.

## 12. MCP Configuration

### 12.1 Capy

Two registration paths (both point at the same launcher):

- **Plugin-bundled:** `plugins/codex/.mcp.json` — convenience for plugin users
- **Template config:** `.codex/config.toml` `[mcp_servers.capy]` section

```toml
[mcp_servers.capy]
command = "bash"
args = [".codex/scripts/capy.sh", "serve"]
```

Capy's own setup command may override these — same pattern as Claude side.

### 12.2 Serena

Not shipped as part of this feature. Works as a user-configured MCP server
on codex — no special handling needed.

## 13. AGENTS.md (Project Instructions)

Codex's equivalent of `CLAUDE.md`. Contains:

- Provider identity statement (redundant with SessionStart hook but serves
  as static fallback)
- Behavioral instructions (ported from `.claude/CLAUDE.extra.md` —
  independent thinking, fail-loud, exploration-first, deferred work
  documentation)
- Capy routing rules (replicated from `.claude/capy/CLAUDE.md` until capy
  ships native codex support)

Template-sync substitutes `PROJECT_NAME`. Codex discovers it via
directory-walk inheritance from repo root.

## 14. Testing

### 14.1 Updated tests

- `test/test-plugin-structure.sh` — update `EXPECTED_*` arrays and all path
  assertions for the `klaude-plugin/` → `plugins/claude/` rename and the
  `skills/` move to repo root

### 14.2 New tests

- Assert `plugins/codex/.codex-plugin/plugin.json` exists and validates as JSON
- Assert `.codex/config.toml` exists and has required sections
- Assert `.codex/hooks.json` validates as JSON
- Assert all five `.codex/agents/*.toml` files exist
- Assert `.codex/rules/default.rules` exists
- Assert `.agents/plugins/marketplace.json` exists with the `kk` plugin entry
- Assert `plugins/codex/skills` resolves (symlink or directory with SKILL.md
  files)
- Assert `AGENTS.md` exists at repo root
- Assert `plugins/claude/skills` is a relative symlink resolving to
  `../../skills`

## 15. Risks and Open Questions

- **Symlink handling in codex's plugin system.** The design assumes codex's
  plugin loader follows symlinks from `plugins/codex/skills/` → `../../skills/`.
  If testing reveals it does not, fallback is a copy step (see §4.3).
- **Codex statusline input format.** Not fully documented. May require
  investigation during implementation (see §11.2).
- **Capy native codex support timeline.** The manually replicated capy rules
  are a stopgap. When capy ships native codex support, the manual entries
  are replaced by capy's generated config.
- **Hook coverage expansion.** Codex's `PreToolUse` currently only intercepts
  `Bash`. When codex expands hook coverage to other tools, additional
  enforcement hooks should be added. See
  [ADR 0005](../../adr/0005-codex-hook-enforcement-gap.md).
- **`codex_hooks` feature flag.** Hooks require
  `[features] codex_hooks = true` in `config.toml`. This is experimental
  and may change. The template config enables it by default; downstream
  repos can disable.
