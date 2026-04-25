# Design: Codex Support

> Status: draft (v2 — reworked from symlink-based approach)
> Created: 2026-04-24
> Updated: 2026-04-25

## 1. Overview

Add first-class OpenAI Codex support to `claude-toolbox`. Today the repo is
Claude-only; after this feature, Codex users get the same skills, equivalent
sub-agents, capy context-protection (within codex's current hook limitations),
MCP wiring, and template configs.

### 1.1 Approach: generate, don't symlink

The v1 design assumed skills could be shared via filesystem symlinks — both
provider plugins would point at a canonical `skills/` directory at repo root.
**This doesn't work.** Claude Code's plugin cache strips symlinks during
installation, so marketplace consumers get zero skills. Codex's plugin loader
has the same limitation.

The new approach: **`klaude-plugin/` is the canonical source of truth.** A Go
generation tool reads from it and produces `kodex-plugin/` with all necessary
transformations. Generated output is committed. Freshness is enforced via CI
(same pattern as `make vendor-profiles`).

This avoids restructuring the repo, avoids symlinks, avoids build-on-clone
footguns, and keeps the Claude plugin completely untouched.

## 2. Goals

1. A Codex user registers the marketplace via
   `codex plugin marketplace add serpro69/claude-toolbox`, then installs the
   `kk` plugin from the `/plugins` browser — all workflow skills are
   immediately available.
2. Skills are authored once in `klaude-plugin/skills/` and generated into
   `kodex-plugin/skills/` by a Go tool. No manual duplication.
3. Codex-specific artifacts (agents, hooks, config, rules) live under `.codex/`
   and `kodex-plugin/` — isolated from Claude's side.
4. Template-sync distributes `.codex/` configs to downstream repos alongside
   `.claude/`.
5. Capy enforcement works via hooks where codex supports it (Bash interception),
   with advisory-only coverage documented for gaps.

## 3. Non-Goals

- **Not** restructuring the repo. `klaude-plugin/` stays where it is.
- **Not** rewriting SKILL.md files to be provider-neutral. The generation tool
  handles provider-specific transformations (tool-name mapping,
  `${CLAUDE_PLUGIN_ROOT}` resolution).
- **Not** supporting codex's `--sparse` checkout for plugin installation.
- **Not** replacing Serena. Codex users can configure it as an MCP server if
  they want; we don't ship it as part of the codex plugin.
- **Not** shipping codex commands. Codex has no slash-command surface — skills
  serve that role, invoked via `/skills` or `$mention`.

## 4. Repository Layout

### 4.1 No restructure

`klaude-plugin/` remains the canonical plugin directory for Claude. No files
move. The only new directories are `kodex-plugin/` (generated) and `.codex/`
(template configs).

### 4.2 Target layout

```
claude-toolbox/
├── klaude-plugin/                       # UNCHANGED — Claude source of truth
│   ├── skills/
│   ├── profiles/
│   ├── commands/
│   ├── agents/
│   ├── hooks/
│   ├── scripts/
│   └── .claude-plugin/plugin.json
├── kodex-plugin/                        # GENERATED from klaude-plugin/
│   ├── skills/                          # copied + transformed SKILL.md files
│   ├── .codex-plugin/plugin.json        # generated manifest
│   └── .mcp.json                        # capy MCP config
├── cmd/
│   ├── vendor-profiles/                 # existing
│   └── generate-kodex/                  # NEW — generation tool
├── scripts/
│   └── kodex-generate-manifest.yml      # NEW — generation manifest
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
│       └── session-start.sh
├── .claude-plugin/marketplace.json      # UNCHANGED
├── .claude/                             # UNCHANGED
├── .serena/                             # UNCHANGED
├── AGENTS.md                            # NEW — codex project instructions
├── CLAUDE.md                            # UNCHANGED
├── docs/
├── test/
└── README.md
```

### 4.3 What lives where

| Artifact | Claude | Codex |
|---|---|---|
| Skills (SKILL.md) | `klaude-plugin/skills/` (authored) | `kodex-plugin/skills/` (generated) |
| Profiles | `klaude-plugin/profiles/` (authored) | Referenced via SessionStart path mapping |
| Agents | `klaude-plugin/agents/*.md` (authored) | `.codex/agents/*.toml` (generated) |
| Commands | `klaude-plugin/commands/` | N/A (codex has no slash-command surface) |
| Hooks | `klaude-plugin/hooks/` | `.codex/hooks.json` (hand-authored, different schema) |
| Rules/Permissions | `.claude/settings.json` | `.codex/rules/default.rules` (hand-authored Starlark) |
| Config | `.claude/settings.json` | `.codex/config.toml` |
| Project instructions | `CLAUDE.md` | `AGENTS.md` |
| MCP (capy) | `.claude/` MCP config | `kodex-plugin/.mcp.json` + `.codex/config.toml` |
| Plugin manifest | `klaude-plugin/.claude-plugin/` | `kodex-plugin/.codex-plugin/` (generated) |
| Marketplace | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |

## 5. Generation Tool (`cmd/generate-kodex/`)

### 5.1 Design principles

The tool follows the same pattern as `cmd/vendor-profiles/`:
- **Manifest-driven.** A YAML manifest (`scripts/kodex-generate-manifest.yml`)
  declares what to generate and how to transform it.
- **Deterministic.** Same input → same output. No network calls. No
  timestamps in output.
- **Dry-run support.** `--dry-run` prints planned actions without writing.
- **Committed output.** Generated files are committed to the repo, not
  gitignored. Marketplace distribution requires real files.

### 5.2 Generation manifest schema

```yaml
# scripts/kodex-generate-manifest.yml
source_plugin: klaude-plugin       # source directory
target_plugin: kodex-plugin        # output directory

skills:
  # Which skills to generate. Default: all SKILL.md files.
  include_all: true
  # Per-skill overrides (optional)
  overrides: []

  # Transformations applied to every SKILL.md
  transforms:
    # Replace ${CLAUDE_PLUGIN_ROOT} references with codex-relative paths
    - type: plugin_root_resolve
      # The value to substitute for ${CLAUDE_PLUGIN_ROOT} references
      # At generation time, paths are made relative to the kodex-plugin dir
      replacement_base: "../klaude-plugin"

    # Inject a tool-name mapping header at the top of each SKILL.md
    - type: inject_header
      content: |
        <!-- codex: tool-name mapping applied. See .codex/scripts/session-start.sh -->

  # Shared instructions (_shared/) handling
  shared:
    # Copy _shared/ directory alongside skills
    copy: true

manifest:
  # Generate .codex-plugin/plugin.json
  name: "kk"
  version_from: "klaude-plugin/.claude-plugin/plugin.json"
  extra_fields:
    skills: "./skills/"
    mcpServers: "./.mcp.json"

mcp:
  # Generate .mcp.json
  servers:
    capy:
      command: "bash"
      args: [".codex/scripts/capy.sh", "serve"]
```

### 5.3 Transform pipeline

For each SKILL.md file:

1. **Read** the source file from `klaude-plugin/skills/<name>/SKILL.md`.
2. **Resolve `${CLAUDE_PLUGIN_ROOT}`** — replace with a path that resolves
   from the codex plugin's installed location. Since profiles and shared
   instructions live in `klaude-plugin/`, the replacement is
   `../klaude-plugin` (relative to `kodex-plugin/`).

   **Important constraint:** This relative path works when both plugins are
   checked out from the same repo (local development, template-sync). For
   marketplace installs where the codex plugin is cached in isolation, profile
   paths won't resolve — but profile content is also injected via the
   SessionStart hook (§7.2), so this is acceptable. The SKILL.md paths serve
   as documentation; the hook provides the runtime resolution.

3. **Copy** shared instructions (`_shared/`) into `kodex-plugin/skills/_shared/`.
4. **Copy** per-skill symlinks to shared instructions. If the source has
   `skills/<name>/shared-foo.md → ../_shared/foo.md`, create the same
   symlink in the generated output. (Symlinks within a flat directory
   structure work fine — it's cross-directory symlinks that break caches.)

   **TODO:** Verify that intra-skills symlinks survive codex's plugin cache.
   If not, the generation tool should resolve them to copies.

5. **Write** to `kodex-plugin/skills/<name>/SKILL.md`.

### 5.4 Manifest generation

Generate `kodex-plugin/.codex-plugin/plugin.json`:
- Read version from `klaude-plugin/.claude-plugin/plugin.json`.
- Set `skills`, `mcpServers`, and metadata fields.

Generate `kodex-plugin/.mcp.json`:
- Capy MCP server configuration.

### 5.5 What the tool does NOT generate

These are hand-authored because their schemas differ fundamentally between
providers — mechanical transformation isn't sufficient:

| Artifact | Why hand-authored |
|---|---|
| `.codex/agents/*.toml` | TOML format, different fields, prompt body needs semantic adaptation |
| `.codex/hooks.json` | Different event model, different response schema |
| `.codex/rules/default.rules` | Starlark — completely different paradigm from JSON deny lists |
| `.codex/config.toml` | Codex-specific settings, no Claude equivalent |
| `AGENTS.md` | Codex-specific project instructions |
| `.codex/scripts/*.sh` | Hook scripts with codex-specific JSON I/O |

The agents are a special case — they could theoretically be generated (the
prompt body is the main content, with structural wrapping around it). But the
adaptation isn't purely mechanical: Claude-specific constructs need semantic
rephrasing, not just find-and-replace. Hand-authoring with the Claude agent
as reference is more reliable. A generation script for agents can be added
later if the manual maintenance burden proves significant.

### 5.6 Developer workflow

```bash
# After editing skills in klaude-plugin/:
make generate-kodex     # runs tool + validates structure

# CI check: ensure generated output is fresh
make generate-kodex
git diff --exit-code kodex-plugin/
```

The Makefile target:
```makefile
generate-kodex:
    go run ./cmd/generate-kodex -manifest scripts/kodex-generate-manifest.yml
    $(MAKE) test-structure
```

## 6. Plugin Distribution & Installation

### 6.1 Marketplace

The repo ships two marketplace files:

**Claude** (existing, unchanged):
`.claude-plugin/marketplace.json` → source: `./klaude-plugin`

**Codex** (new):
`.agents/plugins/marketplace.json`:
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
        "path": "./kodex-plugin"
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

### 6.2 Install flow

1. `codex plugin marketplace add serpro69/claude-toolbox` — registers the
   repo as a marketplace source.
2. User opens `/plugins` in the codex TUI, selects "Claude Toolbox"
   marketplace, installs `kk` plugin.
3. Plugin manifest at `kodex-plugin/.codex-plugin/plugin.json` declares
   `"skills": "./skills/"` — codex discovers all SKILL.md files.
4. Plugin `.mcp.json` registers capy MCP server.

### 6.2.1 What the plugin delivers vs. what it doesn't

The plugin install provides **skills and MCP configuration only**. Remaining
artifacts reach users via template-sync or manual setup:

| Artifact | Location | Delivery mechanism |
|---|---|---|
| Skills + capy MCP | `kodex-plugin/` | Plugin install |
| Custom agents (`.toml`) | `.codex/agents/` | Template-sync or manual setup |
| Hooks (`hooks.json`) | `.codex/hooks.json` | Template-sync or manual setup |
| Starlark rules | `.codex/rules/` | Template-sync or manual setup |
| Config (`config.toml`) | `.codex/config.toml` | Template-sync or manual setup |
| Project instructions | `AGENTS.md` | Template-sync or manual setup |

### 6.3 No sparse checkout

Users must install the full repo. Documented in the plugin README.

### 6.4 Update flow

`codex plugin marketplace upgrade claude-toolbox` pulls the latest from git.

## 7. Provider Bootstrap via SessionStart Hook

Instead of rewriting SKILL.md files, the `SessionStart` hook injects a
tool-name mapping table into the session context. Zero skill file changes
needed (the generation tool handles `${CLAUDE_PLUGIN_ROOT}` references;
tool-name mapping is injected at session level).

### 7.1 Hook configuration

Lives at `.codex/hooks.json`:

```json
{
  "SessionStart": [
    {
      "matcher": "startup|resume",
      "hooks": [
        {
          "type": "command",
          "command": ".codex/scripts/session-start.sh"
        }
      ]
    }
  ]
}
```

Requires `[features] codex_hooks = true` in `config.toml`.

### 7.2 Injected content

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

**Profile path resolution:**

```
Profiles are at: <absolute-repo-root>/klaude-plugin/profiles/
Shared skill instructions are at: <absolute-repo-root>/klaude-plugin/skills/_shared/
```

The `session-start.sh` script computes `<absolute-repo-root>` at runtime
from its own location (`.codex/scripts/session-start.sh` → walk up two
levels to repo root).

### 7.3 Implementation

The hook script at `.codex/scripts/session-start.sh` outputs the JSON
structure codex expects:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<provider identity + mapping + capy rules + agent roster>"
  }
}
```

Content is static except for the absolute repo-root path computed at runtime.

## 8. Capy Enforcement via PreToolUse Hooks

Two independent protection concerns.

### 8.1 File-path denylist (port of `validate-bash.sh`)

The `PreToolUse` hook on `Bash` checks the command against forbidden patterns:
`.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`, `node_modules`,
`__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`.

On match, emits `permissionDecision: "deny"` JSON with descriptive reason.

### 8.2 Capy HTTP routing

Replicates the equivalent rules manually in the `PreToolUse` hook:

- `curl`/`wget` in command → deny with redirect to `capy_fetch_and_index`
- Inline HTTP patterns → deny with redirect to `capy_execute`

When capy ships native codex support, these manual entries will be replaced
by capy's own generated config.

### 8.3 Enforcement gap

Codex's `PreToolUse` currently only intercepts `Bash`/`shell`. It cannot
intercept `read_file`, `write_file`, `apply_patch`, `web_search`, or MCP
tool calls. Advisory coverage only for these — documented in
[ADR 0005](../../adr/0005-codex-hook-enforcement-gap.md).

## 9. Sub-agents

Claude ships five custom sub-agents as markdown files in
`klaude-plugin/agents/`. Codex defines custom agents as TOML files at
`.codex/agents/<name>.toml`.

### 9.1 Agent mapping

| Agent | `sandbox_mode` | Purpose |
|---|---|---|
| `code-reviewer.toml` | `read-only` | Reviews diffs for SOLID violations, security risks, code quality |
| `spec-reviewer.toml` | `read-only` | Compares implementation against design docs |
| `design-reviewer.toml` | `read-only` | Evaluates design docs for completeness and soundness |
| `eval-grader.toml` | `read-only` | Grades skill eval assertions against reviewer output |
| `profile-resolver.toml` | `read-only` | Resolves active profiles and checklist-load decisions for a diff |

All five are read-only and hand-authored. The `developer_instructions` field
carries the prompt body adapted from the Claude markdown agents with tool
names adjusted per the SessionStart mapping.

### 9.2 Spawning

Codex spawns sub-agents via natural-language prompting. Skills that reference
sub-agents already use neutral phrasing — no skill changes needed.

### 9.3 MCP inheritance

Sub-agents inherit the parent's sandbox policy. If capy is configured at
session level, sub-agents can access capy MCP tools.

### 9.4 Concurrency

`agents.max_threads` (default 6) caps concurrent agents.
`agents.max_depth` (default 1) limits nesting.

## 10. Starlark Rules (Command Policies)

Codex uses Starlark `.rules` files — more powerful than Claude's flat
allow/deny lists, with pattern matching, justifications, and inline test
cases.

### 10.1 Port from Claude deny list

`.codex/rules/default.rules` translates Claude's denied commands into
`prefix_rule()` calls. Only `Bash(...)` entries from `.claude/settings.json`
`permissions.deny` are ported — `Read(...)` entries are handled by the
PreToolUse hook and SessionStart advisory context.

### 10.2 Testing

Rules are validated offline:
`codex execpolicy check --pretty --rules .codex/rules/default.rules -- <command>`

## 11. Statusline

Codex's `tui.status_line` is an `array<string>` of built-in identifiers —
no extension point for custom scripts.

```toml
[tui]
status_line = ["model-with-reasoning", "current-dir"]
```

No Catppuccin theming, no context-window display. Platform limitation, not
a design choice.

## 12. MCP Configuration

### 12.1 Capy

Two registration paths (both point at the same launcher):

- **Plugin-bundled:** `kodex-plugin/.mcp.json` — convenience for plugin users
- **Template config:** `.codex/config.toml` `[mcp_servers.capy]` section

Capy's own setup command may override these.

### 12.2 Serena

Not shipped as part of this feature. Works as a user-configured MCP server.

## 13. AGENTS.md (Project Instructions)

Codex's equivalent of `CLAUDE.md`. Contains:

- Provider identity statement
- Behavioral instructions (ported from `.claude/CLAUDE.extra.md`)
- Capy routing rules (replicated from `.claude/capy/CLAUDE.md`)

Template-sync substitutes `PROJECT_NAME`.

## 14. Template Configs & Template-Sync

### 14.1 Codex template configs

| File | Substitution | Notes |
|---|---|---|
| `.codex/config.toml` | `PROJECT_NAME`, model/effort variables | Model, approval policy, agent config, feature flags |
| `.codex/hooks.json` | None (static) | SessionStart + PreToolUse hook definitions |
| `.codex/agents/*.toml` | None (static) | All five sub-agent definitions |
| `.codex/rules/default.rules` | None (static) | Starlark command policies |
| `.codex/scripts/session-start.sh` | None (static) | SessionStart hook script |
| `AGENTS.md` | `PROJECT_NAME` | Provider identity + behavioral instructions |

### 14.2 Not synced (per-repo)

- `.codex/scripts/capy.sh` — generated by capy setup
- Capy-related hook entries in `hooks.json` — generated by capy setup
- `kodex-plugin/` — delivered via marketplace plugin install, not template-sync

### 14.3 Template-sync changes

`template-sync.sh` needs three modifications:

1. Add `.codex/` to the sparse-clone file list.
2. Add `AGENTS.md` to root-level files.
3. Add variable substitution for `.codex/config.toml` and `AGENTS.md`.

### 14.4 Downstream manifest

`.github/template-state.json` gains optional codex-specific variables.
Existing downstream repos that don't set them get sensible defaults.

## 15. Testing

### 15.1 Updated tests

- `test/test-plugin-structure.sh` — add assertions for `kodex-plugin/`
  generated output (skills exist, manifest validates, no dangling symlinks).

### 15.2 New tests

- Assert `kodex-plugin/.codex-plugin/plugin.json` exists and validates as JSON
- Assert `kodex-plugin/skills/` contains SKILL.md files matching
  `klaude-plugin/skills/` (generation completeness check)
- Assert `.codex/config.toml` exists and has required sections
- Assert `.codex/hooks.json` validates as JSON
- Assert all five `.codex/agents/*.toml` files exist
- Assert `.codex/rules/default.rules` exists
- Assert `.agents/plugins/marketplace.json` exists with the `kk` plugin entry
- Assert `AGENTS.md` exists at repo root

### 15.3 Generation freshness check

CI runs `make generate-kodex && git diff --exit-code kodex-plugin/` to ensure
the committed output matches what the tool would produce. Same pattern as
`make vendor-profiles`.

## 16. Risks and Open Questions

- **Intra-skill symlinks in codex cache.** Skills reference shared
  instructions via symlinks within `skills/` (e.g.,
  `skills/<name>/shared-foo.md → ../_shared/foo.md`). These are
  intra-directory and may work, but need testing. If they don't, the
  generation tool resolves them to file copies.
- **Profile access from marketplace installs.** When installed via
  marketplace (cached in isolation), `kodex-plugin/` skills reference
  profiles via relative paths to `klaude-plugin/profiles/`. These won't
  resolve. Mitigation: SessionStart hook injects profile content paths
  using the absolute repo root — works for template-sync users but not
  standalone marketplace users. Acceptable trade-off: profiles are an
  advanced feature; most skills work without them.
- **Capy native codex support timeline.** The manually replicated capy rules
  are a stopgap.
- **Hook coverage expansion.** When codex expands hook coverage beyond Bash,
  add additional enforcement hooks.
- **`codex_hooks` feature flag.** Experimental, may change.
- **Generation tool scope creep.** Keep the tool focused on skills +
  manifest + MCP config. Resist the temptation to generate agents, hooks,
  or rules — the schemas differ too much for mechanical transformation to
  be reliable.
