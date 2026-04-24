# Implementation Plan: Codex Support

> Design: [./design.md](./design.md)
> Status: draft
> Created: 2026-04-24

This plan assumes the implementer is an experienced shell/TOML/Starlark
developer, comfortable with Claude Code's plugin system, and willing to
consult the [Codex docs](https://developers.openai.com/codex/) for specific
API surfaces. Zero project-specific context is assumed.

Phases are ordered so each merges independently. Every phase maps to 1–3
atomic commits (tasks.md defines the exact breakdown).

---

## Phase 1: Repository restructure {#phase-1-restructure}

**Goal:** Move skills and profiles to repo root, rename `klaude-plugin/` to
`plugins/claude/`, and set up symlinks. No behavioral change yet.

**Files to touch:**

- Move `klaude-plugin/skills/*/` → `skills/*/` (physical move to repo root).
- Move `klaude-plugin/profiles/*/` → `profiles/*/` (physical move to repo
  root). Six skills reference profiles via `${CLAUDE_PLUGIN_ROOT}/profiles/`;
  a canonical shared location eliminates cross-plugin path dependencies.
- Move remaining `klaude-plugin/` → `plugins/claude/`. Preserve all
  sub-directories (`commands/`, `agents/`, `hooks/`, `scripts/`,
  `.claude-plugin/plugin.json`, `README.md`).
- Create relative symlinks:
  - `plugins/claude/skills` → `../../skills`
  - `plugins/claude/profiles` → `../../profiles`
- Update `.claude-plugin/marketplace.json`: change the `kk` plugin's
  `source` from `./klaude-plugin` to `./plugins/claude`.
- Grep the repo for all hard-coded `klaude-plugin/` path references
  (scripts, docs, tests, CLAUDE.md, ADRs, examples). Update each.
  **Exception:** `template-sync.sh`'s `run_plugin_migration`
  `dirs_to_remove` — those are historical cleanup paths for downstream
  projects and must retain the old names.
- Update `CLAUDE.md` references to `klaude-plugin/` paths.

**Verification:**

- `.claude-plugin/marketplace.json` still validates as JSON and the plugin
  resolves via `kk@claude-toolbox`.
  → verify: `jq . .claude-plugin/marketplace.json` exits 0; open a Claude
  session and confirm skills are discoverable.
- `git ls-tree HEAD plugins/claude/skills` shows symlink mode `120000`.
  → verify: `file plugins/claude/skills` reports "symbolic link".
- `file plugins/claude/profiles` reports "symbolic link" pointing at
  `../../profiles`.
  → verify: `ls profiles/*/DETECTION.md | head` lists profile files.
- All tests pass: `for test in test/test-*.sh; do $test; done` exits 0.
  → verify: exit code 0, no assertion failures.

---

## Phase 2: Codex plugin scaffold {#phase-2-plugin-scaffold}

**Goal:** Create the codex plugin structure with manifest, marketplace, and
skills symlink. No hooks or config yet.

**Files to create:**

- `plugins/codex/.codex-plugin/plugin.json` — manifest:
  ```json
  {
    "name": "kk",
    "version": "0.1.0",
    "description": "Workflow skills for software engineering: design, implement, review, test, document.",
    "skills": "./skills/",
    "mcpServers": "./.mcp.json",
    "repository": "https://github.com/serpro69/claude-toolbox",
    "license": "MIT",
    "keywords": ["workflow", "skills", "code-review", "design"]
  }
  ```
- `plugins/codex/skills` — relative symlink → `../../skills/`.
- `plugins/codex/.mcp.json` — capy MCP server config. Format TBD during
  implementation (codex plugin `.mcp.json` schema is not fully documented;
  investigate the codex MCP docs for the expected shape).
- `.agents/plugins/marketplace.json` — marketplace entry pointing at
  `./plugins/codex` (see design.md §5.1).
- `plugins/codex/README.md` — installation instructions: marketplace add
  command, skill listing, updating, troubleshooting, minimum codex version
  tested, note about `--sparse` not being supported.

**Verification:**

- `jq . plugins/codex/.codex-plugin/plugin.json` exits 0.
  → verify: valid JSON.
- `plugins/codex/skills` resolves to a directory containing SKILL.md files.
  → verify: `ls plugins/codex/skills/*/SKILL.md | head` lists skills.
- `jq . .agents/plugins/marketplace.json` exits 0.
  → verify: valid JSON with `kk` plugin entry.
- If possible, test installing into a scratch codex session via
  `codex plugin marketplace add <repo>#<branch>`. If the symlink doesn't
  work, implement the copy fallback (see design.md §4.3) and re-test.
  → verify: codex discovers skills from the plugin.

---

## Phase 3: AGENTS.md and SessionStart hook {#phase-3-bootstrap}

**Goal:** Codex sessions get provider identity, tool-name mapping, capy
routing rules, and sub-agent roster injected at session start.

**Files to create:**

- `AGENTS.md` (repo root) — provider identity block, behavioral instructions
  (ported from `.claude/CLAUDE.extra.md`), capy routing rules (replicated
  from `.claude/capy/CLAUDE.md`). Variable `%PROJECT_NAME%` placeholder for
  template-sync substitution.
- `.codex/scripts/session-start.sh` — shell script that emits the
  `SessionStart` JSON with `additionalContext` containing: provider identity,
  tool-name mapping table (design.md §6.2), `${CLAUDE_PLUGIN_ROOT}` path
  resolution (compute absolute repo root from script's own location, map
  `${CLAUDE_PLUGIN_ROOT}` → `<repo-root>/plugins/claude` and profiles →
  `<repo-root>/profiles/`), capy routing rules, sub-agent roster.
- `.codex/hooks.json` — hook configuration using Codex's hook schema.
  Event names are top-level keys; each contains an array of matcher groups
  with nested hook handler entries:
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

**Also touch:**

- `.codex/config.toml` — create initial file with `[features]`
  `codex_hooks = true` to enable the experimental hooks system.

**Verification:**

- `.codex/scripts/session-start.sh` is executable and emits valid JSON
  when run standalone.
  → verify: `bash .codex/scripts/session-start.sh < /dev/null | jq .` exits 0.
- In a codex session, the provider identity and tool mapping appear in
  context.
  → verify: ask "what provider are you running on?" — response should
  mention Codex and the tool mapping.

---

## Phase 4: PreToolUse hooks {#phase-4-pretooluse}

**Goal:** Enforce file-path denylist and capy HTTP routing via PreToolUse
hooks on Bash.

**Files to create:**

- `.codex/scripts/pretooluse-bash.sh` — shell script that reads
  `tool_input.command` from stdin JSON. Checks two categories:
  1. **File-path denylist:** matches against FORBIDDEN_PATTERNS array
     (ported from `plugins/claude/scripts/validate-bash.sh`).
  2. **Capy HTTP routing:** matches `curl`/`wget` and inline-HTTP patterns
     (replicated from `.claude/capy/CLAUDE.md` rules).
  On match, emits `permissionDecision: "deny"` JSON with descriptive reason.
  On no match, exits 0 with no output (pass-through).

**Files to update:**

- `.codex/hooks.json` — add `PreToolUse` matcher group to the existing
  file (alongside SessionStart from Phase 3):
  ```json
  {
    "SessionStart": [ ... ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".codex/scripts/pretooluse-bash.sh"
          }
        ]
      }
    ]
  }
  ```

**Verification:**

- The hook script blocks `cat .env` with the security policy message.
  → verify: `echo '{"tool_input":{"command":"cat .env"}}' | bash .codex/scripts/pretooluse-bash.sh | jq .permissionDecision` outputs `"deny"`.
- The hook script blocks `curl https://example.com` with the capy redirect.
  → verify: same pattern, check reason mentions `capy_fetch_and_index`.
- The hook script passes through `ls`, `git status`.
  → verify: `echo '{"tool_input":{"command":"ls"}}' | bash .codex/scripts/pretooluse-bash.sh` produces no output, exit 0.
- In a codex session, running `cat .env` triggers the deny message.

---

## Phase 5: Sub-agents {#phase-5-agents}

**Goal:** Port all five Claude sub-agents to codex TOML format.

**Files to create under `.codex/agents/`:**

- `code-reviewer.toml` — `sandbox_mode = "read-only"`, review prompt from
  `plugins/claude/agents/code-reviewer.md` adapted with tool-name notes.
- `spec-reviewer.toml` — same pattern.
- `design-reviewer.toml` — same pattern.
- `eval-grader.toml` — same pattern.
- `profile-resolver.toml` — same pattern.

Each file has: `name`, `description`, `sandbox_mode = "read-only"`,
`model` (use a sensible default, e.g., `gpt-5.5`),
`model_reasoning_effort = "high"`, and `developer_instructions` carrying
the prompt body.

**Porting the prompt body:** Copy the Claude agent's markdown body. The
SessionStart hook's tool-name mapping handles most translation. Where the
Claude agent body references Claude-specific constructs explicitly (e.g.,
"use the `Agent` tool with `subagent_type`"), rephrase to codex equivalents
("spawn a subagent with instructions").

**Verification:**

- Each TOML file parses cleanly.
  → verify: a TOML parser (e.g., `python3 -c "import tomllib; ..."`)
  succeeds on each file.
- In a codex session, "spawn the code-reviewer agent" invokes the
  custom agent and produces review output.
  → verify: the agent runs in read-only mode (no file modifications).

---

## Phase 6: Starlark rules {#phase-6-rules}

**Goal:** Port Claude's command deny/ask lists to Starlark rules.

**Files to create:**

- `.codex/rules/default.rules` — one `prefix_rule()` per denied/prompted
  command from `.claude/settings.json`.

**Source of truth:** Read `.claude/settings.json` `permissions.deny` array.
The array contains both `Bash(...)` and `Read(...)` entries. **Only `Bash(...)`
entries are ported here** — Starlark `prefix_rule()` matches shell command
argv only. `Read(...)` entries are handled separately: by the PreToolUse
hook (Phase 4) for shell equivalents like `cat .env`, and by SessionStart
advisory context (Phase 3) for `read_file` — see design.md §7.3.

For each `Bash(...)` entry, create a `prefix_rule` with:
- `pattern` — argv prefix array (e.g., `["rm"]`, `["git", "push", "--force"]`)
- `decision` — `"deny"` for blocked, `"prompt"` for ask
- `justification` — descriptive reason
- `match` / `not_match` — at least one inline test case per rule

**Verification:**

- Each rule validates with codex's policy checker.
  → verify: `codex execpolicy check --pretty --rules .codex/rules/default.rules -- rm -rf /tmp/test` shows `deny` decision.
- Non-matching commands pass through.
  → verify: `codex execpolicy check --pretty --rules .codex/rules/default.rules -- ls` shows `allow` decision.

---

## Phase 7: Statusline configuration {#phase-7-statusline}

**Goal:** Configure codex's built-in statusline with the best available
items.

Codex's `tui.status_line` is an `array<string>` of built-in status item
identifiers — it does not support custom command-driven scripts like Claude.
No custom statusline script is created. See design.md §11 for details.

**Files to update:**

- `.codex/config.toml` — add `[tui]` section with `status_line`:
  ```toml
  [tui]
  status_line = ["model-with-reasoning", "current-dir"]
  ```

**Verification:**

- In a codex session, the statusline displays model and directory info.
  → verify: visual inspection in the TUI footer.

---

## Phase 8: Template-sync extension {#phase-8-template-sync}

**Goal:** Downstream repos receive `.codex/` configs alongside `.claude/`
on template-sync.

**Files to update:**

- `.github/scripts/template-sync.sh`:
  1. Add `.codex/` to the sparse-clone file list.
  2. Add `AGENTS.md` to root-level files.
  3. Add strip rules: exclude `.codex/scripts/capy.sh` from sync (per-repo,
     same as `.claude/scripts/capy.sh`).
  4. Add variable substitution for `.codex/config.toml` and `AGENTS.md`.
  5. Add codex-specific manifest variables: `CODEX_MODEL`,
     `CODEX_APPROVAL_POLICY` — all optional with sensible defaults.

- `.github/workflows/template-sync.yml`:
  1. Add codex variable backfilling to the manifest migration logic.
  2. Add `.codex/` to the commit/PR diff scope.

**Verification:**

- Run template-sync in dry-run mode on a test downstream repo.
  → verify: `.codex/` files appear in the diff output alongside `.claude/`.
- A downstream repo without codex variables in its manifest still syncs
  cleanly (defaults applied or codex files skipped).
  → verify: no errors, no missing-variable failures.

---

## Phase 9: Config.toml finalization {#phase-9-config}

**Goal:** Complete the `.codex/config.toml` template with all sections.

**Files to update:**

- `.codex/config.toml` — add all sections:
  ```toml
  # Top-level settings (MUST appear before any [table] header)
  model = "gpt-5.5"
  model_reasoning_effort = "high"
  approval_policy = "on-request"
  sandbox_mode = "workspace-write"

  [features]
  codex_hooks = true

  [agents]
  max_threads = 6
  max_depth = 1

  [tui]
  status_line = ["model-with-reasoning", "current-dir"]

  [mcp_servers.capy]
  command = "bash"
  args = [".codex/scripts/capy.sh", "serve"]
  ```

  **TOML scoping note:** bare keys after a `[table]` header belong to that
  table. Top-level settings (model, approval_policy, etc.) must appear
  before the first `[table]` declaration, or they will be scoped
  incorrectly (e.g., `features.model` instead of top-level `model`).

  Variable placeholders for template-sync substitution where applicable.

**Verification:**

- The file is valid TOML.
  → verify: `python3 -c "import tomllib; tomllib.load(open('.codex/config.toml','rb'))"` exits 0.
- In a codex session using this config, the model, approval policy, and
  feature flags are active.

---

## Phase 10: Tests and documentation {#phase-10-tests-docs}

**Goal:** Update existing tests, add new codex-specific tests, update
README, write the ADR.

**Test updates:**

- `test/test-plugin-structure.sh` — update all `klaude-plugin/` path
  references to `plugins/claude/`. Update `EXPECTED_*` arrays. Add
  assertions for `skills/` at repo root.

**New tests (add to `test/`):**

- `test/test-codex-structure.sh`:
  - Assert `plugins/codex/.codex-plugin/plugin.json` exists and validates.
  - Assert `.codex/config.toml` exists.
  - Assert `.codex/hooks.json` validates as JSON.
  - Assert all five `.codex/agents/*.toml` files exist.
  - Assert `.codex/rules/default.rules` exists.
  - Assert `.agents/plugins/marketplace.json` exists with `kk` entry.
  - Assert `plugins/codex/skills` resolves (symlink or directory).
  - Assert `AGENTS.md` exists at repo root.
  - Assert `plugins/claude/skills` is a relative symlink to `../../skills`.

**Documentation:**

- `README.md` — new "Providers" section with install paths for Claude and
  Codex. "Migration from pre-restructure layout" subsection.
- `plugins/codex/README.md` — installation, updating, uninstalling,
  troubleshooting, minimum codex version, no-sparse note.
- `plugins/claude/README.md` — update paths only.
- `CLAUDE.md` — update all `klaude-plugin/` references to `plugins/claude/`.

**ADR:**

- `docs/adr/0005-codex-hook-enforcement-gap.md` — documents the gap in
  codex hook coverage, why it's acceptable, and the mitigation strategy
  (advisory via SessionStart context). See design.md §7.3.

**Verification:**

- `for test in test/test-*.sh; do $test; done` exits 0.

---

## Phase 11: Final verification {#phase-11-verification}

Runs after every other phase merges.

- Run `test` skill — full test suite passes, including new codex structure
  checks and updated plugin structure checks.
- Run `document` skill — verify README sections, plugin READMEs, and
  AGENTS.md are accurate and internally consistent.
- Run `review-code` skill on the new shell scripts and TOML/Starlark files.
- Run `review-spec` skill to verify the implementation matches this plan
  and `design.md`.
- Smoke test from a codex session:
  - Install via `codex plugin marketplace add <repo>#<branch>`.
  - Skills are discoverable via `/skills`.
  - SessionStart hook injects provider identity and tool mapping.
  - PreToolUse hook blocks `cat .env` and `curl https://...`.
  - Sub-agents are spawnable (`code-reviewer`, etc.).
  - Capy MCP tools are callable.

---

## Appendix: ordering, dependencies, and parallelization

- **Phase 1** must land before anything else (path invariants).
- **Phase 2** (codex plugin scaffold) depends on Phase 1.
- **Phase 3** (bootstrap) depends on Phase 1 (needs `.codex/` directory).
- **Phases 4, 5, 6** can proceed in parallel after Phase 3 (each is
  independent: hooks, agents, rules).
- **Phase 7** (statusline) is config-only, can proceed any time after
  Phase 1.
- **Phase 8** (template-sync) depends on Phases 1–7 (needs all files in
  place to know what to sync).
- **Phase 9** (config.toml) depends on Phases 3, 4, 7 (hooks, statusline
  config).
- **Phase 10** (tests/docs/ADR) depends on all prior phases.
- **Phase 11** last.
