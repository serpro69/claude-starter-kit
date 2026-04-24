# Tasks: Codex Support

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-24

## Task 1: Repository restructure
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#phase-1-restructure](./implementation.md#phase-1-restructure)

### Subtasks
- [ ] 1.1 Move every `klaude-plugin/skills/<name>/` to the new top-level `skills/<name>/`
- [ ] 1.2 Move every `klaude-plugin/profiles/<name>/` to the new top-level `profiles/<name>/` (six skills reference profiles via `${CLAUDE_PLUGIN_ROOT}/profiles/`; shared location eliminates cross-plugin path dependencies)
- [ ] 1.3 Move remaining `klaude-plugin/` → `plugins/claude/` preserving all contents (`commands/`, `agents/`, `hooks/`, `scripts/`, `.claude-plugin/plugin.json`, `README.md`)
- [ ] 1.4 Create relative symlinks: `plugins/claude/skills` → `../../skills` and `plugins/claude/profiles` → `../../profiles`
- [ ] 1.5 Update `.claude-plugin/marketplace.json`: change the `kk` plugin's `source` from `./klaude-plugin` to `./plugins/claude`
- [ ] 1.6 Grep the repo for all hard-coded `klaude-plugin/` path references in scripts, docs, tests, CLAUDE.md, ADRs; update each to `plugins/claude/`. **Exception:** `template-sync.sh`'s `run_plugin_migration` `dirs_to_remove` — keep old names (historical downstream cleanup paths)
- [ ] 1.7 Update `CLAUDE.md` — all `klaude-plugin/` references become `plugins/claude/`, all `klaude-plugin/skills/` references become `skills/`, all `klaude-plugin/profiles/` references become `profiles/`
- [ ] 1.8 Verify: `jq . .claude-plugin/marketplace.json` exits 0; `file plugins/claude/skills` and `file plugins/claude/profiles` both report symlink; `ls profiles/*/DETECTION.md | head` lists profiles; `for test in test/test-*.sh; do $test; done` exits 0

