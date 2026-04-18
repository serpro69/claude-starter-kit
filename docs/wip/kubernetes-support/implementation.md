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

**Goal.** Introduce `klaude-plugin/profiles/` as a top-level directory; migrate programming-language checklist content from `klaude-plugin/skills/review-code/reference/<lang>/` to `klaude-plugin/profiles/<lang>/review-code/`; author the shared detection procedure and the six consumer symlinks; restructure the `review-code` workflow to be index-driven; update the plugin-structure test, `CLAUDE.md`, and `README.md`. Behavior must remain equivalent to pre-P0 when `review-code` is invoked on diffs affecting the existing programming-language profiles.

### Step 0.1 — Create the `profiles/` top level and migrate programming-language checklists

For each language in (`go`, `python`, `java`, `js_ts`, `kotlin`):

1. Create directory `klaude-plugin/profiles/<lang>/review-code/`.
2. Move the existing files from `klaude-plugin/skills/review-code/reference/<lang>/` to `klaude-plugin/profiles/<lang>/review-code/` using `git mv` (preserves history).
3. Author `klaude-plugin/profiles/<lang>/DETECTION.md` using the mandatory three-section schema (see [design.md §Detection mechanics](design.md#detection-mechanics)): `## Path signals` (empty for programming-language profiles; file-extension detection does not involve path heuristics), `## Filename signals` (empty — language detection is extension-based, not filename-based), `## Content signals` (the file-extension rule: "any file whose extension matches `.go` / `.py` / etc."). The three sections must be present even when empty, so the shared procedure iterates predictably.
4. Author `klaude-plugin/profiles/<lang>/overview.md` — a one-page summary: what the profile covers (the programming language), when it activates, and "Looking up dependencies" targets (context7, language-specific references).
5. Author `klaude-plugin/profiles/<lang>/review-code/index.md` — lists the four migrated files (`security-checklist.md`, `solid-checklist.md`, `code-quality-checklist.md`, `removal-plan.md`) in the "Always load" section with one-line descriptions. No conditional entries for programming-language profiles.
6. Remove the now-empty `klaude-plugin/skills/review-code/reference/<lang>/` directory.

After iterating through all five languages, remove `klaude-plugin/skills/review-code/reference/` itself (now empty).

**Audit downstream migration impact.** Check `.github/scripts/template-sync.sh` for a `run_plugin_migration` function with a `dirs_to_remove` array (or equivalent mechanism). Determine whether the removal of `klaude-plugin/skills/review-code/reference/` requires an entry there to clean up downstream projects that have migrated from an older template version. Document the decision (add an entry OR document that no entry is needed — CLAUDE.md's "don't touch historical entries" directive covers pre-v0.5.0 historical paths, not new migrations introduced by this feature). If an entry is added, follow the existing entry format and date the addition.

**Verify.**
- `ls klaude-plugin/profiles/` shows exactly `go`, `java`, `js_ts`, `kotlin`, `python` (plus, after P1, `k8s`).
- `ls klaude-plugin/skills/review-code/reference/` returns "No such file or directory".
- For each language: `test -f klaude-plugin/profiles/<lang>/{DETECTION.md,overview.md,review-code/index.md}` succeeds.
- For each language: the profile's `DETECTION.md` contains the three required sections (`## Path signals`, `## Filename signals`, `## Content signals`) — any may be empty but all three headings must be present.
- `git log --follow klaude-plugin/profiles/go/review-code/security-checklist.md` shows history continuous with the old path.
- Template-sync audit decision documented in the PR description or as a comment in `template-sync.sh`.

### Step 0.2 — Author the shared profile-detection procedure

Create `klaude-plugin/skills/_shared/profile-detection.md` with the following mandatory sections:

1. **Purpose.** Single source of truth for "compute the set of active profiles for the current context." Used by six consuming skills; the shared file exists to prevent interpretation drift.
2. **Per-consumer input model.** Enumerate what each consuming skill passes as detection input:
   - `review-code` → git diff (staged or explicit range, scoped to the diff's touched files).
   - `review-spec` → git diff when invoked standalone; the feature directory's full file list when invoked by `implement`.
   - `test` → git diff (mid-feature) or full feature-directory file list (post-implementation).
   - `implement` → the current sub-task's target file list, optionally augmented by the diff accumulated so far.
   - `design` → user-declared signal OR keyword inference from the idea prose. Detection in the design phase is not file-based. The file must spell out the interaction: "check idea prose against the high-precision auto-trigger set (`Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`); if any match, ask the user to confirm activation. If no auto-trigger matches but the idea is ambiguous — names infrastructure, deployment, runtime, or platform concerns without naming a specific technology, or includes tokens like `cluster`/`namespace`/`pod` that collide with non-K8s meanings — ask explicitly." Rationale: the narrow auto-trigger set avoids noisy false positives from overloaded tokens.
   - `document` → the feature directory's current file list; diff is optional.
3. **Detection algorithm.** Iterate `klaude-plugin/profiles/*/DETECTION.md`. For each profile, evaluate signals in cost order (path → filename → content). Apply authority rule: filename or content signal matches activate the profile; path signal alone does not activate. Bounded content inspection: ~16 KB per file; multi-document YAML inspected per `---`-separated block. Every profile's `DETECTION.md` uses the three-section schema (`## Path signals` / `## Filename signals` / `## Content signals`); the shared procedure applies the same algorithm against each profile's declared values.
4. **Unset-variable check.** Before returning results, verify `${CLAUDE_PLUGIN_ROOT}` is set. If unset: emit a loud error message naming the variable and pointing at CLAUDE.md's Profile Conventions section; return the empty-set result so consumers fall back to generic guidance rather than panicking. (Per [ADR 0003 §Decision](../../adr/0003-plugin-root-referenced-content.md), the brace form is mandatory — `$CLAUDE_PLUGIN_ROOT` without braces is NOT substituted by the Claude Code harness and will never be used here.)

**Authoring caveat for the shared file itself.** `klaude-plugin/skills/_shared/profile-detection.md` lives INSIDE the plugin tree and is therefore subject to `${CLAUDE_PLUGIN_ROOT}` substitution when an agent reads it. When the file needs to describe the variable BY NAME (e.g., "check that `$CLAUDE_PLUGIN_ROOT` is set"), use the bare form `$CLAUDE_PLUGIN_ROOT` (without braces) — the bare form is not substituted (verified 2026-04-18, ADR 0003 §Verification). When the file uses the variable as a PATH that must resolve at runtime (e.g., `${CLAUDE_PLUGIN_ROOT}/profiles/*/DETECTION.md`), use the brace form — that is the intended substitution. Mixing the two conventions in the same file is normal and correct.
5. **Output shape.** A list of records, one per matched profile: `{profile: <name>, triggered_by: [<signal descriptions>], files: [<paths>]}`. `triggered_by` names the signal type that fired (e.g., `"filename: Chart.yaml"`, `"content: apiVersion+kind in block 2"`).

**Verify.** `test -f klaude-plugin/skills/_shared/profile-detection.md`. The file contains all five sections by heading. File size is ~120–200 lines (a few pages; not a brief summary). Content is readable by a skilled contributor unfamiliar with the plugin — pass it to a colleague for a sanity read.

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

Update the following files to consume `shared-profile-detection.md` and the index-driven loading pattern. Each file needs **specific literal-string replacements**, not just behavioral intent — the old prose hardcodes `reference/<lang>/` paths in multiple places, and the grep verification below catches missed replacements.

- `klaude-plugin/skills/review-code/SKILL.md` — prose gains a sentence linking `[shared-profile-detection.md](shared-profile-detection.md)` (per CLAUDE.md convention: consumers reference the per-skill symlink, not the shared source). No change to the description frontmatter.
- `klaude-plugin/skills/review-code/review-process.md`:
  - "Step 2: Detect primary language" renames to "Step 2: Detect active profiles" and delegates to the shared procedure.
  - Former Steps 3–6 (SOLID / Removal / Security / Quality) collapse into:
    - "Step 3: Load profile review indexes." For each active profile, resolve `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md`; collect always-load entries and conditional entries whose stated triggers match the diff.
    - "Step 4: Apply checklists." Iterate the resolved checklists; each checklist's findings are emitted with `(profile, checklist)` as the grouping key.
  - Subsequent steps (self-check, indexing, output formatting) are renumbered but otherwise unchanged.
  - Replace every literal occurrence of `reference/<lang>/` and `reference/{lang}/` (any variant) with the `${CLAUDE_PLUGIN_ROOT}/profiles/...` equivalent or a description of the index-driven loading step.
- `klaude-plugin/skills/review-code/review-isolated.md` — the same restructure pattern, adapted for the isolated sub-agent variant.
  - **Literal path string to replace:** the sub-agent prompt template in Step 2 currently injects `klaude-plugin/skills/review-code/reference/{language_key}/` into the spawned agent's prompt. This literal string must be replaced with the list of resolved checklists (produced in Step 1 when preparing the scope block). The sub-agent receives the list, not a path.
  - Replace every other literal occurrence of `reference/<lang>/` in the file.
- `klaude-plugin/agents/code-reviewer.md` — the prompt updates to iterate the `(profile, checklist)` list it is given, rather than iterating fixed category names.
  - **Literal path string to replace:** the agent's current Step 2 says "Load the corresponding reference checklists from `klaude-plugin/skills/review-code/reference/{lang}/`" with the full extension table duplicated. Rewrite to: "Apply the checklists provided in the input payload; for each `(profile, checklist)` record, read the checklist content from `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>/review-code/<checklist>` and apply it to the diff." Remove the extension table (detection is no longer the agent's responsibility; the calling skill has already produced the list).

**Verify.**
- Grep check (expanded scope to include `agents/`): `grep -rn 'reference/' klaude-plugin/skills/review-code/ klaude-plugin/agents/code-reviewer.md` returns no lines. If any remain, replacement was incomplete.
- Grep check: `grep -rn '${CLAUDE_PLUGIN_ROOT}/profiles/' klaude-plugin/skills/review-code/` returns matches at the relevant points (Step 3 of review-process.md, equivalent in review-isolated.md).
- Manual dry-run: invoke `/kk:review-code` on a Go-only diff (e.g., a recent commit touching only `.go` files). The output identifies the `go` profile as active and loads the four checklists now at `profiles/go/review-code/`. Findings coverage and categories match pre-P0 output qualitatively.
- `klaude-plugin/agents/code-reviewer.md` parses cleanly (front-matter valid, instructions coherent on a manual read).

### Step 0.5 — Update the plugin-structure test

Modify `test/test-plugin-structure.sh`:

- Add `EXPECTED_PROFILES=("go" "java" "js_ts" "kotlin" "python")` (`k8s` will be appended in Step 1.3 of P1, after k8s content files exist).
- **Per-profile assertions (presence-conditional).** Assertions are predicated on what the profile declares; they do NOT require every profile to populate every phase subdirectory:
  - Directory `klaude-plugin/profiles/<name>/` exists (required for every profile in `EXPECTED_PROFILES`).
  - File `klaude-plugin/profiles/<name>/DETECTION.md` exists (required).
  - `DETECTION.md` contains the three required section headings (`## Path signals`, `## Filename signals`, `## Content signals`). Any may be empty; all must be present. Use `grep -c '^## Path signals' ...` and similar to verify each header appears exactly once.
  - File `klaude-plugin/profiles/<name>/overview.md` exists (required).
  - For each phase subdirectory name in (`review-code`, `design`, `test`, `implement`, `document`, `review-spec`): IF `klaude-plugin/profiles/<name>/<phase>/` exists, THEN `<phase>/index.md` must exist. IF the phase subdirectory does not exist, the test skips (a profile is not required to populate every phase).
- **Bidirectional index invariant.** For every phase subdirectory that exists in any profile:
  - Forward: every markdown link in `<phase>/index.md` resolves to a file that exists on disk.
  - Reverse (new): every `.md` file in `<phase>/` (except `index.md` itself) is referenced by at least one markdown link in `<phase>/index.md`. Extract the set of filenames from the directory listing, extract the set of filenames named in the index (via `grep -oE '\[[^]]+\]\([^)]+\.md\)' <phase>/index.md`), assert the two sets match modulo `index.md`.
- **Symlink assertions.** For each of the six consumer skills (`review-code`, `review-spec`, `design`, `implement`, `test`, `document`): `klaude-plugin/skills/<skill>/shared-profile-detection.md` is a symlink and resolves to `klaude-plugin/skills/_shared/profile-detection.md`.
- Retain existing `EXPECTED_SKILLS` and `EXPECTED_COMMANDS` assertions unchanged.

**Verify.** `bash test/test-plugin-structure.sh` exits 0. Run three targeted break-and-restore experiments to confirm each new assertion produces an actionable message:
1. `git rm` a file referenced by an index.md → forward assertion should fail with the missing filename.
2. Create an orphan `touch klaude-plugin/profiles/go/review-code/__orphan.md` → reverse assertion should fail naming the orphan. Remove the orphan after test.
3. Remove one of the three section headers in a `DETECTION.md` → header assertion should fail naming the missing heading. Restore.
All three failures must exit non-zero with a message that tells a contributor exactly which assertion failed and which file/profile caused it.

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

Follows the mandatory three-section schema from [design.md §Signal model](design.md#signal-model). Content:

**`## Path signals`** — case-insensitive path-match candidate pre-filter (not authoritative):
- `k8s/`, `manifests/`, `charts/`, `kustomize/`, `deploy/`, `templates/` — anywhere in the path.

**`## Filename signals`** — authoritative filename matches:
- `Chart.yaml` → Helm chart root.
- Any filename starting with `values` (e.g., `values.yaml`, `values.yml`, `values-prod.yaml`) AND the containing directory also contains `Chart.yaml` → Helm values by adjacency.
- Any `.yaml`, `.yml`, or `.tpl` file under a `templates/` directory whose ancestor (chart root or anywhere upward within the chart directory structure) contains `Chart.yaml` → Helm template.
- Exact filenames `kustomization.yaml`, `kustomization.yml`, or `Kustomization` → Kustomize.

**`## Content signals`** — authoritative content-inspection for generic YAML not caught by filename:
- Scan each `---`-separated document block in `.yaml` or `.yml` files. A document with both a top-level `apiVersion:` AND a top-level `kind:` at zero indent → Kubernetes manifest. One matching document activates the profile; the first document need not match.
- Inspection is bounded to the first ~16 KB per file.

Additional prose (outside the three schema sections) states:
- **Multi-profile behavior:** additive. The Kubernetes profile coexists with programming-language profiles on the same diff.
- **Dockerfile non-trigger:** a Dockerfile alone does not activate the K8s profile, even under `deploy/` or `k8s/`. Dockerfile review belongs to a future container profile.
- **Bounded `values*` glob:** the `values*.yaml` rule matches any filename beginning with `values` in a directory containing `Chart.yaml`. Names like `values-prod-v2-final.yaml` still match; the adjacency rule is the binding constraint.

**Verify.** `test -f klaude-plugin/profiles/k8s/DETECTION.md`. The three required headings are present exactly once each (use `grep -c '^## Path signals' ...` etc.). Total content is concise (~80-120 lines). Have a second reader (or another Claude session) re-implement the detection rule from this file alone; outputs must agree on test cases covering manifest-only, Helm-chart, Helm-template, Kustomize, values-adjacency, and multi-doc YAML scenarios.

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

### Step 1.3 — Author `profiles/k8s/review-code/` checklists and index, then append `k8s` to `EXPECTED_PROFILES`

Create the following files in `klaude-plugin/profiles/k8s/review-code/`:

- `security-checklist.md` — RBAC least privilege (ServiceAccount scoping, avoid cluster-admin), NetworkPolicy presence and default-deny posture, Pod Security Standards level, non-root containers, `readOnlyRootFilesystem`, secret handling (no inline secrets; preference for external secret managers), image provenance and pull-secret hygiene, avoid `hostPath` and `hostNetwork` without justification, avoid privileged containers.
- `architecture-checklist.md` — one primary concern per resource (don't conflate unrelated services), config injection via env/ConfigMap/Secret rather than hardcoded values, no hardcoded cluster assumptions (cluster-local DNS, namespace names), explicit selectors and labels, clean separation between application code and cluster concerns.
- `quality-checklist.md` — labels and selectors aligned (common recommended set: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`), immutable image tags (digests preferred, `:latest` forbidden), resource requests *and* limits present, probe correctness (`readinessProbe` gates traffic, `livenessProbe` restarts; do not conflate), explicit port naming, annotations over prose in manifests, declarative over imperative patches.
- `reliability-checklist.md` — PodDisruptionBudget presence for multi-replica workloads, probe semantics (startup, readiness, liveness distinctions and interaction), graceful shutdown (`terminationGracePeriodSeconds` and `preStop` hooks), anti-affinity rules for spreading replicas, topology spread constraints across zones/nodes, `RollingUpdate` strategy parameters tuned to workload sensitivity.
- `helm-checklist.md` — `Chart.yaml` metadata completeness (`apiVersion: v2`, `appVersion`, `kubeVersion` constraint when relevant), `values.yaml` schema exposure (and optional `values.schema.json`), template correctness (no unquoted user-supplied strings, proper handling of nil values with `default`, correct use of `toYaml`), chart dependencies pinned with digest or strict semver, `helm lint` clean, chart-level `NOTES.txt` informative for installers.
- `kustomize-checklist.md` — base/overlay separation (bases have no environment specifics, overlays contain environment deltas only), patch targets precise (avoid over-broad selectors), generator options stable (`configMapGenerator` and `secretGenerator` suffix behavior understood), commonLabels/commonAnnotations aligned with quality-checklist labels set, no hidden JSON-patch magic where strategic merge is clearer.
- `removal-plan.md` — template for staged removal of Kubernetes resources and CRDs. Sections: "Safe to remove now" (orphan ConfigMaps, unreferenced Services), "Defer with plan" (CRDs with existing instances, resources owned by Operators, namespaces with persistent volumes), "Checklist before removal" (finalizer audit, backup, rollback plan, consumer notification).

Then author `index.md` with **predicate-form conditional triggers** (per [design.md §Index file structure](design.md#index-file-structure)):

- Always-load entries (in this order): `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md`.
- Conditional entries:
  - `reliability-checklist.md` — **Load if:** the diff contains any file with a top-level YAML document whose `kind:` is `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, or `CronJob`.
  - `helm-checklist.md` — **Load if:** the diff contains a file named `Chart.yaml`; OR any file named `values*.yaml` in a directory that also contains `Chart.yaml`; OR any file under a `templates/` directory whose ancestor contains `Chart.yaml`.
  - `kustomize-checklist.md` — **Load if:** the diff contains a file named `kustomization.yaml`, `kustomization.yml`, or `Kustomization`; OR a file under a `bases/` or `overlays/` directory; OR a patch file referenced by a nearby `kustomization.*`.

Clarify explicitly (edge-case wording inside the index entry prose):

- A standalone `values.yaml` with NO sibling `Chart.yaml` does NOT trigger `helm-checklist.md`.
- A `deployment.yaml` outside any `templates/` directory and containing no `{{ ... }}` directives, matching the K8s content signature, is a plain manifest, not a Helm template.

**Finally,** append `"k8s"` to the `EXPECTED_PROFILES` array in `test/test-plugin-structure.sh`. This is done in THIS step (not a separate step) because `EXPECTED_PROFILES` assertions require the profile's files to exist; appending earlier would fail the structure test.

**Verify.**
- Every checklist file exists and passes a basic readability check (no dangling markdown, no placeholder text).
- Forward index invariant: `index.md` links resolve to files on disk.
- Reverse index invariant: every `.md` file in `profiles/k8s/review-code/` (except `index.md`) is referenced by `index.md`.
- Each conditional `Load if:` clause is a concrete predicate (names `kind:` fields by exact values, names filenames by exact strings — not a vague category label).
- `bash test/test-plugin-structure.sh` exits 0 with `k8s` in `EXPECTED_PROFILES`.

### Step 1.V — P1 verification task

1. **`test` skill.** Prepare a synthetic Kubernetes diff (a new Deployment + Service + ConfigMap). Run `/kk:review-code` against it. Confirm: `k8s` profile is detected; `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md` load (always-load); `reliability-checklist.md` loads (conditional trigger: Deployment in diff). Findings emit with `(k8s, <checklist>)` grouping. Prepare a second synthetic diff containing only a `kustomization.yaml` and a patch; confirm `kustomize-checklist.md` loads, `helm-checklist.md` does not. Prepare a third synthetic diff containing a `Chart.yaml` + `templates/`; confirm `helm-checklist.md` loads. Regression: a Go-only diff does not activate the `k8s` profile.
2. **`document` skill.** Confirm `profiles/k8s/` documentation is coherent; cross-reference to `design.md` is accurate where relevant.
3. **`review-code` skill.** Run `/kk:review-code` on the P1 diff (the feature's own changes). Address findings per project convention.
4. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all`. Confirm P1's intended scope is satisfied by the P1 diff.
5. **Issue #64 closure check.** `review-code` now supports Kubernetes artifacts as described in the issue's expanded discussion; the narrow issue-#64 text is satisfied.

## Phase 2 — `design` / `implement` / `test` / `document` K8s-awareness

Each skill gets the same pattern: (a) add a profile-aware clause to the relevant skill file(s); (b) author the corresponding `profiles/k8s/<phase>/` content files and index; (c) verify with a synthetic K8s scenario in the relevant phase.

**Test-file coordination.** The four skill-extension steps each need to add assertions for a new `profiles/k8s/<phase>/index.md` path. Rather than each step editing `test/test-plugin-structure.sh` in isolation (which creates merge contention if the four steps run in parallel) — the presence-conditional assertion added in Step 0.5 ALREADY handles new phase subdirectories dynamically: it checks "if phase/ exists, assert phase/index.md exists" for every profile. Therefore, P2 steps do NOT need to edit the test file; the structure test automatically covers new phase directories as they appear.

If the presence-conditional assertion was not implemented this way (e.g., if it was enumerated rather than glob-driven), Phase 2 would need serial test-file edits. The presence-conditional design avoids this entirely.

The four steps below can be tackled in parallel with no shared-file contention. The recommended sequence is `design` → `implement` → `test` → `document`, because each subsequent step builds on the prior in a natural flow, but any order is acceptable. Each has its own verification sub-task.

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
- `bash test/test-plugin-structure.sh` exits 0 (presence-conditional assertion automatically covers the new `profiles/k8s/design/index.md`; no test-file edit needed).
- Synthetic scenario: start a fresh design session for a hypothetical K8s-shaped feature with K8s-shaped keywords in the idea prose; confirm the skill surfaces the detection-confirmation question, activates the profile on user confirmation, and asks questions from the K8s question bank in Step 3.
- Synthetic scenario: start a design session for an ambiguous idea (e.g., "containerize this service") — confirm the skill asks the explicit "does this involve Kubernetes/Terraform/other IaC?" question rather than auto-activating.
- Regression: start a design session for a pure Go feature (no K8s keywords, no ambiguity); confirm the K8s profile is NOT activated and behavior is unchanged.

### Step 2.2 — Extend `implement`

File edits:
- `klaude-plugin/skills/implement/SKILL.md` — Step 2 (execute sub-task) gains a bullet about loading `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/implement/index.md` for per-task gotchas, and about applying `dependency-handling` for K8s API versions / CRDs / Helm charts / container images per the P3 widened trigger.

New content:
- `klaude-plugin/profiles/k8s/implement/index.md` — always-load entries.
- `klaude-plugin/profiles/k8s/implement/gotchas.md` — API-version pinning (avoid `extensions/v1beta1` or other deprecated/removed APIs; check `kubectl api-versions`), probe-correctness pitfalls (readiness ≠ liveness; startup probes for slow-starting apps), image-tag immutability (digests preferred), resource-limits-before-shipping (OOMKill risks from missing limits; CPU throttling from unrealistic limits), namespace + label discipline (all resources scoped, labels set per `quality-checklist.md`), webhook timing (CRDs must install before custom resources).

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0 (presence-conditional assertion covers the new `profiles/k8s/implement/index.md`).
- Synthetic scenario: execute a task whose subtasks touch Kubernetes manifests; confirm gotchas are surfaced and `dependency-handling` fires on any manifest referencing a K8s API version.
- Regression: execute a task whose subtasks touch Go code only; behavior is unchanged.

### Step 2.3 — Extend `test`

File edits:
- `klaude-plugin/skills/test/SKILL.md` — guidelines gain the profile-aware clause.

New content:

- `klaude-plugin/profiles/k8s/test/index.md` — always-load entries: `validators.md`, `policy-hook.md`, `presence-check-protocol.md`.
- `klaude-plugin/profiles/k8s/test/presence-check-protocol.md` — the binary-presence protocol documented in [design.md §test](design.md#test--p2-validator-guidance-with-policy-hook-auto-detection): before running any validator, check that its binary is on `PATH`. If missing, surface a per-tool install hint (brew, apt, go install, etc.) and either fall back to descriptive guidance or mark the check as skipped in the report. Missing a floor binary does NOT block the test run. Apply the protocol to floor, menu, and policy tools alike.
- `klaude-plugin/profiles/k8s/test/validators.md` — **floor** (mandated when Kubernetes profile is active AND binary is present): `kubeconform` on all matched YAML, `helm lint` on each Helm chart directory, `kustomize build` on each Kustomize directory. Include per-tool install hints. **Menu** (suggested, run when binary present and user opts in): `kube-score`, `kube-linter`, `polaris`, `trivy config`, `checkov`, `kics`. Cluster-dependent additions (optional, requires `kubectl` configured against a reachable cluster): `kubectl --dry-run=server`, `popeye`.
- `klaude-plugin/profiles/k8s/test/policy-hook.md` — auto-detection rules:
  - Presence of `.conftest/` or `policies/*.rego` AND `conftest` on PATH → run `conftest test`. Missing binary → install hint.
  - Presence of `kyverno-policies/` or resources of kind `ClusterPolicy` / `Policy` AND `kyverno` on PATH → run `kyverno test`.
  - Presence of `.gator/` or Gatekeeper `ConstraintTemplate` / `Constraint` resources AND `gator` on PATH → run `gator test`.
  - No markers present → policy validation skipped silently (no install hints surfaced — the project simply doesn't have a policy toolchain).

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0 (presence-conditional assertion automatically covers the new `profiles/k8s/test/index.md`).
- Synthetic scenario: test-plan a K8s-shaped feature; confirm floor validators are prescribed, menu is cataloged, and policy hook is described as optional but triggered by project markers.
- Synthetic scenario with a dummy `.conftest/` directory: policy-hook trigger fires.
- Synthetic scenario with one floor binary missing (e.g., uninstall or rename `kubeconform` temporarily): install hint is surfaced; other floor checks still run; skill does not crash.

### Step 2.4 — Extend `document`

File edits:
- `klaude-plugin/skills/document/SKILL.md` — guidelines gain the profile-aware clause.

New content:
- `klaude-plugin/profiles/k8s/document/index.md` — always-load entries.
- `klaude-plugin/profiles/k8s/document/rubric.md` — required documentation topics for K8s artifacts: RBAC decision rationale (why certain permissions are granted, scope limits), rollback runbook (steps, owner, verification), resource-baseline documentation (requests/limits reasoning, capacity planning assumptions), cluster-compat matrix (API versions, deprecation horizon), NetworkPolicy/egress posture narrative.

**Verify.**
- `bash test/test-plugin-structure.sh` exits 0 (presence-conditional assertion covers the new `profiles/k8s/document/index.md`).
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
- Apply the threshold rule from [design.md §`review-spec` — P3](design.md#review-spec--p3-k8s-awareness-polish): create `klaude-plugin/profiles/k8s/review-spec/index.md` and supporting content files when the drafted guidance comprises **≥2 distinct checklists** OR includes **any conditional trigger**. Otherwise the guidance lives inline in the three `review-spec` skill files and no `profiles/k8s/review-spec/` subdirectory is created.

**Verify.**
- If `profiles/k8s/review-spec/` exists, `bash test/test-plugin-structure.sh` exits 0 with the new assertion green.
- Synthetic scenario: a K8s feature whose design specifies a PDB and whose implementation omits it — `review-spec` emits a `missing_impl` finding for the PDB.

### Step 3.2 — Widen `dependency-handling`

File edits:
- `klaude-plugin/skills/dependency-handling/SKILL.md`:
  - **Description frontmatter** rewritten to the 223-character form specified in [design.md §Skill description budget](design.md#skill-description-budget-applied-in-this-feature). Confirm length is ≤250 characters.
  - **Body** gains a short paragraph: the cascade rule (capy-first, context7-second, web-last) applies uniformly to all listed dep categories; per-domain specific lookup targets live in each profile's `overview.md`.
- `test/test-plugin-structure.sh`: add a description-length assertion — parse the `description:` field of `klaude-plugin/skills/dependency-handling/SKILL.md`'s YAML frontmatter, measure its length, assert ≤250 characters. This is a mechanical check that prevents regression on the budget.

**Cross-consistency check.** Re-read `klaude-plugin/profiles/k8s/overview.md`'s "Looking up Kubernetes dependencies" section (authored in Step 1.2). Ensure its section heading and anchor match whatever the new `dependency-handling/SKILL.md` body paragraph cites (e.g., if the body says "see each profile's `overview.md` §Looking up dependencies", the K8s overview must have a heading with that exact text). If the heading anchor in the overview diverges, adjust one or the other so they agree.

**Verify.**
- `wc -c` (or the new test assertion) on the extracted description field reports a length ≤250.
- The description contains the phrases "IaC API version", "Helm", "container image" (or equivalent covering terms).
- The body's "Use BEFORE writing the call" instruction survives and is no longer truncated in agent-visible surfaces.
- The `dependency-handling/SKILL.md` body paragraph's anchor reference resolves to an existing heading in `profiles/k8s/overview.md`.
- `bash test/test-plugin-structure.sh` exits 0 with the new description-length assertion green.

### Step 3.V — P3 verification task

1. **`test` skill.** Run `bash test/test-plugin-structure.sh` — description-length assertion passes, all presence-conditional assertions pass, bidirectional index invariants pass. End-to-end synthetic smoke: a brand-new hypothetical K8s feature flows through the full design → implement → review-code → test → document → review-spec chain; each skill applies profile-aware behavior where applicable.
2. **`document` skill.** Review CLAUDE.md for accuracy now that all phases have landed.
3. **Deferred-decision branch check (re: Step 3.1).** If `profiles/k8s/review-spec/` was created in Step 3.1, confirm `test/test-plugin-structure.sh` (via the presence-conditional assertion) covers its `index.md`. If it was inlined instead, confirm `review-spec/SKILL.md`, `review-process.md`, and `review-isolated.md` actually contain the IaC clause and no orphan profile directory was created. Either branch should yield a green structure test.
4. **Cross-reference check.** Verify the `dependency-handling` body paragraph's reference to `profiles/<name>/overview.md` §Looking up dependencies resolves: for each profile that declares a "Looking up dependencies" section in its `overview.md`, the heading exists and the anchor the skill body cites matches.
5. **`review-code` skill.** Run `/kk:review-code` on the P3 diff. Address findings.
6. **`review-spec` skill.** Run `/kk:review-spec kubernetes-support` with scope `all` on the complete feature. Confirm all tasks map to implementation.

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
