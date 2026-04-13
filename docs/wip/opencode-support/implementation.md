# Implementation Plan: Opencode Support

> Design: [./design.md](./design.md)
> Status: draft
> Created: 2026-04-13

This plan assumes the implementer is an experienced TypeScript/JavaScript and
shell developer, comfortable with Claude Code's plugin system, familiar with
markdown YAML frontmatter, and willing to consult the
[OpenCode docs](https://opencode.ai/docs/) for specific API surfaces. Zero
project-specific context is assumed.

Phases are ordered so each merges independently. Every phase maps to 1–3
atomic commits (tasks.md defines the exact breakdown).

---

## Phase 1: Repository restructure {#phase-1-restructure}

**Goal:** Move skills to a canonical location and rename the Claude plugin
tree so the multi-provider layout is in place. No behavioral change yet.

**Files to touch:**
- Move `klaude-plugin/` → `plugins/claude/`. Preserve all sub-directories
  (`commands/`, `agents/`, `hooks/`, `scripts/`, `.claude-plugin/plugin.json`,
  `README.md`).
- Move `klaude-plugin/skills/*/` → `skills/*/` (physical move to repo root).
  Every skill directory becomes a child of the new top-level `skills/`.
- Create relative symlink `plugins/claude/skills` → `../../skills`. Use a
  *relative* symlink, not absolute, so git clones on any filesystem resolve
  correctly. This symlink is **Claude-side only** — OpenCode resolves skills
  at runtime and does not symlink.
- Update `.claude-plugin/marketplace.json`: change the `kk` plugin's
  `source` from `./klaude-plugin` to `./plugins/claude`.
- Grep the repo for any hard-coded `klaude-plugin/` path references
  (scripts, docs, tests, examples). Update each. Treat each path update as
  part of this phase — do not leave stale references.

**Verification:**
- `.claude-plugin/marketplace.json` still validates as JSON and the plugin
  resolves via `kk@claude-toolbox`.
- Claude Code loaded from this repo still discovers all skills and commands.
- `git ls-files plugins/claude/skills | head` shows symlinked skill files
  (or, if git records the symlink, `git ls-tree` shows mode `120000`).

**Notes:**
- `.claude/` (project-local Claude config) stays untouched.
- Claude plugin system must resolve the symlink. If testing reveals it does
  not, fallback is documented in design.md §12 (post-install copy). Do not
  implement the fallback unless the symlink approach demonstrably fails.

---

## Phase 2: Skills refactor — extract provider-specifics {#phase-2-skills-refactor}

**Goal:** For each skill, separate provider-agnostic workflow from
provider-specific details. No new behavior; preserve every existing workflow
rule.

**Pre-refactor housekeeping — `reference/` naming collision resolution:**

Before the refactor, `review-code` has `reference/{go,java,js_ts,kotlin,python}/`
subdirectories with language-specific code-quality checklists. The new schema
reserves `reference/` for provider files only (`claude.md`, `opencode.md`,
`codex.md`).

Rename the existing language dirs from `skills/review-code/reference/<lang>/`
to `skills/review-code/checklists/<lang>/`. Update every reference to
these paths inside SKILL.md, any sub-docs, and any command files in
`plugins/claude/commands/review-code/`. Commit this rename before
creating the new `reference/{claude,opencode,codex}.md` files in the same
skill.

Apply the same rule to any other skill found to have a pre-existing
`reference/<subdir>/` structure: rename to a semantically appropriate name
(`checklists/`, `examples/`, `templates/`, etc.) so that `reference/` stays
reserved for provider files. Audit during the refactor.

**For each skill directory under `skills/<skill-name>/`:**

1. Create `reference/claude.md`. Move from SKILL.md (and any supporting
   files) the Claude-specific parts:
   - Tool name mappings used in the skill (e.g. `Read`, `Write`, `Edit`,
     `Grep`, `Glob`, `Bash`, `WebFetch`).
   - Slash-command names associated with the skill.
   - Capy routing rules and MCP tool names (`capy_batch_execute`, etc.).
   - `kk:` prefixed skill names where referenced.
   - `Task` / `TaskCreate` / `TaskUpdate` usage and `Skill` tool usage
     phrased in Claude-tool terms.

2. Create `reference/opencode.md`. Author the OpenCode equivalents:
   - Lowercase tool names (`read`, `write`, `edit`, `grep`, `glob`, `bash`,
     `webfetch`).
   - OpenCode's `skill` tool for skill invocation.
   - Sub-agent invocation via `@mention`.
   - Capy routing with lowercase tool names (same capy MCP tools).
   - Slash-command names as OpenCode slash-commands (see Phase 5).

3. Create `reference/codex.md`. Minimal content:
   - Note that codex provides native skill discovery; most workflow
     constructs in the parent SKILL.md apply.
   - Tool-name notes as far as codex's CLI documents them.
   - If a construct has no Codex analog, state so explicitly (e.g.,
     "Codex has no slash-commands; invoke by natural language").

4. Rewrite SKILL.md to be provider-neutral:
   - Replace tool literals with neutral phrasing ("read the file", "search
     the knowledge base", "invoke a sub-agent").
   - Remove `kk:` prefixes from skill references in the body.
   - Keep the workflow checklist, quality standards, DO/DO-NOT guidance.
   - Insert exactly one pointer line near the top:
     *"For tool names, slash-command syntax, and knowledge-base routing
     specific to your runtime, load `reference/<provider>.md` (where
     `<provider>` is the one your bootstrap identifies)."*

5. Update any supporting files inside the skill that use Claude literals
   (example-tasks.md, idea-process.md, etc.) to also use neutral phrasing,
   or, if they are explicitly Claude-specific (e.g. `capy.md`), move them
   into `reference/claude.md` or a `reference/claude/` subdir.

**Scope:** Repeat for each skill currently in `skills/`:
`chain-of-verification`, `dependency-handling`, `design`, `document`,
`implement`, `merge-docs`, `review-code`, `review-design`, `review-spec`,
`test`, `_shared` (if it contains provider-specific content).

**Verification:**
- Existing Claude sessions using these skills behave identically after the
  refactor. Run a dry-run of one representative workflow (e.g.,
  `/design` on a trivial idea) and confirm the pointer line is
  resolved correctly by the agent (by pre-populating `CLAUDE.md` with the
  provider-identity statement from Phase 7).
- Lint (added in Phase 9) runs clean: no forbidden literals in any
  SKILL.md.

---

## Phase 3: Bootstrap identity on Claude {#phase-3-claude-bootstrap}

**Goal:** Tell the Claude-side agent its provider identity so the skill's
pointer line resolves.

**Background:** `klaude-plugin/.claude-plugin/plugin.json` (soon
`plugins/claude/.claude-plugin/plugin.json`) does NOT have a field for
injecting a CLAUDE.md at plugin load — verified from the existing schema. The
bootstrap therefore relies on the **project-level `CLAUDE.md`** containing
the identity statement. There is no plugin-level injection fallback.

**Files to touch:**
- `CLAUDE.md` (project root): add a short "Provider identity" block stating
  *"You are running on Claude Code. When a skill references
  `reference/<provider>.md`, load `reference/claude.md`."* Place it near the
  top so it's always in context.
- `plugins/claude/README.md`: prominently document that installing the
  plugin requires adding the provider-identity block to the target project's
  `CLAUDE.md`. Include the exact text to paste. Optional: ship a one-off
  helper script (`plugins/claude/scripts/install-provider-identity.sh`) that
  appends the block to an existing `CLAUDE.md` or creates one.

**Verification:**
- In a Claude session, load any skill. The agent's behavior matches the
  pre-refactor behavior (it correctly identifies Claude tool names).
- Manual smoke: in a fresh clone of a downstream project, run the helper
  script (if shipped) or follow the README instructions; confirm
  `CLAUDE.md` contains the block.

---

## Phase 4: OpenCode plugin scaffold {#phase-4-opencode-plugin-scaffold}

**Goal:** Stand up the OpenCode plugin with the minimal surface required
(provider-identity injection + skill directory registration). No capy hooks
yet.

**Files to create:**
- **Root-level `package.json`** (at repo root) — the OpenCode plugin manifest.
  Declares `@opencode-ai/plugin` as a dependency, sets `type: "module"`,
  `name: "kk"` (or similar — match the user-facing install string), and
  `main: "plugins/opencode/runtime/kk.ts"` (or a compiled JS path if the
  setup requires a build step). Required because OpenCode's Bun-based
  loader reads the manifest at the installed repo's root.
- `plugins/opencode/runtime/kk.ts` — the TypeScript entry. Exports one or
  more plugin functions per OpenCode's plugin docs. Responsibilities:
  1. **`config` hook**: register the canonical `skills/` directory as a
     skills path. Resolve the absolute path at runtime from
     `import.meta.url` — walk up three directory levels
     (`runtime/` → `opencode/` → `plugins/` → repo root) and append
     `skills`. Do NOT hardcode paths.
  2. **`experimental.chat.system.transform` hook** (per-turn): inject the
     provider-identity statement, the list of shipped sub-agents (discovered
     from `plugins/opencode/agents/` at runtime), and a short tool-name
     mapping table. Gracefully degrade if the hook is unavailable — log a
     warning and skip; users still have the `AGENTS.md` template as fallback.
- `plugins/opencode/README.md` — installation instructions. Mirror the
  structure of the [superpowers OpenCode README](https://github.com/obra/superpowers/blob/main/docs/README.opencode.md).
  Cover: installation (via `"plugin": ["kk@git+<repo>.git"]`), skill
  listing, personal skills, updating, troubleshooting, minimum OpenCode
  version tested.
- `plugins/opencode/AGENTS.md` — template that users drop into their
  project root as the belt-and-suspenders bootstrap. Contains the
  provider-identity statement in static form.
- `plugins/opencode/opencode.jsonc` — reference config with the `plugin`,
  `mcp`, and `permission` blocks users merge into their own config (see
  Phase 8).

**Testing approach:**
- Install the plugin into a scratch OpenCode project via
  `"plugin": ["kk@git+<repo>.git#<branch>"]` (no subpath).
- Run `opencode run --print-logs "tell me about your skills"` and confirm
  the bootstrap text appears and skills are discovered.
- Verify the skills path is resolved correctly from the Bun cache location
  by logging `import.meta.url` and the computed absolute path in dev builds.
- Record the minimum OpenCode version tested in the plugin README.

---

## Phase 5: OpenCode commands {#phase-5-opencode-commands}

**Goal:** Port existing Claude slash-commands to OpenCode.

**Files to create under `plugins/opencode/commands/`:**

| File                             | `agent` frontmatter |
|----------------------------------|---------------------|
| `chain-of-verification.md`       | `build`             |
| `review-code.md`                 | `plan`              |
| `review-spec.md`                 | `plan`              |
| `migrate-from-taskmaster.md`     | `build`             |
| `sync-workflow.md`               | `build`             |

Rationale for `plan` vs `build`: review commands must not modify files, so
they run under `plan` (read-only primary agent). Others run under `build`
for full-tool access.

Each file uses OpenCode's command frontmatter:
```
---
description: <same description text as the Claude version>
agent: <value from table above>
model: <optional>
---
```

The body is a short prompt that invokes the relevant skill or sub-agent
using OpenCode conventions. Keep the body to what the Claude version does
— do not add opencode-specific features beyond what already existed. Use
`$ARGUMENTS` where the Claude version accepts args.

**Verification:**
- Typing `/chain-of-verification` in an OpenCode session runs the equivalent
  workflow as the Claude version.
- `/review-code` and `/review-spec` do not attempt file
  edits (plan-mode restriction visible in OpenCode's permission prompts).

---

## Phase 6: OpenCode agents {#phase-6-opencode-agents}

**Goal:** Port the three custom sub-agents to OpenCode format.

**Files to create under `plugins/opencode/agents/`:**
- `code-reviewer.md`
- `spec-reviewer.md`
- `design-reviewer.md`

Each uses OpenCode's agent frontmatter with `mode: subagent`, read-only
`tools` (`write: false, edit: false, bash: false`), appropriate `model`,
and the prompt body copied from the Claude agent file with tool names
lowercased and Claude-specific routing removed.

OpenCode's built-in `general` and `explore` sub-agents already cover the
use cases of our `general-purpose` and `Explore` references — do not
re-ship.

**Verification:**
- `@code-reviewer` in an OpenCode session invokes the sub-agent and
  produces a review identical in spirit to the Claude version.

---

## Phase 7: Context-protection hooks — split port {#phase-7-capy-hook}

**Goal:** Reproduce Claude's two independent protection mechanisms inside
`plugins/opencode/runtime/kk.ts`. These are two separate concerns with two
separate sources of truth on the Claude side — mirror that split on the
OpenCode side.

**Critical: blocking API**
OpenCode's `tool.execute.before` hook blocks execution by
**`throw new Error("<message>")`** — NOT by returning a message. Returning
a value does not block. The thrown error message is surfaced to the agent.

### Phase 7a: File-path denylist (port of `validate-bash.sh`)

**Source of truth:** `plugins/claude/scripts/validate-bash.sh` (formerly
`klaude-plugin/scripts/validate-bash.sh`). The script's `FORBIDDEN_PATTERNS`
array covers: `.env`, `.ansible/`, `.terraform/`, `build/`, `dist/`,
`node_modules`, `__pycache__`, `.git/`, `venv/`, `.pyc`, `.csv`, `.log`.

**Additions to `kk.ts`:**
- `tool.execute.before` on `bash`: read the command string; if it matches
  any denylist regex, `throw new Error("Access to '<pattern>' is blocked by security policy")`.
- `tool.execute.before` on `read`: if OpenCode's native glob-based
  `permission.read` cannot express these file-pattern denies, enforce
  the same denylist on the read target path and `throw` on match.
- Port the regex patterns verbatim from `validate-bash.sh`. Keep them in a
  single exported constant so future edits stay in sync.

### Phase 7b: Capy HTTP/output routing (port of `.claude/capy/CLAUDE.md`)

**Source of truth:** `.claude/capy/CLAUDE.md`'s "BLOCKED commands" and
"REDIRECTED tools" sections. Port those patterns and messages.

**Additions to `kk.ts`:**
- `tool.execute.before` on `bash`: if the command matches `curl` or `wget`,
  `throw new Error("curl/wget blocked — use capy_fetch_and_index(url, source) instead")`.
- `tool.execute.before` on `bash`: if it matches inline-HTTP patterns
  (`fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(`),
  `throw new Error("inline HTTP blocked — use capy_execute(language, code) in the sandbox")`.
- `tool.execute.before` on `webfetch`: unconditional
  `throw new Error("webfetch blocked — use capy_fetch_and_index(url, source) then capy_search(queries)")`.
- Optional: `tool.execute.after` on `bash` that appends non-blocking
  guidance if stdout exceeds ~20 lines — matches the tone of the Claude
  SessionStart hook. Non-blocking means no throw; just log/warn.

### Verification (covers both 7a and 7b)

- In an OpenCode session with this plugin enabled, running
  `bash` with `cat .env` throws the policy message (7a).
- Running `bash` with `curl https://...` throws the capy redirect (7b).
- Running `webfetch` with any URL throws the capy redirect (7b).
- Capy MCP tools (`capy_fetch_and_index`, `capy_search`,
  `capy_batch_execute`, `capy_execute`) work when invoked via the
  OpenCode-to-capy MCP bridge (Phase 8 sets up the bridge).
- Regression: non-matching bash commands (e.g. `ls`, `git status`) pass
  through unchanged.

---

## Phase 8: OpenCode configuration reference {#phase-8-opencode-config}

**Goal:** Provide a ready-to-merge `opencode.jsonc` so users know what to
add to their own config.

**Contents of `plugins/opencode/opencode.jsonc`:**
- `plugin` array with the `kk@git+...?subpath=plugins/opencode` entry.
- `mcp` block registering capy as a local server, pointing at whatever
  path capy ships for OpenCode (see design.md §8.1).
- `permission` block mirroring `.claude/settings.json`'s allow/deny intent
  translated to OpenCode's schema:
  - Top-level `edit`, `bash`, `webfetch` defaults.
  - Per-bash-command deny/ask rules (`rm *`, `git push`, etc.) as glob
    patterns.
- Comments (this is JSONC) explaining each block and pointing to design
  and README.

**Verification:**
- The file parses as JSONC (check with `jq` after stripping comments or
  with a JSONC-aware validator).
- Merging this into a user's own `opencode.jsonc` produces a session
  where all the intended permissions and MCPs are active.

---

## Phase 9: Linting and template-sync updates {#phase-9-lints-and-sync}

**Goal:** Enforce the invariants and keep the sync feature working.

**New checks (add to `test/`):**
- `test/test-skills-lint.sh`: walks `skills/*/SKILL.md` and fails if any
  match forbidden literals (case-sensitive: `Skill`, `Task`, `TodoWrite`,
  `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `WebFetch`, `capy_`,
  `kk:`, `/design` (and other known slash-commands)). Allow
  explicit opt-outs via a comment marker on the offending line (e.g.,
  `<!-- allow-literal: reason -->`).
- `test/test-skills-pointer.sh`: walks `skills/*/SKILL.md` and fails if any
  file does not contain **exactly one** line matching the
  `reference/<provider>.md` pointer pattern. Catches the most common
  authoring error (pointer missing or duplicated).
- `test/test-skills-references.sh`: for every `skills/<name>/SKILL.md`,
  assert that `reference/claude.md` and `reference/opencode.md` exist.
  `reference/codex.md` is warn, not fail.
- `test/test-reference-dir-reserved.sh`: assert `reference/` inside any
  skill contains only `claude.md`, `opencode.md`, `codex.md` — no
  subdirectories, no other files. Catches regressions of the
  language-dir collision.
- `test/test-symlinks.sh`: assert `plugins/claude/skills` is a relative
  symlink resolving to `../../skills`. Do NOT assert a symlink on
  `plugins/opencode/skills` — the OpenCode side has no skills symlink
  (runtime path resolution).
- `test/test-opencode-jsonc.sh`: assert `plugins/opencode/opencode.jsonc`
  parses as JSONC and has required top-level keys (`plugin`, `mcp`,
  `permission`).
- `test/test-root-package-json.sh`: assert the root `package.json` exists,
  declares the correct name, the `@opencode-ai/plugin` dep, and a `main`
  pointing at an existing file.

**Template-sync updates:**
- Locate the actual sync entry point. `docs/update.sh` is one candidate;
  `test/helpers.sh` is another. Walk the repo to find where the sync
  logic lives before editing. Update the discovered file to include
  `plugins/opencode/` and root-level files (`package.json`, `opencode.jsonc`
  if exported) alongside `plugins/claude/` and the canonical `skills/`.
- Update existing `test/test-*.sh` cases whose path expectations changed.

**Verification:**
- `for test in test/test-*.sh; do $test; done` exits zero.

---

## Phase 10: Documentation {#phase-10-docs}

**Goal:** Users can find their way to the right install path.

**README.md (repo root) — new "Providers" section:**
- Short summary of supported providers.
- Install links:
  - Claude Code: existing install paths (unchanged).
  - OpenCode: one-liner linking to `plugins/opencode/README.md`.
  - Codex: "coming soon" with a link to the open issue.
- "Migration from pre-opencode layout" subsection explaining the
  `klaude-plugin/` → `plugins/claude/` rename and skills move for
  contributors.

**plugins/opencode/README.md:**
Already drafted in Phase 4. Expand to cover:
- Installation (`opencode.jsonc` plugin entry).
- Migration note (if applicable).
- Listing skills, loading skills.
- Personal vs project skills.
- Updating, uninstalling.
- Troubleshooting: plugin not loading, skills not found, bootstrap not
  appearing.

**plugins/claude/README.md:**
Update only where paths changed. Do not otherwise expand.

**Capy knowledge base:**
Per design Step 5 guidance, index non-obvious architecture
decisions as `kk:arch-decisions`. Candidate entries:
- Why skills are at repo root (not in `klaude-plugin/`).
- Why reference files are selected by bootstrap, not build step.
- Why commands/agents are not shared across providers.
- Why OpenCode gets a JS plugin (not just install docs).
- Why capy is fully ported to OpenCode, not optional.

---

## Phase 11: Final verification {#phase-11-verification}

Runs after every other phase merges.

- Run `test` skill — full test suite passes, including the new
  lint and symlink checks.
- Run `document` — verify the new README sections and
  plugin READMEs are accurate and internally consistent.
- Run `review-code` on the TypeScript plugin code and shell lint
  scripts.
- Run `review-spec` to verify the result matches this plan and
  `design.md`.
- Smoke test from a fresh OpenCode install:
  - Install via `opencode.jsonc` plugin entry.
  - `/chain-of-verification`, `@code-reviewer`, `use skill tool to load design`
    all work.
  - Capy hook intercepts `curl` and `webfetch` (via Phase 7b).
  - File-path denylist triggers on `cat .env` (via Phase 7a).
  - Capy MCP tools are callable.
- **Bootstrap regression snapshot:** capture the provider-identity
  injection output from a known-good session (via
  `opencode run --print-logs "hello"`). Save to `test/fixtures/bootstrap.expected`.
  Add `test/test-bootstrap-regression.sh` that runs the same command and
  diffs against the fixture — catches accidental changes to the
  provider-identity block text or hook wiring. This is a smoke test, not
  a semantic test of LLM behavior.

---

## Appendix: ordering, dependencies, and parallelization

- **Phase 1** must land before anything else (path invariants).
- **Phase 2** (skills refactor) and **Phase 4** (opencode plugin scaffold)
  can proceed in parallel after Phase 1. Phase 2 is self-contained;
  Phase 4 only needs the path layout.
- **Phase 3** (Claude bootstrap) can land any time after Phase 2.
- **Phases 5, 6, 8** depend on Phase 4 scaffold.
- **Phase 7** depends on Phase 4 scaffold and on the design of capy
  routing rules in `reference/opencode.md` (Phase 2).
- **Phase 9** (lints) should ideally land alongside or immediately after
  Phase 2 — enforcing the invariants as they are established prevents
  regressions while the rest of the work proceeds.
- **Phase 10** (docs) continuous; finalized after Phase 8.
- **Phase 11** last.
