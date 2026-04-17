# ADR 0003 — Profile content referenced via `${CLAUDE_PLUGIN_ROOT}`, not symlinked

- **Status:** Accepted
- **Date:** 2026-04-17
- **Originated in:** [docs/wip/kubernetes-support/design.md](../wip/kubernetes-support/design.md)
- **Related:** [ADR 0001](0001-profile-detection-model.md), [ADR 0002](0002-profile-content-organization.md)

## Context

[ADR 0002](0002-profile-content-organization.md) introduces `klaude-plugin/profiles/<name>/` as a new top-level directory, peer to `klaude-plugin/skills/`. Profile content is consumed by multiple skills (`review-code`, `review-spec`, `design`, `implement`, `test`, `document`) and by their sub-agents.

The plugin has an existing pattern for content shared across skills: `klaude-plugin/skills/_shared/<name>.md` with per-consuming-skill symlinks at `skills/<skill>/shared-<name>.md` → `../_shared/<name>.md`. This pattern is documented in `CLAUDE.md` and used today by `capy-knowledge-protocol.md`, `pal-codereview-invocation.md`, and `review-scope-protocol.md`.

If the same pattern were applied to profiles, a per-skill symlink into `profiles/` would look like:

```
skills/review-code/profiles  →  ../../profiles
```

This link points **outside** the `skills/` directory, to a sibling of `skills/`. A prior architecture decision, recorded in `kk:arch-decisions` during the OpenCode-support feature's design review, notes that relative symlinks pointing outside a package directory break under some plugin installers — specifically OpenCode's Bun-cache install, which copies the package into `~/.cache/opencode/node_modules/` without preserving outside-package relatives. The existing `_shared/` symlinks work because both ends stay inside `skills/`, so the relative path `../_shared/<name>.md` continues to resolve after the copy. A symlink into `profiles/` does not share that property.

Separately, Claude Code's runtime harness provides the environment variable `${CLAUDE_PLUGIN_ROOT}`, which resolves to the installed plugin's root directory. The plugin already uses this variable in `klaude-plugin/hooks/hooks.json` for hook script references.

## Decision

**Profile content is referenced from consuming skills and agents via plugin-root-relative paths: `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...`. No symlinks are created from skills into `profiles/`.**

Skills and agents, when their prose needs to cite profile content, use the variable directly — for example, "load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md` for each active profile". The runtime agent resolves the path; the harness guarantees the variable is set.

The existing `_shared/` symlink pattern is **retained unchanged** for mechanism protocols (`capy-knowledge-protocol.md`, `pal-codereview-invocation.md`, `review-scope-protocol.md`, and the new `profile-detection.md` introduced by this feature). This ADR does *not* migrate those; they continue to use the established convention because they already work, and re-engineering them carries risk without immediate benefit.

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

Create `klaude-plugin/skills/profiles` → `../profiles`. Skills would then reference `profiles/<name>/…` as a sibling directory within `skills/`.

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

### Rollout approach (if we pursue this)

1. **Observe this feature's rollout.** Profiles land with `${CLAUDE_PLUGIN_ROOT}`-based references (no symlinks). Watch for failure modes over one or more releases:
   - Does the variable resolve correctly across all supported Claude Code versions and installers?
   - Do IDE navigation and markdown-link tooling work acceptably for contributors reading skill prose?
   - Do sub-agents receive the variable correctly when prompts include it?

2. **If no friction surfaces**, propose a follow-up ADR to deprecate `_shared/` symlinks. The migration is O(N) where N = number of existing symlinks (~18). Mechanical:
   - Rewrite skill prose to reference `${CLAUDE_PLUGIN_ROOT}/skills/_shared/<name>.md` directly.
   - `git rm` each `skills/<skill>/shared-<name>.md` symlink.
   - Update `test/test-plugin-structure.sh` to drop the symlink assertions; keep the existence assertions on the shared files themselves.
   - Update `CLAUDE.md`'s "Shared instructions" section to describe variable references instead of the symlink pattern.

3. **If friction surfaces**, retain the dual approach permanently. `_shared/` keeps symlinks (they work); `profiles/` uses `${CLAUDE_PLUGIN_ROOT}`. The asymmetry becomes a stable pattern, not a transitional one. This ADR already documents why.

### Non-goals

This ADR does **not** migrate `_shared/` to `${CLAUDE_PLUGIN_ROOT}` references. Scoping that decision into the Kubernetes feature would conflate an architectural cleanup with a feature delivery. Profiles are the prototype; the broader migration, if any, is a separate deliberate step with its own ADR.

## References

- [ADR 0002 — Profile-first layout](0002-profile-content-organization.md)
- [CLAUDE.md — Shared instructions](../../CLAUDE.md) (existing convention, retained)
- [CLAUDE.md — Profile Conventions](../../CLAUDE.md) (added by this feature)
- `kk:arch-decisions` — OpenCode Bun-cache symlink fragility (from OpenCode-support feature design review)
- `klaude-plugin/hooks/hooks.json` — prior use of `${CLAUDE_PLUGIN_ROOT}` in the plugin
