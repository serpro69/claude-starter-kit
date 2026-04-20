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

[ADR 0001](../../adr/0001-profile-detection-model.md) records that detection remains a single axis — all detectable artifact types (programming languages, IaC DSLs, config schemas) are equal rows in one detection table. Matching a file contributes that row's reference directory to the set loaded for the current task. Multiple matches are additive.

**`%LANGUAGE%` placeholder semantics:**
- When one or more programming-language profiles are active, `%LANGUAGE%` resolves to the primary programming language (existing behavior).
- When no programming-language profile is active but an IaC/config-schema profile is (pure-K8s repo, pure-Terraform repo), `%LANGUAGE%` resolves to the dominant non-language profile's natural tongue — Kubernetes → "Kubernetes", Terraform → "Terraform", Helm → "Helm". Prose like "a highly-skilled %LANGUAGE% developer" remains readable ("a highly-skilled Kubernetes developer").
- When no profile matches at all, `%LANGUAGE%` falls back to generic guidance (existing behavior).

Profile content is consulted additively regardless of how `%LANGUAGE%` resolves.

The term "language" is retained. Editor tooling (LSP, VS Code) already treats YAML, Dockerfile, HCL, and others as "languages" under an umbrella-term usage. Adopting that framing keeps the existing prose honest.

### Profile-first content layout

[ADR 0002](../../adr/0002-profile-content-organization.md) records that profile content lives in a new top-level `klaude-plugin/profiles/<name>/` directory, peer to `klaude-plugin/skills/`. Each profile is self-contained (`DETECTION.md`, `overview.md`, per-phase subdirectories). Existing `review-code/reference/<lang>/` directories migrate in. Skills discover content via `index.md` routers inside per-phase subdirectories — not via hardcoded filenames.

### Plugin-root references instead of outside-tree symlinks

