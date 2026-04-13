# Design: Opencode Support (and Multi-Provider Foundation)

> Status: draft
> Created: 2026-04-13

## 1. Overview

Add first-class support for [OpenCode](https://opencode.ai) to `claude-toolbox`, and
restructure the repository so that future providers (Codex, and potentially others)
can be added with minimal churn.

Today, this repo is a Claude-Code-only toolbox:
- `klaude-plugin/` distributes skills, commands, agents, and hooks via Claude Code's
  plugin system (`.claude-plugin/marketplace.json` → `kk` plugin).
- `.claude/` holds the project's own Claude configuration (settings, statusline,
  capy MCP wiring, Serena LSP integration).

After this feature:
- Skills live at a canonical, provider-neutral path (`skills/`) and are consumed by
  every provider's distribution.
- Each provider has a dedicated sub-tree under `plugins/<provider>/` with
  format-correct commands, agents, configs, and (where applicable) a runtime plugin.
- OpenCode users get feature parity with Claude users: the same skills, equivalent
  slash-commands, equivalent sub-agents, capy context-protection, and MCP wiring.

## 2. Goals

1. A user running OpenCode can install this toolbox with a one-line addition to
   their `opencode.jsonc` and immediately use all workflow skills, commands,
   sub-agents, and capy routing.
2. Skills are authored **once**, in a provider-neutral form, and consumed unchanged
   by every provider.
3. Provider-specific details (tool names, slash commands, routing rules, MCP tool
   names) are isolated in per-provider reference files and bootstrap configs — they
   never leak into the shared skill body.
4. Future providers (Codex first) can be added by dropping a new `plugins/codex/`
   tree and a `reference/codex.md` file into each skill — no changes to the skills
   themselves.
5. Existing Claude-side external consumers (`kk@claude-toolbox` via the marketplace)
   continue to work after restructure.

## 3. Non-Goals

- **Not** abstracting commands, agents, or hooks across providers. Formats differ
  too much; translation at authoring time is cheaper than a generator.
- **Not** shipping a TypeScript build pipeline for skills. Skills remain plain
  markdown.
- **Not** supporting ACP editors (Zed/JetBrains) as a shipped artifact of this
  repo — users remain free to wire OpenCode's ACP themselves.
- **Not** keeping backward-compatibility shims for the pre-restructure paths in
  local checkouts. The external plugin contract (`kk@claude-toolbox`) is preserved;
  contributors with local clones do a one-shot path update.
- **Not** replacing Serena. OpenCode has built-in LSP; users can adopt it or keep
  Serena — both work.

## 4. Core concepts

### 4.1 Canonical skills with per-provider reference files

**Every skill has this shape:**

```
skills/<skill-name>/
├── SKILL.md                   # provider-neutral workflow
├── reference/
│   ├── claude.md              # tool names, capy routing, slash commands
│   ├── opencode.md            # tool names, @mention, capy-on-opencode
│   └── codex.md               # codex specifics (usually minimal)
└── <supporting .md files>     # examples, sub-processes — unchanged
```

**SKILL.md rules:**
- Use neutral verbs — *"read the file"*, *"search the knowledge base"*,
  *"invoke a sub-agent"*, *"use the skill tool"*.
- No hard-coded tool literals (`Skill`, `Task`, `TodoWrite`, `Read`, `Write`,
  `Edit`, `Grep`, `Glob`, `Bash`, `WebFetch`, `capy_*`, `kk:` prefixes,
  `/slash-command` names).
- Near the top, include exactly one pointer line directing the agent to load
  `reference/<provider>.md` for runtime-specific tool names and conventions.

**reference/<provider>.md content (per skill, as relevant):**
- Mapping of abstract actions to concrete tool names (`read the file → Read`
  on Claude, `read` on opencode).
- Sub-agent invocation syntax.
- Slash-command names corresponding to the skill's triggers.
- Knowledge-base routing rules (capy on Claude; capy-via-opencode on opencode;
  none on codex).
- Relevant MCP tool names and when to use them.

### 4.2 Provider self-identification via bootstrap

The skill doesn't detect its runtime; the runtime tells the skill who it is.

Each provider has a session-level bootstrap that includes a one-line provider
identity statement. When the agent loads a skill and sees
`reference/<provider>.md`, it substitutes the identified provider.

