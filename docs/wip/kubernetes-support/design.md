# Kubernetes support — design

- **Feature:** kubernetes-support
- **Status:** in-design
- **Branch:** `k8s_support`
- **Closes:** [issue #64 — Enhance review-code skill with support for k8s](https://github.com/serpro69/claude-toolbox/issues/64) (narrow) — expanded to the whole plugin flow per the originating discussion
- **Implementation plan:** [implementation.md](implementation.md)
- **Task list:** [tasks.md](tasks.md)
- **ADRs:** [0001](../../adr/0001-profile-detection-model.md), [0002](../../adr/0002-profile-content-organization.md), [0003](../../adr/0003-plugin-root-referenced-content.md)

## Overview

Kubernetes becomes a first-class *profile* that every phase of the plugin's design → implement → review → test → document flow can consult when the artifacts under work are Kubernetes resources (plain manifests, Helm charts, Kustomize overlays). The feature also refactors the plugin's content organization so that Kubernetes is the first instance of a general pattern, not a special case — future profiles (Terraform, Ansible, Dockerfile, others) drop into the same slots without further architectural change.

The literal text of issue #64 is narrow: "enhance `review-code` with support for k8s". The chosen scope is broader — the whole flow, phased — because fixing only `review-code` would leave design, implementation, test, and documentation skills unable to deploy the same Kubernetes awareness, forcing per-project duplication of concerns that the plugin exists to provide.

## Motivation

The plugin currently handles programming languages (Go, Python, Java, JS/TS, Kotlin) as the only axis of per-project variation. When the code under review is Kubernetes YAML, the language-detection step returns nothing, and the reviewer falls back to generic guidance that is blind to Kubernetes-specific concerns (RBAC least privilege, probe correctness, PodDisruptionBudget presence, secret handling, image-tag immutability, Helm chart hygiene, Kustomize composition). The same blindness affects every other skill in the flow.

Three architectural decisions (recorded as ADRs [0001](../../adr/0001-profile-detection-model.md), [0002](../../adr/0002-profile-content-organization.md), [0003](../../adr/0003-plugin-root-referenced-content.md)) must be settled before Kubernetes content can land coherently, and they apply beyond Kubernetes. This feature adopts them in-feature rather than deferring, so that the Kubernetes content lands in its final shape and is not migrated later.

## Scope

### In scope (this feature)

- **Kubernetes manifests.** Core resources: Deployment, StatefulSet, DaemonSet, Job, CronJob, Service, Ingress, ConfigMap, Secret, RBAC (Role/ClusterRole/RoleBinding/ClusterRoleBinding/ServiceAccount), NetworkPolicy, HorizontalPodAutoscaler, PodDisruptionBudget, SecurityContext, probes, resource requests/limits.
- **Helm chart hygiene.** `Chart.yaml` metadata, `values.yaml` schema, `templates/` correctness, dependency pinning.
- **Kustomize composition.** `kustomization.yaml`, base/overlay structure, patch targets, generator options.
- **Profile-first plugin architecture.** `klaude-plugin/profiles/<name>/` top-level directory; migration of the existing programming-language reference sets into the new layout.
- **Index-driven content loading.** `index.md` routing inside each profile's per-phase subdirectory.
- **Cross-skill plumbing.** `klaude-plugin/skills/_shared/profile-detection.md` as a shared mechanism; plugin-root path references from skills to profile content.
- **Conventions.** `CLAUDE.md` additions documenting profiles, skill description budgets, and ADR location. Three ADRs under `docs/adr/`.

### Out of scope (explicit deferrals)

- **GitOps resources** (ArgoCD `Application`/`ApplicationSet`, Flux `Kustomization`/`HelmRelease`). Most GitOps rules reduce to "does the synced manifest pass the manifest rules?"; the ArgoCD-vs-Flux split would add noise without a clear payoff at this stage. A follow-up feature can add a `gitops/` slot inside the Kubernetes profile or a separate GitOps profile.
- **Service mesh** (Istio, Linkerd, Gateway API). Too stack-specific for a shipped generic profile; better captured per-project as `kk:project-conventions`.
- **Observability CRDs** (`ServiceMonitor`, `PrometheusRule`). Same reasoning.
- **Policy engines** (Kyverno, OPA/Gatekeeper) as baseline content. The `test` phase auto-detects policy toolchains via project markers (see §[test skill integration](#test-skill-integration)); hard-coding any single engine into the profile is out of scope.
- **Dockerfile.** Conceptually adjacent but distinct. A future container profile can address Dockerfiles; conflating would widen the Kubernetes profile beyond its focus.
- **Programming-language profile authoring.** Existing Go/Python/Java/JS-TS/Kotlin checklists migrate unchanged in content; no new per-language content is added by this feature.

## Architecture overview

Three concepts, described here and expanded in their own sections below.

### A single, additive detection axis

[ADR 0001](../../adr/0001-profile-detection-model.md) records that detection remains a single axis — all detectable artifact types (programming languages, IaC DSLs, config schemas) are equal rows in one detection table. Matching a file contributes that row's reference directory to the set loaded for the current task. Multiple matches are additive. The existing `%LANGUAGE%` placeholder in skill prose retains its current semantics; profile content is consulted additively where it applies.

The term "language" is retained. Editor tooling (LSP, VS Code) already treats YAML, Dockerfile, HCL, and others as "languages" under an umbrella-term usage. Adopting that framing keeps the existing prose honest.

### Profile-first content layout

[ADR 0002](../../adr/0002-profile-content-organization.md) records that profile content lives in a new top-level `klaude-plugin/profiles/<name>/` directory, peer to `klaude-plugin/skills/`. Each profile is self-contained (`DETECTION.md`, `overview.md`, per-phase subdirectories). Existing `review-code/reference/<lang>/` directories migrate in. Skills discover content via `index.md` routers inside per-phase subdirectories — not via hardcoded filenames.

### Plugin-root references instead of outside-tree symlinks

[ADR 0003](../../adr/0003-plugin-root-referenced-content.md) records that skills and agents reference profile content via plugin-root-relative paths: `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...`. No symlinks are created from skills into `profiles/`. The existing `_shared/` symlink pattern, which stays inside `skills/`, is unchanged. The choice of variable-referenced paths for outside-skills-directory content prototypes a pattern that may later replace `_shared/` symlinks entirely (see ADR 0003's "prototype for future work" section).

## Detection mechanics

Detection is the responsibility of each profile, declared in `klaude-plugin/profiles/<name>/DETECTION.md`. Skills consume detection through a shared procedure (see [Shared mechanisms](#shared-mechanisms)), not by replicating per-profile logic.

### Kubernetes detection — combined rule

A file matches the Kubernetes profile when any of the following holds. The three signals are ordered from cheapest to most authoritative; authority is content.

1. **Path heuristic (fast pre-filter).** The file lives under one of `k8s/`, `manifests/`, `charts/`, `kustomize/`, `deploy/` (case-insensitive, anywhere in the path). A match under path heuristic alone promotes the file to a candidate but does not decide by itself.
2. **Filename (authoritative for known names).** `Chart.yaml` → Helm (authoritative). `values*.yaml` at the same directory level as a `Chart.yaml` → Helm values (authoritative by adjacency). `kustomization.yaml` → Kustomize (authoritative). These filenames are unambiguous by definition.
3. **Content signature (authoritative for generic YAML).** For any `.yaml` or `.yml` file not already resolved by #2, the first few tens of lines are examined for a top-level `apiVersion:` *and* `kind:` at zero indent. Both present → Kubernetes manifest. Either missing → not Kubernetes (the file may still match some other profile; generic YAML that belongs to neither CI configuration nor a config schema is treated as no-profile).

A file matching under #2 or #3 activates the profile even without a path heuristic hit — the profile works correctly on non-conventional layouts. A file matching only #1, with neither #2 nor #3, does not activate the profile — the path heuristic alone is insufficient signal.

### Multi-profile and no-profile outcomes

- **Multiple profiles match in the same diff.** Every matching profile's reference directory is loaded. A Go + Kubernetes diff consults `profiles/go/review/` and `profiles/k8s/review/` both. Findings are emitted grouped by (profile, checklist).
- **No profile matches.** The skill proceeds with generic guidance, identical to today's "no language detected" fallback.

### Dockerfile interaction

If a Dockerfile appears in a diff that also contains Kubernetes artifacts, the Kubernetes profile still activates — but Dockerfile-specific review is not performed. A future container profile can own Dockerfiles independently; this feature explicitly does not widen the Kubernetes profile to cover them.

### Detection output shape

Detection emits a list of records, one per matched profile: `{profile: <name>, triggered_by: [<signal descriptions>], files: [<paths>]}`. Downstream skills use the `files` field to scope their own behavior — for example, the `test` skill runs `helm lint` only on files that triggered under Helm signals, not on every YAML.

## File structure

Per-profile layout is uniform. Every profile under `klaude-plugin/profiles/` follows the same shape:

```
klaude-plugin/profiles/<name>/
  DETECTION.md             # authoritative trigger rule (see §Detection mechanics)
  overview.md              # human-readable profile summary + dependency-lookup targets
  review/                  # consumed by review-code
    index.md               # router: always-load entries, conditional entries, one-liners
    <checklist files>      # named to fit the profile's content; no fixed schema
  design/                  # consumed by design (populated per-profile as needed)
  test/                    # consumed by test (populated per-profile as needed)
  implement/               # consumed by implement (populated per-profile as needed)
  document/                # consumed by document (populated per-profile as needed)
  review-spec/             # consumed by review-spec (populated per-profile as needed)
```

Not every profile populates every phase subdirectory. A programming-language profile may only ever need `review/`; an IaC profile like Kubernetes populates all six. The plugin structure test (`test/test-plugin-structure.sh`) asserts the *presence* of each directory and file a profile declares — not that every profile populates every slot.

### The Kubernetes profile, concretely

After both P0 and P1 have landed:

```
klaude-plugin/profiles/k8s/
  DETECTION.md
  overview.md
  review/
    index.md
    security-checklist.md           # RBAC, Pod Security, NetworkPolicy, secrets, image provenance
    architecture-checklist.md       # resource separation of concerns, config injection, no hardcoded cluster assumptions
    quality-checklist.md            # labels/selectors, immutable tags, resource requests+limits, probe correctness
    reliability-checklist.md        # PDBs, probe semantics, graceful shutdown, anti-affinity, topology spread
    helm-checklist.md               # Chart.yaml metadata, values schema, templates correctness, pinned deps
    kustomize-checklist.md          # overlay structure, patch targets, generator options
    removal-plan.md                 # template for staged resource/CRD/namespace removal
```

P2 adds `profiles/k8s/design/`, `profiles/k8s/test/`, `profiles/k8s/implement/`, `profiles/k8s/document/`, each with an `index.md` and the corresponding content.

P3 adds `profiles/k8s/review-spec/` if K8s-specific spec-vs-implementation semantics warrant a slot.

### Migrated programming-language profiles

The existing content under `klaude-plugin/skills/review-code/reference/<lang>/` moves to `klaude-plugin/profiles/<lang>/review/`. Files keep their current names (`security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`) — SOLID *is* the appropriate content for Go and the other programming-language profiles, and "code-quality" fits those profiles naturally. Each profile gains a new `index.md` listing the existing four files as always-load entries. Cross-profile consistency comes from the presence of `index.md`, not from filename uniformity.

## Content organization within profiles

Each per-phase subdirectory contains an `index.md`. The index is the contract between the profile and consuming skills.

### Index file structure

An `index.md` has two sections:

- **Always load.** Files that must be loaded whenever the profile is active. Each entry is a markdown link to the file plus a one-line description of what it covers.
- **Conditional.** Files that are loaded only when a stated trigger matches the current task. Each entry is the same link + description, followed by an explicit **Load if:** clause naming the trigger condition. Triggers are stated in prose for readability; structured trigger expressions are a possible future extension (see [ADR 0002](../../adr/0002-profile-content-organization.md), "Forward direction").

For the Kubernetes `review/index.md`:

- Always-load: `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md`.
- Conditional: `reliability-checklist.md` (when workload resources — Deployment / StatefulSet / DaemonSet / Job / CronJob — are in the diff), `helm-checklist.md` (when `Chart.yaml`, `values*.yaml`, or `templates/` appear), `kustomize-checklist.md` (when `kustomization.yaml`, `bases/`, `overlays/`, or patches appear).

For the migrated programming-language profiles (e.g., `profiles/go/review/index.md`), all four existing files are always-load; no conditional entries.

### Content file structure

Individual checklist files are free-form markdown organized by whatever structure fits the content. The feature does not impose an inner schema. Consumers read the index and then read the full file content of whatever the index tells them to load.

## Shared mechanisms

### `_shared/profile-detection.md`

A new file, `klaude-plugin/skills/_shared/profile-detection.md`, captures the detection procedure exactly once. Consumers: `review-code`, `review-spec`, `design`, `implement`, `test`, `document`. The procedure takes a diff (or workspace) as input and produces the list of active profiles by iterating `klaude-plugin/profiles/*/DETECTION.md` and applying each rule.

Per CLAUDE.md's "Shared instructions" convention, each consuming skill gets a symlink: `klaude-plugin/skills/<skill>/shared-profile-detection.md` → `../_shared/profile-detection.md`. Six symlinks total.

Agents (under `klaude-plugin/agents/`) that need to invoke detection reference the shared file by repo-relative path — `klaude-plugin/skills/_shared/profile-detection.md` — per the existing CLAUDE.md rule that agents do not use the per-skill symlink pattern.

### Why this is symlinked but `profiles/` is not

The `_shared/` symlink stays inside `skills/`. A symlink from `skills/<skill>/shared-profile-detection.md` → `../_shared/profile-detection.md` crosses a single directory boundary but does not leave the `skills/` tree, which is the property installers such as OpenCode's Bun-cache preserve reliably. A symlink from `skills/<skill>` into the sibling `profiles/` directory does not share that property. See [ADR 0003](../../adr/0003-plugin-root-referenced-content.md) for the full rationale.

## Skill integration

### `review-code` — P0 refactor + P1 Kubernetes content

**P0 (behavior-preserving refactor).** The existing reference directories migrate to `profiles/`. The workflow inside `review-code` changes shape: hardcoded category steps collapse into a generic index-driven loading step.

Touched files:
- `klaude-plugin/skills/review-code/SKILL.md` — prose updated to describe profile detection (via shared procedure) and index-driven loading. The description frontmatter does not change.
- `klaude-plugin/skills/review-code/review-process.md` — the former "Step 2: Detect primary language" renames to "Step 2: Detect active profiles" and consults the shared procedure. Former steps 3–6 (SOLID, Removal, Security, Quality) collapse into a pair of generic steps: "Step 3: For each active profile, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md`; resolve entries per always-load and conditional triggers" and "Step 4: Apply each resolved checklist; emit findings grouped by (profile, checklist)". Downstream steps (self-check, indexing, output formatting) are unchanged.
- `klaude-plugin/skills/review-code/review-isolated.md` — parallel restructure; the sub-agent prompt receives the list of resolved checklists, not a hardcoded category sequence.
- `klaude-plugin/skills/review-code/reference/` — directory removed (its contents have moved to `profiles/<lang>/review/`).
- `klaude-plugin/agents/code-reviewer.md` — prompt updated to iterate the resolved-checklists list.

**P1 (Kubernetes content).** No additional `review-code` skill changes. The profile-first architecture absorbs the new profile transparently.

Touched files:
- `klaude-plugin/profiles/k8s/DETECTION.md` (new)
- `klaude-plugin/profiles/k8s/overview.md` (new)
- `klaude-plugin/profiles/k8s/review/index.md` (new)
- `klaude-plugin/profiles/k8s/review/*.md` (seven checklist files, new)

### `design` — P2 Kubernetes-aware idea refinement

When detection identifies Kubernetes in the anticipated surface area of a feature, the `design` skill's idea-refinement step consults `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/design/index.md` for Kubernetes-specific question banks and design-section prompts (cluster topology, GitOps tool choice, secrets strategy, multi-tenancy, observability posture, rollback strategy).

Touched files:
- `klaude-plugin/skills/design/SKILL.md` — top-level prose retains its current meaning.
- `klaude-plugin/skills/design/idea-process.md` — Step 3 (refine the idea) and Step 5 (document the design) gain a clause: "Run profile detection; for each active profile, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/design/index.md` and let it inform the question bank and design sections."
- `klaude-plugin/skills/design/existing-task-process.md` — equivalent clause in the continue-WIP flow.
- `klaude-plugin/skills/design/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/design/index.md` (new)
- `klaude-plugin/profiles/k8s/design/<content files>` (new)

### `implement` — P2 per-task K8s gotchas

When the current sub-task touches files matching an active profile, `implement` loads `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/implement/index.md` for per-task gotchas before writing.

Touched files:
- `klaude-plugin/skills/implement/SKILL.md` — Step 2 (execute sub-task) gains a bullet: "When the sub-task touches a file matching an active profile's detection rule, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/implement/index.md` for per-task gotchas before writing. Apply the `dependency-handling` skill if the sub-task introduces or changes a dependency (including Kubernetes API versions, CRDs, Helm charts, container images per the widened trigger — see §[dependency-handling](#dependency-handling-integration))."
- `klaude-plugin/skills/implement/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/implement/index.md` (new)
- `klaude-plugin/profiles/k8s/implement/<content files>` (new)

### `test` — P2 validator guidance with policy-hook auto-detection

The `test` skill's K8s content mandates a minimum validator floor, catalogs additional tools as a menu, and auto-honors project-local policy toolchains when markers are present. See decisions Q7:C in the design Q&A.

**Minimum floor (mandated when Kubernetes profile is active).**
- `kubeconform` — offline schema validation on all matched K8s YAML.
- `helm lint` — run on each Helm chart directory matched in the diff (via `Chart.yaml` presence).
- `kustomize build` — run on each Kustomize directory matched in the diff (via `kustomization.yaml` presence).

Cluster-dependent tools (`kubectl --dry-run=server`, `popeye`) are not in the floor; they are mentioned as optional "if a staging cluster is available".

**Menu (suggested).**
- `kube-score`, `kube-linter`, `polaris` — best-practices linters.
- `trivy config`, `checkov`, `kics` — security scanners (overlapping; projects usually pick one).

**Policy-hook auto-detection.** The skill checks the project for policy-toolchain markers:
- `.conftest/` directory or `policies/*.rego` → run `conftest test` against the matched manifests.
- `kyverno-policies/` directory or presence of Kyverno `ClusterPolicy`/`Policy` resources → run `kyverno test`.
- `.gator/` or Gatekeeper `ConstraintTemplate`/`Constraint` resources → run `gator test`.
- None present → policy validation is skipped without comment.

Tools in the floor and the active policy engine are treated as required checks; menu tools are treated as optional.

Touched files:
- `klaude-plugin/skills/test/SKILL.md` — guidelines gain a clause: "After language-specific test patterns, for each active profile load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/test/index.md` and apply the validators and check categories it specifies."
- `klaude-plugin/skills/test/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/test/index.md` (new)
- `klaude-plugin/profiles/k8s/test/<content files>` (new) — floor validators, the menu, the policy-hook detection procedure.

### `document` — P2 rubric for K8s artifacts

The `document` skill consults `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/document/index.md` for the doc rubric when an active profile has opinions about what to document.

Touched files:
- `klaude-plugin/skills/document/SKILL.md` — guidelines gain: "For each active profile, consult `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/document/index.md` for the per-profile doc rubric."
- `klaude-plugin/skills/document/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/document/index.md` (new)
- `klaude-plugin/profiles/k8s/document/<content files>` (new) — RBAC decision rationale, rollback runbook, resource-baseline documentation, cluster-compat matrix when applicable.

### `review-spec` — P3 K8s-awareness polish

The existing `review-spec` finding taxonomy (missing_impl, spec_dev, doc_incon, extra_impl) carries over to Kubernetes unchanged; the shape of findings shifts slightly because "implementation" is declarative YAML, not imperative code.

- "Missing implementation" looks like a design-specified resource (e.g., a PDB with stated `minAvailable`) that is not present in any manifest.
- "Spec deviation" looks like a field value in manifest that disagrees with the design (e.g., `imagePullPolicy: Always` where the design says `IfNotPresent`).
- "Doc inconsistency" looks like a port mismatch between design narrative and Service/Container port declarations.

Touched files:
- `klaude-plugin/skills/review-spec/SKILL.md` — prose gains a clause: "When profile detection finds an IaC profile active (e.g., K8s, Terraform), treat the declarative artifacts as the implementation; absence of a specified resource is a `missing_impl` finding, not a `doc_incon`."
- `klaude-plugin/skills/review-spec/review-process.md` and `klaude-plugin/skills/review-spec/review-isolated.md` — parallel clause where the finding taxonomy is described.
- `klaude-plugin/skills/review-spec/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/review-spec/index.md` (new, if the Kubernetes-specific semantics warrant dedicated content) *or* inlined into `review-spec` prose if one paragraph suffices. The implementation plan defers the choice until writing.

### `dependency-handling` — P3 trigger widening

The skill's description frontmatter and body widen to acknowledge IaC/config artifacts with external versioning. See Q8:C in the design Q&A.

Touched files:
- `klaude-plugin/skills/dependency-handling/SKILL.md` — description frontmatter rewritten to fit in ≤250 characters (see §[Skill description budget](#skill-description-budget)) while including IaC-dep categories. Body gains a short paragraph pointing to per-profile `overview.md` for domain-specific lookup targets (Kubernetes API versions → context7 k8s.io docs or `kubectl explain`; CRDs → operator docs; Helm charts → chart repo README; container images → registry metadata).
- `klaude-plugin/profiles/k8s/overview.md` — "Looking up Kubernetes dependencies" section names the cascade targets.

## Conventions

### `CLAUDE.md` additions

A new top-level section, **Profile Conventions**, describes:
- Profile directory layout (`DETECTION.md`, `overview.md`, per-phase subdirs with `index.md`).
- `DETECTION.md` as authoritative trigger rule; signal types (path, filename, content).
- `index.md` as the contract with consuming skills; always-load vs conditional entries with one-line descriptions.
- Naming: lowercase profile names, underscores allowed where filename-safe (`js_ts` is retained from the existing language convention).
- Profile content is referenced via `${CLAUDE_PLUGIN_ROOT}/profiles/...` from skills and agents (see [ADR 0003](../../adr/0003-plugin-root-referenced-content.md)).
- Adding a new profile = copy an existing profile as a template, customize `DETECTION.md` and content, and append to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh`.

A new subsection under **Skill & Command Naming Conventions**, titled **Skill description budget**, records:
- The `description` frontmatter field of a skill is truncated at 250 characters when surfaced to agents.
- Lead with trigger keywords, not prose; truncation happens at the tail.
- Detailed rules, cascades, and examples belong in the body of SKILL.md, not the description.

A new subsection, **ADR location**, records:
- Architecture decisions spanning more than one feature live at `docs/adr/NNNN-slug.md` (Michael Nygard template).
- Per-feature design docs continue to live at `docs/wip/<feature>/` and move to `docs/done/<feature>/` on completion.

### Skill description budget applied in this feature

Only one skill's description changes: `dependency-handling`. The revised description is:

> TRIGGER when: adding or upgrading any dependency — library, SDK, framework, API, IaC API version (K8s/Terraform/Helm), CRD, or container image. Use BEFORE writing the call. Forces context7/capy lookup instead of guessing.

223 characters, under the 250-character budget, leads with the trigger keyword, covers both programming-language and IaC dep categories, and preserves the "Use BEFORE writing the call" instruction that the current (over-budget) description truncates in practice.

Other skills extended in this feature (`design`, `implement`, `test`, `document`, `review-code`, `review-spec`) acquire new behavior but no new trigger semantics; their descriptions do not change.

### Test suite updates

`test/test-plugin-structure.sh` grows an `EXPECTED_PROFILES` array. Per-profile assertions check:
- `klaude-plugin/profiles/<name>/DETECTION.md` exists.
- `klaude-plugin/profiles/<name>/overview.md` exists.
- `klaude-plugin/profiles/<name>/review/index.md` exists.
- Every file referenced by any `index.md` in the profile actually exists on disk (catches stale indexes).
- For profiles that declare per-phase content, the corresponding `<phase>/index.md` exists.

The six shared-file symlinks (`shared-profile-detection.md` under each consuming skill) are asserted to exist and to resolve to `_shared/profile-detection.md`.

The `dependency-handling` description-length assertion can be added opportunistically once the description rewrite lands, but is not a blocking requirement for the test suite (the 250-character budget is informally documented today; adding enforcement is a judgment call).

### README.md

A short paragraph introduces `klaude-plugin/profiles/` as a peer of `skills/`, `commands/`, `agents/`, `hooks/` in the plugin layout overview. One or two sentences; no detailed documentation (CLAUDE.md carries the conventions).

## Phases

The feature ships in four phases, plus a feature-close task. Each phase is individually verifiable and mergeable. See [tasks.md](tasks.md) for the task list.

### P0 — Profile-first refactor (behavior-preserving)

Introduces the `profiles/` top-level; migrates programming-language content from `review-code/reference/<lang>/`; creates the shared detection procedure and its symlinks; restructures the `review-code` workflow to be index-driven; updates the plugin-structure test; adds Profile Conventions, Skill description budget, and ADR-location sections to CLAUDE.md; mentions `profiles/` in README.md.

**Verification criteria.** `test/test-plugin-structure.sh` passes with the new `EXPECTED_PROFILES` array and symlink assertions. A dry-run invocation of `/kk:review-code` on a Go-only diff produces findings equivalent to pre-P0 (same coverage, same categories). No broken markdown links in touched skill prose. `review-code`, `review-spec`, `test`, `document` are applied to P0's own changes as a final task.

### P1 — Kubernetes profile for review-code (closes #64)

Adds `profiles/k8s/` with detection, overview, and the seven review-phase checklists plus their index. Appends `k8s` to `EXPECTED_PROFILES`.

**Verification criteria.** Structure test passes. A synthetic Kubernetes diff activates the profile, loads the always-load checklists, and loads conditional checklists per their triggers (e.g., Helm checklist present when `Chart.yaml` is in the diff; absent otherwise). Regression check on a non-Kubernetes diff — the profile must remain inactive. Issue #64 is closeable.

### P2 — `design` / `implement` / `test` / `document` K8s-awareness

One task per extended skill. Each task adds the profile-aware clause to the skill, authors the corresponding `profiles/k8s/<phase>/index.md` and content files, and verifies with a synthetic K8s scenario in the relevant phase.

**Verification criteria (per skill).** Smoke test: invoke the skill against a Kubernetes scenario, observe that profile content is loaded and applied. Smoke test: invoke the skill against a non-Kubernetes scenario, observe that behavior is unchanged. Structure test passes with the new per-phase index files asserted.

### P3 — `review-spec` and `dependency-handling`

`review-spec` prose gains the K8s-awareness clause and optional `profiles/k8s/review-spec/` content. `dependency-handling` description is rewritten to fit the 250-character budget while widening to IaC; body gains the per-profile lookup pointer.

**Verification criteria.** `dependency-handling` description length ≤250 characters (manual or automated check). Spec-vs-impl scenario on Kubernetes artifacts exercises the widened finding shapes. End-to-end smoke: an entirely synthetic K8s feature is carried through the design → implement → review-code → test → document → review-spec flow; each step invokes profile-aware behavior where applicable.

### Feature close

Move `docs/wip/kubernetes-support/` → `docs/done/kubernetes-support/`. Update any status metadata in the feature's own docs. Branch-level merge is a human action, not a task.

## Open questions deferred to implementation

These are small decisions intentionally left for the implementer to resolve during P1–P3:

- **Whether `profiles/k8s/review-spec/` warrants its own directory**, or a single paragraph inline in `review-spec/SKILL.md` suffices. The trade-off depends on how much K8s-specific spec-vs-impl guidance crystallizes during P3 content authoring.
- **Exact trigger-condition wording** inside `profiles/k8s/review/index.md` for conditional entries (e.g., how to name "Helm context detected"). Prose form is chosen by the author; structured triggers are a future refinement (see [ADR 0002](../../adr/0002-profile-content-organization.md), "Forward direction").
- **Whether to add an opportunistic description-length assertion** to `test/test-plugin-structure.sh` for `dependency-handling`'s description or leave the 250-character budget as informal convention. Either is acceptable for P3 close.

## References

- [ADR 0001 — Profile/language detection remains a single additive axis](../../adr/0001-profile-detection-model.md)
- [ADR 0002 — Profile-first layout with index-driven content loading](../../adr/0002-profile-content-organization.md)
- [ADR 0003 — Profile content referenced via `${CLAUDE_PLUGIN_ROOT}`, not symlinked](../../adr/0003-plugin-root-referenced-content.md)
- [implementation.md](implementation.md) — step-by-step implementation plan
- [tasks.md](tasks.md) — phase-grouped task list with per-phase verification
- [GitHub issue #64](https://github.com/serpro69/claude-toolbox/issues/64) — originating issue (narrow scope)
