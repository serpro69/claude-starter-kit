# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a starter template repository providing a complete development environment for Claude Code with pre-configured MCP servers and tools. It is a **configuration-only repository** with no application code.

## Architecture

Three integrated components:

1. **Claude Code** (`.claude/`): Project settings (`settings.json`), statusline scripts, and sync infrastructure
2. **kk plugin** (`klaude-plugin/`): Skills, commands, hooks, and utility scripts — distributed via the Claude Code plugin system
3. **Serena** (`.serena/`): Semantic code analysis via LSP — language detection, gitignore integration, tool exclusions (`project.yml`)

For API keys and MCP server setup, see the "MCP Server Configuration" section in `README.md`.

## Testing

Tests for the template-sync feature are in `test/`. Run with:

```bash
for test in test/test-*.sh; do $test; done
```

Tests use shared utilities from `test/helpers.sh`. See that file for available assertions and helpers.

## Troubleshooting

See `README.md` for detailed troubleshooting of MCP connection issues, Serena language detection, and template sync problems.

## Skill & Command Naming Conventions

Applies when creating or renaming kk-plugin skills and commands.

### Skills

- **Imperative verbs over noun phrases.** `design` not `analysis-process`, `implement` not `implementation-process`. Drop filler suffixes like `-process`. Skills are invoked as `/skill-name` — shorter names are faster to type.
- **Self-documenting over acronyms.** `chain-of-verification` beats `cove`. If the name requires expansion to understand it, it's the wrong name.
- **Family prefixes for grouped skills.** When multiple skills do the same action on different targets, share a prefix: `review-design`, `review-spec`, `review-code`. Tab-completion, discoverability, and mental grouping all benefit.
- **Reference bare in prose.** Inside skill/command files, reference other skills without the `kk:` prefix (e.g., `` `review-code` `` not `` `kk:review-code` ``). The `kk:` prefix is for command invocations, not prose references.

### Commands

Commands live under `klaude-plugin/commands/<name>/`. For skills with standard + isolated modes:

- `default.md` — standard variant, invoked as `/kk:<name>:default`
- `isolated.md` — isolated sub-agent variant, invoked as `/kk:<name>:isolated`

Symmetric naming avoids stuttering (`/kk:cove:cove` → `/kk:chain-of-verification:default`).

### Agents

Agent names describe the **role**, not the skill that invokes them. `code-reviewer`, `design-reviewer`, `spec-reviewer` persist across skill renames. Don't rename agent files when renaming the skills that delegate to them.

### Shared instructions

Instructions referenced by more than one skill live in `klaude-plugin/skills/_shared/<name>.md` with a bare basename (e.g., `review-scope-protocol.md`, `pal-codereview-invocation.md`).

Each consuming skill gets a **per-skill symlink** at `klaude-plugin/skills/<skill>/shared-<name>.md` pointing to `../_shared/<name>.md`. Reasons:

- Markdown links inside a skill stay local — `[shared-foo.md](shared-foo.md)` resolves without `../` path traversal, which keeps links working when the skill is bundled/copied.
- The `shared-` prefix in the skill directory makes it obvious at a glance which files are shared vs skill-specific.
- Only symlink into skills that actually reference the file — don't blanket-symlink.

When adding a new shared instruction:

1. Create `klaude-plugin/skills/_shared/<name>.md` (bare basename, no `shared-` prefix on the source file).
2. In each consuming skill directory, run `ln -s ../_shared/<name>.md shared-<name>.md`.
3. Reference it in skill docs as `[shared-<name>.md](shared-<name>.md)`.
4. Agents (in `klaude-plugin/agents/`) can't use the per-skill symlink pattern — reference shared files by their repo-relative path: `klaude-plugin/skills/_shared/<name>.md`.

### When renaming

- Update `test/test-plugin-structure.sh` `EXPECTED_SKILLS` and `EXPECTED_COMMANDS`.
- **Don't touch `run_plugin_migration`'s `dirs_to_remove` in `.github/scripts/template-sync.sh`** — those are historical paths for cleaning up pre-v0.5.0 downstream projects. They must stay as the names that existed at migration time.
- Leave `docs/done/**` untouched — it's frozen history.
- Watch for substring collisions (e.g., a `design-review` → `review-design` rename will also hit the `design-reviewer` agent name via simple sed; hand-fix those).

### Skill description budget