| Provider | Where the bootstrap lives                                           | Reliability mechanism |
|----------|---------------------------------------------------------------------|------------------------|
| Claude   | Project `CLAUDE.md` (required — Claude plugin system has no injection field; the project-level file IS the mechanism) | Always loaded at session start |
| OpenCode | JS plugin injects via `experimental.chat.system.transform` **per turn** (survives compaction) + `AGENTS.md` template at project root as belt-and-suspenders | Plugin re-injects on every turn; AGENTS.md is static fallback |
| Codex    | Install README instructs user to add a line to `~/.codex/AGENTS.md` | AGENTS.md is loaded at session start |

The bootstrap also carries any provider-specific routing rules (e.g. capy on
OpenCode uses lowercase tool names and different hook mechanism).

**Per-turn injection rationale (OpenCode):** `experimental.chat.system.transform`
can be applied on every turn rather than only at session start. The plugin
opts into the per-turn form so that long sessions, context compaction, or
the agent mid-session dropping earlier context still see the provider identity.
Additional token cost per turn is minimal (the provider-identity block is
intentionally compact — tens of tokens, not hundreds).

### 4.3 Per-provider trees — not shared

`commands/`, `agents/`, `hooks/` (where applicable), and provider configuration
live under `plugins/<provider>/`. They are authored in each provider's native
format. We do not share these across providers because:

- Claude's slash-command frontmatter differs from OpenCode's in both syntax and
  semantics (`agent`, `model` keys differ).
- Claude's sub-agent model and OpenCode's primary/sub-agent distinction aren't
  1:1.
- Claude's `hooks.json` has no OpenCode analog — OpenCode expresses hook intent
  inside a JS plugin.
- Codex has no commands/agents/hooks surface at all.

Command and agent bodies are short (3–10 lines each). Porting them per-provider
is hours, not days.

## 5. Target repository layout

```
claude-toolbox/
├── skills/                          # canonical; one dir per skill
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── reference/               # RESERVED — provider files only
│       │   ├── claude.md
│       │   ├── opencode.md
│       │   └── codex.md
│       ├── checklists/              # (example) non-provider subdirs use other names
│       │   └── <lang>/              # e.g. review-code's former reference/<lang>/
│       └── <supporting files>
├── plugins/
│   ├── claude/                      # renamed from klaude-plugin/
│   │   ├── skills                   # symlink → ../../skills (works: Claude plugin system supports symlinks)
│   │   ├── commands/                # Claude-format markdown, unchanged
│   │   ├── agents/                  # Claude-format agents, unchanged
│   │   ├── hooks/hooks.json         # Claude hook wiring, unchanged
│   │   ├── scripts/                 # validate-bash.sh, etc.
│   │   ├── .claude-plugin/plugin.json
│   │   └── README.md
│   └── opencode/                    # new — ORGANIZATIONAL container for opencode artifacts
│       ├── commands/                # opencode-format markdown (re-authored)
│       ├── agents/                  # opencode primary/subagent markdown
│       ├── runtime/                 # TypeScript runtime plugin (renamed from plugins/ to avoid double-plugins nesting)
│       │   └── kk.ts                # bootstrap, capy hooks, tool mapping
│       ├── opencode.jsonc           # reference config users merge into theirs
│       └── README.md
├── package.json                     # NEW — opencode plugin manifest (repo root)
│                                    # declares `@opencode-ai/plugin` dep; main points at plugins/opencode/runtime/kk.ts
├── .claude-plugin/
│   └── marketplace.json             # updated: "source": "./plugins/claude"
├── .claude/                         # this repo's own Claude config — unchanged
├── .opencode/                       # this repo's own OpenCode config (optional, for dog-fooding)
├── docs/
├── test/                            # template-sync tests + new lint checks
├── examples/
└── README.md                        # new "Providers" section
```

**Distribution model (addresses OpenCode plugin-fetcher constraints):**

OpenCode plugins installed via `"plugin": ["kk@git+..."]` are fetched by Bun
into `~/.cache/opencode/node_modules/`. Relative symlinks that point OUTSIDE
the installed package directory do NOT reliably survive this fetch. Therefore:

- **There is no `plugins/opencode/skills` symlink.** Instead, the OpenCode
  plugin's runtime code resolves the skills path from its own file location
  (via `import.meta.url`) up to the repo/package root and then into `./skills/`.
- **Install target is the whole repo, no `?subpath=`.** Mirrors superpowers'
  pattern: `"plugin": ["kk@git+https://github.com/serpro69/claude-toolbox.git"]`.
  Bun clones the entire repo — `skills/`, `plugins/opencode/`, and the
  root-level `package.json` are all present in the cache. The plugin resolves
  `skills/` at a known relative offset from `kk.ts`.
- **Root-level `package.json` is required** because OpenCode's Bun-based loader
  expects a package manifest at the installed path's root. It declares
  `@opencode-ai/plugin` as a dep and points `main` at the runtime entry file.
- **npm-publish fallback** (if an alternate distribution channel is later
  needed): the root `package.json` `files` field declares `skills/`,
  `plugins/opencode/`, and any needed bits. `npm pack` dereferences symlinks
  automatically, so the skills content lands in the tarball.

**Key invariants:**
- `plugins/claude/skills` is a relative symlink to `../../skills`. Claude Code's
  plugin system follows symlinks; this is the validated path.
- The **OpenCode side never symlinks**. Its plugin runtime resolves skills at
  load time via `import.meta.url`.
- `.claude-plugin/marketplace.json` still points to a valid plugin directory
  (`./plugins/claude`) so the external `kk@claude-toolbox` contract is intact.
- `reference/` inside any skill is **reserved for provider files** (`claude.md`,
  `opencode.md`, `codex.md`). Any existing `reference/<lang>/` subdirs (notably
  in `review-code`) are renamed to `checklists/<lang>/` (or similar
  semantic name) as part of the skills refactor.
- Repo-root dotfiles for provider configs (`.claude/`, `.opencode/`) are for
  this repo's own development (dog-fooding) and are not part of what gets
  distributed.

## 6. OpenCode plugin architecture

### 6.1 Delivery

Users install by adding one line to their `opencode.jsonc`:

```jsonc
{
  "plugin": [
    "kk@git+https://github.com/serpro69/claude-toolbox.git"
  ]
}
```

No `?subpath=`. OpenCode's Bun-based plugin loader clones the whole repo into
its cache and reads the root-level `package.json`. That manifest declares the
dependency on `@opencode-ai/plugin` and points `main` at the runtime file
(`plugins/opencode/runtime/kk.ts`).

This mirrors superpowers' delivery model: the installable unit is the repo,
and the plugin entry point navigates the repo via file-location-relative
resolution at load time. It sidesteps the "symlink does not survive Bun
fetch" problem because skills are accessed via a *runtime-computed path*,
not a filesystem symlink.

**Minimum OpenCode version:** The bootstrap injection relies on
`experimental.chat.system.transform`, which is explicitly experimental in
OpenCode. `plugins/opencode/README.md` must document the minimum OpenCode
version tested, and the plugin must degrade gracefully if the hook is
unavailable (log a warning, skip the injection; skills continue to work via
static AGENTS.md bootstrap).

### 6.2 What the plugin does

The plugin is a TypeScript module using `@opencode-ai/plugin`. Its
responsibilities, all at runtime:

**a. Provider-identity bootstrap injection.**
Via OpenCode's `experimental.chat.system.transform` hook, prepend a compact
system note **on every turn** (not just session start — survives context
compaction). Content:
- `Provider: opencode.` For skills with `reference/<provider>.md`, load
  `reference/opencode.md`.
- Available sub-agents (discovered from `plugins/opencode/agents/`).
- The capy routing block (lowercased tool names, OpenCode-specific mechanisms).

Belt-and-suspenders fallback: an `AGENTS.md` template in
`plugins/opencode/` that users can drop into their project root. Contains the
same provider-identity statement so the bootstrap survives even if the plugin
hook fires late or OpenCode skips it for any reason.

**b. Skill discovery / path registration.**
Via the `config` hook, register the canonical `skills/` directory so SKILL.md
files appear in OpenCode's native `skill` tool listing. Path is resolved at
load time via `import.meta.url`:
- `kk.ts` lives at `<plugin-root>/plugins/opencode/runtime/kk.ts`.
- The skills path is `<plugin-root>/skills/`, computed by walking up three
  levels from `import.meta.url` and appending `skills`.