## Task 2: Codex plugin scaffold
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-2-plugin-scaffold](./implementation.md#phase-2-plugin-scaffold)

### Subtasks
- [ ] 2.1 Create `plugins/codex/.codex-plugin/plugin.json` with manifest: `name: "kk"`, `version: "0.1.0"`, `skills: "./skills/"`, `mcpServers: "./.mcp.json"`, plus metadata fields (description, repository, license, keywords)
- [ ] 2.2 Create relative symlink `plugins/codex/skills` → `../../skills`
- [ ] 2.3 Create `plugins/codex/.mcp.json` with capy MCP server config (investigate codex plugin `.mcp.json` schema from docs)
- [ ] 2.4 Create `.agents/plugins/marketplace.json` with marketplace entry for the `kk` plugin pointing at `./plugins/codex`
- [ ] 2.5 Create `plugins/codex/README.md` — installation via `codex plugin marketplace add`, skill listing, updating, troubleshooting, minimum codex version, no-sparse note
- [ ] 2.6 Verify: `jq . plugins/codex/.codex-plugin/plugin.json` exits 0; `ls plugins/codex/skills/*/SKILL.md | head` lists skills; `jq . .agents/plugins/marketplace.json` exits 0
- [ ] 2.7 Test symlink: if possible, install into a scratch codex session via `codex plugin marketplace add <repo>#<branch>`. If symlink doesn't resolve, implement copy fallback and document in design.md §4.3

## Task 3: AGENTS.md and SessionStart hook
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-3-bootstrap](./implementation.md#phase-3-bootstrap)

### Subtasks
- [ ] 3.1 Create `AGENTS.md` at repo root — provider identity block, behavioral instructions (port from `.claude/CLAUDE.extra.md`), capy routing rules (replicate from `.claude/capy/CLAUDE.md`). Use `%PROJECT_NAME%` placeholder for template-sync substitution
- [ ] 3.2 Create `.codex/scripts/session-start.sh` — shell script emitting `SessionStart` JSON with `additionalContext` containing: provider identity, tool-name mapping table (Read→read_file, Write→write_file, Edit→apply_patch, Bash→shell, Grep→shell+grep, Glob→shell+find, WebSearch→web_search, WebFetch→capy, Agent/Task→natural-language subagent spawning, Skill→$mention), `${CLAUDE_PLUGIN_ROOT}` path resolution (compute absolute repo root from script location, map to `<repo-root>/plugins/claude` for plugin refs and `<repo-root>/profiles/` for profile refs), capy routing rules, sub-agent roster (all five agents)
- [ ] 3.3 Create `.codex/hooks.json` using Codex's hook schema — event names as top-level keys, matcher groups with nested hook handlers: `{"SessionStart": [{"matcher": "startup|resume", "hooks": [{"type": "command", "command": ".codex/scripts/session-start.sh"}]}]}`
- [ ] 3.4 Create `.codex/config.toml` with initial `[features] codex_hooks = true`
- [ ] 3.5 Verify: `bash .codex/scripts/session-start.sh < /dev/null | jq .` exits 0 with valid JSON; in a codex session, provider identity appears

## Task 4: PreToolUse hooks
- **Status:** pending
- **Depends on:** Task 3
- **Docs:** [implementation.md#phase-4-pretooluse](./implementation.md#phase-4-pretooluse)

### Subtasks
- [ ] 4.1 Create `.codex/scripts/pretooluse-bash.sh` — reads `tool_input.command` from stdin JSON; checks file-path denylist (FORBIDDEN_PATTERNS ported from `plugins/claude/scripts/validate-bash.sh`: `.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`, `node_modules`, `__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`) and capy HTTP patterns (`curl`/`wget`, `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(`); emits `permissionDecision: "deny"` JSON on match, exits 0 with no output on pass-through
- [ ] 4.2 Update `.codex/hooks.json` — add `PreToolUse` matcher group using Codex hook schema: `{"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".codex/scripts/pretooluse-bash.sh"}]}]}` alongside existing SessionStart entry
- [ ] 4.3 Verify: `echo '{"tool_input":{"command":"cat .env"}}' | bash .codex/scripts/pretooluse-bash.sh | jq .hookSpecificOutput.permissionDecision` outputs `"deny"`; same for `curl https://example.com`; `echo '{"tool_input":{"command":"ls"}}' | bash .codex/scripts/pretooluse-bash.sh` produces no output with exit 0

## Task 5: Sub-agents
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-5-agents](./implementation.md#phase-5-agents)

### Subtasks
- [ ] 5.1 Read all five Claude agent files in `plugins/claude/agents/` (`code-reviewer.md`, `spec-reviewer.md`, `design-reviewer.md`, `eval-grader.md`, `profile-resolver.md`) to extract prompt bodies
- [ ] 5.2 Create `.codex/agents/code-reviewer.toml` — `name = "code-reviewer"`, `sandbox_mode = "read-only"`, `model = "gpt-5.5"`, `model_reasoning_effort = "high"`, `developer_instructions` carrying the review prompt adapted from the Claude agent
- [ ] 5.3 Create `.codex/agents/spec-reviewer.toml` — same pattern
- [ ] 5.4 Create `.codex/agents/design-reviewer.toml` — same pattern
- [ ] 5.5 Create `.codex/agents/eval-grader.toml` — same pattern
- [ ] 5.6 Create `.codex/agents/profile-resolver.toml` — same pattern
- [ ] 5.7 Verify: each TOML file parses cleanly (`python3 -c "import tomllib; tomllib.load(open('<file>','rb'))"` exits 0 for each); in a codex session, spawning code-reviewer produces review output in read-only mode

## Task 6: Starlark rules
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-6-rules](./implementation.md#phase-6-rules)

### Subtasks
- [ ] 6.1 Read `.claude/settings.json` `permissions.deny` array to extract denied commands. **Only `Bash(...)` entries are ported here** — `Read(...)` entries are handled by PreToolUse hook (Task 4) and SessionStart advisory context (Task 3); see design.md §7.3
- [ ] 6.2 Create `.codex/rules/default.rules` — one `prefix_rule()` per `Bash(...)` denied command with `decision = "deny"`, `justification`, and at least one `match`/`not_match` inline test case. Port "ask" commands as `decision = "prompt"`
- [ ] 6.3 Verify: `codex execpolicy check --pretty --rules .codex/rules/default.rules -- rm -rf /tmp/test` shows `deny`; `codex execpolicy check --pretty --rules .codex/rules/default.rules -- ls` shows `allow`

## Task 7: Statusline configuration
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-7-statusline](./implementation.md#phase-7-statusline)

Codex's `tui.status_line` is an `array<string>` of built-in item identifiers — it does not support custom command-driven scripts. No custom script is created.

### Subtasks
- [ ] 7.1 Update `.codex/config.toml` — add `[tui] status_line = ["model-with-reasoning", "current-dir"]` to configure the best available built-in items
- [ ] 7.2 Verify: in a codex session, statusline footer displays model and directory info

## Task 8: Template-sync extension
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7
- **Docs:** [implementation.md#phase-8-template-sync](./implementation.md#phase-8-template-sync)

### Subtasks
- [ ] 8.1 Update `.github/scripts/template-sync.sh` — add `.codex/` to sparse-clone file list; add `AGENTS.md` to root-level files; add strip rules excluding `.codex/scripts/capy.sh` from sync (per-repo, same as Claude side); add variable substitution for `.codex/config.toml` and `AGENTS.md`
- [ ] 8.2 Add codex-specific manifest variables to `docs/template-sync/template-state-schema.json` (the actual schema source): `CODEX_MODEL`, `CODEX_APPROVAL_POLICY` — all optional with sensible defaults. Also update `.github/template-state.example.json` and any relevant test fixtures
- [ ] 8.3 Update `.github/workflows/template-sync.yml` — add codex variable backfilling to manifest migration; add `.codex/` to commit/PR diff scope
- [ ] 8.4 Verify: dry-run template-sync on a test downstream repo — `.codex/` files appear in diff; downstream repo without codex variables syncs cleanly

## Task 9: Config.toml finalization
- **Status:** pending
- **Depends on:** Task 3, Task 4, Task 7
- **Docs:** [implementation.md#phase-9-config](./implementation.md#phase-9-config)

### Subtasks
- [ ] 9.1 Finalize `.codex/config.toml` with all sections. **TOML scoping:** top-level settings (`model`, `model_reasoning_effort`, `approval_policy`, `sandbox_mode`) MUST appear before any `[table]` header — bare keys after `[features]` would be scoped as `features.model` etc. Order: top-level keys → `[features]` → `[agents]` → `[tui]` → `[mcp_servers.capy]`. Add template-sync variable placeholders where applicable
- [ ] 9.2 Verify: TOML parses cleanly (`python3 -c "import tomllib; ..."` exits 0); in a codex session, model and feature flags are active

## Task 10: Tests, documentation, and ADR
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9
- **Docs:** [implementation.md#phase-10-tests-docs](./implementation.md#phase-10-tests-docs)

### Subtasks
- [ ] 10.1 Update `test/test-plugin-structure.sh` — all `klaude-plugin/` path references become `plugins/claude/`; update `EXPECTED_*` arrays; add assertions for `skills/` and `profiles/` at repo root
- [ ] 10.2 Create `test/test-codex-structure.sh` — assert all codex files exist and validate (plugin.json, config.toml, hooks.json, five agent TOMLs, rules file, marketplace.json, AGENTS.md, skills symlink/dir, claude skills symlink, claude profiles symlink)
- [ ] 10.3 Update `README.md` — new "Providers" section with install paths for Claude and Codex; "Migration from pre-restructure layout" subsection
- [ ] 10.4 Update `plugins/claude/README.md` — path updates only
- [ ] 10.5 Write `docs/adr/0005-codex-hook-enforcement-gap.md` (already created alongside this task list — verify content is accurate post-implementation)
- [ ] 10.6 Verify: `for test in test/test-*.sh; do $test; done` exits 0

## Task 11: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10

### Subtasks
- [ ] 11.1 Run `test` skill — full test suite passes including new codex structure checks and updated plugin structure checks
- [ ] 11.2 Run `document` skill — verify README, plugin READMEs, and AGENTS.md are accurate and internally consistent
- [ ] 11.3 Run `review-code` skill on the new shell scripts, TOML files, Starlark rules, and JSON configs
- [ ] 11.4 Run `review-spec` skill to verify implementation matches design.md and implementation.md
- [ ] 11.5 Smoke test from a codex session: install via `codex plugin marketplace add <repo>#<branch>`; skills discoverable via `/skills`; SessionStart hook injects provider identity and tool mapping; PreToolUse blocks `cat .env` and `curl`; sub-agents spawnable; capy MCP tools callable
