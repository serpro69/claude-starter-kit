# Tasks — kubernetes-support

- **Feature status:** pending
- **Design:** [design.md](design.md)
- **Implementation plan:** [implementation.md](implementation.md)
- **Branch:** `k8s_support`
- **Closes:** [issue #64](https://github.com/serpro69/claude-toolbox/issues/64) (at end of Phase 1)
- **ADRs:** [0001 — Profile detection model](../../adr/0001-profile-detection-model.md), [0002 — Profile content organization](../../adr/0002-profile-content-organization.md), [0003 — Plugin-root referenced content](../../adr/0003-plugin-root-referenced-content.md)
- **Review mode (session default):** standard. Individual tasks may override per `implement` skill guidance.

---

> **Phase 0 — Profile-first refactor.** Behavior-preserving. Introduces `klaude-plugin/profiles/` as a top-level directory; migrates programming-language reference checklists into the new layout; creates the shared profile-detection procedure and consumer symlinks; restructures the `review-code` workflow to be index-driven; updates the plugin-structure test; adds Profile Conventions, Skill description budget, and ADR location sections to CLAUDE.md; mentions `profiles/` in README.md. Ships as a standalone PR; issue #64 is not yet closed after this phase.

## Task 1 — Migrate programming-language profiles to `profiles/`

- **Phase:** P0
- **Status:** pending
- **Depends on:** —
- **Links:** [implementation.md §Step 0.1](implementation.md#step-01--create-the-profiles-top-level-and-migrate-programming-language-checklists), [design.md §Migrated programming-language profiles](design.md#migrated-programming-language-profiles)

Subtasks:

- [ ] Create the top-level directory `klaude-plugin/profiles/`.
- [ ] For each language in (`go`, `python`, `java`, `js_ts`, `kotlin`): create `klaude-plugin/profiles/<lang>/review/` and `git mv` the four files from `klaude-plugin/skills/review-code/reference/<lang>/` into it. Preserve git history.
- [ ] Author `klaude-plugin/profiles/<lang>/DETECTION.md` per migrated profile — extract the file-extension rule for that language from `review-code/review-process.md` into a standalone detection document.
- [ ] Author `klaude-plugin/profiles/<lang>/overview.md` per migrated profile — one-page summary: what the profile covers, when it activates, "Looking up dependencies" cascade targets.
- [ ] Author `klaude-plugin/profiles/<lang>/review/index.md` per migrated profile — lists the four migrated files under "Always load" with one-line descriptions; no conditional entries.
- [ ] Remove each emptied `klaude-plugin/skills/review-code/reference/<lang>/` directory.
- [ ] Remove the now-empty `klaude-plugin/skills/review-code/reference/` directory.
- [ ] Verify: `ls klaude-plugin/profiles/` shows the five languages; `ls klaude-plugin/skills/review-code/reference/` returns ENOENT; `git log --follow` on a migrated file shows continuous history.

## Task 2 — Author the shared profile-detection procedure

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 1
- **Links:** [implementation.md §Step 0.2](implementation.md#step-02--author-the-shared-profile-detection-procedure), [design.md §Shared mechanisms](design.md#shared-mechanisms)

Subtasks:

- [ ] Create `klaude-plugin/skills/_shared/profile-detection.md`.
- [ ] Document the purpose: single source of truth for detection.
- [ ] Document the procedure: iterate `klaude-plugin/profiles/*/DETECTION.md`, apply rules, produce records `{profile, triggered_by, files}`.
- [ ] Document the signal-combination rules: filename > content > path; path alone insufficient.
- [ ] Document the output shape (the structured list consumers reuse).
- [ ] Verify: file exists; ≤~120 lines; readable by a contributor with no project context.

## Task 3 — Create the six consumer symlinks for `shared-profile-detection.md`

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 2
- **Links:** [implementation.md §Step 0.3](implementation.md#step-03--create-the-six-consumer-symlinks), [design.md §Shared mechanisms](design.md#shared-mechanisms)

Subtasks:

- [ ] `klaude-plugin/skills/review-code/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] `klaude-plugin/skills/review-spec/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] `klaude-plugin/skills/design/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] `klaude-plugin/skills/implement/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] `klaude-plugin/skills/test/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] `klaude-plugin/skills/document/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [ ] Verify each symlink: `test -L <path>` succeeds; `readlink` returns `../_shared/profile-detection.md`; `realpath` resolves to the shared file.

## Task 4 — Restructure the `review-code` workflow for index-driven loading

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 1, Task 3
- **Links:** [implementation.md §Step 0.4](implementation.md#step-04--restructure-the-review-code-workflow), [design.md §review-code — P0 refactor + P1 Kubernetes content](design.md#review-code--p0-refactor--p1-kubernetes-content)

Subtasks:

- [ ] Update `klaude-plugin/skills/review-code/SKILL.md`: add reference to `[shared-profile-detection.md](shared-profile-detection.md)` in the appropriate section. Description frontmatter unchanged.
- [ ] Update `klaude-plugin/skills/review-code/review-process.md`:
  - Rename "Step 2: Detect primary language" to "Step 2: Detect active profiles"; delegate to the shared procedure.
  - Collapse former Steps 3–6 (SOLID / Removal / Security / Quality) into a two-step sequence: "Step 3: Load profile review indexes" (for each active profile, resolve `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review/index.md`; collect always-load + matching conditional entries) and "Step 4: Apply checklists" (iterate resolved checklists; emit findings grouped by `(profile, checklist)`).
  - Renumber subsequent steps; verify internal references within the file remain consistent.
- [ ] Update `klaude-plugin/skills/review-code/review-isolated.md`: mirror the restructure; the sub-agent prompt receives the list of resolved checklists, not a hardcoded category sequence.
- [ ] Update `klaude-plugin/agents/code-reviewer.md`: prompt iterates `(profile, checklist)` from the provided list rather than fixed category names.
- [ ] Verify: `grep -rn 'reference/' klaude-plugin/skills/review-code/` finds no residual references to the removed layout.
- [ ] Verify: manual dry-run of `/kk:review-code` on a Go-only commit — output identifies `go` as the active profile; four checklists are loaded from the new `profiles/go/review/` location; finding coverage matches pre-P0.

## Task 5 — Update `test/test-plugin-structure.sh`

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 1, Task 3
- **Links:** [implementation.md §Step 0.5](implementation.md#step-05--update-the-plugin-structure-test), [design.md §Test suite updates](design.md#test-suite-updates)

Subtasks:

- [ ] Add `EXPECTED_PROFILES=("go" "java" "js_ts" "kotlin" "python")` (k8s appended in Task 8).
- [ ] Per-profile assertions: `profiles/<name>/{DETECTION.md,overview.md,review/index.md}` exist; every file referenced by any `index.md` in the profile exists on disk.
- [ ] Symlink assertions: each of the six `shared-profile-detection.md` paths under consuming skills is a symlink and resolves to `klaude-plugin/skills/_shared/profile-detection.md`.
- [ ] Retain existing `EXPECTED_SKILLS` and `EXPECTED_COMMANDS` assertions.
- [ ] Verify: `bash test/test-plugin-structure.sh` exits 0; deliberately breaking a post-condition (e.g., `git rm` a referenced checklist) makes the test fail with an actionable message; restore.

## Task 6 — Update `CLAUDE.md` and `README.md`

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 1, Task 2
- **Links:** [implementation.md §Step 0.6](implementation.md#step-06--update-claudemd-and-readmemd), [design.md §Conventions](design.md#conventions)

Subtasks:

- [ ] Add a new top-level section **Profile Conventions** to `CLAUDE.md` describing profile directory layout, `DETECTION.md` authority, `index.md` contract, naming, `${CLAUDE_PLUGIN_ROOT}` reference pattern per ADR 0003, and the steps for adding a new profile.
- [ ] Add a new subsection **Skill description budget** under "Skill & Command Naming Conventions" describing the 250-character limit and the lead-with-trigger-keywords guidance.
- [ ] Add a new subsection **ADR location** describing `docs/adr/NNNN-slug.md` convention with Michael Nygard template.
- [ ] Update `README.md` plugin-layout section with a one-paragraph mention of `profiles/` as a peer to `skills/`, `commands/`, `agents/`, `hooks/`.
- [ ] Verify: both files render as valid Markdown; internal links resolve; no stale references to the old `review-code/reference/<lang>/` path anywhere in `CLAUDE.md` or `README.md`.

## Task 7 — Phase 0 verification

- **Phase:** P0
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6
- **Links:** [implementation.md §Step 0.V](implementation.md#step-0v--p0-verification-task)

Subtasks:

- [ ] **test**: `bash test/test-plugin-structure.sh` exits 0.
- [ ] **test**: dry-run `/kk:review-code` on a recent Go-only change; confirm `go` profile detected; four checklists loaded from `profiles/go/review/`; findings qualitatively equivalent to pre-P0.
- [ ] **document**: confirm `CLAUDE.md` and `README.md` updates are accurate; no stale `reference/<lang>/` references anywhere in the plugin.
- [ ] **review-code**: run `/kk:review-code` against the P0 diff; address P0-blocking findings per project convention.
- [ ] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all`; confirm P0's portion of design.md and implementation.md is satisfied by the P0 diff.
- [ ] Set this task's status to `done` only after all four skills report no P0-blocking findings.

---

> **Phase 1 — Kubernetes profile for `review-code`.** Closes issue #64. Adds `profiles/k8s/` with detection, overview, and the seven review-phase checklists plus their index. No `review-code` skill prose changes — the index-driven architecture from P0 absorbs the new profile transparently. Ships as a standalone PR.

## Task 8 — Author `profiles/k8s/DETECTION.md` and `overview.md`, append to `EXPECTED_PROFILES`

- **Phase:** P1
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 1.1](implementation.md#step-11--author-profilesk8sdetectionmd), [implementation.md §Step 1.2](implementation.md#step-12--author-profilesk8soverviewmd), [implementation.md §Step 1.4](implementation.md#step-14--append-k8s-to-expected_profiles), [design.md §Detection mechanics](design.md#detection-mechanics)

Subtasks:

- [ ] Create `klaude-plugin/profiles/k8s/DETECTION.md` with the combined detection rule: path heuristic (pre-filter), filename (authoritative for `Chart.yaml`, `values*.yaml` adjacent to `Chart.yaml`, `kustomization.yaml`), content signature (top-level `apiVersion:` + `kind:` on generic YAML).
- [ ] State multi-profile behavior (additive loading) and the Dockerfile non-trigger explicitly in the document.
- [ ] Create `klaude-plugin/profiles/k8s/overview.md`: what the profile covers, when it activates, per-category lookup-cascade targets for Kubernetes API versions, CRDs, Helm charts, and container images.
- [ ] Append `"k8s"` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh`.
- [ ] Verify: `bash test/test-plugin-structure.sh` passes with the `k8s` entry asserted.

## Task 9 — Author `profiles/k8s/review/` checklists and index

- **Phase:** P1
- **Status:** pending
- **Depends on:** Task 8
- **Links:** [implementation.md §Step 1.3](implementation.md#step-13--author-profilesk8sreview-checklists-and-index), [design.md §The Kubernetes profile, concretely](design.md#the-kubernetes-profile-concretely), [design.md §Content organization within profiles](design.md#content-organization-within-profiles)

Subtasks:

- [ ] Create `klaude-plugin/profiles/k8s/review/security-checklist.md` — RBAC least privilege, NetworkPolicy default-deny, Pod Security Standards, non-root/readOnlyRootFilesystem, secret handling, image provenance, hostPath/hostNetwork/privileged avoidance.
- [ ] Create `klaude-plugin/profiles/k8s/review/architecture-checklist.md` — single-concern resources, config injection via env/ConfigMap/Secret, no hardcoded cluster assumptions, explicit labels/selectors, cluster-vs-application separation.
- [ ] Create `klaude-plugin/profiles/k8s/review/quality-checklist.md` — recommended label set, immutable image tags (digests preferred), resource requests+limits, probe correctness, declarative patterns.
- [ ] Create `klaude-plugin/profiles/k8s/review/reliability-checklist.md` — PodDisruptionBudget presence, probe semantics, graceful shutdown (`terminationGracePeriodSeconds`, `preStop`), anti-affinity, topology spread, RollingUpdate tuning.
- [ ] Create `klaude-plugin/profiles/k8s/review/helm-checklist.md` — `Chart.yaml` metadata completeness, values schema, template correctness, dependency pinning, `helm lint` cleanliness, `NOTES.txt`.
- [ ] Create `klaude-plugin/profiles/k8s/review/kustomize-checklist.md` — base/overlay separation, patch precision, generator stability, common labels, patch-type clarity.
- [ ] Create `klaude-plugin/profiles/k8s/review/removal-plan.md` — template with "Safe to remove now", "Defer with plan", "Checklist before removal" sections tailored to Kubernetes resources (CRDs, PVs, finalizers).
- [ ] Create `klaude-plugin/profiles/k8s/review/index.md` — always-load: security/architecture/quality/removal-plan; conditional with stated triggers: reliability (workload resources), helm (Chart.yaml/values/templates), kustomize (kustomization.yaml/bases/overlays/patches).
- [ ] Verify: every file in the directory is referenced exactly once by `index.md`; no file is unreferenced; `bash test/test-plugin-structure.sh` exits 0 with the file-referenced-by-index assertion green.

## Task 10 — Phase 1 verification

- **Phase:** P1
- **Status:** pending
- **Depends on:** Task 8, Task 9
- **Links:** [implementation.md §Step 1.V](implementation.md#step-1v--p1-verification-task)

Subtasks:

- [ ] **test**: prepare a synthetic Kubernetes diff (Deployment + Service + ConfigMap); run `/kk:review-code`; confirm `k8s` profile detected, always-load checklists plus `reliability-checklist.md` load, findings grouped by `(k8s, <checklist>)`.
- [ ] **test**: synthetic Kustomize-only diff (`kustomization.yaml` + a patch) — `kustomize-checklist.md` loads; `helm-checklist.md` does not.
- [ ] **test**: synthetic Helm-only diff (`Chart.yaml` + `templates/`) — `helm-checklist.md` loads.
- [ ] **test**: regression — Go-only diff does NOT activate `k8s`.
- [ ] **document**: confirm `profiles/k8s/` documentation coherence; cross-references to `design.md` accurate.
- [ ] **review-code**: run `/kk:review-code` on the P1 diff; address findings.
- [ ] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all`; confirm P1 portion satisfied.
- [ ] **Issue #64 closure check**: confirm `review-code` now handles Kubernetes artifacts as designed; the narrow issue-#64 text is satisfied.

---

> **Phase 2 — `design` / `implement` / `test` / `document` K8s-awareness.** Each skill gets a profile-aware clause; the corresponding `profiles/k8s/<phase>/index.md` and content files are authored. The four tasks below can proceed in parallel; the P2 verification task runs after all four land.

## Task 11 — Extend `design` with K8s-aware idea refinement

- **Phase:** P2
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.1](implementation.md#step-21--extend-design), [design.md §design — P2 Kubernetes-aware idea refinement](design.md#design--p2-kubernetes-aware-idea-refinement)

Subtasks:

- [ ] Update `klaude-plugin/skills/design/idea-process.md` — Steps 3 and 5 gain the profile-aware clause (load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/design/index.md` for each active profile).
- [ ] Update `klaude-plugin/skills/design/existing-task-process.md` — equivalent clause in the continue-WIP flow.
- [ ] Optional prose touch-up in `klaude-plugin/skills/design/SKILL.md` body (no description change).
- [ ] Create `klaude-plugin/profiles/k8s/design/index.md` — always-load entries.
- [ ] Create `klaude-plugin/profiles/k8s/design/questions.md` — question bank (cluster topology, GitOps choice, secrets strategy, multi-tenancy, observability stack, rollback posture).
- [ ] Create `klaude-plugin/profiles/k8s/design/sections.md` — required design sections for K8s-shaped features (cluster-compat matrix, resource budget, reliability posture, security posture, failure-mode narrative).
- [ ] Add per-phase index existence assertion for `profiles/k8s/design/index.md` to `test/test-plugin-structure.sh`.
- [ ] Verify: structure test passes; synthetic design session for a hypothetical K8s feature surfaces the question bank; regression — a Go-only design session does not surface it.

## Task 12 — Extend `implement` with K8s per-task gotchas

- **Phase:** P2
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.2](implementation.md#step-22--extend-implement), [design.md §implement — P2 per-task K8s gotchas](design.md#implement--p2-per-task-k8s-gotchas)

Subtasks:

- [ ] Update `klaude-plugin/skills/implement/SKILL.md` Step 2: add the profile-aware clause and the `dependency-handling` reference for K8s API versions / CRDs / Helm / container images.
- [ ] Create `klaude-plugin/profiles/k8s/implement/index.md`.
- [ ] Create `klaude-plugin/profiles/k8s/implement/gotchas.md` — API-version pinning, probe-correctness distinctions, image-tag immutability, resource-limits discipline, namespace/label hygiene, CRD-before-CR ordering.
- [ ] Add per-phase index existence assertion for `profiles/k8s/implement/index.md` to `test/test-plugin-structure.sh`.
- [ ] Verify: structure test passes; synthetic K8s-task execution surfaces gotchas and fires `dependency-handling` on manifests referencing K8s API versions; regression — Go-task execution unchanged.

## Task 13 — Extend `test` with K8s validator guidance

- **Phase:** P2
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.3](implementation.md#step-23--extend-test), [design.md §test — P2 validator guidance with policy-hook auto-detection](design.md#test--p2-validator-guidance-with-policy-hook-auto-detection)

Subtasks:

- [ ] Update `klaude-plugin/skills/test/SKILL.md` guidelines: add the profile-aware clause.
- [ ] Create `klaude-plugin/profiles/k8s/test/index.md` — always-load entries (validators, policy-hook); no conditional entries unless a natural split emerges during authoring.
- [ ] Create `klaude-plugin/profiles/k8s/test/validators.md` — **floor** (`kubeconform`, `helm lint`, `kustomize build`); **menu** (`kube-score`, `kube-linter`, `polaris`, `trivy config`, `checkov`, `kics`); **cluster-dependent optional** (`kubectl --dry-run=server`, `popeye`).
- [ ] Create `klaude-plugin/profiles/k8s/test/policy-hook.md` — auto-detection rules: `.conftest/` or `policies/*.rego` → `conftest test`; `kyverno-policies/` or Kyverno resources → `kyverno test`; `.gator/` or Gatekeeper resources → `gator test`; none present → skip silently.
- [ ] Add per-phase index existence assertion for `profiles/k8s/test/index.md` to `test/test-plugin-structure.sh`.
- [ ] Verify: structure test passes; synthetic K8s test-plan prescribes the floor, catalogs the menu, describes policy-hook auto-detection; a synthetic scenario with `.conftest/` triggers policy-hook.

## Task 14 — Extend `document` with K8s doc rubric

- **Phase:** P2
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.4](implementation.md#step-24--extend-document), [design.md §document — P2 rubric for K8s artifacts](design.md#document--p2-rubric-for-k8s-artifacts)

Subtasks:

- [ ] Update `klaude-plugin/skills/document/SKILL.md` guidelines: add the profile-aware clause.
- [ ] Create `klaude-plugin/profiles/k8s/document/index.md` — always-load entries.
- [ ] Create `klaude-plugin/profiles/k8s/document/rubric.md` — RBAC decision rationale, rollback runbook, resource-baseline documentation, cluster-compat matrix, NetworkPolicy/egress posture.
- [ ] Add per-phase index existence assertion for `profiles/k8s/document/index.md` to `test/test-plugin-structure.sh`.
- [ ] Verify: structure test passes; synthetic K8s documentation session surfaces the rubric; regression — Go documentation session unchanged.

## Task 15 — Phase 2 verification

- **Phase:** P2
- **Status:** pending
- **Depends on:** Task 11, Task 12, Task 13, Task 14
- **Links:** [implementation.md §Step 2.V](implementation.md#step-2v--p2-verification-task)

Subtasks:

- [ ] **test**: `bash test/test-plugin-structure.sh` exits 0 with all new `profiles/k8s/<phase>/index.md` assertions green; re-run the four synthetic scenarios from Tasks 11–14.
- [ ] **document**: cross-check that each extended skill's prose and the corresponding `profiles/k8s/<phase>/` content are internally consistent.
- [ ] **review-code**: run `/kk:review-code` on the cumulative P2 diff; address findings.
- [ ] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all`; confirm P2 portion satisfied.

---

> **Phase 3 — `review-spec` and `dependency-handling`.** Polish phase. `review-spec` learns K8s-specific spec-vs-implementation semantics; `dependency-handling` description and body widen to cover IaC/config artifacts with external versioning. Ships as a standalone PR.

## Task 16 — Extend `review-spec` for K8s spec-vs-implementation semantics

- **Phase:** P3
- **Status:** pending
- **Depends on:** Task 10
- **Links:** [implementation.md §Step 3.1](implementation.md#step-31--extend-review-spec), [design.md §review-spec — P3 K8s-awareness polish](design.md#review-spec--p3-k8s-awareness-polish)

Subtasks:

- [ ] Update `klaude-plugin/skills/review-spec/SKILL.md`, `review-process.md`, and `review-isolated.md`: where the finding taxonomy is described, add the clause explaining that for IaC profiles the declarative artifacts *are* the implementation; absence of a specified resource is `missing_impl`, not `doc_incon`.
- [ ] Decide during authoring whether the Kubernetes-specific guidance warrants more than one paragraph; if yes, create `klaude-plugin/profiles/k8s/review-spec/index.md` and supporting files and add a structure-test assertion for the new index; if no, inline in the three `review-spec` files and skip the `profiles/k8s/review-spec/` subdirectory.
- [ ] Verify: synthetic scenario — a K8s feature whose design specifies a PDB but whose implementation omits the PDB — produces a `missing_impl` finding.

## Task 17 — Widen `dependency-handling` description and body for IaC

- **Phase:** P3
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 3.2](implementation.md#step-32--widen-dependency-handling), [design.md §dependency-handling integration](design.md#dependency-handling-integration), [design.md §Skill description budget](design.md#skill-description-budget-applied-in-this-feature)

Subtasks:

- [ ] Rewrite the description frontmatter of `klaude-plugin/skills/dependency-handling/SKILL.md` to the 223-character form specified in design.md (covers library/SDK/framework/API + IaC API version + CRD + container image; leads with TRIGGER keyword; preserves "Use BEFORE writing the call").
- [ ] Verify description length ≤250 characters.
- [ ] Update the body: short paragraph noting that the cascade rule (capy-first, context7-second, web-last) applies uniformly to all listed dep categories; per-domain lookup targets live in each profile's `overview.md`.
- [ ] Cross-check `klaude-plugin/profiles/k8s/overview.md` "Looking up Kubernetes dependencies" section is consistent with the new body paragraph.
- [ ] Verify: length check passes; description contains "IaC API version" (or equivalent); "Use BEFORE writing the call" is present and not truncated in agent-visible surfaces.

## Task 18 — Phase 3 verification

- **Phase:** P3
- **Status:** pending
- **Depends on:** Task 16, Task 17
- **Links:** [implementation.md §Step 3.V](implementation.md#step-3v--p3-verification-task)

Subtasks:

- [ ] **test**: description-length check on `dependency-handling` passes (≤250 chars).
- [ ] **test**: end-to-end synthetic smoke — design a hypothetical K8s feature, implement a slice of it, run review-code, run test, run document, run review-spec; each skill applies profile-aware behavior where applicable.
- [ ] **document**: review `CLAUDE.md` for accuracy with all phases landed.
- [ ] **review-code**: run `/kk:review-code` on the P3 diff; address findings.
- [ ] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all` on the complete feature; confirm all tasks map to implementation.

---

## Task 19 — Feature close

- **Phase:** feature-close
- **Status:** pending
- **Depends on:** Task 7, Task 10, Task 15, Task 18
- **Links:** [implementation.md §Feature close](implementation.md#feature-close)

Subtasks:

- [ ] `git mv docs/wip/kubernetes-support docs/done/kubernetes-support`.
- [ ] Update the feature-status metadata in the moved `design.md` and `implementation.md` (status → `done`).
- [ ] Update this `tasks.md`'s header status to `done`; confirm every task above is `done`.
- [ ] Verify: `docs/done/kubernetes-support/` exists; `docs/wip/kubernetes-support/` does not; `git log --stat docs/done/kubernetes-support/` shows history preserved.