- No hardcoded paths; no symlinks.

**c. Capy context-protection — split into two independent hooks.**

The existing Claude-side protection is implemented in two places, with two
different concerns:

1. **File-path denylist** — in `plugins/claude/scripts/validate-bash.sh`.
   Blocks access to `.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`,
   `node_modules`, `__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`
   via the PreToolUse hook.

2. **Capy HTTP/output routing** — in `.claude/capy/CLAUDE.md` (injected
   context, loaded via `@.claude/capy/CLAUDE.md` in the project CLAUDE.md).
   Blocks `curl`/`wget`/inline-HTTP and `WebFetch`; provides routing guidance
   for high-output commands.

OpenCode reproduces both, as two independent logical hooks inside `kk.ts`:

**c1. File-path denylist** — `tool.execute.before` on `bash`:
- Mirror the FORBIDDEN_PATTERNS array from `validate-bash.sh` verbatim.
- When a bash command matches any pattern, block by
  `throw new Error("Access to '<pattern>' is blocked by security policy")`.
  **Blocking is done by throwing** — returning a message does not block.
- Also consider applying the denylist to `read` via `tool.execute.before` on
  `read`, to cover file-pattern deny rules expressed in `.claude/settings.json`
  that OpenCode's `read` permission may not handle natively.

**c2. Capy HTTP routing** — `tool.execute.before` on `bash` and `webfetch`:
- On `bash`: match `curl` or `wget` in the command →
  `throw new Error("curl/wget blocked — use capy_fetch_and_index(url, source) instead")`.
- On `bash`: match inline-HTTP patterns (`fetch('http`, `requests.get(`,
  `requests.post(`, `http.get(`, `http.request(`) →
  `throw new Error("inline HTTP blocked — use capy_execute(language, code) in the sandbox")`.
- On `webfetch`: unconditionally →
  `throw new Error("webfetch blocked — use capy_fetch_and_index(url, source) then capy_search(queries)")`.

Optional: `tool.execute.after` on `bash` that appends non-blocking guidance if
stdout exceeds ~20 lines (matches the tone of the Claude SessionStart hook).

**d. Tool-name-mapping safety net.**
A small mapping table appended to the system prompt at session start, so that
if a skill body accidentally references a Claude-tool name the linter missed
(e.g., `Read`), the agent still resolves it to the OpenCode equivalent.

### 6.3 Dependencies

Root-level `package.json` declares `@opencode-ai/plugin` as a dependency and
points `main` at `plugins/opencode/runtime/kk.ts` (or a compiled JS if the
setup requires it — decision during Phase 4). OpenCode's loader runs
`bun install` at startup (documented in their plugin docs). No additional
toolchain required in the main repo beyond what Bun handles.

## 7. Commands, agents, hooks — per-provider specifics

### 7.1 Commands

| Existing Claude command       | OpenCode port                                            | `agent` frontmatter |
|-------------------------------|----------------------------------------------------------|---------------------|
| `/chain-of-verification`      | `plugins/opencode/commands/chain-of-verification.md`     | `build`             |
| `/review-code`                | `plugins/opencode/commands/review-code.md`               | `plan` (read-only analysis) |
| `/review-spec`                | `plugins/opencode/commands/review-spec.md`               | `plan`              |
| `/migrate-from-taskmaster`    | `plugins/opencode/commands/migrate-from-taskmaster.md`   | `build`             |
| `/sync-workflow`              | `plugins/opencode/commands/sync-workflow.md`             | `build`             |

Rationale: review commands (`review-code`, `review-spec`) run
under `plan` because they should not modify files. The rest run under `build`
so they can execute the multi-step workflow they drive. The mapping can be
adjusted during Phase 5 if initial testing reveals a better fit, but the
default is locked here to avoid implementer guesswork.

Each command body is a short prompt that invokes the relevant skill or
sub-agent using OpenCode conventions. `$ARGUMENTS` is used where the Claude
version accepts args.

### 7.2 Agents

