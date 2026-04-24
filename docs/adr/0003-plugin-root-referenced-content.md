# ADR 0003 — Profile content referenced via `${CLAUDE_PLUGIN_ROOT}`, not symlinked

- **Status:** Accepted
- **Date:** 2026-04-17
- **Originated in:** [docs/wip/kubernetes-support/design.md](../wip/kubernetes-support/design.md)
- **Related:** [ADR 0001](0001-profile-detection-model.md), [ADR 0002](0002-profile-content-organization.md)

## Context

[ADR 0002](0002-profile-content-organization.md) introduces `profiles/<name>/` as a new top-level directory, peer to `skills/`. Profile content is consumed by multiple skills (`review-code`, `review-spec`, `design`, `implement`, `test`, `document`) and by their sub-agents.

The plugin has an existing pattern for content shared across skills: `skills/_shared/<name>.md` with per-consuming-skill symlinks at `skills/<skill>/shared-<name>.md` → `../_shared/<name>.md`. This pattern is documented in `CLAUDE.md` and used today by `capy-knowledge-protocol.md`, `pal-codereview-invocation.md`, and `review-scope-protocol.md`.

If the same pattern were applied to profiles, a per-skill symlink into `profiles/` would look like:

```
skills/review-code/profiles  →  ../../profiles
```

This link points **outside** the `skills/` directory, to a sibling of `skills/`. A prior architecture decision, recorded in `kk:arch-decisions` during the OpenCode-support feature's design review, notes that relative symlinks pointing outside a package directory break under some plugin installers — specifically OpenCode's Bun-cache install, which copies the package into `~/.cache/opencode/node_modules/` without preserving outside-package relatives. The existing `_shared/` symlinks work because both ends stay inside `skills/`, so the relative path `../_shared/<name>.md` continues to resolve after the copy. A symlink into `profiles/` does not share that property.

Separately, Claude Code's runtime harness provides the environment variable `${CLAUDE_PLUGIN_ROOT}`, which resolves to the installed plugin's root directory. The plugin already uses this variable in `plugins/claude/hooks/hooks.json` for hook script references.

## Decision

**Profile content is referenced from consuming skills and agents via plugin-root-relative paths: `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...`. No symlinks are created from skills into `profiles/`.**

Skills and agents, when their prose needs to cite profile content, use the variable directly — for example, "load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md` for each active profile". The runtime agent resolves the path; the harness guarantees the variable is set.

**The brace form is mandatory.** Empirical verification (see §Verification) found that `${CLAUDE_PLUGIN_ROOT}` is substituted in SKILL.md prose but bare `$CLAUDE_PLUGIN_ROOT` (without braces) is NOT. Consuming skills and agents must use the brace form exclusively.

**Consuming code must handle the unset case.** If `CLAUDE_PLUGIN_ROOT` is absent (harness bug, manual CLI, local testing), `${CLAUDE_PLUGIN_ROOT}/foo` resolves to `/foo` at filesystem root — silent `ENOENT`. The `_shared/profile-detection.md` procedure (introduced by this feature) MUST include a presence check: fail loudly with an actionable message, or fall back to generic (no-profile) guidance. Every consumer inherits this check through the shared procedure.

The existing `_shared/` symlink pattern is **retained unchanged** for mechanism protocols (`capy-knowledge-protocol.md`, `pal-codereview-invocation.md`, `review-scope-protocol.md`, and the new `profile-detection.md` introduced by this feature). This ADR does *not* migrate those; they continue to use the established convention because they already work, and re-engineering them carries risk without immediate benefit.

## Verification

The mechanism was empirically tested on 2026-04-17 against Claude Code v2.1.112 / Opus 4.7 / `kk` plugin v0.9.0, by injecting three probes into an installed SKILL.md and invoking the skill in a fresh session (session-caching prevents mid-session testing).

Results:

- **`${CLAUDE_PLUGIN_ROOT}/path` in SKILL.md prose** — substituted to absolute path before the agent reads. **Works as specified.**
- **Mid-sentence substitution** (`The plugin root is ${CLAUDE_PLUGIN_ROOT}.`) — substituted. **Works.**
- **Sub-agent delivery** — a sub-agent spawned via the Task/Agent tool received the same already-substituted content as the top-level agent. **Works across agent boundaries.**
- **Bare `$CLAUDE_PLUGIN_ROOT` (no braces)** — NOT substituted; stays literal. **Brace form is required.**
- **Substitution inside inline code spans** (backticks) — DOES happen. Documentation that needs to reference the variable name literally cannot rely on inline backticks to protect it.

**Follow-up verification on 2026-04-18** (same environment; full results in `docs/wip/kubernetes-support/.sessions/probe-session-2.txt` and `probe-session-2-subagent.txt`) tested 14 markdown containers across both main-conversation and sub-agent contexts. Result: substitution is a pre-rendering text replacement matching the literal token `${CLAUDE_PLUGIN_ROOT}`, **unaware of any markdown container**. The following ALL substitute:

- inline backticks (`` ` ``)
- fenced code blocks (plain ```, ```bash, ```markdown, `~~~` tilde)
- indented code blocks (4-space)
- blockquotes (`>`)
- HTML comments (`<!-- ... -->`)
- backslash escape (`\${CLAUDE_PLUGIN_ROOT}` — the `\` is preserved, but the variable still expands)
- double backslash (same — both `\\` preserved, variable expands)

Only two forms survive unsubstituted:

- **Bare `$CLAUDE_PLUGIN_ROOT` (no braces)** — simplest form.
- **`&#36;{CLAUDE_PLUGIN_ROOT}` (HTML entity for `$`)** — useful when the brace form must appear in rendered output for readers.

Sub-agent context behaves identically to the main context; the substitution happens once in the harness pre-processing step, before any agent reads the content.

**Follow-up verification on 2026-04-19** (same environment; probe skill at `skills/test-plugin-root/SKILL.md` — temporary, removed after testing) tested how the substituted path is consumed by each tool the agent has when the substitution appears in **top-level SKILL.md prose**:

| Tool | Brace form in SKILL.md | Agent's tool input | Tool behavior |
|---|---|---|---|
| `Read`  | `${CLAUDE_PLUGIN_ROOT}/profiles/go/DETECTION.md` | resolved absolute path | reads file — **works** |
| `Bash`  | `ls ${CLAUDE_PLUGIN_ROOT}/profiles/` | command with resolved path | shell executes, lists files — **works** |
| `Glob`  | pattern `${CLAUDE_PLUGIN_ROOT}/profiles/*/DETECTION.md` | resolved absolute pattern | returns 0 matches — **fails silently** |

The `Glob` tool is scoped to the project `cwd`. Even when given a valid resolved absolute path that points outside `cwd`, it returns 0 matches. Substitution worked; the cwd-scoping is a tool-behavior constraint layered on top.

**Mechanism clarification (observed 2026-04-19).** A later probe against plugin v0.10.0-rc.1-alpha.3, reading `shared-profile-detection.md` (a `_shared/` referenced content file loaded via a per-skill symlink), emitted a `Bash(ls ${CLAUDE_PLUGIN_ROOT}/profiles/*/DETECTION.md)` call with the **literal `${CLAUDE_PLUGIN_ROOT}` token** reaching the shell. Shell expanded it against the unset env var to empty and silently missed. This pinned down the actual substitution boundary:

- **Substitution happens at plugin-load time**, for files the harness loads directly: `SKILL.md`, `plugins/claude/agents/*.md`, hook configs, MCP configs. By the time the agent's context receives these files, `${CLAUDE_PLUGIN_ROOT}` is already replaced with an absolute path.
- **The `Read` tool does not substitute.** When an agent calls `Read` at runtime on any file — including files inside `plugins/claude/` (referenced content under `_shared/`, profile files, anything in `profiles/`) — the tool returns the on-disk bytes verbatim. `${CLAUDE_PLUGIN_ROOT}` in that content stays literal. If the agent then copies that literal into another tool argument (Bash, another Read), the downstream tool receives the literal too: Bash shell-expands against the usually-unset env var to empty; Read fails ENOENT.

The 2026-04-17/18 SKILL.md probes were correct — substitution works for SKILL.md. Our 2026-04-18 follow-up note in `shared-profile-detection.md` claiming "verified on 2026-04-18; see ADR 0003 §Verification" was incorrect about *this* file — the probe sessions behind it tested SKILL.md, not `_shared/` content. The conflation was the bug. Symlink traversal, version regression, and install inconsistency all turned out to be non-causes — the mechanism was simply load-time vs runtime.

### Authoring rules

The rules follow directly from the mechanism:

1. **Plugin-load-time-substituted files** (safe to use `${CLAUDE_PLUGIN_ROOT}/…` freely):
   - `skills/<name>/SKILL.md`
   - `plugins/claude/agents/<name>.md`
   - `plugins/claude/hooks/*.json` command strings
   - `.mcp.json` / `mcp.json` configs

   Paths written with the brace form here reach the agent as resolved absolute paths and can be copied directly into tool arguments.

2. **Runtime-Read files** (the literal token reaches the agent; do NOT pass it to tools):
   - Any file referenced from a SKILL.md and loaded via `Read` at runtime. This includes everything in `skills/_shared/`, every per-skill referenced content file, every `profiles/**/*.md`, every file an agent reads mid-workflow.

   For these files, two patterns are safe:
   - **Explicit content** (preferred): hard-code the list of names/paths the procedure needs. Example: the **Known profiles** list in `shared-profile-detection.md` — profiles are enumerated from an explicit list in the file, not from a runtime filesystem walk.
   - **Inherit the resolved prefix from SKILL.md context**: instruct the agent to construct absolute paths using the resolved plugin-root it already knows from SKILL.md. Document this explicitly — the agent must know to substitute in its own reasoning, not forward the literal.

3. **Never use `Glob` against `${CLAUDE_PLUGIN_ROOT}/…` patterns.** Cwd-scoping applies regardless of substitution — even when the substituted absolute path is valid, `Glob` returns 0 matches for outside-cwd paths.

4. **Referencing the variable *by name* in prose** (documentation, convention text about the variable, not a runtime path): use bare `$CLAUDE_PLUGIN_ROOT` or `&#36;{CLAUDE_PLUGIN_ROOT}` — these survive plugin-load substitution intact. Functional uses in load-time files continue to use the brace form.

CLAUDE.md and `docs/adr/*.md` live outside the plugin tree; they are not subject to substitution and can use the brace form in any container.

Authoritative spec: [`code.claude.com/docs/en/plugins-reference`](https://code.claude.com/docs/en/plugins-reference) — "`${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are substituted inline anywhere they appear in skill content, agent content, hook commands, and MCP or LSP server configs."

Related upstream bug: [claude-code issue #9354](https://github.com/anthropics/claude-code/issues/9354) — `${CLAUDE_PLUGIN_ROOT}` was reportedly not substituted in slash-command markdown. Our empirical result above covers SKILL.md prose specifically, not slash-command markdown. If this plugin ever needs to reference the variable in `plugins/claude/commands/<name>/*.md` files, re-verify at that time.

Indexed as `kk:arch-decisions` for future retrieval: verification date, results, and caveats.

## Alternatives considered

### Per-skill symlinks to `../../profiles`

Mirror the existing `_shared/` pattern: create a directory symlink in each consuming skill that points at `profiles/`.

**Rejected.** Fragile under the documented OpenCode Bun-cache failure mode. Paying O(skills × profiles) symlink-maintenance cost for a property (local markdown link resolution) that profiles do not actually need — skills consume profiles dynamically based on detection, not via static markdown links in skill prose.

### Inline profile content in each consuming skill

Duplicate profile content under each skill's own directory.

**Rejected.** Opposes the single-source-of-truth principle that the profile-first architecture (ADR 0002) was chosen to uphold. Divergence is the exact failure mode shared directories were designed to prevent.

### Bundle profiles inside a designated "host" skill

Put profiles under (say) `review-code/profiles/` and have other skills reach across via `../review-code/profiles/`.

**Rejected.** Violates ADR 0002 — profiles are a peer concept, not property of any single skill. Putting them under a skill implies ownership that does not exist.

### Single symlink at plugin root pointing at profiles

Create `skills/profiles` → `../profiles`. Skills would then reference `profiles/<name>/…` as a sibling directory within `skills/`.

**Rejected.** Still an outside-skills-directory link from the perspective of downstream skills that would resolve through it. Preserves the fragility without its benefit. Also semantically misleading — skills would appear to have an in-tree `profiles` subfolder that does not exist in the source.

## Consequences

**Positive**

- Zero symlink maintenance for profile content. Adding, removing, or renaming a consuming skill does not touch `profiles/`. Adding a new profile does not touch any skill directory.
- Portable. A move or rename of `profiles/` updates every consumer by touching one variable (or keeping the convention stable). No scattered symlinks to repair.
- Decoupled from the package-install fragility. `${CLAUDE_PLUGIN_ROOT}` is resolved by the harness at runtime from whatever the installed plugin layout actually is; contributors do not need to think about Bun-cache or any other specific installer.
- Consistent with how the plugin already references internal paths in `hooks.json`.

**Negative**

- Markdown links inside skill prose that point at profile content are no longer clickable in a plain editor (`${CLAUDE_PLUGIN_ROOT}/profiles/k8s/...` is not a standard markdown link). Mitigation: skill prose describes the path rather than linking to it ("load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md`"), and the corresponding files in `profiles/` contain normal local markdown links that resolve in-tree.
- Contributors must be aware that the variable exists and is to be preferred for cross-directory references. Documented in `CLAUDE.md`'s new "Profile Conventions" section.
- Skills that are bundled or extracted in isolation (without the surrounding plugin) lose access to profile content. Acceptable: skills are not intended to be used outside the plugin context.

**Neutral**

- Asymmetry with `_shared/` symlinks. Documented here (see "Asymmetry rationale" below). Not a mistake — a deliberate reflection of the differing fragility profiles of the two link kinds.

## Asymmetry rationale — why `_shared/` uses symlinks and `profiles/` does not

Both patterns share a goal: give consuming skills access to content authored elsewhere without duplication.

They differ in one structural property:

- `_shared/<name>.md` lives **inside** `skills/`. A symlink from `skills/<skill>/shared-<name>.md` → `../_shared/<name>.md` stays **within** the package's `skills/` directory tree. Installers that copy `skills/` preserve the relative path.
- `profiles/<name>/...` lives **outside** `skills/`. A symlink from `skills/<skill>/...` into `../../profiles/...` crosses the package boundary. Installers that copy `skills/` (or parts of it) do not necessarily preserve the outside-the-tree relative.

The existing `_shared/` symlink pattern is safe *because* of the inside-skills-tree constraint. Generalizing it to `profiles/` would not be safe without confronting the outside-tree fragility. Using `${CLAUDE_PLUGIN_ROOT}` sidesteps the fragility entirely.

## Prototype for future work: can `_shared/` symlinks be removed?

A secondary, non-binding aim of this ADR is to document that the `${CLAUDE_PLUGIN_ROOT}` approach could *in principle* also replace the `_shared/` symlink pattern. We did not consider this option when the `_shared/` pattern was introduced. If it proves reliable for profiles, a future ADR may extend it.

### Hypothesis

`${CLAUDE_PLUGIN_ROOT}/skills/_shared/<name>.md` is resolvable by the runtime agent in the same way `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...` is. If true, the entire `_shared/` symlink apparatus could be replaced with direct variable-referenced paths, eliminating:

- Per-skill symlinks (~18 today: 3 shared files × 6 consuming skills, growing as more shared mechanisms are added).
- The `shared-<name>.md` file-naming convention.
- The need for contributors to remember "add a symlink when a skill starts consuming a shared file".

### Rollout approach

**Phase 1 — Mechanism validation (complete as of 2026-04-18).** See §Verification. All open questions from the original rollout plan are answered:

- Variable resolves correctly in SKILL.md prose on the tested Claude Code version. ✅
- Sub-agents receive substituted paths. ✅
- Brace form is required; bare form is not substituted. ⚠️ (new constraint, documented)
- Markdown-container awareness: the harness is NOT container-aware — substitution happens in every markdown container tested (fenced blocks, indented code, blockquotes, HTML comments, backslash escape). Literal-reference escape forms: bare `$CLAUDE_PLUGIN_ROOT` or `&#36;{CLAUDE_PLUGIN_ROOT}`. ✅

One question remains open and is deferred to real-world usage:

- Do IDE navigation and markdown-link tooling work acceptably for contributors reading skill prose? (`${CLAUDE_PLUGIN_ROOT}/foo/bar` is not a clickable link in most markdown viewers — minor contributor-experience cost, not a behavioral blocker.)

**Phase 2 — Real-world observation (pending).** Profiles ship with the mechanism; watch for issues across Claude Code releases, on OpenCode, and in contributor feedback:
- Cross-version stability of the substitution spec.
- Contributor confusion about where to use the variable vs a relative path.
- Cases where the HTML-entity escape renders unexpectedly in non-HTML markdown contexts.

**Phase 3 — Decision point (future ADR).** If no friction after one or more releases, propose a follow-up ADR to deprecate `_shared/` symlinks. Migration is O(N) where N = number of existing symlinks (~18 today). Mechanical:

- Rewrite skill prose to reference `${CLAUDE_PLUGIN_ROOT}/skills/_shared/<name>.md` directly.
- `git rm` each `skills/<skill>/shared-<name>.md` symlink.
- Update `test/test-plugin-structure.sh` to drop the symlink assertions; keep the existence assertions on the shared files themselves.
- Update `CLAUDE.md`'s "Shared instructions" section to describe variable references instead of the symlink pattern.

If friction surfaces in Phase 2, retain the dual approach permanently. `_shared/` keeps symlinks (they work); `profiles/` uses `${CLAUDE_PLUGIN_ROOT}`. The asymmetry becomes a stable pattern, not a transitional one. This ADR already documents why (see §Asymmetry rationale).

### Non-goals

This ADR does **not** migrate `_shared/` to `${CLAUDE_PLUGIN_ROOT}` references. Scoping that decision into the Kubernetes feature would conflate an architectural cleanup with a feature delivery. Profiles are the prototype; the broader migration, if any, is a separate deliberate step with its own ADR.

## References

- [ADR 0002 — Profile-first layout](0002-profile-content-organization.md)
- [CLAUDE.md — Shared instructions](../../CLAUDE.md) (existing convention, retained)
- [CLAUDE.md — Profile Conventions](../../CLAUDE.md) (added by this feature)
- `kk:arch-decisions` — OpenCode Bun-cache symlink fragility (from OpenCode-support feature design review)
- `plugins/claude/hooks/hooks.json` — prior use of `${CLAUDE_PLUGIN_ROOT}` in the plugin