Claude Code loads skill descriptions into context so the model can pick the right skill. Two caps apply (see [Claude Code docs — Skill descriptions are cut short](https://code.claude.com/docs/en/skills#skill-descriptions-are-cut-short)):

- **Per-entry cap: 1,536 characters.** Each skill's `description` + `when_to_use` combined text is truncated at 1,536 characters regardless of the global budget.
- **Global context budget.** Scales dynamically at 1% of the context window, with a fallback of 8,000 characters. Override via the `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable. When many skills are loaded, each description's share of the budget shrinks — trailing content gets stripped first.

OpenCode's documented limit for the same field is 1024 characters. For portability across both harnesses, treat 1,024 as a soft budget for skills that must work on both; stay under 1,536 at a minimum.

Authoring rules:

- **Lead with trigger keywords.** Truncation happens at the tail, so the decisive "when to invoke this" words must come first.
- **Front-load the key use case.** The Claude Code docs' own guidance — one concrete TRIGGER phrase beats a paragraph of hedging.
- **Keep descriptions tight.** Detailed rules, cascades, and examples belong in the SKILL.md body, not the description.

When touching a skill description in the future, re-check the docs page linked above in case the caps have shifted.

### Skill workflow ordering — instructions before action

Applies to every plugin skill. The canonical failure example surfaced in `review-code`, but the rule is universal. See [ADR 0004](docs/adr/0004-skill-workflow-ordering.md) for the full rationale and the failure transcripts.

Core rule: a skill MUST fully load its instructions before taking any action on its subject matter.

- **Instructions** = `SKILL.md` + every process/rubric/protocol file it links + every per-skill symlinked shared instruction + (for profile-driven skills) every profile file the detection procedure resolves.
- **Action on subject matter** = reading diff/file content, editing code, engaging with idea prose beyond detection keywords, running tests, emitting documentation, producing findings.
- **Minimal early scope is permitted** — enough to drive profile detection. Examples: `git diff --stat` for filenames, a feature-directory listing, a keyword scan of idea prose. Content-level reading is blocked until instructions are fully loaded.
- **Content-level read instructions appear exactly once** in the workflow, after the instruction-load steps. Restating them earlier — even as a "Preflight" step — re-creates the failure mode.

Profile-driven skills have an additional specialization: profile content (resolved checklists, gotchas, rubrics, validator lists) is part of "instructions". Every `(profile, <phase>/<content>)` pair the detection procedure resolves is read via the `Read` tool before content-level subject-matter reading — index entries alone are not enough.

Authoring requirements for every skill:

1. **Mandatory-order directive** at the top of SKILL.md's Workflow section, explicitly stating that the flow is strictly sequential and subject-matter action is blocked until instructions are loaded. Name the rule by intent, not by step numbers — step numbers drift; intent does not.
2. **Workflow phase summary in SKILL.md matches the detailed process file.** A reader who skims SKILL.md must not see a different ordering than the process file prescribes.
3. **Dedup pass.** After drafting, grep the skill directory for repeated content-read instructions — if the same `git diff` / `Read` step appears twice, collapse to one instance at the post-instruction position.

Sub-agents delegated by skills (in `klaude-plugin/agents/`) inherit the same rule. Payload delivery order (the spawning skill passing instructions and subject matter in the same prompt) is not sufficient — the sub-agent's own workflow must read instructions before acting, or the LLM will re-create the shortcut on its side.

## Profile Conventions

Applies when authoring profiles under `klaude-plugin/profiles/`. Profiles make per-domain concerns (programming languages, IaC DSLs, config schemas) available to every phase of the `design` → `implement` → `review-code` → `test` → `document` flow.

### Directory layout

Every profile lives at `klaude-plugin/profiles/<name>/` and follows the same shape:

```
klaude-plugin/profiles/<name>/
  DETECTION.md       # authoritative trigger rule (required)
  overview.md        # human-readable summary + dependency-lookup targets (required)
  review-code/       # per-phase subdirectory (populated as needed)
    index.md         # router; see §`index.md` contract
    <content files>
  design/
  implement/
  test/
  document/
  review-spec/
```

Not every profile populates every phase — a programming-language profile may only need `review-code/`; an IaC profile like `k8s` populates all six. A phase subdirectory contains only its `index.md` and the files the index references; human-facing authoring notes belong in `overview.md` or a sibling file at the profile root.

### `DETECTION.md` — three-section schema

`DETECTION.md` is the single authoritative source for "when does this profile activate". It uses a mandatory three-section schema; every heading must be present even when its body is empty:

- **`## Path signals`** — path globs that promote a file to a candidate. Fast pre-filter only; not authoritative on their own.
- **`## Filename signals`** — literal filenames or filename globs. Authoritative: any match activates the profile.
- **`## Content signals`** — content-inspection rules (anchors, regexes, key presence). Authoritative for files not already caught by filename signals. Bounded inspection (~16 KB per file; multi-document YAML inspected per `---`-separated block).

**Two dimensions, different orders.** Signals are *evaluated* in cost order (path → filename → content) but *authority* runs filename ≈ content > path — filename and content are equally authoritative; filename resolves first only because it is cheaper to evaluate (a filename match short-circuits content inspection for that file). A file caught only by a path signal does not activate the profile.

Consumers invoke `klaude-plugin/skills/_shared/profile-detection.md` (via the per-skill symlinks `shared-profile-detection.md`) — they do not replicate per-profile logic.

### `index.md` contract — bidirectional invariant

Each phase subdirectory's `index.md` is the contract between the profile and the consuming skill. It has two sections:

- **Always load.** Files loaded whenever the profile is active. Each entry: markdown link + one-line description.
- **Conditional.** Files loaded only when a stated trigger matches. Each entry: link + description + an explicit **Load if:** clause naming concrete diff properties (field values, filenames, directory names) — not vague category labels. Two agents evaluating the same diff against the same trigger must reach the same conclusion.

**Bidirectional invariant** (enforced by `test/test-plugin-structure.sh`):

- **Forward.** Every markdown link in `index.md` resolves to a file on disk.
- **Reverse.** Every `.md` file in the phase subdirectory (except `index.md` itself) is referenced by at least one link in `index.md`.

An unreferenced `.md` inside a phase subdirectory is always a bug — an orphan checklist or a stray README. Authoring notes and READMEs belong at the profile root (in `overview.md` or a sibling file), not inside a phase subdirectory.

### Naming

- Lowercase profile names. Underscores allowed where filename-safe (e.g., `js_ts`).
- Phase subdirectory names match the consuming skill's directory name exactly: `review-code/`, `review-spec/`, `design/`, `implement/`, `test/`, `document/`.

### Referencing profile content from skills and agents

Skills and agents reference profile content via `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...` — no symlinks from skills into `profiles/` ([ADR 0003](docs/adr/0003-plugin-root-referenced-content.md)).

**Brace form required for substitution.** The Claude Code harness substitutes `${CLAUDE_PLUGIN_ROOT}` (with braces) before any agent reads the content. Bare `$CLAUDE_PLUGIN_ROOT` is NOT substituted.

**Substitution is markdown-container-unaware.** The harness applies a literal text replacement. Substitution happens inside inline backticks, fenced code blocks (plain / bash / markdown / tilde), indented code blocks, blockquotes, and HTML comments. **No markdown container escapes substitution.**

**Literal-reference authoring rule.** When prose *inside* `klaude-plugin/` (SKILL.md, agent files, profile content) needs to reference the variable *by name* — documenting or explaining it, not using it as a runtime path — use one of two surviving forms:

- Bare `$CLAUDE_PLUGIN_ROOT` (simplest; verified not substituted on 2026-04-18).
- HTML entity `&#36;{CLAUDE_PLUGIN_ROOT}` (useful when the brace shape must appear in rendered output).

**Substitution boundary: plugin-load vs `Read` tool.** The harness substitutes `${CLAUDE_PLUGIN_ROOT}` at **plugin-load time** for files the harness loads directly — SKILL.md, `agents/*.md`, hook configs, MCP configs. The brace form in those files reaches the agent as a resolved absolute path and can be used directly in tool arguments. **The `Read` tool does NOT substitute** — it returns file content byte-for-byte. Any `${CLAUDE_PLUGIN_ROOT}` inside a file an agent reads at runtime via `Read` (everything under `klaude-plugin/skills/_shared/`, per-skill referenced content, every `profiles/**/*.md`) reaches the agent as a literal token. Forwarding that literal into another tool call fails: `Bash` shell-expands against the usually-unset env var to empty; `Read` fails `ENOENT`.

Authoring consequence:

- Use `${CLAUDE_PLUGIN_ROOT}/…` freely in plugin-load files (SKILL.md, agent files, hook/MCP configs).
- In files consumed via `Read` at runtime, **prefer explicit content over tokens**: hard-code the names/paths the procedure needs (e.g., the Known Profiles list in `shared-profile-detection.md`). If the file must describe a plugin-root path, instruct the agent to construct it using the resolved prefix it already knows from the SKILL.md that invoked it — not to forward the literal `${CLAUDE_PLUGIN_ROOT}` token.
- Never use `Glob` against `${CLAUDE_PLUGIN_ROOT}/…` patterns regardless of substitution: `Glob` is cwd-scoped and returns 0 matches for outside-cwd absolute paths.

Files outside `klaude-plugin/` (this CLAUDE.md, README.md, ADRs under `docs/adr/`) are NOT subject to substitution and may use the brace form freely.

### Adding a new profile

1. Copy an existing profile as a template (e.g., `cp -r klaude-plugin/profiles/go klaude-plugin/profiles/<name>`).
2. Rewrite `DETECTION.md` with the new profile's three-section rule. Keep all three headings, even when empty.
3. Rewrite `overview.md`: what the profile covers, when it activates, and "Looking up dependencies" cascade targets for each dependency category the profile cares about.
4. Populate the phase subdirectories the profile needs. Each populated phase must have an `index.md` listing its content files (always-load + conditional with explicit **Load if:** clauses). Leave phases the profile does not serve absent — the structure test's presence-conditional assertion only fires on directories that exist.
5. Append the profile name to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` — *after* the profile's files exist, not before. Per-profile assertions will fail if the profile is listed first.
6. Append the profile name to the **Known profiles** list in `klaude-plugin/skills/_shared/profile-detection.md`. This list is the authoritative runtime enumeration — consumers iterate it rather than enumerating the filesystem (see §Referencing profile content for why).
7. Run `bash test/test-plugin-structure.sh` and confirm green.

## ADR location

Architecture decisions that span more than one feature live at `docs/adr/NNNN-slug.md` using [Michael Nygard's template](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (Context, Decision, Consequences). Per-feature design docs live at `docs/wip/<feature>/` while work is active and move to `docs/done/<feature>/` on completion — they are not ADRs.

# Extra Instructions

@.claude/CLAUDE.extra.md

# capy — MANDATORY routing rules

@.claude/capy/CLAUDE.md
