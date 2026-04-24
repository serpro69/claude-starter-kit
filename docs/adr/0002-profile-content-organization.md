# ADR 0002 — Profile-first layout with index-driven content loading

- **Status:** Accepted
- **Date:** 2026-04-17
- **Originated in:** [docs/wip/kubernetes-support/design.md](../wip/kubernetes-support/design.md)
- **Related:** [ADR 0001](0001-profile-detection-model.md), [ADR 0003](0003-plugin-root-referenced-content.md)

## Context

Profile detection ([ADR 0001](0001-profile-detection-model.md)) produces a set of active profiles for the current task. Skills need a consistent place and shape for the profile content they consume: review-code loads checklists; `design` loads idea-refinement prompts; `test` loads validator catalogs; `implement` loads per-task gotchas; `document` loads doc rubrics; `review-spec` loads spec-vs-impl semantics.

Two orthogonal organizational questions must be answered together:

1. **Where does profile content live?** The plugin has an existing `skills/_shared/<name>.md` pattern for shared instructions consumed by multiple skills, with per-skill symlinks. That pattern works for mechanism (capy knowledge protocol, review-scope protocol, pal-codereview invocation). For profile *content*, which can grow along two axes — number of profiles, and (skill × profile) combinations — the flat `_shared/` directory becomes a dumping ground that mixes mechanism with content, and the symlink count grows linearly with profile count.

2. **What shape does content take inside a profile?** The existing `reference/<lang>/` directory uses fixed filenames: `security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`. For Kubernetes, "SOLID" is a stretch and "code-quality" is an awkward name for YAML. Additional profile-specific checklists (Helm, Kustomize) do not fit any of the four slots.

The two questions are linked: if content organization is hardcoded by filename across skills, shape divergence cascades into cross-profile inconsistency. If the shape is discoverable per profile, the organization can be more flexible.

## Decision

**Profile content lives in a new top-level `profiles/<name>/` directory, peer to `skills/`. Each profile is self-contained and self-describing. Skills discover content via `index.md` files inside per-phase subdirectories, not via hardcoded filenames. The index acts as a router: it lists available content with always-load vs conditional-load metadata and one-line descriptions; consumers load the subset relevant to the current task.**

Profile layout:

```
profiles/<name>/
  DETECTION.md         # authoritative trigger rule (per ADR 0001)
  overview.md          # human-readable profile summary, dependency-lookup targets
  review/
    index.md           # router: always-load entries, conditional entries with triggers
    <checklist files>  # named to fit the profile's content, not a fixed schema
  design/              # populated as profiles adopt design-phase content
    index.md
  test/
  implement/
  document/
  review-spec/         # populated as profiles adopt review-spec-phase content
```

Existing `review-code/reference/<lang>/` directories migrate to `profiles/<lang>/review/` as part of this feature's P0 phase. Migration is mechanical: file moves, plus an authored `index.md` per profile that lists the already-existing checklists as always-load entries.

Skill workflows stop encoding checklist filenames as hardcoded step names. The review-code workflow's former "Step 3: SOLID / Step 4: Removal / Step 5: Security / Step 6: Quality" collapses into "Step 3: load each active profile's `review/index.md`; resolve entries per always-load and conditional triggers; apply each resolved checklist; group findings by (profile, checklist)". The same index-driven pattern extends to every other per-phase subdirectory consumed by other skills.

## Alternatives considered

### Flat `_shared/<profile>-<phase>.md` (per-skill content in shared dir)

Place profile content as flat files in the existing `_shared/` dir: `_shared/k8s-profile.md`, `_shared/k8s-design.md`, `_shared/terraform-profile.md`, etc. Consuming skills get per-skill symlinks per existing convention.

**Rejected.** Three failure modes:

1. **Mixes mechanism with content.** `_shared/` today holds mechanism protocols (capy, review-scope, pal-codereview). Profile content is a different category of thing; conflating them erodes the purpose of `_shared/`.
2. **Symlink proliferation.** Each consuming skill needs one symlink per shared profile file. Five profiles × six consuming skills × (at most) five phase files per profile = up to 150 symlinks. Maintainable but noisy.
3. **(Skill × profile) content is a 2D matrix flattened into a 1D directory.** A file like `_shared/go-patterns-for-implement.md` is semantically (implement × go), but the flat directory obscures the structure. A profile-first layout expresses the matrix directly as `profiles/go/implement/`.

### Strict filename parallelism

All profiles use the same fixed filenames (`security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`). K8s stretches "solid" to mean "architecture/composition" and folds Helm/Kustomize content into the quality file.

**Rejected.** Forces semantic mismatch at the filename level. "SOLID for Kubernetes" is misleading; "code-quality for YAML" is imprecise. The resulting content reads as if it were retrofitted into the wrong slots. Index-driven loading decouples skill prose from filenames and dissolves this problem: each profile names its files to fit its content.

### Fully free-form per profile

No naming convention at all. Each profile picks whatever filenames make sense; the workflow iterates all `.md` files in `review/` and applies them.

**Rejected.** Removes useful cross-profile consistency. Reviewers and contributors benefit from knowing "every profile has *some* security guidance and *some* architecture guidance"; entirely free-form loses that scaffolding without giving back enough in exchange.

### Per-skill duplication

Each consuming skill copies the K8s-specific block inline in its own SKILL.md.

**Rejected.** The exact failure mode the shared-instruction pattern was created to prevent. Divergence is inevitable.

## Consequences

**Positive**
- One self-contained directory per profile; adding a new profile is a template-copy operation.
- Cross-profile consistency comes from the presence of `index.md` in each phase subdirectory, not from rigid filename conventions.
- Adding a new checklist to an existing profile = create the file, add an index line; no skill prose touched.
- Index-driven loading scales naturally to any number of checklists per profile, and any number of profiles.
- (Skill × profile) content has a natural home: `profiles/<name>/<phase>/*`.

**Negative**
- A one-time workflow restructure inside `review-code` (SKILL.md, review-process.md, review-isolated.md, code-reviewer agent prompt). Steps 3–6 collapse into a more generic "load indexes, apply checklists" sequence. This is paid once, benefits all current and future profiles.
- A new top-level directory convention in the plugin. Documented in CLAUDE.md.
- Consumers that previously hardcoded a filename (`security-checklist.md`) now depend on the index being accurate. Mitigated by a test assertion that every file referenced by an index.md exists on disk.

**Neutral**
- Programming-language profiles retain their existing checklist filenames (SOLID is still the right content for Go); the rename that Q6 considered is no longer needed. Each profile names its files to fit, and cross-profile uniformity is re-established at the index layer.

## Forward direction

The index-driven pattern has room to grow without schema churn:

- **Richer index entries.** Conditional triggers are currently described in prose ("Load if Deployment/StatefulSet in diff"). As detection matures, triggers could take structured form (regex, content patterns, path globs) parsable by the workflow. Index files remain readable markdown by adding structured fields alongside the descriptions, not replacing them.
- **(Skill × profile) content.** Already expressible: `profiles/<name>/<phase>/*`. No additional decision needed.
- **Cross-profile aggregation.** A future tool could enumerate profiles and produce a plugin-wide checklist catalog. Possible because each profile's shape is uniform.

Migration back to a flat or pre-profile-first layout would be mechanical (`git mv`). The content and the index mental model port forward; the directory layout is the variable under our control.

## References

- [design.md — Architecture overview](../wip/kubernetes-support/design.md#architecture-overview)
- [design.md — File structure](../wip/kubernetes-support/design.md#file-structure)
- [design.md — Content organization within profiles](../wip/kubernetes-support/design.md#content-organization-within-profiles)
- [CLAUDE.md — Profile Conventions (added by this feature)](../../CLAUDE.md)