Existing Claude sub-agents (`code-reviewer`, `spec-reviewer`, `design-reviewer`)
are re-authored as OpenCode markdown agents with frontmatter specifying:
- `description`
- `mode: subagent`
- `model`
- `temperature` (if relevant)
- `tools: { write: false, edit: false, bash: false }` for read-only reviewers
- `permission` block for finer-grained control

Content bodies are copied from the Claude agent files with tool names
lowercased.

The system agents (OpenCode's built-in `build`, `plan`, `general`, `explore`,
`compaction`, `title`) are **not** shipped by us — users already have them.

### 7.3 Hooks

There is no shared `hooks.json` analog. OpenCode expresses hook intent inside
the JS plugin (see 6.2). Claude's `plugins/claude/hooks/hooks.json` and
`scripts/validate-bash.sh` stay where they are.

## 8. Configuration parity

### 8.1 MCP servers

- **Claude**: `.mcp.json` unchanged (capy entry).
- **OpenCode**: `plugins/opencode/opencode.jsonc` declares the same capy server
  in OpenCode's `mcp` block. The capy MCP server itself is provider-agnostic
  (MCP is the contract). The *routing rules* that differ between providers
  live in the respective `reference/<provider>.md` files and the OpenCode JS
  plugin's bootstrap text — not in the server.
- **Capy script placement**: capy's install script location is capy's own
  concern. The preferred outcome is upstream capy placing the script at an
  OpenCode-appropriate path (e.g. `.opencode/scripts/capy.sh`), which we file
  as an upstream issue. **Fallback if upstream hasn't shipped OpenCode-aware
  placement when this feature lands:** `plugins/opencode/opencode.jsonc`
  ships with the capy `mcp.command` array set to a placeholder path (e.g.
  `["bash", "${CAPY_SCRIPT_PATH:-.claude/scripts/capy.sh}", "serve"]`) and
  the plugin README instructs users to either (a) run capy's Claude-install
  flow and point `CAPY_SCRIPT_PATH` at the resulting script, or (b) set an
  absolute path manually. This keeps the feature functional even if the
  upstream issue is not yet resolved.

### 8.2 Permissions

- **Claude**: existing allow/deny lists in `.claude/settings.json` — unchanged.
- **OpenCode**: equivalent intent expressed in `opencode.jsonc` `permission`
  block. File-pattern deny rules that OpenCode's `read` permission doesn't
  natively support are enforced by a `tool.execute.before` hook in the JS
  plugin.

Mapping examples documented in `plugins/opencode/README.md`:
- Claude `Bash(rm:*)` deny → OpenCode `bash: { "rm *": "deny" }`.
- Claude WebFetch deny-with-redirect → OpenCode `webfetch: "deny"` + plugin
  intercept.

### 8.3 Settings that don't port

