# Implementation Plan: Codex Support

> Design: [./design.md](./design.md)
> Status: draft (v2 — reworked from symlink-based approach)
> Created: 2026-04-24
> Updated: 2026-04-25

This plan assumes the implementer is comfortable with Go, shell scripting,
TOML, and Claude Code's plugin system. Zero project-specific context is
assumed beyond what's in the design doc.

Phases are ordered so each merges independently. Every phase maps to 1–3
atomic commits (tasks.md defines the exact breakdown).

---

## Phase 0: Revert repository restructure {#phase-0-revert}

**Goal:** Undo Task 1 from v1. Restore `klaude-plugin/` as the canonical
plugin directory with skills and profiles inside it.

**Actions:**

- Revert the commit that moved skills/profiles to repo root and renamed
  `klaude-plugin/` to `plugins/claude/`.
- Verify `klaude-plugin/skills/`, `klaude-plugin/profiles/`,
  `klaude-plugin/agents/`, etc. are back in place.
- Verify `.claude-plugin/marketplace.json` source points at `./klaude-plugin`.
- All existing tests pass.

**Note:** The user will perform this revert manually.

**Verification:**

- `ls klaude-plugin/skills/*/SKILL.md | wc -l` matches expected skill count.
- `jq .plugins[0].source.path .claude-plugin/marketplace.json` outputs
  `"./klaude-plugin"`.
- `for test in test/test-*.sh; do $test; done` exits 0.

---

## Phase 1: Generation tool (`cmd/generate-kodex/`) {#phase-1-generate-tool}

**Goal:** Build the Go tool that generates `kodex-plugin/` from
`klaude-plugin/`. Follow the `cmd/vendor-profiles/` pattern.

**Files to create:**

- `cmd/generate-kodex/main.go` — CLI entry point. Flags: `-manifest`
  (required), `-target` (default: `kodex-plugin`), `-dry-run`.
- `cmd/generate-kodex/manifest.go` — YAML manifest parsing. Schema mirrors
  design.md §5.2.
- `cmd/generate-kodex/skills.go` — Skill generation: iterate source skills,
  apply transforms, write to target.
- `cmd/generate-kodex/transforms.go` — Transform implementations:
  `plugin_root_resolve` (replace `${CLAUDE_PLUGIN_ROOT}` with relative
  path), `inject_header` (prepend content).
- `cmd/generate-kodex/shared.go` — Copy `_shared/` directory. Handle
  intra-skill symlinks (copy or resolve based on testing).
- `cmd/generate-kodex/manifest_gen.go` — Generate `.codex-plugin/plugin.json`
  from source plugin manifest + overrides.
- `cmd/generate-kodex/mcp.go` — Generate `.mcp.json` from manifest config.
- `cmd/generate-kodex/*_test.go` — Tests for each component. Use testdata/
  fixtures following the vendor-profiles pattern.
- `scripts/kodex-generate-manifest.yml` — Generation manifest.

**Design decisions:**

- The tool reads the source manifest version and uses it for the generated
  manifest. No separate versioning.
- `${CLAUDE_PLUGIN_ROOT}` replacement uses `../klaude-plugin` as the
  relative path from `kodex-plugin/` to `klaude-plugin/`. This works for
  local development and template-sync users.
- The `_shared/` directory is copied in full. Per-skill symlinks to `_shared/`
  are preserved if they survive codex's cache, otherwise resolved to copies.

**Verification:**

- `go test ./cmd/generate-kodex/...` passes.
- `go run ./cmd/generate-kodex -manifest scripts/kodex-generate-manifest.yml -dry-run`
  prints expected actions.
- `go run ./cmd/generate-kodex -manifest scripts/kodex-generate-manifest.yml`
  produces `kodex-plugin/` with expected contents.
- `ls kodex-plugin/skills/*/SKILL.md | wc -l` matches
  `ls klaude-plugin/skills/*/SKILL.md | wc -l` (excluding `_shared`).
- `jq . kodex-plugin/.codex-plugin/plugin.json` exits 0.
- `cat kodex-plugin/.mcp.json | jq .` exits 0.
- No `${CLAUDE_PLUGIN_ROOT}` literals remain in generated SKILL.md files:
  `grep -r 'CLAUDE_PLUGIN_ROOT' kodex-plugin/skills/` returns empty.

---

## Phase 2: Makefile integration and CI {#phase-2-makefile}

