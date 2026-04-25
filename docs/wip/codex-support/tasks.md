# Tasks: Codex Support

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending (v2 — reworked)
> Created: 2026-04-24
> Updated: 2026-04-25

## Task 0: Revert repository restructure
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#phase-0-revert](./implementation.md#phase-0-revert)
- **Note:** User will perform this revert manually.

### Subtasks
- [ ] 0.1 Revert the commit that moved skills/profiles to repo root and renamed `klaude-plugin/` to `plugins/claude/`
- [ ] 0.2 Verify `klaude-plugin/` is restored with skills, profiles, agents, commands, hooks, scripts
- [ ] 0.3 Verify `.claude-plugin/marketplace.json` source points at `./klaude-plugin`
- [ ] 0.4 Verify all existing tests pass: `for test in test/test-*.sh; do $test; done` exits 0

## Task 1: Generation tool (`cmd/generate-kodex/`)
- **Status:** pending
- **Depends on:** Task 0
- **Docs:** [implementation.md#phase-1-generate-tool](./implementation.md#phase-1-generate-tool)

### Subtasks
- [ ] 1.1 Create `cmd/generate-kodex/manifest.go` — YAML manifest parsing with schema matching design.md §5.2 (source_plugin, target_plugin, skills transforms, shared handling, manifest generation config, MCP config)
- [ ] 1.2 Create `cmd/generate-kodex/transforms.go` — transform implementations: `plugin_root_resolve` (replace `${CLAUDE_PLUGIN_ROOT}` with relative path from target to source plugin), `inject_header` (prepend content to files)
- [ ] 1.3 Create `cmd/generate-kodex/skills.go` — skill generation: copy entire skill directories from `klaude-plugin/skills/*/` to `kodex-plugin/skills/*/`, apply transform pipeline to SKILL.md, copy auxiliary files (process docs, isolated workflow files, evals) as-is (verified: no `${CLAUDE_PLUGIN_ROOT}` in auxiliary files)
- [ ] 1.4 Create `cmd/generate-kodex/shared.go` — copy `klaude-plugin/skills/_shared/` to `kodex-plugin/skills/_shared/`. Handle per-skill symlinks to `_shared/` (preserve if they survive codex cache testing, otherwise resolve to copies)
- [ ] 1.5 Create `cmd/generate-kodex/agents.go` — agent generation: read each `klaude-plugin/agents/*.md`, extract markdown body (strip frontmatter), apply `plugin_root_resolve` transform, wrap in TOML structure (`name`, `description`, `sandbox_mode = "read-only"`, `model`, `model_reasoning_effort`, `developer_instructions`), write to `.codex/agents/*.toml`
- [ ] 1.6 Create `cmd/generate-kodex/manifest_gen.go` — generate `kodex-plugin/.codex-plugin/plugin.json` from source plugin manifest + overrides from generation manifest
- [ ] 1.7 Create `cmd/generate-kodex/mcp.go` — generate `kodex-plugin/.mcp.json` from manifest config
- [ ] 1.8 Create `cmd/generate-kodex/main.go` — CLI entry point with flags: `-manifest` (required), `-target` (default: `kodex-plugin`), `-dry-run`
- [ ] 1.9 Create `scripts/kodex-generate-manifest.yml` — generation manifest declaring all skills, transforms, agent config, manifest config, MCP config
- [ ] 1.10 Create tests: `cmd/generate-kodex/*_test.go` with testdata fixtures. Cover: manifest parsing, each transform, skill generation, shared dir copy, agent generation (.md → .toml), manifest generation, MCP generation, end-to-end with dry-run
- [ ] 1.11 Run generation and verify: `kodex-plugin/skills/` contains all SKILL.md files; `.codex/agents/` contains all five TOML files; no `${CLAUDE_PLUGIN_ROOT}` literals in generated output; `.codex-plugin/plugin.json` and `.mcp.json` validate as JSON; each TOML parses cleanly
- [ ] 1.12 Commit generated `kodex-plugin/` and `.codex/agents/` output

## Task 2: Makefile integration
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-2-makefile](./implementation.md#phase-2-makefile)

### Subtasks
- [ ] 2.1 Add `generate-kodex` target to `Makefile`: runs `go test`, then `go run`, then `make test-structure`
- [ ] 2.2 Add `generate-all` target combining `vendor-profiles` and `generate-kodex`
- [ ] 2.3 Verify: `make generate-kodex` succeeds; modifying a SKILL.md in `klaude-plugin/` then running `make generate-kodex` produces a diff in `kodex-plugin/`

## Task 3: Codex marketplace
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-3-marketplace](./implementation.md#phase-3-marketplace)

### Subtasks
- [ ] 3.1 Create `.agents/plugins/marketplace.json` with marketplace entry for `kk` plugin pointing at `./kodex-plugin`
- [ ] 3.2 Create `kodex-plugin/README.md` — installation via `codex plugin marketplace add`, skill listing, updating, troubleshooting, minimum codex version, no-sparse note
- [ ] 3.3 Verify: `jq . .agents/plugins/marketplace.json` exits 0; path field is `"./kodex-plugin"`

## Task 4: AGENTS.md and SessionStart hook
- **Status:** pending
- **Depends on:** Task 0
- **Docs:** [implementation.md#phase-4-bootstrap](./implementation.md#phase-4-bootstrap)

### Subtasks
- [ ] 4.1 Create `AGENTS.md` at repo root — provider identity block, behavioral instructions (port from `.claude/CLAUDE.extra.md`), capy routing rules (replicate from `.claude/capy/CLAUDE.md`). Use `%PROJECT_NAME%` placeholder for template-sync
- [ ] 4.2 Create `.codex/scripts/session-start.sh` — shell script emitting SessionStart JSON with `additionalContext` containing: provider identity, tool-name mapping table (Read→read_file, Write→write_file, Edit→apply_patch, Bash→shell, Grep→shell+grep, Glob→shell+find, WebSearch→web_search, WebFetch→capy, Agent/Task→natural-language subagent spawning, Skill→$mention), profile/shared-instruction paths resolved to `<repo-root>/klaude-plugin/...`, capy routing rules, sub-agent roster (all five agents)
- [ ] 4.3 Create `.codex/hooks.json` — initial hook config: `{"SessionStart": [{"matcher": "startup|resume", "hooks": [{"type": "command", "command": ".codex/scripts/session-start.sh"}]}]}`
- [ ] 4.4 Create `.codex/config.toml` with initial `[features] codex_hooks = true`
- [ ] 4.5 Verify: `bash .codex/scripts/session-start.sh < /dev/null | jq .` exits 0; output JSON contains tool-name mapping and profile paths

## Task 5: PreToolUse hooks
- **Status:** pending
- **Depends on:** Task 4
- **Docs:** [implementation.md#phase-5-pretooluse](./implementation.md#phase-5-pretooluse)

### Subtasks
- [ ] 5.1 Create `.codex/scripts/pretooluse-bash.sh` — reads `tool_input.command` from stdin JSON; checks file-path denylist (FORBIDDEN_PATTERNS ported from `klaude-plugin/scripts/validate-bash.sh`: `.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`, `node_modules`, `__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`) and capy HTTP patterns (`curl`/`wget`, `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(`); emits `permissionDecision: "deny"` JSON on match, exits 0 with no output on pass-through
- [ ] 5.2 Update `.codex/hooks.json` — add `PreToolUse` matcher group: `{"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".codex/scripts/pretooluse-bash.sh"}]}]}` alongside existing SessionStart entry
- [ ] 5.3 Verify: `echo '{"tool_input":{"command":"cat .env"}}' | bash .codex/scripts/pretooluse-bash.sh | jq .hookSpecificOutput.permissionDecision` outputs `"deny"`; same for `curl https://example.com`; `echo '{"tool_input":{"command":"ls"}}' | bash .codex/scripts/pretooluse-bash.sh` produces no output with exit 0

## Task 6: Sub-agent verification
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-6-agents](./implementation.md#phase-6-agents)
- **Note:** Agent TOML files are generated by the tool (Task 1). This task verifies correctness.

### Subtasks
- [ ] 6.1 Verify all five `.codex/agents/*.toml` files exist and parse cleanly (`python3 -c "import tomllib; tomllib.load(open('<file>','rb'))"` exits 0 for each)
- [ ] 6.2 Verify `developer_instructions` contains the full prompt body from each source agent (no truncation, no missing sections)
- [ ] 6.3 Verify no `${CLAUDE_PLUGIN_ROOT}` literals remain in generated agent files
- [ ] 6.4 Smoke test in a codex session: "spawn the code-reviewer agent" produces review output in read-only mode

## Task 7: Starlark rules
- **Status:** pending
- **Depends on:** Task 0
- **Docs:** [implementation.md#phase-7-rules](./implementation.md#phase-7-rules)

### Subtasks
- [ ] 7.1 Read `.claude/settings.json` `permissions.deny` array to extract denied commands. **Only `Bash(...)` entries are ported** — `Read(...)` entries handled by PreToolUse hook (Task 5) and SessionStart advisory (Task 4)
- [ ] 7.2 Create `.codex/rules/default.rules` — one `prefix_rule()` per denied `Bash(...)` command with `decision = "deny"`, `justification`, and at least one `match`/`not_match` inline test case. Port "ask" commands as `decision = "prompt"`
- [ ] 7.3 Verify: `codex execpolicy check --pretty --rules .codex/rules/default.rules -- rm -rf /tmp/test` shows `deny`; `-- ls` shows `allow`

## Task 8: Config.toml finalization and statusline
- **Status:** pending
- **Depends on:** Task 4, Task 5
- **Docs:** [implementation.md#phase-8-config](./implementation.md#phase-8-config)

### Subtasks
- [ ] 8.1 Finalize `.codex/config.toml` with all sections: top-level settings (`model`, `model_reasoning_effort`, `approval_policy`, `sandbox_mode`) before any `[table]` header, then `[features]`, `[agents]`, `[tui]`, `[mcp_servers.capy]`. Add template-sync variable placeholders
- [ ] 8.2 Verify: TOML parses cleanly (`python3 -c "import tomllib; ..."` exits 0)

## Task 9: Template-sync extension
- **Status:** pending
- **Depends on:** Task 4, Task 5, Task 6, Task 7, Task 8
- **Docs:** [implementation.md#phase-9-template-sync](./implementation.md#phase-9-template-sync)

### Subtasks
- [ ] 9.1 Update `.github/scripts/template-sync.sh` — add `.codex/` to sparse-clone file list; add `AGENTS.md` to root-level files; add strip rules excluding `.codex/scripts/capy.sh` from sync; add variable substitution for `.codex/config.toml` and `AGENTS.md`
- [ ] 9.2 Add codex-specific manifest variables: `CODEX_MODEL`, `CODEX_APPROVAL_POLICY` — all optional with sensible defaults. Update schema and example files
- [ ] 9.3 Update `.github/workflows/template-sync.yml` — add codex variable backfilling; add `.codex/` to commit/PR diff scope
- [ ] 9.4 Verify: dry-run template-sync on a test downstream repo — `.codex/` files appear in diff; downstream repo without codex variables syncs cleanly

## Task 10: Tests and documentation
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9
- **Docs:** [implementation.md#phase-10-tests-docs](./implementation.md#phase-10-tests-docs)

### Subtasks
- [ ] 10.1 Update `test/test-plugin-structure.sh` — add assertions for `kodex-plugin/` generated output: skills exist and match source count, manifest validates, no `${CLAUDE_PLUGIN_ROOT}` literals in generated skills, no dangling symlinks
- [ ] 10.2 Create `test/test-codex-structure.sh` — assert all codex files exist and validate (plugin.json, config.toml, hooks.json, five agent TOMLs, rules file, marketplace.json, AGENTS.md)
- [ ] 10.3 Update `README.md` — new "Providers" section with install paths for Claude and Codex
- [ ] 10.4 Verify `docs/adr/0005-codex-hook-enforcement-gap.md` is up to date with v2 design (ADR already exists with "Accepted" status from v1 — check section references and content accuracy)
- [ ] 10.5 Verify: `for test in test/test-*.sh; do $test; done` exits 0

## Task 11: Final verification
- **Status:** pending
- **Depends on:** all previous tasks

### Subtasks
- [ ] 11.1 Run full test suite including new codex structure checks
- [ ] 11.2 Run `make generate-kodex` and verify `git diff --exit-code kodex-plugin/` (output is fresh)
- [ ] 11.3 Run `review-code` on new Go code, shell scripts, TOML, Starlark
- [ ] 11.4 Run `review-spec` to verify implementation matches design.md and implementation.md
- [ ] 11.5 Smoke test from codex session: install plugin via marketplace, verify skills discoverable, SessionStart hook works, PreToolUse blocks forbidden commands, sub-agents spawnable, capy MCP callable