- Claude's `statusline` config — no OpenCode analog.
- Claude-specific env vars (`CLAUDE_STATUSLINE_*`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`).
- Claude's `enabledPlugins`, `extraKnownMarketplaces`.

## 9. Capy on OpenCode

Capy's context-protection regime is reproduced faithfully on OpenCode:

1. **MCP server**: same capy server, registered via `opencode.jsonc` `mcp` block.
2. **Routing rules**: documented in two places with lowercase OpenCode tool
   names — the OpenCode JS plugin's bootstrap injection, and each skill's
   `reference/opencode.md` where the skill-specific rules apply.
3. **Hooks**: Claude's PreToolUse → `validate-bash.sh` behavior is reproduced
   by the OpenCode JS plugin's `tool.execute.before` on `bash` and `webfetch`.
4. **Output constraints**: the skills' generic "under 500 words" / "write
   artifacts to files" rules stay in SKILL.md, unchanged.

## 10. Codex forward-compatibility

Codex's ecosystem is skills-only: it has native skill discovery at
`~/.agents/skills/` but no commands, agents, or hooks surface comparable to
Claude/OpenCode.

When Codex support is added in a later feature:

1. `plugins/codex/README.md` documents a one-line install (`ln -s $repo/skills
   ~/.agents/skills/kk`).
2. `reference/codex.md` files in each skill get fleshed out.
3. Bootstrap-identity statement goes into the user's `~/.codex/AGENTS.md` per
   install doc.
4. No code artifacts — no JS plugin, no commands dir, no agents dir.

This design ensures Codex needs no changes to skills or to the repo structure
to land.

## 11. Migration and compatibility

### 11.1 External contract (preserved)

`.claude-plugin/marketplace.json`'s plugin array remains a single `kk` entry.
Only the `source` path changes from `./klaude-plugin` to `./plugins/claude`.
External consumers installing via `kk@claude-toolbox` are not affected.

### 11.2 Local clones (one-shot migration)

Contributors with local clones update paths once. The README "Migration from
pre-opencode layout" section explains:
- `klaude-plugin/` → `plugins/claude/`
- `klaude-plugin/skills/` → `skills/` (physical move at repo root, referenced
  from Claude side via symlink)
- New `plugins/opencode/` tree + root-level `package.json`
- Updated `.claude-plugin/marketplace.json` `source` path

**For contributors with local skill customizations:**
- `git log --follow` may not survive the rename + content rewrite cleanly. If
  you need blame history for skill files, run `git log -- klaude-plugin/skills/<name>/SKILL.md`
  against a pre-migration commit.
- If you have uncommitted edits in `klaude-plugin/skills/<name>/SKILL.md`,
  stash them before pulling, then apply them to the new `skills/<name>/SKILL.md`.
  The file will have been refactored for provider neutrality; your edits may
  need reformulation (e.g., if your edit mentioned `Read`, rephrase to "read
  the file" or move the Claude-specific wording into `reference/claude.md`).
- If you have local edits to files under `skills/<name>/reference/<lang>/`
  (review-code language checklists), those subdirs are renamed to
  `checklists/<lang>/` — move your edits accordingly.
- If you added a custom skill not in the main repo, recreate the same shape
  under `skills/<name>/` with `reference/{claude,opencode,codex}.md` files.
  The reference files are mandatory going forward (see lint in Phase 9).

No compat shims or symlinks for the old layout are kept.

### 11.3 Template-sync

The template-sync feature (`test/` + its helper script) is updated to know
about both plugin trees and the canonical `skills/` path. Existing downstream
projects receive the new layout on next sync; any user customizations remain
under their project-local paths.

## 12. Risks and open questions

- **Symlink handling in Claude Code's plugin system (Claude side).** The
  design assumes the Claude plugin loader follows `plugins/claude/skills` →
  `../../skills`. If testing reveals it does not, fallback is a post-install
  script inside the plugin that copies skills on first load. OpenCode side
  does NOT rely on symlinks (see §5 distribution model).
- **`experimental.chat.system.transform` stability.** The hook is prefixed
  `experimental` in OpenCode. The plugin must degrade gracefully if the hook
  is unavailable (skip injection with a warning; users still have the
  belt-and-suspenders `AGENTS.md` template). `plugins/opencode/README.md`
  documents the minimum OpenCode version tested.
- **Claude plugin CLAUDE.md injection.** `plugins/claude/.claude-plugin/plugin.json`
  does not have a field for injecting a CLAUDE.md at plugin load (verified
  from the existing schema). The provider-identity bootstrap on Claude
  therefore relies on the **project-level `CLAUDE.md`** containing the
  statement — there is no plugin-level fallback. This is documented
  prominently in `plugins/claude/README.md`; the plugin installer flow
  instructs users to add the statement to their project CLAUDE.md (or
  auto-append it on first run via a one-off helper).
- **OpenCode's file-pattern permissions on `read`.** Unclear from docs whether
  glob-based denylist on `read` is natively supported. If not, the JS plugin
  enforces file-path denies via `tool.execute.before` on `read` (throws on
  match).
- **Content drift between `reference/claude.md` and `reference/opencode.md`.**
  Mitigated by CI lints (forbidden-literal check in SKILL.md, presence-check
  for each provider reference file, "exactly one pointer line per SKILL.md"
  check). Does not prevent semantic drift — that is a code-review concern.
- **`kk:` namespace on OpenCode.** OpenCode surfaces skills as bare names
  (`design`, not `kk:design`). Acceptable naming
  divergence between providers; documented in `plugins/opencode/README.md`.
- **Template-sync entry point.** The current repo may not have a single
  `docs/update.sh`; template-sync logic lives in the `test/` suite plus
  associated helper scripts (see `test/helpers.sh`). Phase 9 locates the
  actual sync entry during implementation and updates the right file.