**Goal:** Add `make generate-kodex` target and CI freshness check.

**Files to update:**

- `Makefile` — add targets:
  ```makefile
  generate-kodex:
      go test ./cmd/generate-kodex/...
      go run ./cmd/generate-kodex -manifest scripts/kodex-generate-manifest.yml
      $(MAKE) test-structure

  generate-all: vendor-profiles generate-kodex
  ```

**Files to create (if CI exists):**

- CI workflow step that runs `make generate-kodex && git diff --exit-code kodex-plugin/`
  to fail on stale generated output.

**Verification:**

- `make generate-kodex` succeeds end-to-end.
- Modifying a SKILL.md in `klaude-plugin/` then running `make generate-kodex`
  produces a diff in `kodex-plugin/`.

---

## Phase 3: Codex marketplace and plugin manifest {#phase-3-marketplace}

**Goal:** Set up the codex marketplace entry so the plugin is installable.

**Files to create:**

- `.agents/plugins/marketplace.json` — marketplace entry pointing at
  `./kodex-plugin` (see design.md §6.1).
- `kodex-plugin/README.md` — installation instructions: marketplace add
  command, skill listing, updating, troubleshooting, minimum codex version,
  no-sparse note.

**Note:** `kodex-plugin/.codex-plugin/plugin.json` and `kodex-plugin/.mcp.json`
are generated by the tool (Phase 1). This phase only adds the marketplace
entry and README.

**Verification:**

- `jq . .agents/plugins/marketplace.json` exits 0.
- `jq .plugins[0].source.path .agents/plugins/marketplace.json` outputs
  `"./kodex-plugin"`.

---

## Phase 4: AGENTS.md and SessionStart hook {#phase-4-bootstrap}

**Goal:** Codex sessions get provider identity, tool-name mapping, capy
routing rules, profile paths, and sub-agent roster injected at session start.

**Files to create:**

- `AGENTS.md` (repo root) — provider identity block, behavioral instructions
  (port from `.claude/CLAUDE.extra.md`), capy routing rules (replicate from
  `.claude/capy/CLAUDE.md`). Use `%PROJECT_NAME%` placeholder for
  template-sync.
- `.codex/scripts/session-start.sh` — shell script emitting SessionStart JSON.
  Computes absolute repo root from script location. Injects: provider
  identity, tool-name mapping table (design.md §7.2), profile/shared-
  instruction paths resolved to `<repo-root>/klaude-plugin/...`, capy
  routing rules, sub-agent roster.
- `.codex/hooks.json` — initial hook config with SessionStart entry.
- `.codex/config.toml` — initial file with `[features] codex_hooks = true`.

**Verification:**

- `bash .codex/scripts/session-start.sh < /dev/null | jq .` exits 0.
- The output JSON contains the tool-name mapping and profile paths.
- In a codex session, provider identity appears in context.

---

## Phase 5: PreToolUse hooks {#phase-5-pretooluse}

**Goal:** Enforce file-path denylist and capy HTTP routing via PreToolUse.

**Files to create:**

- `.codex/scripts/pretooluse-bash.sh` — reads `tool_input.command` from
  stdin JSON. Checks file-path denylist (ported from
  `klaude-plugin/scripts/validate-bash.sh`) and capy HTTP patterns. Emits
  `permissionDecision: "deny"` on match, exits 0 silently on pass-through.

**Files to update:**

- `.codex/hooks.json` — add `PreToolUse` matcher group alongside SessionStart.

**Verification:**

- `echo '{"tool_input":{"command":"cat .env"}}' | bash .codex/scripts/pretooluse-bash.sh | jq .hookSpecificOutput.permissionDecision` outputs `"deny"`.
- Same for `curl https://example.com`.
- `echo '{"tool_input":{"command":"ls"}}' | bash .codex/scripts/pretooluse-bash.sh` produces no output, exit 0.

---

## Phase 6: Sub-agents {#phase-6-agents}

**Goal:** Port all five Claude sub-agents to codex TOML format.

**Files to create under `.codex/agents/`:**

- `code-reviewer.toml`
- `spec-reviewer.toml`
- `design-reviewer.toml`
- `eval-grader.toml`
- `profile-resolver.toml`

Each file has: `name`, `description`, `sandbox_mode = "read-only"`,
`model`, `model_reasoning_effort = "high"`, and `developer_instructions`
carrying the prompt body adapted from the Claude markdown agents.