[ADR 0003](../../adr/0003-plugin-root-referenced-content.md) records that skills and agents reference profile content via plugin-root-relative paths: `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/...`. No symlinks are created from skills into `profiles/`. The existing `_shared/` symlink pattern, which stays inside `skills/`, is unchanged. The choice of variable-referenced paths for outside-skills-directory content prototypes a pattern that may later replace `_shared/` symlinks entirely (see ADR 0003's "prototype for future work" section).

## Detection mechanics

Detection is the responsibility of each profile, declared in `klaude-plugin/profiles/<name>/DETECTION.md`. Skills consume detection through a shared procedure (see [Shared mechanisms](#shared-mechanisms)), not by replicating per-profile logic.

### Signal model

Every profile's `DETECTION.md` uses a mandatory, structured three-section schema so that six consuming skills interpret the rule identically. Prose-only detection rules are insufficient — cross-consumer drift is a real risk ([ADR 0002 context](../../adr/0002-profile-content-organization.md)).

Required sections (each may be empty if the profile has no signals of that kind):

- **`## Path signals`** — path globs that promote a file to a candidate. Path signals are a *fast pre-filter* only; they do not activate the profile on their own.
- **`## Filename signals`** — literal filenames or filename globs that are *authoritative*: any matching file activates the profile regardless of path.
- **`## Content signals`** — content-inspection rules (anchors, regexes, presence-of-keys) that are *authoritative* for files not already resolved by filename signals. Inspection is bounded to the first N KB per file (each profile declares N in its `DETECTION.md`); within that bound, multi-document YAML is handled per `---`-separated block. Profiles whose content rule is naturally per-block describe that handling explicitly.

The two-dimensional framing: signals are **ordered by evaluation cost** (path → filename → content; cheapest first), but **authority follows a different order** (filename > content > path; path alone is insufficient). A file not caught by filename or content signals, regardless of any path hit, does not activate the profile.

The `_shared/profile-detection.md` procedure (see [Shared mechanisms](#shared-mechanisms)) applies this fixed algorithm against the per-profile values declared in each `DETECTION.md`.

### Kubernetes detection rule

Path signals:

- `k8s/`, `manifests/`, `charts/`, `kustomize/`, `deploy/`, `templates/` — case-insensitive match anywhere in the path. Candidate pre-filter only.

Filename signals (authoritative):

- `Chart.yaml` → Helm chart root. Authoritative.
- `values*.yaml` (any filename starting with `values` in a directory that also contains `Chart.yaml`) → Helm values by adjacency. Authoritative.
- Files with `.yaml`, `.yml`, or `.tpl` extension inside `<dir>/templates/` where `<dir>` itself contains a `Chart.yaml` as a direct child → Helm template. Authoritative by adjacency. The `templates/` directory must sit directly next to a `Chart.yaml` — at a chart root or at a subchart root under `<parent>/charts/<subchart>/`. A `templates/` nested elsewhere in the tree (e.g., `docs/templates/`, `ci/templates/`) does NOT activate this rule even when a `Chart.yaml` exists higher up at the repo root, because those intermediate directories do not themselves contain a `Chart.yaml`. Avoids the monorepo false-positive (umbrella root `Chart.yaml` spuriously claiming unrelated `templates/` directories) and still avoids the trap where a standalone edit to a chart's `templates/deployment.yaml` contains `{{ if ... }}` directives before any `apiVersion:` and would otherwise fail the content signal.
- `kustomization.yaml`, `kustomization.yml`, or `Kustomization` (exact filenames) → Kustomize. Authoritative.

Content signals (authoritative for generic YAML not caught by filename):

- For any `.yaml` or `.yml` file, scan each `---`-separated document block. A document containing both a top-level `apiVersion:` *and* a top-level `kind:` at zero indent → Kubernetes manifest. A file may contain multiple documents; one matching document activates the profile. If the first document lacks the markers but a later document has them, the profile still activates. Inspection is bounded to the first ~16 KB per file to avoid runaway reads on large generated manifests.
- A file with no matching document in any block → not Kubernetes (the file may still match some other profile; generic YAML belongs to no profile by default).

Multi-profile and no-profile outcomes:

- **Multiple profiles match in the same diff.** Every matching profile's reference directory is loaded. A Go + Kubernetes diff consults `profiles/go/review-code/` and `profiles/k8s/review-code/` both. Findings are emitted grouped by (profile, checklist).
- **No profile matches.** The skill proceeds with generic guidance, identical to today's "no language detected" fallback.

### Dockerfile non-trigger

A Dockerfile on its own — even under a `deploy/` or `k8s/` directory — does NOT activate the Kubernetes profile. Dockerfiles have no K8s signal: they are not `Chart.yaml`/`values*.yaml`/`kustomization.yaml`, and they do not contain `apiVersion:` + `kind:`. When a Dockerfile appears in the same diff as Kubernetes manifests, the Kubernetes profile activates on the K8s manifests' signals; the Dockerfile is not reviewed by this profile. A future container profile may own Dockerfiles independently.

### Detection output shape

Detection emits a list of records, one per matched profile: `{profile: <name>, triggered_by: [<signal descriptions>], files: [<paths>]}`. The `triggered_by` list names which signal type fired for each file (e.g., `"filename: Chart.yaml"`, `"content: apiVersion+kind in block 2"`). Downstream skills use the `files` field to scope behavior — for example, the `test` skill runs `helm lint` only on files triggered under Helm signals, not on every YAML.

## File structure

Per-profile layout is uniform. Every profile under `klaude-plugin/profiles/` follows the same shape:

```
klaude-plugin/profiles/<name>/
  DETECTION.md             # authoritative trigger rule (see §Detection mechanics)
  overview.md              # human-readable profile summary + dependency-lookup targets
  review-code/             # consumed by review-code
    index.md               # router: always-load entries, conditional entries, one-liners
    <checklist files>      # named to fit the profile's content; no fixed schema
  design/                  # consumed by design (populated per-profile as needed)
  test/                    # consumed by test (populated per-profile as needed)
  implement/               # consumed by implement (populated per-profile as needed)
  document/                # consumed by document (populated per-profile as needed)
  review-spec/             # consumed by review-spec (populated per-profile as needed)
```

Not every profile populates every phase subdirectory. A programming-language profile may only ever need `review-code/`; an IaC profile like Kubernetes populates all six. The plugin structure test (`test/test-plugin-structure.sh`) asserts the *presence* of each directory and file a profile declares — not that every profile populates every slot.

**Phase-subdirectory contents.** A phase subdirectory contains only its `index.md` and the checklist/content files the index references. Human-facing documentation (authoring notes, READMEs) lives at the profile root — typically inside `overview.md`, or as a sibling file next to it — never inside a phase subdirectory. This keeps the bidirectional index invariant (§Test suite updates) sharp: an unreferenced `.md` inside a phase dir is always a bug, never a README.

### The Kubernetes profile, concretely

After both P0 and P1 have landed:

```
klaude-plugin/profiles/k8s/
  DETECTION.md
  overview.md
  review-code/
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

The existing content under `klaude-plugin/skills/review-code/reference/<lang>/` moves to `klaude-plugin/profiles/<lang>/review-code/`. Files keep their current names (`security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`) — SOLID *is* the appropriate content for Go and the other programming-language profiles, and "code-quality" fits those profiles naturally. Each profile gains a new `index.md` listing the existing four files as always-load entries. Cross-profile consistency comes from the presence of `index.md`, not from filename uniformity.

## Content organization within profiles

Each per-phase subdirectory contains an `index.md`. The index is the contract between the profile and consuming skills.

### Index file structure

An `index.md` has two sections:

- **Always load.** Files that must be loaded whenever the profile is active. Each entry is a markdown link to the file plus a one-line description of what it covers.
- **Conditional.** Files that are loaded only when a stated trigger matches the current task. Each entry is the same link + description, followed by an explicit **Load if:** clause naming the trigger condition.

**Conditional-trigger wording discipline.** Triggers are stated in prose for readability, but the prose must be an unambiguous predicate keyed to concrete diff properties — not a vague category label. Two agents evaluating the same diff against the same trigger must reach the same conclusion.

- Good: `Load if: any file contains a top-level YAML document with kind: Deployment|StatefulSet|DaemonSet|Job|CronJob`
- Bad: `Load if: workload resources are in the diff`

The good form names what to inspect (`kind:` field) and what to match (specific resource names). The bad form requires the agent to interpret "workload resources" — the interpretation can drift per agent or per prompt context. Structured trigger expressions remain a possible future extension (see [ADR 0002](../../adr/0002-profile-content-organization.md), "Forward direction"); until then, prose must be precise.

For the Kubernetes `review-code/index.md`:

- Always-load: `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md`.
- Conditional entries with predicate-form triggers:
  - `reliability-checklist.md` — **Load if:** the diff contains any file with a top-level YAML document whose `kind:` is `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, or `CronJob`.
  - `helm-checklist.md` — **Load if:** the diff contains a file named `Chart.yaml`, or any file named `values*.yaml` in a directory that also contains `Chart.yaml`, or any file under a `templates/` directory whose ancestor contains `Chart.yaml`.
  - `kustomize-checklist.md` — **Load if:** the diff contains a file named `kustomization.yaml`, `kustomization.yml`, or `Kustomization`; or a file under a `bases/` or `overlays/` directory; or a patch file referenced by a nearby `kustomization.*`.

Edge cases to note explicitly in the index entry prose so agents do not drift:

- A standalone `values.yaml` with NO sibling `Chart.yaml` does NOT trigger `helm-checklist.md` (it is not a Helm-values file; it might be any project's config file).
- A `deployment.yaml` NOT under a `templates/` directory and NOT containing `{{ ... }}` template directives, matching the K8s content signal, is a plain manifest, not a Helm template.

For the migrated programming-language profiles (e.g., `profiles/go/review-code/index.md`), all four existing files are always-load; no conditional entries.

### Content file structure

Individual checklist files are free-form markdown organized by whatever structure fits the content. The feature does not impose an inner schema. Consumers read the index and then read the full file content of whatever the index tells them to load.

## Shared mechanisms

### `_shared/profile-detection.md`

A new file, `klaude-plugin/skills/_shared/profile-detection.md`, captures the detection procedure exactly once. Consumers: `review-code`, `review-spec`, `design`, `implement`, `test`, `document`.

The file documents:

1. **Inputs per consuming skill.** Not every consumer has a diff available. The procedure defines what *each* skill uses as its detection input:
   - `review-code` → git diff (staged or explicit range).
   - `review-spec` → git diff (when invoked standalone) OR feature-directory file list (when invoked by `implement`).
   - `test` → git diff (when feature work is in progress) OR feature-directory file list (post-implementation).
   - `implement` → the current sub-task's target file list + any diff accumulated so far in the feature.
   - `design` → user-declared signal (a direct question in Step 3: "is this a Kubernetes / Terraform / … feature?") OR keyword inference from the initial idea prose (matches like "Kubernetes", "Helm", "manifests", "Deployment" → surface the question, let the user confirm). Detection in the design phase is the only non-file-based input model; the procedure spells out the interaction pattern.
   - `document` → feature-directory file list; diff optional (post-implementation docs may review the whole feature, not just recent changes).
2. **The algorithm** applied against each profile's `DETECTION.md`:
   - Iterate the explicit **§Known profiles** list maintained inside `_shared/profile-detection.md`. Filesystem enumeration (`Glob`, `ls`) is not used: the `Glob` tool is `cwd`-scoped and silently returns 0 matches against outside-`cwd` plugin-root paths, even when `${CLAUDE_PLUGIN_ROOT}` substitution resolves correctly (empirical verification indexed as `kk:arch-decisions` "Glob tool is cwd-scoped; use Bash for plugin-root enumeration", 2026-04-19). The list is the authoritative enumeration; adding a new profile means appending its `<name>` to the list (one-line edit, same as `EXPECTED_PROFILES` in the structure test). Entries whose directory does not yet exist on disk are tolerated — the algorithm skips on `ENOENT` silently so the list can be populated ahead of a profile's content landing (see §Algorithm step 1 in `_shared/profile-detection.md`).
   - For each profile, read its `DETECTION.md` via the `Read` tool (not `Glob`) and evaluate signals in cost order (path → filename → content).
   - Apply authority rule: a file activates the profile if a filename or content signal matches; a path-only match is insufficient.
   - Bounded content inspection: ~16 KB per file, multi-document YAML handled per block.
3. **Unset-variable handling.** Before emitting results, the procedure checks that `CLAUDE_PLUGIN_ROOT` is set and non-empty. If unset: fail loudly with an actionable error (`CLAUDE_PLUGIN_ROOT is not set; profile detection cannot locate profiles/ directory. See CLAUDE.md §Profile Conventions.`) and fall back to the generic no-profile path. Consumers inherit this check by invoking the shared procedure — they do not need to repeat it.
4. **Output shape.** A list of records as described in §Detection mechanics.

Per CLAUDE.md's "Shared instructions" convention, each consuming skill gets a symlink: `klaude-plugin/skills/<skill>/shared-profile-detection.md` → `../_shared/profile-detection.md`. Six symlinks total.

Agents (under `klaude-plugin/agents/`) that need to invoke detection reference the shared file by repo-relative path — `klaude-plugin/skills/_shared/profile-detection.md` — per the existing CLAUDE.md rule that agents do not use the per-skill symlink pattern.

### Why this is symlinked but `profiles/` is not

The `_shared/` symlink stays inside `skills/`. A symlink from `skills/<skill>/shared-profile-detection.md` → `../_shared/profile-detection.md` crosses a single directory boundary but does not leave the `skills/` tree, which is the property installers such as OpenCode's Bun-cache preserve reliably. A symlink from `skills/<skill>` into the sibling `profiles/` directory does not share that property. See [ADR 0003](../../adr/0003-plugin-root-referenced-content.md) for the full rationale.

### `${CLAUDE_PLUGIN_ROOT}` — empirically verified

The design's reliance on `${CLAUDE_PLUGIN_ROOT}` substitution in SKILL.md prose was verified on 2026-04-17 (initial) and extended on 2026-04-18 (markdown-container sweep) against Claude Code v2.1.112 / `kk` plugin v0.9.0. Full results in [ADR 0003 §Verification](../../adr/0003-plugin-root-referenced-content.md). Key constraints consumers must observe:

- **Functional use: brace form required.** For path references that are *meant* to be resolved at runtime, use `${CLAUDE_PLUGIN_ROOT}/...`. Bare `$CLAUDE_PLUGIN_ROOT` is NOT substituted by the harness.
- **Substitution is markdown-container-unaware.** The harness applies a literal text replacement on the token `${CLAUDE_PLUGIN_ROOT}` before any agent reads the content. It happens in inline backticks, fenced code blocks (plain / bash / markdown / tilde), indented code blocks, blockquotes, HTML comments, and even after backslash escape (`\` is preserved but the variable still expands). **No markdown container escapes substitution.**
- **Literal-reference authoring rule.** When prose under the plugin tree (SKILL.md, agent files, profile content under `klaude-plugin/`) needs to reference the variable *by name* (documenting or explaining it, not using it as a path), use one of the two surviving forms: **bare `$CLAUDE_PLUGIN_ROOT`** (simplest) or **`&#36;{CLAUDE_PLUGIN_ROOT}`** (HTML entity for `$`; useful when the brace shape must appear in rendered output). CLAUDE.md, ADRs, and other project-root files are NOT subject to substitution — they can use the brace form freely.
- **Sub-agents receive substituted paths.** Sub-agent context behaves identically to the main context; substitution happens once in the harness pre-processing step regardless of which agent reads the content.

## Skill integration

### `review-code` — P0 refactor + P1 Kubernetes content

**P0 (behavior-preserving refactor).** The existing reference directories migrate to `profiles/`. The workflow inside `review-code` changes shape: hardcoded category steps collapse into a generic index-driven loading step.

Touched files:
- `klaude-plugin/skills/review-code/SKILL.md` — prose updated to describe profile detection (via shared procedure) and index-driven loading. The description frontmatter does not change.
- `klaude-plugin/skills/review-code/review-process.md` — the former "Step 2: Detect primary language" renames to "Step 2: Detect active profiles" and consults the shared procedure. Former steps 3–6 (SOLID, Removal, Security, Quality) collapse into a pair of generic steps: "Step 3: For each active profile, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md`; resolve entries per always-load and conditional triggers" and "Step 4: Apply each resolved checklist; emit findings grouped by (profile, checklist)". Downstream steps (self-check, indexing, output formatting) are unchanged.
- `klaude-plugin/skills/review-code/review-isolated.md` — parallel restructure; the sub-agent prompt receives the list of resolved checklists, not a hardcoded category sequence.
- `klaude-plugin/skills/review-code/reference/` — directory removed (its contents have moved to `profiles/<lang>/review-code/`).
- `klaude-plugin/agents/code-reviewer.md` — prompt updated to iterate the resolved-checklists list.

**P1 (Kubernetes content).** No additional `review-code` skill changes. The profile-first architecture absorbs the new profile transparently.

Touched files:
- `klaude-plugin/profiles/k8s/DETECTION.md` (new)
- `klaude-plugin/profiles/k8s/overview.md` (new)
- `klaude-plugin/profiles/k8s/review-code/index.md` (new)
- `klaude-plugin/profiles/k8s/review-code/*.md` (seven checklist files, new)

### `design` — P2 Kubernetes-aware idea refinement

The `design` skill runs before any implementation exists — there is no diff to inspect. Profile detection in this phase uses the user-declared / keyword-inference input model defined in [Shared mechanisms](#shared-mechanisms):

1. At Step 3 (refine the idea), the skill checks the initial idea prose against a **high-precision auto-trigger set**: `Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`. These tokens are unambiguous — a match surfaces the confirmation prompt without a second check.
2. If any auto-trigger token matches, the skill surfaces a single confirmation question: "This appears to be a Kubernetes feature. Activate the Kubernetes profile for this design session?" The user answers yes/no.
3. If no auto-trigger matches but the idea is **ambiguous** — names infrastructure, deployment, runtime, or platform concerns without naming a specific technology (e.g., "add a caching layer for the service", "build a CI pipeline", "deploy to production", or bare-word collisions with non-K8s meanings like `cluster` / `namespace` / `pod`) — the skill asks explicitly: "Does this feature involve Kubernetes, Terraform, or other IaC artifacts? If yes, which?" The narrow auto-trigger set and explicit ambiguity path together avoid noisy false positives from tokens that overload across domains.
4. On user confirmation, the Kubernetes profile is active for the rest of the design session. The skill loads `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/design/index.md` and consults its content (question bank, required design sections) during Step 3 refinement and Step 5 design documentation.

When the profile is active, the design skill asks questions from the K8s question bank (cluster topology, GitOps tool choice, secrets strategy, multi-tenancy, observability posture, rollback strategy) and ensures the resulting `design.md` includes the required K8s-shaped sections (cluster-compat matrix, resource budget, reliability posture, security posture, failure-mode narrative).

Touched files:
- `klaude-plugin/skills/design/SKILL.md` — top-level prose retains its current meaning.
- `klaude-plugin/skills/design/idea-process.md` — Step 3 (refine the idea) gains the user-declared detection model described above; Step 5 (document the design) gains a clause: "for each active profile, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/design/index.md` and apply its section requirements to the documented design."
- `klaude-plugin/skills/design/existing-task-process.md` — equivalent clause in the continue-WIP flow; here the feature directory's existing files ARE available, so detection falls back to the file-based input model.
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

The `test` skill's K8s content mandates a minimum validator floor, catalogs additional tools as a menu, and auto-honors project-local policy toolchains when markers are present. (Rationale: the floor/menu split keeps offline-runnable, non-opinionated tools mandatory while leaving stack-specific or cluster-dependent tools as opt-in; see `.sessions/design-session.txt` question Q7 for the full trade-off discussion.)

**Binary presence is a first-class protocol step.** Before running any validator, the skill checks that the required binary is on `PATH`. If missing, the skill must NOT attempt blind execution — shell errors are a bad user experience. Instead: surface an install hint (per-tool, e.g., `kubeconform: install via 'brew install kubeconform' or 'go install github.com/yannh/kubeconform/cmd/kubeconform@latest'`) and either (a) fall back to descriptive guidance that names what the validator would have checked, or (b) mark the check as skipped in the test report with a clear "binary not installed" note. The protocol applies to floor, menu, and policy tools alike.

**Minimum floor (mandated when Kubernetes profile is active, if binary is present).**
- `kubeconform` — offline schema validation on all matched K8s YAML.
- `helm lint` — run on each Helm chart directory matched in the diff (via `Chart.yaml` presence).
- `kustomize build` — run on each Kustomize directory matched in the diff (via `kustomization.yaml` presence).

If any floor binary is missing, the skill reports it with an install hint and continues with the remaining checks; a missing floor tool does NOT block the test run.

Cluster-dependent tools (`kubectl --dry-run=server`, `popeye`) are not in the floor; they are mentioned as optional "if a staging cluster is available and `kubectl` is configured".

**Menu (suggested, run when binary present and user opts in).**
- `kube-score`, `kube-linter`, `polaris` — best-practices linters.
- `trivy config`, `checkov`, `kics` — security scanners (overlapping; projects usually pick one).

**Policy-hook auto-detection.** The skill checks the project for policy-toolchain markers AND the presence of the corresponding binary:
- `.conftest/` directory or `policies/*.rego` → if `conftest` is on PATH, run `conftest test` against the matched manifests. If binary missing, surface install hint.
- `kyverno-policies/` directory or presence of Kyverno `ClusterPolicy`/`Policy` resources → if `kyverno` is on PATH, run `kyverno test`.
- `.gator/` or Gatekeeper `ConstraintTemplate`/`Constraint` resources → if `gator` is on PATH, run `gator test`.
- None of the above markers present → policy validation is skipped silently (project has no policy toolchain).

Tools in the floor and the active policy engine are treated as required checks when their binaries are available; menu tools are treated as optional.

Touched files:
- `klaude-plugin/skills/test/SKILL.md` — guidelines gain a clause: "After language-specific test patterns, for each active profile load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/test/index.md` and apply the validators and check categories it specifies."
- `klaude-plugin/skills/test/shared-profile-detection.md` — symlink (created in P0).
- `klaude-plugin/profiles/k8s/test/index.md` (new)
- `klaude-plugin/profiles/k8s/test/<content files>` (new) — floor validators, the menu, the policy-hook detection procedure, and the binary-presence protocol.

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
- `klaude-plugin/profiles/k8s/review-spec/index.md` (new) — **create** when the K8s-specific spec-review guidance comprises **two or more distinct checklists** OR includes **any conditional trigger** (diff-property-dependent loading). Otherwise **inline** a single paragraph into `review-spec/SKILL.md`, `review-process.md`, and `review-isolated.md`. The implementation plan defers the choice until writing so the threshold can be applied to the actual drafted content.

### `dependency-handling` — P3 trigger widening

The skill's description frontmatter and body widen to acknowledge IaC/config artifacts with external versioning. (Rationale: IaC API versions, CRDs, Helm charts, and container images are all dependencies with external versioning that benefit from the same "lookup BEFORE writing" discipline the skill already enforces for libraries and SDKs; see `.sessions/design-session.txt` question Q8 for the scope decision.)

Touched files:
- `klaude-plugin/skills/dependency-handling/SKILL.md` — description frontmatter rewritten to fit in ≤1,536 characters (the documented per-entry cap; see §[Skill description budget](#skill-description-budget)) while including IaC-dep categories. Body gains a short paragraph pointing to per-profile `overview.md` for domain-specific lookup targets (Kubernetes API versions → context7 k8s.io docs or `kubectl explain`; CRDs → operator docs; Helm charts → chart repo README; container images → registry metadata).
- `klaude-plugin/profiles/k8s/overview.md` — "Looking up Kubernetes dependencies" section names the cascade targets.

## Conventions

### `CLAUDE.md` additions

A new top-level section, **Profile Conventions**, describes:
- Profile directory layout (`DETECTION.md`, `overview.md`, per-phase subdirs with `index.md`).
- `DETECTION.md` as authoritative trigger rule; signal types (path, filename, content).
- `index.md` as the contract with consuming skills; always-load vs conditional entries with one-line descriptions.
- Naming: lowercase profile names, underscores allowed where filename-safe (`js_ts` is retained from the existing language convention).
- Profile content is referenced via `${CLAUDE_PLUGIN_ROOT}/profiles/...` from skills and agents (see [ADR 0003](../../adr/0003-plugin-root-referenced-content.md)).
- Adding a new profile = copy an existing profile as a template, customize `DETECTION.md` and content, and add to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` (the array is alphabetised and the structure test treats it as a set, so position is aesthetic).

A new subsection under **Skill & Command Naming Conventions**, titled **Skill description budget**, records:
- **Per-entry cap: 1,536 characters.** Each skill's `description` + `when_to_use` combined text is truncated at 1,536 characters regardless of the global budget (per [Claude Code docs — Skill descriptions are cut short](https://code.claude.com/docs/en/skills#skill-descriptions-are-cut-short)).
- **Global context budget.** Scales dynamically at 1% of the context window, with a fallback of 8,000 characters. Override via the `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable. When many skills are loaded, trailing content of each description gets stripped first.
- **OpenCode parity.** OpenCode's documented limit is 1,024 characters; treat 1,024 as a soft budget for skills that must work on both harnesses.
- **Lead with trigger keywords.** Truncation happens at the tail; front-load the key use case.
- **Keep descriptions tight.** Detailed rules, cascades, and examples belong in the SKILL.md body, not the description.
- **Re-verify the caps** against the docs page above when touching this limit in the future.

A new subsection, **ADR location**, records:
- Architecture decisions spanning more than one feature live at `docs/adr/NNNN-slug.md` (Michael Nygard template).
- Per-feature design docs continue to live at `docs/wip/<feature>/` and move to `docs/done/<feature>/` on completion.

### Skill description budget applied in this feature

Only one skill's description changes: `dependency-handling`. The revised description is:

> TRIGGER when: adding or upgrading any dependency — library, SDK, framework, API, IaC API version (K8s/Terraform/Helm), CRD, or container image. Use BEFORE writing the call. Forces context7/capy lookup instead of guessing.

223 characters — well under the 1,536-character per-entry cap and the 1,024-character OpenCode soft budget. Leads with the trigger keyword, covers both programming-language and IaC dep categories, and preserves the "Use BEFORE writing the call" instruction that the current description currently truncates in practice under context-pressure shrinking.

Other skills extended in this feature (`design`, `implement`, `test`, `document`, `review-code`, `review-spec`) acquire new behavior but no new trigger semantics; their descriptions do not change.

### Test suite updates

`test/test-plugin-structure.sh` grows an `EXPECTED_PROFILES` array. Per-profile assertions are **presence-conditional** — they predicate on what the profile declares, not on a fixed schema:

- `klaude-plugin/profiles/<name>/DETECTION.md` exists (every profile must declare detection).
- `klaude-plugin/profiles/<name>/overview.md` exists (every profile must declare an overview).
- The profile's `DETECTION.md` contains the three required sections (`## Path signals`, `## Filename signals`, `## Content signals`) — any may be empty, but all must be present.
- For each phase subdirectory that exists under `profiles/<name>/` (`review-code/`, `design/`, `test/`, `implement/`, `document/`, `review-spec/`), that subdirectory's `index.md` exists. A profile that does not populate a phase simply doesn't have that subdirectory; the test does not require it.

**Bidirectional index invariant** — the index-as-contract rule is enforced symmetrically:
- Every file referenced by any `index.md` in the profile actually exists on disk (catches stale indexes — an index entry pointing to a deleted file).
- Every `.md` file inside a profile's phase subdirectory (excluding `index.md` itself) is referenced by that subdirectory's `index.md` (catches orphans — a content file added to the directory but not registered as always-load or conditional).

The six shared-file symlinks (`shared-profile-detection.md` under each consuming skill) are asserted to exist and to resolve to `_shared/profile-detection.md`.

The `dependency-handling` description-length assertion lands when the description rewrite lands: a one-line check that the `description` frontmatter field is ≤1,536 characters (the documented per-entry cap). Not technically required (the cap is enforced by the harness, not the plugin), but mechanical to add and prevents regression on the agreed-upon description length.

### README.md

A short paragraph introduces `klaude-plugin/profiles/` as a peer of `skills/`, `commands/`, `agents/`, `hooks/` in the plugin layout overview. One or two sentences; no detailed documentation (CLAUDE.md carries the conventions).

## Phases

The feature ships in four phases, plus a feature-close task. Each phase is individually verifiable and mergeable. See [tasks.md](tasks.md) for the task list.

### P0 — Profile-first refactor (behavior-preserving)

Introduces the `profiles/` top-level; migrates programming-language content from `review-code/reference/<lang>/`; creates the shared detection procedure and its symlinks; restructures the `review-code` workflow to be index-driven; updates the plugin-structure test; adds Profile Conventions, Skill description budget, and ADR-location sections to CLAUDE.md; mentions `profiles/` in README.md.

**Verification criteria.** `test/test-plugin-structure.sh` passes with the new `EXPECTED_PROFILES` array and symlink assertions. A dry-run invocation of `/kk:review-code` on a Go-only diff produces findings equivalent to pre-P0 (same coverage, same categories). No broken markdown links in touched skill prose. `review-code`, `review-spec`, `test`, `document` are applied to P0's own changes as a final task.

### P1 — Kubernetes profile for review-code (closes #64)

Adds `profiles/k8s/` with detection, overview, and the seven review-phase checklists plus their index. Adds `k8s` to `EXPECTED_PROFILES` (alphabetical; the array is a set).

**Verification criteria.** Structure test passes. A synthetic Kubernetes diff activates the profile, loads the always-load checklists, and loads conditional checklists per their triggers (e.g., Helm checklist present when `Chart.yaml` is in the diff; absent otherwise). Regression check on a non-Kubernetes diff — the profile must remain inactive. Issue #64 is closeable.

### P2 — `design` / `implement` / `test` / `document` K8s-awareness

One task per extended skill. Each task adds the profile-aware clause to the skill, authors the corresponding `profiles/k8s/<phase>/index.md` and content files, and verifies with a synthetic K8s scenario in the relevant phase.

**Verification criteria (per skill).** Smoke test: invoke the skill against a Kubernetes scenario, observe that profile content is loaded and applied. Smoke test: invoke the skill against a non-Kubernetes scenario, observe that behavior is unchanged. Structure test passes with the new per-phase index files asserted.

### P3 — `review-spec` and `dependency-handling`

`review-spec` prose gains the K8s-awareness clause and optional `profiles/k8s/review-spec/` content. `dependency-handling` description is rewritten to fit the 1,536-character per-entry cap while widening to IaC; body gains the per-profile lookup pointer.

**Verification criteria.** `dependency-handling` description length ≤1,536 characters (manual or automated check). Spec-vs-impl scenario on Kubernetes artifacts exercises the widened finding shapes. End-to-end smoke: an entirely synthetic K8s feature is carried through the design → implement → review-code → test → document → review-spec flow; each step invokes profile-aware behavior where applicable.

### Feature close

Move `docs/wip/kubernetes-support/` → `docs/done/kubernetes-support/`. Update any status metadata in the feature's own docs. Branch-level merge is a human action, not a task.

## Open questions deferred to implementation

These are small decisions intentionally left for the implementer to resolve during P1–P3:

- **Whether `profiles/k8s/review-spec/` warrants its own directory**, or a single paragraph inline in the three `review-spec` skill files suffices. Apply the threshold rule from §`review-spec` — P3: create the directory when the guidance comprises ≥2 distinct checklists OR any conditional trigger; inline otherwise.
- **Exact trigger-condition wording** inside `profiles/k8s/review-code/index.md` for conditional entries (e.g., how to name "Helm context detected"). Prose form is chosen by the author; structured triggers are a future refinement (see [ADR 0002](../../adr/0002-profile-content-organization.md), "Forward direction").
- **Whether to add an opportunistic description-length assertion** to `test/test-plugin-structure.sh` for `dependency-handling`'s description or leave the 1,536-character cap enforced only by the harness. Either is acceptable for P3 close.

## Amendments (post-review deferrals)

These items were flagged by reviews against in-feature commits but are intentionally deferred — they require changes beyond the current feature's scope and can be picked up once the current design is fully implemented.

**Follow-up entry point:** [tasks.md Task 20 — Design amendments follow-up](tasks.md#task-20--design-amendments-follow-up-post-feature-handoff). That task is a handoff pointer; a future contributor starts there when an amendment's "When to apply" conditions are met.

### A1 — Generify the `design` auto-trigger set across profiles

**Flagged by:** isolated review of P0 Task 2 (commit `a22a63c`, 2026-04-18) — both `code-reviewer` sub-agent and `pal codereview` (gemini-3-pro-preview) independently identified this as a drift surface.

**Current state.** `klaude-plugin/skills/_shared/profile-detection.md` §The `design` interaction pattern hard-codes the Kubernetes auto-trigger token set (`Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`) and the confirmation prompt (`"This appears to be a Kubernetes feature. Activate the Kubernetes profile for this design session?"`). Task 11 prescribes the same literal token list for `klaude-plugin/skills/design/idea-process.md`. Two files, one literal list, K8s-specific prompt.

**Architectural concern.** The shared procedure exists to prevent drift across six consumers. Placing profile-specific content (token list + hard-coded display name in the prompt) inside a cross-profile shared file re-creates the exact drift surface the file was designed to eliminate. Adding a second IaC profile (Terraform, Ansible, Dockerfile) requires editing both the shared file and `design/idea-process.md`.

**Proposed refactor.**
1. Extend `profiles/<name>/DETECTION.md` (or a sibling file — the slot is an authoring detail) with an optional `## Design signals` section: the profile declares its own high-precision auto-trigger tokens plus a `display_name` metadata value.
2. Rewrite the shared procedure's §The `design` interaction pattern to iterate each profile's `## Design signals` section, build the union of triggers, and parameterize the confirmation prompt: `"This appears to be a {profile.display_name} feature. Activate the {profile.name} profile for this design session?"`.
3. Rewrite `skills/design/idea-process.md` Step 3 to consume the same iteration — no K8s literals in skill prose.
4. Update this `design.md` and `implementation.md` Step 0.2 to reflect the generic framing; the K8s-specific tokens move to `profiles/k8s/DETECTION.md` under the new section.

**Why it's deferred.** The current spec (this design.md §Shared mechanisms and implementation.md §Step 0.2) prescribes the literal K8s tokens live in the shared file. Flipping to a profile-driven model is a spec deviation, not a task-level fix. Doing it mid-feature would ripple through Task 2, Task 11, and multiple spec sections.

**When to apply.** After all four phases (P0–P3) have landed and the plugin is shipping with the K8s profile. Earlier is acceptable if a second IaC profile (Terraform, Ansible, Dockerfile) gets proposed — the refactor is cheaper before the duplication pattern hardens across two or more profiles. Track as a follow-up issue referencing this amendment section.

**Out of scope for kubernetes-support.** Yes.

### A2 — Apply the mandatory-order directive to all skills

**Flagged by:** Task 7 P0 verification dry-run (2026-04-19) — user-led `/kk:review-code` runs in a sibling Go project (`capy`) reproduced the same process-bypass behavior across three consecutive invocations. Diagnosis and fix framework captured in [ADR 0004 — Skill workflow ordering: instructions before action](../../adr/0004-skill-workflow-ordering.md).

**Current state.** [ADR 0004](../../adr/0004-skill-workflow-ordering.md) establishes the universal convention: every plugin skill must fully load its instructions before acting on subject matter. The ADR + [CLAUDE.md §Skill workflow ordering](../../../CLAUDE.md#skill-workflow-ordering--instructions-before-action) bind the rule for future skill authoring. Only `review-code` (`SKILL.md` + `review-process.md`) and its sub-agent (`klaude-plugin/agents/code-reviewer.md`) have been retrofitted as part of Task 7's defect fix. The remaining nine skills still follow the old pattern:

- `review-spec`, `review-design` — review family, same analyze-an-artifact shape as `review-code`
- `test` — profile-driven validator guidance
- `implement` — executes a task plan; needs per-task profile gotchas loaded before editing code
- `design` — turns idea into PRD; needs question bank + section schema loaded before engaging the idea prose
- `document` — needs profile rubric loaded before writing docs
- `merge-docs` — needs merge methodology loaded before reading the two docs
- `dependency-handling` — needs the cascade rule (capy-first, context7-second, web-last) loaded before making lookups
- `chain-of-verification` — meta-skill; needs the CoVe process loaded before applying verification

**Architectural concern.** The convention binds future work but not existing skills. Each un-swept skill is a latent instance of the same failure mode, waiting to surface the next time a user inspects its behavior carefully.

**Proposed refactor.**
1. For each of the nine remaining skills, add a **Mandatory ordering** block at the top of its Workflow section in `SKILL.md`, naming the rule by intent (subject matter and minimal-early-scope vary per skill — see the table in [ADR 0004 §Decision](../../adr/0004-skill-workflow-ordering.md#decision)). Reference ADR 0004 for rationale.
2. For each skill, audit the process/rubric files it references. If content-level read instructions (`git diff`, `Read` of subject-matter files, etc.) appear before instruction-loading steps, reorder so content reads happen once, after instructions are loaded.
3. For sub-agents referenced by these skills (`design-reviewer`, `spec-reviewer`, any others), apply the same ordering fix internally — payload delivery order does not substitute for the sub-agent reading its instructions before acting.
4. Dedup pass per skill: grep for repeated `git diff` / subject-matter `Read` instructions; collapse each to one instance at the post-instruction position.

**Why it's deferred.** Nine `SKILL.md` edits plus their referenced process/rubric files plus affected sub-agents is enough diff to deserve its own review pass. Per-skill wording needs tailoring because each skill's "subject matter" and "minimal early scope" differ (a batch copy-paste risks stilted prose). Bundling it into Task 7's defect-fix commit would obscure both changes.

**When to apply.** Any time after Task 7 lands. Ideally before a second skill's process-bypass failure surfaces in practice; ordering is cheaper to fix proactively than to debug via repeated user-led dry-runs.

**Out of scope for kubernetes-support.** Yes.

### A3 — Surface `(profile, checklist)` grouping and `triggered_by` in review output

**Flagged by:** Task 7 P0 review-spec pass (2026-04-19) — cross-check between `review-process.md`, `code-reviewer.md`, and `review-isolated.md` output templates.

**Current state.** Three files instruct the reviewer to emit findings grouped by `(profile, checklist)`:

- `klaude-plugin/skills/review-code/review-process.md:96` — *"Emit findings using `(profile, checklist)` as the grouping key so the report in Step 10 can organize them."*
- `klaude-plugin/agents/code-reviewer.md:79` — *"Emit findings grouped by `(profile, checklist)` so the report surface can organize them."*
- `klaude-plugin/skills/review-code/review-isolated.md` Step 5 — expects a report surface organized by agreement level + profile.

But zero output templates implement the grouping:

- `review-process.md:132–175` (Step 10 template) groups by **severity** (P0–P3) only.
- `code-reviewer.md:110–131` (Output Format) groups by **severity** (P0–P3) only.
- `review-isolated.md` Step 5 template (lines 193–228) groups by **reviewer source** (Corroborated / Code Reviewer / External / Author-Sourced).

The `(profile, checklist)` grouping is instructed in three places and silently dropped in three templates. In parallel, the detection output's `triggered_by` field — documented at `_shared/profile-detection.md:135` as *"For debugging and for explaining detection to the user"* — is captured per finding by detection but never surfaces to the user anywhere.

**Architectural concern.** Two separate pieces of per-finding context (which profile fired, and which signal activated it) are computed, held in memory, and discarded before the user sees output. The system collects debugging signal and throws it away. When a reviewer flags a RBAC issue on a Helm template that also happens to match the Go profile via a stray filename, the user has no way to see "this came from profiles/k8s/review-code/security-checklist.md, triggered by `filename: Chart.yaml` in an ancestor directory" — a piece of context the design explicitly scoped for surfacing.

**Proposed refactor.**

1. Decide the output shape. Two viable nestings: (a) severity-major with profile/checklist as a sub-label per finding, or (b) profile-major sections with severity subsections inside. Option (a) preserves the current severity-first mental model reviewers already use; option (b) better expresses the additive-profiles framing.
2. Update the three output templates to match the chosen shape. Each finding gains a visible `profile: <name>` / `checklist: <filename>` line (for form (a)) or lands inside the profile section (for form (b)).
3. Surface `triggered_by` once per finding: `triggered_by: content: apiVersion+kind in block 2` (or the signal description returned by detection). Emit "none" for findings whose file was touched but didn't activate any profile.
4. Update `_shared/profile-detection.md` §Output shape if the field's presentation contract changes (currently the field exists only in the internal record; it would gain a user-visible channel).

**Why it's deferred.** Three coordinated template edits across two skills and one agent; the output-shape decision (severity-major vs profile-major) benefits from a round of feedback on a realistic multi-profile review (e.g., a Go + k8s diff) before locking it in. Task 7's defect-fix bar was no-P0-findings; this is a design-coherence cleanup, not a correctness issue — the skills produce correct findings today, the reports just under-surface the grouping metadata the detection step worked to produce.

**When to apply.** After P1 lands (so a realistic multi-profile review is available as a test fixture) and before P3 verification (so the end-to-end smoke in Task 18 can exercise the surfaced grouping). Earlier is acceptable if another skill grows a profile-aware output template and the precedent starts to calcify.

**Out of scope for kubernetes-support.** Yes.

### A4 — Bound the Helm-template ancestor search to the nearest `Chart.yaml`

**Status:** **Resolved in Task 10 (2026-04-20).** The Helm-template filename rule in `klaude-plugin/profiles/k8s/DETECTION.md` and in [§Kubernetes detection rule](#kubernetes-detection-rule) is now scoped to a `templates/` directory that is a direct sibling of a `Chart.yaml` (chart root or subchart root). The monorepo false-positive regression is covered by `klaude-plugin/skills/review-code/evals/k8s-monorepo-false-positive/`. The historical context below is preserved as written at amendment time.

**Flagged by:** Task 8 P1 isolated code review (2026-04-19) — corroborated between `code-reviewer` sub-agent and `pal codereview` (gemini-3-pro-preview).

**Current state.** The Helm-template filename signal in [§Kubernetes detection rule](#kubernetes-detection-rule) and its implementation in `klaude-plugin/profiles/k8s/DETECTION.md` match any `.yaml` / `.yml` / `.tpl` file inside a `templates/` directory whose ancestor — at any depth — contains `Chart.yaml`. The ancestor search is depth-unbounded.

**Architectural concern.** In a monorepo whose repository root contains a `Chart.yaml` (e.g., an umbrella chart, or a project whose root `Chart.yaml` installs the whole product), every `.yaml`/`.yml`/`.tpl` under any `templates/` directory anywhere in the tree becomes a "Helm template" — including unrelated `templates/` dirs (Go `html/template` assets, CI scaffolding, docs-site templates). The profile activates against files that are not Helm templates, and downstream skills apply the `helm-checklist.md` to them.

The current phrasing has a secondary issue: Task 8's `DETECTION.md:24` prose says "whose chart root ancestor (any ancestor directory that contains `Chart.yaml`) is present" — the parenthetical restates the rule in terms that still leave depth unbounded, and uses two phrasings ("chart root ancestor" vs "ancestor directory that contains `Chart.yaml`") in one sentence. Whichever direction the fix goes, the two phrasings should converge.

**Proposed refactor.**

1. Tighten the rule to the **nearest** ancestor directory containing `Chart.yaml`: walk outward from the file's directory toward the repo root and stop at the first directory containing `Chart.yaml`; that directory is the "chart root" for that file. If the nearest chart root also contains the `templates/` directory the file sits under (directly or via the chart's own subtree), activate. If no `Chart.yaml` is found before the repo root, do not activate on this signal.
2. Update `klaude-plugin/profiles/k8s/DETECTION.md` filename-signal bullet for Helm templates to say "nearest chart-root ancestor" and drop the parenthetical alternate phrasing.
3. Update [§Kubernetes detection rule](#kubernetes-detection-rule) to mirror the tighter wording.
4. Add one synthetic test case to the Task 10 verification matrix: a repo with a root-level `Chart.yaml` and an unrelated `templates/` subdirectory elsewhere in the tree; the unrelated `templates/` must NOT activate `k8s`.

**Why it's deferred.** The depth-unbounded reading is faithful to the current design doc; tightening it is a spec change, not a pure implementation fix. The risk is theoretical until a real repo exhibits the false-positive; the fix cost is small but it drops naturally alongside Task 9 (which authors the Helm checklist) and Task 10 (which owns the synthetic-fixture matrix). Leaving the Task 8 file as a faithful implementation of the current spec — with the as-authored note — preserves the option to either adopt A4 or reject it during P1 verification.

**When to apply.** Before or during Task 10 (P1 verification). A monorepo-shaped synthetic fixture will make the need concrete; resolving A4 at that point is cheaper than reopening Task 8's file in a later phase.

**Out of scope for Task 8.** Yes — deferring via this amendment keeps the Task 8 PR focused on "implement the spec as written."

## References

- [ADR 0001 — Profile/language detection remains a single additive axis](../../adr/0001-profile-detection-model.md)
- [ADR 0002 — Profile-first layout with index-driven content loading](../../adr/0002-profile-content-organization.md)
- [ADR 0003 — Profile content referenced via `${CLAUDE_PLUGIN_ROOT}`, not symlinked](../../adr/0003-plugin-root-referenced-content.md)
- [implementation.md](implementation.md) — step-by-step implementation plan
- [tasks.md](tasks.md) — phase-grouped task list with per-phase verification
- [GitHub issue #64](https://github.com/serpro69/claude-toolbox/issues/64) — originating issue (narrow scope)
