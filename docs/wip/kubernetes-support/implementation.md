# Kubernetes support — implementation plan

- **Feature:** kubernetes-support
- **Design:** [design.md](design.md)
- **Tasks:** [tasks.md](tasks.md)
- **Status:** implementation-plan
- **Branch:** `k8s_support`

This document is a step-by-step guide for implementing the design. Each step is paired with an explicit verification. Tasks in [tasks.md](tasks.md) reference the corresponding steps here.

## Conventions

- All file paths in this document are relative to the repository root unless noted otherwise.
- Each step's **verify** clause specifies how the implementer confirms the step succeeded. Steps without a verification are not considered complete.
- Commits are atomic per task in [tasks.md](tasks.md); a task may span multiple steps here, but the steps collectively map to one self-contained commit.
- The order of steps within a phase is significant; dependencies are stated explicitly where a later step requires the output of an earlier one.

## Prerequisites

Before starting P0:

1. The three ADRs ([0001](../../adr/0001-profile-detection-model.md), [0002](../../adr/0002-profile-content-organization.md), [0003](../../adr/0003-plugin-root-referenced-content.md)) have been authored in `docs/adr/`.
2. `docs/wip/kubernetes-support/` exists with this file, `design.md`, and `tasks.md`.
3. The branch `k8s_support` is checked out (confirm with `git branch --show-current`).
4. The plugin-structure test currently passes on the branch (confirm with `bash test/test-plugin-structure.sh` — captures the pre-P0 baseline).

## Phase 0 — Profile-first refactor

**Goal.** Introduce `klaude-plugin/profiles/` as a top-level directory; migrate programming-language checklist content from `klaude-plugin/skills/review-code/reference/<lang>/` to `klaude-plugin/profiles/<lang>/review/`; author the shared detection procedure and the six consumer symlinks; restructure the `review-code` workflow to be index-driven; update the plugin-structure test, `CLAUDE.md`, and `README.md`. Behavior must remain equivalent to pre-P0 when `review-code` is invoked on diffs affecting the existing programming-language profiles.

### Step 0.1 — Create the `profiles/` top level and migrate programming-language checklists

For each language in (`go`, `python`, `java`, `js_ts`, `kotlin`):

1. Create directory `klaude-plugin/profiles/<lang>/review/`.
2. Move the existing files from `klaude-plugin/skills/review-code/reference/<lang>/` to `klaude-plugin/profiles/<lang>/review/` using `git mv` (preserves history).
3. Author `klaude-plugin/profiles/<lang>/DETECTION.md` — one short document stating the detection rule (the file-extension table row currently in `review-code/review-process.md`, extracted and restated per-profile).
4. Author `klaude-plugin/profiles/<lang>/overview.md` — a one-page summary: what the profile covers (the programming language), when it activates (file-extension match), and "Looking up dependencies" targets (context7, language-specific references).
5. Author `klaude-plugin/profiles/<lang>/review/index.md` — lists the four migrated files (`security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`) in the "Always load" section with one-line descriptions. No conditional entries for programming-language profiles.
6. Remove the now-empty `klaude-plugin/skills/review-code/reference/<lang>/` directory.

After iterating through all five languages, remove `klaude-plugin/skills/review-code/reference/` itself (now empty).

**Verify.**
- `ls klaude-plugin/profiles/` shows exactly `go`, `java`, `js_ts`, `kotlin`, `python` (plus, after P1, `k8s`).
- `ls klaude-plugin/skills/review-code/reference/` returns "No such file or directory".
- For each language: `test -f klaude-plugin/profiles/<lang>/{DETECTION.md,overview.md,review/index.md}` succeeds.
- `git log --follow klaude-plugin/profiles/go/review/security-checklist.md` shows history continuous with the old path.

### Step 0.2 — Author the shared profile-detection procedure

Create `klaude-plugin/skills/_shared/profile-detection.md`. Content:

- **Purpose.** Single source of truth for "given a diff or workspace, compute the set of active profiles."
- **Procedure.** Iterate over `klaude-plugin/profiles/*/DETECTION.md`; apply each profile's detection rule to the diff; produce the result list of records `{profile, triggered_by, files}`.
- **Rules for combining signals** (as described in [design.md §Detection mechanics](design.md#detection-mechanics)). Content authority: filename → content → path (path alone is insufficient).
- **Output shape.** The structured list consumers reuse.

**Verify.** `test -f klaude-plugin/skills/_shared/profile-detection.md`. The file is ≤~120 lines; clearly structured with the sections above; readable by a skilled contributor unfamiliar with the plugin.

### Step 0.3 — Create the six consumer symlinks

Create the following symlinks (each is `shared-profile-detection.md` pointing at `../_shared/profile-detection.md`):

- `klaude-plugin/skills/review-code/shared-profile-detection.md`
- `klaude-plugin/skills/review-spec/shared-profile-detection.md`
- `klaude-plugin/skills/design/shared-profile-detection.md`
- `klaude-plugin/skills/implement/shared-profile-detection.md`
- `klaude-plugin/skills/test/shared-profile-detection.md`
- `klaude-plugin/skills/document/shared-profile-detection.md`

**Verify.**
- For each symlink path P: `test -L P` succeeds; `readlink P` returns `../_shared/profile-detection.md`; `realpath P` resolves to the shared file.

### Step 0.4 — Restructure the `review-code` workflow

Update the following files to consume `shared-profile-detection.md` and the index-driven loading pattern:

- `klaude-plugin/skills/review-code/SKILL.md` — prose gains a sentence linking `[shared-profile-detection.md](shared-profile-detection.md)` (per CLAUDE.md convention: consumers reference the per-skill symlink, not the shared source). No change to the description frontmatter.
- `klaude-plugin/skills/review-code/review-process.md`:
  - "Step 2: Detect primary language" renames to "Step 2: Detect active profiles" and delegates to the shared procedure.
  - Former Steps 3–6 (SOLID / Removal / Security / Quality) collapse into:
    - "Step 3: Load profile review indexes." For each active profile, resolve `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md`; collect always-load entries and conditional entries whose stated triggers match the diff.
    - "Step 4: Apply checklists." Iterate the resolved checklists; each checklist's findings are emitted with `(profile, checklist)` as the grouping key.
  - Subsequent steps (self-check, indexing, output formatting) are renumbered but otherwise unchanged.
- `klaude-plugin/skills/review-code/review-isolated.md` — the same restructure pattern, adapted for the isolated sub-agent variant: the sub-agent's prompt receives the list of resolved checklists (not a hardcoded category sequence).
- `klaude-plugin/agents/code-reviewer.md` — the prompt updates to iterate the `(profile, checklist)` list it is given, rather than iterating fixed category names.

**Verify.**
- Grep check: `klaude-plugin/skills/review-code/` prose contains no references to `reference/<lang>/` paths.
- Grep check: `klaude-plugin/skills/review-code/` prose references `${CLAUDE_PLUGIN_ROOT}/profiles/` or `shared-profile-detection.md` at the relevant points.
- Manual dry-run: invoke `/kk:review-code` on a Go-only diff (e.g., a recent commit touching only `.go` files). The output identifies the `go` profile as active and loads the four checklists now at `profiles/go/review/`. Findings coverage and categories match pre-P0 output qualitatively.
- `klaude-plugin/agents/code-reviewer.md` parses cleanly (front-matter valid, instructions coherent on a manual read).

### Step 0.5 — Update the plugin-structure test

Modify `test/test-plugin-structure.sh`:

- Add `EXPECTED_PROFILES=("go" "java" "js_ts" "kotlin" "python")` (`k8s` will be appended in P1).
- Add per-profile assertions:
  - Directory `klaude-plugin/profiles/<name>/` exists.
  - File `klaude-plugin/profiles/<name>/DETECTION.md` exists.
  - File `klaude-plugin/profiles/<name>/overview.md` exists.
  - File `klaude-plugin/profiles/<name>/review/index.md` exists.
  - Every file referenced by any `index.md` in the profile actually exists on disk.
- Add symlink assertions: for each of the six consumer skills, `klaude-plugin/skills/<skill>/shared-profile-detection.md` is a symlink, and it resolves to `klaude-plugin/skills/_shared/profile-detection.md`.
- Retain existing `EXPECTED_SKILLS` and `EXPECTED_COMMANDS` assertions.

**Verify.** `bash test/test-plugin-structure.sh` exits 0. Deliberately break a post-condition (e.g., `git rm` a referenced checklist file) and confirm the test fails with an actionable message; restore the file.

### Step 0.6 — Update `CLAUDE.md` and `README.md`

Update `CLAUDE.md`:

- **New top-level section: "Profile Conventions."** Content per [design.md §Conventions](design.md#conventions).
- **New subsection under "Skill & Command Naming Conventions": "Skill description budget."** Content per [design.md §Skill description budget](design.md#skill-description-budget-applied-in-this-feature).
- **New subsection: "ADR location."** Content per [design.md §Conventions](design.md#conventions) — ADRs live at `docs/adr/NNNN-slug.md` using Michael Nygard's template.
- The existing "Shared instructions" subsection remains as-is (unchanged by this feature).

Update `README.md`:

- In the plugin-layout section of the README, add a one-paragraph mention of `klaude-plugin/profiles/` as a peer of `skills/`, `commands/`, `agents/`, and `hooks/`. Point curious readers to `CLAUDE.md` for the full convention.

**Verify.** `CLAUDE.md` renders as valid Markdown; new sections are internally linked where they cross-reference other parts of CLAUDE.md. `README.md` includes the `profiles/` mention.

### Step 0.V — P0 verification task

Final task for P0. Apply the plugin's own workflow skills to the P0 changes:

1. **`test` skill.** Run `bash test/test-plugin-structure.sh`. Confirm pass. Manually dry-run `/kk:review-code` on a recent Go-only change; confirm profile detection surfaces `go`, four checklists load, findings equivalent to pre-P0.
2. **`document` skill.** Confirm `CLAUDE.md` and `README.md` changes are accurate; no stale references to old `reference/<lang>/` paths anywhere in the plugin's prose.
3. **`review-code` skill.** Run `/kk:review-code` against the P0 diff. Address findings up to the project-convention severity floor.
4. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all`. Confirm P0's subset of design/implementation/tasks is satisfied by the P0 diff.

**Verify.** All four skill invocations report no P0-blocking findings; the P0 verification task in `tasks.md` is marked `done`.

## Phase 1 — Kubernetes profile for `review-code`

**Goal.** Add `klaude-plugin/profiles/k8s/` with detection, overview, and the seven review-phase checklists plus their index. No `review-code` skill prose changes — the index-driven architecture from P0 absorbs the new profile.

### Step 1.1 — Author `profiles/k8s/DETECTION.md`

Content: the combined detection rule described in [design.md §Detection mechanics](design.md#detection-mechanics). Path heuristic (pre-filter), filename (authoritative for `Chart.yaml`, `values*.yaml` adjacent to a `Chart.yaml`, `kustomization.yaml`), content signature (authoritative for generic `.yaml`/`.yml`: top-level `apiVersion:` + `kind:`). States the multi-profile behavior (additive) and the Dockerfile non-trigger (explicitly *not* handled by this profile).

**Verify.** `test -f klaude-plugin/profiles/k8s/DETECTION.md`. Content is concise (≤~80 lines). Rule wording is unambiguous enough to be re-implemented from scratch by a second reader.

### Step 1.2 — Author `profiles/k8s/overview.md`

Content:

- What the profile covers (Kubernetes manifests, Helm, Kustomize; scoped per [design.md §Scope](design.md#scope)).
- When the profile activates (summary of the detection rule — authoritative text remains in `DETECTION.md`).
- A brief architecture note: declarative model, common resource categories, relationship to Helm and Kustomize.
- **Looking up Kubernetes dependencies.** Per-category cascade targets:
  - Kubernetes API versions → context7 k8s.io docs; `kubectl explain <resource>`.
  - Third-party CRDs → the operator/controller project's docs.
  - Helm chart versions → the chart's repository README and `helm show chart <chart>`.
  - Container images → registry metadata; image digests over tags.

**Verify.** `test -f klaude-plugin/profiles/k8s/overview.md`. Cascade targets match what [design.md §dependency-handling integration](design.md#dependency-handling-integration) prescribes for P3.

### Step 1.3 — Author `profiles/k8s/review/` checklists and index

Create the following files in `klaude-plugin/profiles/k8s/review/`:

- `security-checklist.md` — RBAC least privilege (ServiceAccount scoping, avoid cluster-admin), NetworkPolicy presence and default-deny posture, Pod Security Standards level, non-root containers, `readOnlyRootFilesystem`, secret handling (no inline secrets; preference for external secret managers), image provenance and pull-secret hygiene, avoid `hostPath` and `hostNetwork` without justification, avoid privileged containers.
- `architecture-checklist.md` — one primary concern per resource (don't conflate unrelated services), config injection via env/ConfigMap/Secret rather than hardcoded values, no hardcoded cluster assumptions (cluster-local DNS, namespace names), explicit selectors and labels, clean separation between application code and cluster concerns.
- `quality-checklist.md` — labels and selectors aligned (common recommended set: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`), immutable image tags (digests preferred, `:latest` forbidden), resource requests *and* limits present, probe correctness (`readinessProbe` gates traffic, `livenessProbe` restarts; do not conflate), explicit port naming, annotations over prose in manifests, declarative over imperative patches.
- `reliability-checklist.md` — PodDisruptionBudget presence for multi-replica workloads, probe semantics (startup, readiness, liveness distinctions and interaction), graceful shutdown (`terminationGracePeriodSeconds` and `preStop` hooks), anti-affinity rules for spreading replicas, topology spread constraints across zones/nodes, `RollingUpdate` strategy parameters tuned to workload sensitivity.
- `helm-checklist.md` — `Chart.yaml` metadata completeness (`apiVersion: v2`, `appVersion`, `kubeVersion` constraint when relevant), `values.yaml` schema exposure (and optional `values.schema.json`), template correctness (no unquoted user-supplied strings, proper handling of nil values with `default`, correct use of `toYaml`), chart dependencies pinned with digest or strict semver, `helm lint` clean, chart-level `NOTES.txt` informative for installers.
- `kustomize-checklist.md` — base/overlay separation (bases have no environment specifics, overlays contain environment deltas only), patch targets precise (avoid over-broad selectors), generator options stable (`configMapGenerator` and `secretGenerator` suffix behavior understood), commonLabels/commonAnnotations aligned with quality-checklist labels set, no hidden JSON-patch magic where strategic merge is clearer.
- `removal-plan.md` — template for staged removal of Kubernetes resources and CRDs. Sections: "Safe to remove now" (orphan ConfigMaps, unreferenced Services), "Defer with plan" (CRDs with existing instances, resources owned by Operators, namespaces with persistent volumes), "Checklist before removal" (finalizer audit, backup, rollback plan, consumer notification).
- `index.md` — the router. Always-load entries: `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md`. Conditional entries:
  - `reliability-checklist.md` — **Load if:** any of Deployment, StatefulSet, DaemonSet, Job, CronJob are in the diff.
  - `helm-checklist.md` — **Load if:** `Chart.yaml`, `values*.yaml` adjacent to a `Chart.yaml`, or `templates/` directory are in the diff.
  - `kustomize-checklist.md` — **Load if:** `kustomization.yaml`, `bases/`, `overlays/`, or explicit patches files are in the diff.

**Verify.**
- Every file above exists and passes a basic readability check (no dangling markdown, no placeholder text).
- `index.md` references every file in the directory exactly once; no file in the directory is unreferenced by `index.md`.
- The always-load / conditional split matches [design.md §Content organization within profiles](design.md#content-organization-within-profiles).

### Step 1.4 — Append `k8s` to `EXPECTED_PROFILES`

Update `test/test-plugin-structure.sh`: append `"k8s"` to the `EXPECTED_PROFILES` array.

**Verify.** `bash test/test-plugin-structure.sh` exits 0 and reports `k8s` as a known profile with all assertions green.

### Step 1.V — P1 verification task

1. **`test` skill.** Prepare a synthetic Kubernetes diff (a new Deployment + Service + ConfigMap). Run `/kk:review-code` against it. Confirm: `k8s` profile is detected; `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md` load (always-load); `reliability-checklist.md` loads (conditional trigger: Deployment in diff). Findings emit with `(k8s, <checklist>)` grouping. Prepare a second synthetic diff containing only a `kustomization.yaml` and a patch; confirm `kustomize-checklist.md` loads, `helm-checklist.md` does not. Prepare a third synthetic diff containing a `Chart.yaml` + `templates/`; confirm `helm-checklist.md` loads. Regression: a Go-only diff does not activate the `k8s` profile.
2. **`document` skill.** Confirm `profiles/k8s/` documentation is coherent; cross-reference to `design.md` is accurate where relevant.
3. **`review-code` skill.** Run `/kk:review-code` on the P1 diff (the feature's own changes). Address findings per project convention.
4. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all`. Confirm P1's intended scope is satisfied by the P1 diff.
5. **Issue #64 closure check.** `review-code` now supports Kubernetes artifacts as described in the issue's expanded discussion; the narrow issue-#64 text is satisfied.

## Phase 2 — `design` / `implement` / `test` / `document` K8s-awareness

Each skill gets the same pattern: (a) add a profile-aware clause to the relevant skill file(s); (b) author the corresponding `profiles/k8s/<phase>/` content files and index; (c) update the plugin-structure test if new `index.md` assertions are needed; (d) verify with a synthetic K8s scenario in the relevant phase.

The four steps below can be tackled in parallel if desired — they touch disjoint files aside from small shared conventions in `test/test-plugin-structure.sh`. The recommended sequence is `design` → `implement` → `test` → `document`, because each subsequent step builds on the prior in a natural flow, but any order is acceptable. Each has its own verification sub-task.

### Step 2.1 — Extend `design`

File edits:
- `klaude-plugin/skills/design/SKILL.md` — no change to the top-level description; body prose gains a sentence about profile-aware question banks.
- `klaude-plugin/skills/design/idea-process.md` — Steps 3 and 5 gain the profile-detection clause from [design.md §design — P2 Kubernetes-aware idea refinement](design.md#design--p2-kubernetes-aware-idea-refinement).
- `klaude-plugin/skills/design/existing-task-process.md` — equivalent clause in the WIP-continuation flow.

New content:
- `klaude-plugin/profiles/k8s/design/index.md` — always-load entries for K8s-aware design prompts; no conditional entries unless a natural split emerges during authoring.
- `klaude-plugin/profiles/k8s/design/questions.md` — the question bank: cluster topology (target clusters, multi-cluster?), GitOps choice (ArgoCD/Flux/none), secrets strategy (external secrets operator / Sealed Secrets / cluster-native), multi-tenancy (namespace isolation, network segmentation), observability (logging, metrics, tracing stack), rollback posture (Helm rollback, GitOps sync disable, canary/blue-green).
- `klaude-plugin/profiles/k8s/design/sections.md` — required sections for K8s-shaped designs: cluster-compat matrix (K8s API versions supported), resource budget (requests/limits baselines), reliability posture (PDB/probe policy), security posture (RBAC summary, NetworkPolicy defaults), failure-mode/rollback narrative.

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0 (new assertion: `profiles/k8s/design/index.md` exists).
- Synthetic scenario: start a fresh design session for a hypothetical K8s-shaped feature; confirm the profile is detected and the K8s question bank is surfaced in Step 3.
- Regression: start a design session for a pure Go feature; confirm the K8s question bank is NOT surfaced and behavior is unchanged.

### Step 2.2 — Extend `implement`

File edits:
- `klaude-plugin/skills/implement/SKILL.md` — Step 2 (execute sub-task) gains a bullet about loading `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/implement/index.md` for per-task gotchas, and about applying `dependency-handling` for K8s API versions / CRDs / Helm charts / container images per the P3 widened trigger.

New content:
- `klaude-plugin/profiles/k8s/implement/index.md` — always-load entries.
- `klaude-plugin/profiles/k8s/implement/gotchas.md` — API-version pinning (avoid `extensions/v1beta1` or other deprecated/removed APIs; check `kubectl api-versions`), probe-correctness pitfalls (readiness ≠ liveness; startup probes for slow-starting apps), image-tag immutability (digests preferred), resource-limits-before-shipping (OOMKill risks from missing limits; CPU throttling from unrealistic limits), namespace + label discipline (all resources scoped, labels set per `quality-checklist.md`), webhook timing (CRDs must install before custom resources).

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0.
- Synthetic scenario: execute a task whose subtasks touch Kubernetes manifests; confirm gotchas are surfaced and `dependency-handling` fires on any manifest referencing a K8s API version.
- Regression: execute a task whose subtasks touch Go code only; behavior is unchanged.

### Step 2.3 — Extend `test`

File edits:
- `klaude-plugin/skills/test/SKILL.md` — guidelines gain the profile-aware clause.

New content:
- `klaude-plugin/profiles/k8s/test/index.md` — always-load entries for the floor and the menu; conditional entries for policy-hook validators.
- `klaude-plugin/profiles/k8s/test/validators.md` — **floor** (mandated when Kubernetes profile is active): `kubeconform` on all matched YAML, `helm lint` on each Helm chart directory, `kustomize build` on each Kustomize directory. **Menu** (suggested): `kube-score`, `kube-linter`, `polaris`, `trivy config`, `checkov`, `kics`. Cluster-dependent additions (optional): `kubectl --dry-run=server`, `popeye`.
- `klaude-plugin/profiles/k8s/test/policy-hook.md` — auto-detection rules:
  - Presence of `.conftest/` or `policies/*.rego` → run `conftest test`.
  - Presence of `kyverno-policies/` or resources of kind `ClusterPolicy` / `Policy` → run `kyverno test`.
  - Presence of `.gator/` or Gatekeeper `ConstraintTemplate` / `Constraint` resources → run `gator test`.
  - None of the above → policy validation skipped without comment.

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0.
- Synthetic scenario: test-plan a K8s-shaped feature; confirm floor validators are prescribed, menu is cataloged, and policy hook is described as optional but triggered by project markers.
- Synthetic scenario with a dummy `.conftest/` directory: policy-hook trigger fires.

### Step 2.4 — Extend `document`

File edits:
- `klaude-plugin/skills/document/SKILL.md` — guidelines gain the profile-aware clause.

New content:
- `klaude-plugin/profiles/k8s/document/index.md` — always-load entries.
- `klaude-plugin/profiles/k8s/document/rubric.md` — required documentation topics for K8s artifacts: RBAC decision rationale (why certain permissions are granted, scope limits), rollback runbook (steps, owner, verification), resource-baseline documentation (requests/limits reasoning, capacity planning assumptions), cluster-compat matrix (API versions, deprecation horizon), NetworkPolicy/egress posture narrative.

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0.
- Synthetic scenario: document a K8s-shaped feature; confirm the rubric is surfaced.
- Regression: document a Go-shaped feature; rubric is not surfaced; behavior unchanged.

### Step 2.V — P2 verification task

1. **`test` skill.** Run `bash test/test-plugin-structure.sh`. Run the four per-skill synthetic scenarios above.
2. **`document` skill.** Spot-check that each extended skill's prose and the corresponding `profiles/k8s/<phase>/` content are internally consistent.
3. **`review-code` skill.** Run `/kk:review-code` on the P2 diff (cumulative over Steps 2.1–2.4). Address findings.
4. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all`. Confirm P2 tasks match design.md.

## Phase 3 — `review-spec` and `dependency-handling`

### Step 3.1 — Extend `review-spec`

File edits:
- `klaude-plugin/skills/review-spec/SKILL.md`, `review-process.md`, `review-isolated.md` — where the finding taxonomy is described, add the clause from [design.md §review-spec — P3 K8s-awareness polish](design.md#review-spec--p3-k8s-awareness-polish) explaining that for IaC profiles the declarative artifacts *are* the implementation; absence of a specified resource is `missing_impl`, not `doc_incon`.

New content (conditional):
- If the K8s-specific spec-vs-implementation guidance crystallizes into more than one paragraph during authoring, create `klaude-plugin/profiles/k8s/review-spec/index.md` and supporting content files. Otherwise, the guidance lives inline in the three skill files and no `profiles/k8s/review-spec/` subdirectory is created.

**Verify.**
- If `profiles/k8s/review-spec/` exists, `bash test/test-plugin-structure.sh` exits 0 with the new assertion green.
- Synthetic scenario: a K8s feature whose design specifies a PDB and whose implementation omits it — `review-spec` emits a `missing_impl` finding for the PDB.

### Step 3.2 — Widen `dependency-handling`

File edits:
- `klaude-plugin/skills/dependency-handling/SKILL.md`:
  - **Description frontmatter** rewritten to the 223-character form specified in [design.md §Skill description budget](design.md#skill-description-budget-applied-in-this-feature). Confirm length is ≤250 characters.
  - **Body** gains a short paragraph: the cascade rule (capy-first, context7-second, web-last) applies uniformly to all listed dep categories; per-domain specific lookup targets live in each profile's `overview.md`.

**Verify.**
- `wc -c` (or equivalent) on the extracted description field reports a length ≤250.
- The description contains the phrases "IaC API version", "Helm", "container image" (or equivalent covering terms).
- The body's "Use BEFORE writing the call" instruction survives and is no longer truncated in agent-visible surfaces.

### Step 3.V — P3 verification task

1. **`test` skill.** Description-length check as above. End-to-end synthetic smoke: a brand-new hypothetical K8s feature flows through the full design → implement → review-code → test → document → review-spec chain; each skill applies profile-aware behavior where applicable.
2. **`document` skill.** Review CLAUDE.md for accuracy now that all phases have landed.
3. **`review-code` skill.** Run `/kk:review-code` on the P3 diff. Address findings.
4. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all` on the complete feature. Confirm all tasks map to implementation.

## Feature close

Move the WIP docs to completed:

```
git mv docs/wip/kubernetes-support docs/done/kubernetes-support
```

Update the feature status metadata inside the moved files (e.g., `Status: done` in `design.md` and `implementation.md`). `tasks.md` header status set to `done`; all task statuses reported as `done`.

Branch merge and PR process is outside this plan — it is a human decision.

**Verify.**
- `test -d docs/done/kubernetes-support && ! test -d docs/wip/kubernetes-support`.
- `git log --stat docs/done/kubernetes-support/` shows the move preserved history.