**Porting approach:** Copy Claude agent's markdown body into
`developer_instructions`. Adjust Claude-specific constructs (e.g., "use the
`Agent` tool" → "spawn a subagent"). The SessionStart tool-name mapping
handles most translation at runtime.

**Verification:**

- Each TOML file parses: `python3 -c "import tomllib; tomllib.load(open('<file>','rb'))"`.
- In a codex session, "spawn the code-reviewer agent" produces review output.

---

## Phase 7: Starlark rules {#phase-7-rules}

**Goal:** Port Claude's command deny/ask lists to Starlark rules.

**Files to create:**

- `.codex/rules/default.rules` — one `prefix_rule()` per denied `Bash(...)`
  command from `.claude/settings.json`. At least one inline test case per rule.

**Verification:**

- `codex execpolicy check --pretty --rules .codex/rules/default.rules -- rm -rf /tmp/test` shows `deny`.
- `codex execpolicy check --pretty --rules .codex/rules/default.rules -- ls` shows `allow`.

---

## Phase 8: Statusline and config.toml finalization {#phase-8-config}

**Goal:** Complete `.codex/config.toml` with all sections.

**Files to update:**

- `.codex/config.toml`:
  ```toml
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

**Verification:**

- TOML parses: `python3 -c "import tomllib; tomllib.load(open('.codex/config.toml','rb'))"`.

---

## Phase 9: Template-sync extension {#phase-9-template-sync}

**Goal:** Downstream repos receive `.codex/` configs on template-sync.

**Files to update:**

- `.github/scripts/template-sync.sh` — add `.codex/` to sparse-clone list,
  add `AGENTS.md` to root-level files, add strip rules for
  `.codex/scripts/capy.sh`, add variable substitution for codex files.
- `.github/workflows/template-sync.yml` — add codex variable backfilling
  and `.codex/` to diff scope.

**Verification:**

- Dry-run template-sync: `.codex/` files appear in diff.
- Downstream repo without codex variables syncs cleanly.

---

## Phase 10: Tests and documentation {#phase-10-tests-docs}

**Goal:** Structure tests, README updates, ADR.

**Test updates:**

- `test/test-plugin-structure.sh` — add assertions for `kodex-plugin/`
  generated output: skills exist and match source count, manifest validates,
  no dangling symlinks, no `${CLAUDE_PLUGIN_ROOT}` literals in generated
  skills.

**New tests:**

- `test/test-codex-structure.sh`:
  - Assert `kodex-plugin/.codex-plugin/plugin.json` validates.
  - Assert `.codex/config.toml` exists.
  - Assert `.codex/hooks.json` validates as JSON.
  - Assert all five `.codex/agents/*.toml` exist.
  - Assert `.codex/rules/default.rules` exists.
  - Assert `.agents/plugins/marketplace.json` exists with `kk` entry.
  - Assert `AGENTS.md` exists at repo root.

**Documentation:**

- `README.md` — new "Providers" section.
- `kodex-plugin/README.md` — installation guide (created in Phase 3).
- `docs/adr/0005-codex-hook-enforcement-gap.md` — enforcement gap ADR.

**Verification:**

- `for test in test/test-*.sh; do $test; done` exits 0.

---

## Phase 11: Final verification {#phase-11-verification}

- All tests pass.
- `make generate-kodex` produces no diff (output is fresh).
- `review-code` on new Go code, shell scripts, TOML, Starlark.
- `review-spec` against this plan and design.md.
- Smoke test from a codex session: install plugin, verify skills, hooks,
  agents, capy.

---

## Appendix: ordering, dependencies, and parallelization

- **Phase 0** (revert) must land first.
- **Phase 1** (generation tool) depends on Phase 0.
- **Phase 2** (Makefile/CI) depends on Phase 1.
- **Phase 3** (marketplace) depends on Phase 1 (generated output must exist).
- **Phase 4** (bootstrap) is independent of Phases 1–3 (only creates `.codex/` files).
- **Phase 5** (PreToolUse) depends on Phase 4 (updates `.codex/hooks.json`).
- **Phases 6, 7** can proceed in parallel after Phase 0 (each is independent).
- **Phase 8** (config finalization) depends on Phases 4, 5 (hooks and initial config exist).
- **Phase 9** (template-sync) depends on Phases 4–8 (needs all `.codex/` files).
- **Phase 10** (tests/docs) depends on all prior phases.
- **Phase 11** last.
