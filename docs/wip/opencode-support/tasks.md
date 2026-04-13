# Tasks: Opencode Support

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-13

## Task 1: Repository restructure
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#phase-1-restructure](./implementation.md#phase-1-restructure)

### Subtasks
- [ ] 1.1 Move `klaude-plugin/` → `plugins/claude/` preserving all contents (`commands/`, `agents/`, `hooks/`, `scripts/`, `.claude-plugin/plugin.json`, `README.md`)
- [ ] 1.2 Move every `klaude-plugin/skills/<name>/` to the new top-level `skills/<name>/`
- [ ] 1.3 Create relative symlink `plugins/claude/skills` → `../../skills`
- [ ] 1.4 Update `.claude-plugin/marketplace.json`: change the `kk` plugin's `source` from `./klaude-plugin` to `./plugins/claude`
- [ ] 1.5 Grep the repo for hard-coded `klaude-plugin/` path references in scripts, docs, tests, examples; update each to the new path
- [ ] 1.6 Verify locally: `kk@claude-toolbox` still resolves via the marketplace; existing slash-commands and skills are still discoverable inside a Claude session loaded from this repo

## Task 2: Skills refactor — extract provider-specifics into reference files
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-2-skills-refactor](./implementation.md#phase-2-skills-refactor)

### Subtasks
One subtask per skill (after 2.0 housekeeping). For each: create `reference/{claude,opencode,codex}.md`, move Claude-specific details out of `SKILL.md` into `reference/claude.md`, author equivalent content in `reference/opencode.md`, minimal `reference/codex.md`, rewrite `SKILL.md` to be provider-neutral, add exactly one pointer line directing the agent to `reference/<provider>.md`.

- [ ] 2.0 Housekeeping: rename `skills/review-code/reference/<lang>/` (existing `go/`, `java/`, `js_ts/`, `kotlin/`, `python/`) to `skills/review-code/checklists/<lang>/`. Update every reference to these paths in `SKILL.md` and any related command/agent files. Audit other skills for similar pre-existing `reference/<subdir>/` structures and rename them too — `reference/` is reserved for provider files from this point onward.
- [ ] 2.1 Refactor `skills/chain-of-verification/`
- [ ] 2.2 Refactor `skills/dependency-handling/`
- [ ] 2.3 Refactor `skills/design/`
- [ ] 2.4 Refactor `skills/document/`
- [ ] 2.5 Refactor `skills/implement/`
- [ ] 2.6 Refactor `skills/merge-docs/`
- [ ] 2.7 Refactor `skills/review-code/` (post-housekeeping; `reference/` now only holds provider files, language content lives in `checklists/`)
- [ ] 2.8 Refactor `skills/review-design/`
- [ ] 2.9 Refactor `skills/review-spec/`
- [ ] 2.10 Refactor `skills/test/`
- [ ] 2.11 Audit `skills/_shared/` and normalize any provider-specific content; either neutralize in place or split into provider-scoped files

## Task 3: Provider-identity bootstrap on Claude
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md#phase-3-claude-bootstrap](./implementation.md#phase-3-claude-bootstrap)

### Subtasks
- [ ] 3.1 Add a "Provider identity" block near the top of the project `CLAUDE.md` stating the agent is on Claude Code and should load `reference/claude.md` for provider-scoped skill references
- [ ] 3.2 Update `plugins/claude/README.md` to prominently document that users must add the provider-identity block to their target project's `CLAUDE.md`; include the exact block to paste
- [ ] 3.3 (Optional) Ship a one-off helper script (e.g. `plugins/claude/scripts/install-provider-identity.sh`) that appends the block to an existing `CLAUDE.md` or creates one
- [ ] 3.4 Dry-run a representative skill (e.g. `/design`) and confirm the agent resolves the pointer line correctly using the Claude reference

## Task 4: OpenCode plugin scaffold
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#phase-4-opencode-plugin-scaffold](./implementation.md#phase-4-opencode-plugin-scaffold)

### Subtasks
- [ ] 4.1 Create `plugins/opencode/` with subdirectories `commands/`, `agents/`, `runtime/` (note: `runtime/`, not `plugins/` — avoids double-plugins nesting). Do NOT create a `plugins/opencode/skills` symlink — OpenCode resolves skills at runtime from `import.meta.url`.
- [ ] 4.2 Create root-level `package.json` at the repo root declaring `name: "kk"` (or a matching user-facing install name), `type: "module"`, `@opencode-ai/plugin` in `dependencies`, and `main` pointing at the runtime entry (`plugins/opencode/runtime/kk.ts` or a compiled JS equivalent if a build step is added)
- [ ] 4.3 Create `plugins/opencode/runtime/kk.ts` with the initial hooks: `config` hook resolves the canonical `skills/` dir via `import.meta.url` (walk up three levels, append `skills`) and registers it as a skills path; `experimental.chat.system.transform` hook injects the provider-identity statement + sub-agent list (discovered at runtime from `plugins/opencode/agents/`) + compact tool-name mapping table, per-turn. Gracefully degrade if the hook is unavailable (log warning, skip).
- [ ] 4.4 Create `plugins/opencode/AGENTS.md` template file carrying the static provider-identity statement (belt-and-suspenders for users whose OpenCode version does not support `experimental.chat.system.transform`)
- [ ] 4.5 Create initial `plugins/opencode/README.md` covering installation via `opencode.jsonc` `plugin` entry (without subpath), skill listing, personal vs project skills, updating, troubleshooting, minimum OpenCode version tested
- [ ] 4.6 Test installing into a scratch OpenCode project via `"plugin": ["kk@git+<repo>.git#<branch>"]` (no subpath); verify the bootstrap appears and skills are discoverable; verify the runtime path resolution resolves to the correct `skills/` dir inside the Bun cache; record the minimum OpenCode version tested in the README

## Task 5: OpenCode commands
- **Status:** pending
- **Depends on:** Task 4
- **Docs:** [implementation.md#phase-5-opencode-commands](./implementation.md#phase-5-opencode-commands)

### Subtasks
- [ ] 5.1 Create `plugins/opencode/commands/chain-of-verification.md` — frontmatter `agent: build`; body invokes the `chain-of-verification` skill
- [ ] 5.2 Create `plugins/opencode/commands/review-code.md` — frontmatter `agent: plan` (read-only)
- [ ] 5.3 Create `plugins/opencode/commands/review-spec.md` — frontmatter `agent: plan`
- [ ] 5.4 Create `plugins/opencode/commands/migrate-from-taskmaster.md` — frontmatter `agent: build`
- [ ] 5.5 Create `plugins/opencode/commands/sync-workflow.md` — frontmatter `agent: build`; body has path-aware prompts for the new layout
- [ ] 5.6 Verify each command in an OpenCode session executes the equivalent workflow as the Claude version; verify review commands cannot write (plan-mode restriction)

## Task 6: OpenCode agents
- **Status:** pending
- **Depends on:** Task 4
- **Docs:** [implementation.md#phase-6-opencode-agents](./implementation.md#phase-6-opencode-agents)

### Subtasks
- [ ] 6.1 Create `plugins/opencode/agents/code-reviewer.md` with `mode: subagent`, read-only tools, body ported from the Claude sub-agent with tool names lowercased
- [ ] 6.2 Create `plugins/opencode/agents/spec-reviewer.md`
- [ ] 6.3 Create `plugins/opencode/agents/design-reviewer.md`
- [ ] 6.4 Verify `@code-reviewer` (and the other two) invokes correctly in an OpenCode session and produces output consistent with the Claude version

## Task 7: Context-protection hooks on OpenCode (split port)
- **Status:** pending
- **Depends on:** Task 4
- **Docs:** [implementation.md#phase-7-capy-hook](./implementation.md#phase-7-capy-hook)

**Note:** Claude-side protection lives in TWO separate mechanisms with TWO sources of truth. The port reproduces both independently. All blocking uses `throw new Error("<message>")` — returning a value does NOT block.

### Subtasks — Phase 7a: File-path denylist (port of `validate-bash.sh`)
- [ ] 7a.1 In `plugins/opencode/runtime/kk.ts`, add a `tool.execute.before` handler for `bash` that matches any `FORBIDDEN_PATTERNS` regex from `plugins/claude/scripts/validate-bash.sh` (`.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`, `node_modules`, `__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`) and throws `new Error("Access to '<pattern>' is blocked by security policy")`
- [ ] 7a.2 Add a `tool.execute.before` handler for `read` that enforces the same denylist on the read target path (throws on match). This covers glob-based file denies if OpenCode's native `permission.read` can't express them.
- [ ] 7a.3 Keep the pattern list in a single exported constant to avoid drift between the `bash` and `read` handlers

### Subtasks — Phase 7b: Capy HTTP routing (port of `.claude/capy/CLAUDE.md`)
- [ ] 7b.1 In the same `kk.ts` `bash` handler, add a match for `curl` / `wget` that throws `new Error("curl/wget blocked — use capy_fetch_and_index(url, source) instead")`
- [ ] 7b.2 Add a match for inline-HTTP patterns (`fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(`) that throws `new Error("inline HTTP blocked — use capy_execute(language, code) in the sandbox")`
- [ ] 7b.3 Add a `tool.execute.before` handler for `webfetch` that unconditionally throws `new Error("webfetch blocked — use capy_fetch_and_index(url, source) then capy_search(queries)")`
- [ ] 7b.4 (Optional) Add a non-blocking `tool.execute.after` on `bash` that appends guidance if stdout exceeds ~20 lines (no throw)

### Verification (covers both 7a and 7b)
- [ ] 7.V1 In an OpenCode session: `bash` with `cat .env` throws the policy message (7a)
- [ ] 7.V2 `bash` with `curl https://example.com` throws the capy redirect (7b)
- [ ] 7.V3 `webfetch` with any URL throws the capy redirect (7b)
- [ ] 7.V4 Capy MCP tools (`capy_fetch_and_index`, `capy_search`, `capy_batch_execute`, `capy_execute`) work when capy is configured per Task 8
- [ ] 7.V5 Non-matching bash commands (`ls`, `git status`) pass through unchanged

## Task 8: OpenCode configuration reference file
- **Status:** pending
- **Depends on:** Task 4, Task 7
- **Docs:** [implementation.md#phase-8-opencode-config](./implementation.md#phase-8-opencode-config)

### Subtasks
- [ ] 8.1 Create `plugins/opencode/opencode.jsonc` with: `plugin` array entry `"kk@git+<repo>.git"` (no subpath); `mcp` block registering capy with a placeholder script path (e.g. `"command": ["bash", "${CAPY_SCRIPT_PATH:-.claude/scripts/capy.sh}", "serve"]`) — reflects capy-script-placement fallback; `permission` block mirroring `.claude/settings.json`'s allow/deny intent via OpenCode's glob-based schema (top-level `edit`/`bash`/`webfetch` + per-bash-command globs for `rm *`, `git push`, etc.)
- [ ] 8.2 Add comments (JSONC) explaining each block, linking to the design doc and plugin README, and documenting the `CAPY_SCRIPT_PATH` escape hatch
- [ ] 8.3 Verify the file parses as JSONC and merging it into a user's own `opencode.jsonc` yields a working session

## Task 9: Lints and template-sync updates
- **Status:** pending
- **Depends on:** Task 2, Task 4
- **Docs:** [implementation.md#phase-9-lints-and-sync](./implementation.md#phase-9-lints-and-sync)

### Subtasks
- [ ] 9.1 Add `test/test-skills-lint.sh`: walk every `skills/*/SKILL.md` and fail on forbidden tool literals (`Skill`, `Task`, `TodoWrite`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `WebFetch`, `capy_`, `kk:`, known slash-command names); support an opt-out comment marker for justified exceptions
- [ ] 9.2 Add `test/test-skills-pointer.sh`: assert every `skills/*/SKILL.md` contains EXACTLY ONE line matching the `reference/<provider>.md` pointer pattern
- [ ] 9.3 Add `test/test-skills-references.sh`: for every `skills/*/SKILL.md`, assert that `reference/claude.md` and `reference/opencode.md` exist; warn if `reference/codex.md` is missing
- [ ] 9.4 Add `test/test-reference-dir-reserved.sh`: assert `reference/` inside any skill contains only the three provider files; fail on any subdirectory or additional file
- [ ] 9.5 Add `test/test-symlinks.sh`: assert `plugins/claude/skills` is a relative symlink resolving to `../../skills`. Do NOT assert any symlink on the OpenCode side.
- [ ] 9.6 Add `test/test-opencode-jsonc.sh`: validate `plugins/opencode/opencode.jsonc` parses and has the required top-level keys (`plugin`, `mcp`, `permission`)
- [ ] 9.7 Add `test/test-root-package-json.sh`: validate root `package.json` exists, declares the plugin name, `@opencode-ai/plugin` dep, and a `main` pointing at an existing file
- [ ] 9.8 Update `test/helpers.sh` with any shared helpers the new tests need
- [ ] 9.9 Locate the actual template-sync entry point (walk the repo; `docs/update.sh` is a candidate but not confirmed). Update it so it copies `plugins/opencode/` and the canonical `skills/` and root-level files (`package.json`) correctly; keep `capy.sh` excluded
- [ ] 9.10 Update existing `test/test-*.sh` cases whose path expectations changed
- [ ] 9.11 Run the full test suite: `for test in test/test-*.sh; do $test; done` — exit zero

## Task 10: Documentation
- **Status:** pending
- **Depends on:** Task 1, Task 4, Task 5, Task 6, Task 7, Task 8
- **Docs:** [implementation.md#phase-10-docs](./implementation.md#phase-10-docs)

### Subtasks
- [ ] 10.1 Add a "Providers" section to the top-level `README.md` with install paths for Claude, OpenCode, and a "coming soon" stub for Codex
- [ ] 10.2 Add a "Migration from pre-opencode layout" subsection to `README.md` for contributors with local clones
- [ ] 10.3 Flesh out `plugins/opencode/README.md` (installation, updating, uninstalling, skill listing, personal/project skills, troubleshooting)
- [ ] 10.4 Update `plugins/claude/README.md` only where paths changed; do not otherwise expand
- [ ] 10.5 Index non-obvious architecture decisions to capy `kk:arch-decisions`: skills at repo root, reference-via-bootstrap selection, non-shared commands/agents, OpenCode JS plugin vs install-only, capy fully ported to OpenCode

## Task 11: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10

### Subtasks
- [ ] 11.1 Run `test` skill — full test suite passes including new lint, reference-presence, pointer, reference-dir-reserved, symlink, opencode-jsonc, and root-package-json checks
- [ ] 11.2 Run `document` skill — verify README sections and plugin READMEs are accurate and internally consistent
- [ ] 11.3 Run `review-code` skill with `typescript,shell` language input for the OpenCode plugin and new lint scripts
- [ ] 11.4 Run `review-spec` skill to verify the implementation matches `design.md` and `implementation.md`
- [ ] 11.5 Smoke test from a fresh OpenCode install: plugin loads via `opencode.jsonc` plugin entry (no subpath); `/chain-of-verification`, `/review-code`, `@code-reviewer` work; `use skill tool to load design` works; capy HTTP routing intercepts `curl` and `webfetch` (Phase 7b); file-path denylist triggers on `cat .env` (Phase 7a)
- [ ] 11.6 Capture the provider-identity injection output from a known-good session via `opencode run --print-logs "hello"` and save to `test/fixtures/bootstrap.expected`; add `test/test-bootstrap-regression.sh` that diffs live output against the fixture
