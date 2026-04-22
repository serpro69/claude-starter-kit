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
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 0.1](implementation.md#step-01--create-the-profiles-top-level-and-migrate-programming-language-checklists), [design.md §Migrated programming-language profiles](design.md#migrated-programming-language-profiles)

Subtasks:

- [x] Create the top-level directory `klaude-plugin/profiles/`.
- [x] For each language in (`go`, `python`, `java`, `js_ts`, `kotlin`): create `klaude-plugin/profiles/<lang>/review-code/` and `git mv` the four files from `klaude-plugin/skills/review-code/reference/<lang>/` into it. Preserve git history.
- [x] Author `klaude-plugin/profiles/<lang>/DETECTION.md` per migrated profile using the mandatory three-section schema: `## Path signals` (empty — language detection is extension-based), `## Filename signals` (empty), `## Content signals` (the file-extension rule for that language). All three headings must be present even when empty.
- [x] Author `klaude-plugin/profiles/<lang>/overview.md` per migrated profile — one-page summary: what the profile covers, when it activates, "Looking up dependencies" cascade targets.
- [x] Author `klaude-plugin/profiles/<lang>/review-code/index.md` per migrated profile — lists the four migrated files under "Always load" with one-line descriptions; no conditional entries.
- [x] Remove each emptied `klaude-plugin/skills/review-code/reference/<lang>/` directory.
- [x] Remove the now-empty `klaude-plugin/skills/review-code/reference/` directory.
- [x] **Audit `template-sync.sh` for downstream migration impact.** Decision: **no action needed.** `run_plugin_migration`'s `dirs_to_remove` targets `.claude/skills/*` paths owned by pre-v0.5.0 downstream projects (paths copied out by template-sync before the Claude Code plugin marketplace took over). The removed path `klaude-plugin/skills/review-code/reference/` lives inside the plugin tree itself and is distributed via the marketplace; downstream consumers receive the migration automatically on the next plugin update without any template-sync intervention. Documented in the PR description.
- [x] Verify: `ls klaude-plugin/profiles/` shows the five languages; `ls klaude-plugin/skills/review-code/reference/` returns ENOENT; `git log --follow` on a migrated file shows continuous history. (First two confirmed now; `--follow` is observable only post-commit, but history is preserved by `git mv`.)
- [x] Verify: for each of (`go`, `python`, `java`, `js_ts`, `kotlin`): `test -f klaude-plugin/profiles/<lang>/review-code/index.md` succeeds (explicitly named so the task's verify step catches missing index files before Task 5's structure test does).
- [x] Verify: for each migrated profile, `grep -c '^## Path signals\|^## Filename signals\|^## Content signals' klaude-plugin/profiles/<lang>/DETECTION.md` returns 3 (all three required headings present).

## Task 2 — Author the shared profile-detection procedure

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 1
- **Links:** [implementation.md §Step 0.2](implementation.md#step-02--author-the-shared-profile-detection-procedure), [design.md §Shared mechanisms](design.md#shared-mechanisms)

Subtasks:

- [x] Create `klaude-plugin/skills/_shared/profile-detection.md`.
- [x] Document the purpose: single source of truth for detection; prevents interpretation drift across the six consuming skills.
- [x] **Document the per-consumer input model** per [design.md §Shared mechanisms](design.md#shared-mechanisms): `review-code` → diff; `review-spec` → diff or feature-directory file list; `test` → diff or feature files; `implement` → sub-task's target files + diff-so-far; `design` → user-declared signal or keyword inference from idea prose (interaction pattern spelled out); `document` → feature-directory file list.
- [x] Document the detection algorithm: iterate `klaude-plugin/profiles/*/DETECTION.md`; evaluate per-profile signals in cost order (path → filename → content); apply authority rule (filename or content activates; path alone does not); bounded content inspection ~16 KB per file; multi-doc YAML inspected per `---`-separated block.
- [x] Document the two-dimensional framing: signals ordered by evaluation cost (cheapest first) but authority differs (content/filename > path; path alone insufficient). Both dimensions named explicitly.
- [x] Document the `${CLAUDE_PLUGIN_ROOT}` unset-check protocol: verify the variable is set and non-empty before emitting results; if unset, fail loudly with an actionable error and return empty-set so consumers fall back to generic guidance.
- [x] **Authoring note — the shared file is inside the plugin tree.** When `profile-detection.md` prose references the variable BY NAME (documenting / explaining it), use the bare form `$CLAUDE_PLUGIN_ROOT` (no braces) — verified 2026-04-18 to survive harness substitution (see [ADR 0003 §Verification](../../adr/0003-plugin-root-referenced-content.md)). When the prose uses the variable as a PATH that must resolve at runtime, use the brace form `${CLAUDE_PLUGIN_ROOT}/...`. Both conventions coexist in the same file.
- [x] Document the output shape: list of records `{profile, triggered_by, files}` where `triggered_by` names the signal type that fired (e.g., `"filename: Chart.yaml"`, `"content: apiVersion+kind in block 2"`).
- [x] Verify: file exists; ~120–200 lines; readable by a contributor with no project context (pass it to a colleague or another Claude session for a sanity read).

## Task 3 — Create the six consumer symlinks for `shared-profile-detection.md`

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 2
- **Links:** [implementation.md §Step 0.3](implementation.md#step-03--create-the-six-consumer-symlinks), [design.md §Shared mechanisms](design.md#shared-mechanisms)

Subtasks:

- [x] `klaude-plugin/skills/review-code/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] `klaude-plugin/skills/review-spec/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] `klaude-plugin/skills/design/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] `klaude-plugin/skills/implement/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] `klaude-plugin/skills/test/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] `klaude-plugin/skills/document/shared-profile-detection.md` → `../_shared/profile-detection.md`.
- [x] Verify each symlink: `test -L <path>` succeeds; `readlink` returns `../_shared/profile-detection.md`; `realpath` resolves to the shared file.

## Task 4 — Restructure the `review-code` workflow for index-driven loading

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 1, Task 3
- **Links:** [implementation.md §Step 0.4](implementation.md#step-04--restructure-the-review-code-workflow), [design.md §review-code — P0 refactor + P1 Kubernetes content](design.md#review-code--p0-refactor--p1-kubernetes-content)

Subtasks:

- [x] Update `klaude-plugin/skills/review-code/SKILL.md`: add reference to `[shared-profile-detection.md](shared-profile-detection.md)` in the appropriate section. Description frontmatter unchanged.
- [x] Update `klaude-plugin/skills/review-code/review-process.md`:
  - Rename "Step 2: Detect primary language" to "Step 2: Detect active profiles"; delegate to the shared procedure.
  - Collapse former Steps 3–6 (SOLID / Removal / Security / Quality) into a two-step sequence: "Step 3: Load profile review indexes" (for each active profile, resolve `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md`; collect always-load + matching conditional entries) and "Step 4: Apply checklists" (iterate resolved checklists; emit findings grouped by `(profile, checklist)`).
  - Renumber subsequent steps; verify internal references within the file remain consistent.
  - Replace every literal occurrence of `reference/<lang>/` or `reference/{lang}/` with the index-driven path or a description of the new step.
- [x] Update `klaude-plugin/skills/review-code/review-isolated.md`: mirror the restructure; the sub-agent prompt receives the list of resolved checklists, not a hardcoded category sequence. **Specific literal-string edit:** the sub-agent prompt template currently injects `klaude-plugin/skills/review-code/reference/{language_key}/` into the spawned agent's prompt — replace this string with the list of resolved checklists prepared in Step 1.
- [x] Update `klaude-plugin/agents/code-reviewer.md`: prompt iterates `(profile, checklist)` from the provided list rather than fixed category names. **Specific literal-string edit:** the agent's current Step 2 says "Load the corresponding reference checklists from `klaude-plugin/skills/review-code/reference/{lang}/`" with the full extension table duplicated — rewrite to "Apply the checklists provided in the input payload; for each `(profile, checklist)` record, read the checklist content from `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>/review-code/<checklist>` and apply it to the diff." Remove the extension table entirely (detection is no longer the agent's responsibility).
- [x] Verify: `grep -rn 'reference/' klaude-plugin/skills/review-code/ klaude-plugin/agents/code-reviewer.md` finds no residual references to the removed layout (grep scope **expanded to include `agents/`** because `code-reviewer.md` lives there, not under `skills/`).
- [x] Verify: `grep -rn '${CLAUDE_PLUGIN_ROOT}/profiles/' klaude-plugin/skills/review-code/` returns matches at Step 3 of `review-process.md` and equivalent points in `review-isolated.md`.
- [ ] Verify: manual dry-run of `/kk:review-code` on a Go-only commit — output identifies `go` as the active profile; four checklists are loaded from the new `profiles/go/review-code/` location; finding coverage matches pre-P0. (**Deferred:** runtime verification belongs to Task 7 P0-V.)

## Task 5 — Update `test/test-plugin-structure.sh`

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 1, Task 2, Task 3
- **Links:** [implementation.md §Step 0.5](implementation.md#step-05--update-the-plugin-structure-test), [design.md §Test suite updates](design.md#test-suite-updates)

Subtasks:

- [x] Add `EXPECTED_PROFILES=("go" "java" "js_ts" "kotlin" "python")` — k8s is added (in alphabetical position) in Task 9 (after k8s files exist), NOT here.
- [x] **Presence-conditional per-profile assertions.** For every profile in `EXPECTED_PROFILES`: assert `profiles/<name>/DETECTION.md` and `overview.md` exist. Assert `DETECTION.md` contains the three required section headings (`## Path signals`, `## Filename signals`, `## Content signals`). For each phase subdirectory name in (`review-code`, `design`, `test`, `implement`, `document`, `review-spec`): IF `profiles/<name>/<phase>/` exists, THEN assert `<phase>/index.md` exists. A profile that does not populate a phase does NOT require an assertion for that phase. (Phase name corrected from `review` → `review-code` to match design.md §File structure and on-disk layout; the `review` token was a typo in the original task wording.)
- [x] **Bidirectional index invariant.** For every `<phase>/index.md` that exists: (forward) every markdown link resolves to a file on disk; (reverse) every `.md` file in the directory — excluding `index.md` itself — is referenced by at least one markdown link in the index.
- [x] Symlink assertions: each of the six `shared-profile-detection.md` paths under consuming skills is a symlink and resolves to `klaude-plugin/skills/_shared/profile-detection.md`.
- [x] Retain existing `EXPECTED_SKILLS` and `EXPECTED_COMMANDS` assertions unchanged.
- [x] Verify: `bash test/test-plugin-structure.sh` exits 0 (31 test cases, 109 assertions). Break-and-restore experiments all produced actionable failures: (1) forward — renamed `profiles/go/review-code/security-checklist.md` → failure named the missing file and index path; (2) reverse — `touch profiles/go/review-code/__orphan.md` → failure named the orphan and phase; (3) heading — removed `## Content signals` from `profiles/go/DETECTION.md` → failure named the missing heading and profile. All state restored.

## Task 6 — Update `CLAUDE.md` and `README.md`

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 1, Task 2
- **Links:** [implementation.md §Step 0.6](implementation.md#step-06--update-claudemd-and-readmemd), [design.md §Conventions](design.md#conventions)

Subtasks:

- [x] Add a new top-level section **Profile Conventions** to `CLAUDE.md` describing profile directory layout, `DETECTION.md`'s three-section schema, `index.md` contract with bidirectional-invariant semantics, naming conventions, `${CLAUDE_PLUGIN_ROOT}` reference pattern per ADR 0003 (including the brace-form-required constraint and the substitution-in-code-spans gotcha), and the steps for adding a new profile.
- [x] Add a new subsection **Skill description budget** under "Skill & Command Naming Conventions" — documented 1,536-character per-entry cap and the 1%/8,000-char global budget (with `SLASH_COMMAND_TOOL_CHAR_BUDGET` override); lead-with-trigger-keywords guidance; OpenCode's 1,024-character soft budget as a portability note. Cite [Claude Code docs — Skill descriptions are cut short](https://code.claude.com/docs/en/skills#skill-descriptions-are-cut-short); re-verify against that page when touching this limit in the future.
- [x] Add a new subsection **ADR location** describing `docs/adr/NNNN-slug.md` convention with Michael Nygard template.
- [x] Update `README.md` plugin-layout section with a one-paragraph mention of `profiles/` as a peer to `skills/`, `commands/`, `agents/`, `hooks/`.
- [x] Verify: both files render as valid Markdown; internal links resolve; no stale references to the old `review-code/reference/<lang>/` path anywhere in `CLAUDE.md` or `README.md`. `bash test/test-plugin-structure.sh` exits 0 (31 cases, 109 assertions). **Note:** CLAUDE.md and README.md live OUTSIDE the plugin tree and are NOT subject to `${CLAUDE_PLUGIN_ROOT}` substitution — the brace form can be used freely in any container. The literal-reference escape rule (bare `$CLAUDE_PLUGIN_ROOT` or `&#36;{CLAUDE_PLUGIN_ROOT}`) only applies to prose inside `klaude-plugin/` (SKILL.md, agent files, profile content). See [ADR 0003 §Verification](../../adr/0003-plugin-root-referenced-content.md).

## Task 7 — Phase 0 verification

- **Phase:** P0
- **Status:** done
- **Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6
- **Links:** [implementation.md §Step 0.V](implementation.md#step-0v--p0-verification-task)

Subtasks:

- [x] **test**: `bash test/test-plugin-structure.sh` exits 0.
- [x] **test**: dry-run `/kk:review-code` on a recent Go-only change; confirm `go` profile detected; four checklists loaded from `profiles/go/review-code/`; findings qualitatively equivalent to pre-P0.
- [x] **document**: confirm `CLAUDE.md` and `README.md` updates are accurate; no stale `reference/<lang>/` references anywhere in the plugin.
- [x] **review-code**: run `/kk:review-code` against the P0 diff; address P0-blocking findings per project convention. (Two P2s and one P3 found and fixed: CLAUDE.md signal-authority wording aligned with shared procedure; review-process.md gained Step 6 to resolve content-evaluable `Load if:` conditionals after Step 5 reads content; review-isolated.md placeholder convention unified on `<plugin_root>`. No P0/P1 findings.)
- [x] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all`; confirm P0's portion of design.md and implementation.md is satisfied by the P0 diff. (Three findings surfaced, all non-blocking: P2 OUTDATED_DOC in `code-reviewer.md:105` output contract — fixed (Primary language → Active profiles); P3 OUTDATED_DOC in `design.md §Shared mechanisms` iteration step — fixed (now describes explicit §Known profiles enumeration with `Glob`-cwd rationale); P3 SPEC_DEV on `k8s` pre-populated in §Known profiles before P1 content lands — deferred (mitigated by ENOENT-tolerant handler in the algorithm). `(profile, checklist)` grouping gap captured as §Amendments A3 — out of scope for P0.)
- [x] Set this task's status to `done` only after all four skills report no P0-blocking findings.

---

> **Phase 1 — Kubernetes profile for `review-code`.** Closes issue #64. Adds `profiles/k8s/` with detection, overview, and the seven review-phase checklists plus their index. No `review-code` skill prose changes — the index-driven architecture from P0 absorbs the new profile transparently. Ships as a standalone PR.

## Task 8 — Author `profiles/k8s/DETECTION.md` and `overview.md`

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 1.1](implementation.md#step-11--author-profilesk8sdetectionmd), [implementation.md §Step 1.2](implementation.md#step-12--author-profilesk8soverviewmd), [design.md §Kubernetes detection rule](design.md#kubernetes-detection-rule)

Note: the `EXPECTED_PROFILES` update to the test suite is NOT in this task. It lives in Task 9 (after the checklist files exist), because adding `k8s` to the list before the files exist would fail the structure test's per-profile assertions. `k8s` is inserted in alphabetical position; `EXPECTED_PROFILES` is a set-valued array, not a history-ordered one.

Subtasks:

- [x] Create `klaude-plugin/profiles/k8s/DETECTION.md` using the mandatory three-section schema.
- [x] **`## Path signals`**: case-insensitive candidate pre-filter — `k8s/`, `manifests/`, `charts/`, `kustomize/`, `deploy/`, `templates/`.
- [x] **`## Filename signals`** (authoritative): `Chart.yaml` → Helm chart root; filename starting with `values` in a directory containing `Chart.yaml` → Helm values by adjacency; `.yaml`/`.yml`/`.tpl` under a `templates/` directory whose ancestor contains `Chart.yaml` → Helm template; `kustomization.yaml`, `kustomization.yml`, or `Kustomization` → Kustomize.
- [x] **`## Content signals`** (authoritative for generic YAML): scan each `---`-separated document block; a block with top-level `apiVersion:` AND top-level `kind:` at zero indent → Kubernetes manifest. One matching block activates the profile; first document need not match. Inspection bounded to ~16 KB.
- [x] Add the multi-profile behavior statement (additive) and the Dockerfile non-trigger (Dockerfile alone does not activate K8s even under `deploy/`/`k8s/`) outside the three schema sections.
- [x] Clarify the `values*` glob adjacency rule in prose: any filename starting with `values` in a directory containing `Chart.yaml` matches; no upper bound on the wildcard; adjacency is the binding constraint.
- [x] Create `klaude-plugin/profiles/k8s/overview.md`: what the profile covers, when it activates, per-category lookup-cascade targets for Kubernetes API versions, CRDs, Helm charts, and container images. Include a heading anchor named `Looking up Kubernetes dependencies` (or equivalent) that Task 17's `dependency-handling` body paragraph will cite.
- [x] Verify: `test -f klaude-plugin/profiles/k8s/DETECTION.md` and `overview.md`. `grep -c '^## Path signals\|^## Filename signals\|^## Content signals' DETECTION.md` returns 3. DETECTION rule unambiguous enough for a second reader to re-implement without ambiguity on the test cases in [implementation.md §Step 1.1](implementation.md#step-11--author-profilesk8sdetectionmd).

## Task 9 — Author `profiles/k8s/review-code/` checklists and index; append `k8s` to `EXPECTED_PROFILES`

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 8
- **Links:** [implementation.md §Step 1.3](implementation.md#step-13--author-profilesk8sreview-checklists-and-index-then-append-k8s-to-expected_profiles), [design.md §The Kubernetes profile, concretely](design.md#the-kubernetes-profile-concretely), [design.md §Index file structure](design.md#index-file-structure)

Subtasks:

- [x] Create `klaude-plugin/profiles/k8s/review-code/security-checklist.md` — RBAC least privilege, NetworkPolicy default-deny, Pod Security Standards, non-root/readOnlyRootFilesystem, secret handling, image provenance, hostPath/hostNetwork/privileged avoidance.
- [x] Create `klaude-plugin/profiles/k8s/review-code/architecture-checklist.md` — single-concern resources, config injection via env/ConfigMap/Secret, no hardcoded cluster assumptions, explicit labels/selectors, cluster-vs-application separation.
- [x] Create `klaude-plugin/profiles/k8s/review-code/quality-checklist.md` — recommended label set, immutable image tags (digests preferred), resource requests+limits, probe correctness, declarative patterns.
- [x] Create `klaude-plugin/profiles/k8s/review-code/reliability-checklist.md` — PodDisruptionBudget presence, probe semantics, graceful shutdown (`terminationGracePeriodSeconds`, `preStop`), anti-affinity, topology spread, RollingUpdate tuning.
- [x] Create `klaude-plugin/profiles/k8s/review-code/helm-checklist.md` — `Chart.yaml` metadata completeness, values schema, template correctness, dependency pinning, `helm lint` cleanliness, `NOTES.txt`.
- [x] Create `klaude-plugin/profiles/k8s/review-code/kustomize-checklist.md` — base/overlay separation, patch precision, generator stability, common labels, patch-type clarity.
- [x] Create `klaude-plugin/profiles/k8s/review-code/removal-plan.md` — template with "Safe to remove now", "Defer with plan", "Checklist before removal" sections tailored to Kubernetes resources (CRDs, PVs, finalizers).
- [x] Create `klaude-plugin/profiles/k8s/review-code/index.md` with **predicate-form conditional triggers**:
  - Always-load: `security-checklist.md`, `architecture-checklist.md`, `quality-checklist.md`, `removal-plan.md`.
  - Conditional — `reliability-checklist.md` **Load if:** the diff contains any file with a top-level YAML document whose `kind:` is `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, or `CronJob`.
  - Conditional — `helm-checklist.md` **Load if:** the diff contains a file named `Chart.yaml`; OR a file named `values*.yaml` in a directory that also contains `Chart.yaml`; OR a file under a `templates/` directory whose ancestor contains `Chart.yaml`.
  - Conditional — `kustomize-checklist.md` **Load if:** the diff contains `kustomization.yaml`, `kustomization.yml`, or `Kustomization`; OR a file under `bases/` or `overlays/`; OR a patch file referenced by a nearby `kustomization.*`.
  - Include edge-case clarifications in the index prose: a standalone `values.yaml` without a sibling `Chart.yaml` does NOT trigger `helm-checklist.md`; a plain `deployment.yaml` outside `templates/` and without `{{ ... }}` directives is a manifest, not a Helm template.
- [x] Add `"k8s"` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` (alphabetical position between `js_ts` and `kotlin`). Done in this task (not Task 8) because the structure test's per-profile assertions would fail if `k8s` were in `EXPECTED_PROFILES` before its checklist files exist. The list is alphabetised — ordering is aesthetic; the structure test treats it as a set.
- [x] Verify: forward index invariant — every link in `index.md` resolves. Reverse index invariant — every `.md` file in the directory (except `index.md`) is referenced. Each conditional `Load if:` names concrete properties (`kind:` field values, filename strings, directory names) — not vague categories like "workload resources in diff". `bash test/test-plugin-structure.sh` exits 0 with `k8s` in `EXPECTED_PROFILES`.

## Task 10 — Phase 1 verification

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 8, Task 9
- **Links:** [implementation.md §Step 1.V](implementation.md#step-1v--p1-verification-task)

Subtasks:

- [x] **test**: prepare a synthetic Kubernetes diff (Deployment + Service + ConfigMap); run `/kk:review-code`; confirm `k8s` profile detected, always-load checklists plus `reliability-checklist.md` load, findings grouped by `(k8s, <checklist>)`. **Eval:** [`evals/k8s-workload-full/eval.json`](../../../klaude-plugin/skills/review-code/evals/k8s-workload-full/eval.json). Content-finding assertion `1.8` added during Task 10. **Run result:** 8/8 PASS via isolated `kk:code-reviewer` sub-agent (see `.sessions/task10-eval-runs.txt`).
- [x] **test**: synthetic Kustomize-only diff (`kustomization.yaml` + a patch) — `kustomize-checklist.md` loads; `helm-checklist.md` does not. **Eval:** [`evals/k8s-kustomize-only/eval.json`](../../../klaude-plugin/skills/review-code/evals/k8s-kustomize-only/eval.json). Assertion `2.1` reworded to distinguish filename-signal vs content-signal activation per file; assertion `2.7` added for content-level finding coverage. **Run result:** 7/7 PASS.
- [x] **test**: synthetic Helm-only diff (`Chart.yaml` + `templates/`) — `helm-checklist.md` loads. **Eval:** [`evals/k8s-helm-chart/eval.json`](../../../klaude-plugin/skills/review-code/evals/k8s-helm-chart/eval.json). Content-finding assertion `3.9` added during Task 10. **Run result:** 9/9 PASS.
- [x] **test**: regression — Go-only diff does NOT activate `k8s`. **Eval:** [`evals/go-regression/eval.json`](../../../klaude-plugin/skills/review-code/evals/go-regression/eval.json). **Run result:** 5/5 PASS.
- [x] **test (A4 regression)**: monorepo with a root `Chart.yaml` and an unrelated `docs/templates/` subtree — `docs/templates/reference.yaml` must NOT be flagged as a Helm template. **Eval:** [`evals/k8s-monorepo-false-positive/eval.json`](../../../klaude-plugin/skills/review-code/evals/k8s-monorepo-false-positive/eval.json). Authored during Task 10 in response to design.md §A4 step 4. DETECTION.md and §Kubernetes detection rule tightened to require the `templates/` directory to sit directly next to a `Chart.yaml`. **Run result:** 6/6 PASS — sub-agent explicitly excluded `docs/templates/reference.yaml` from the k8s `files:` list.
- [x] **document**: confirm `profiles/k8s/` documentation coherence; cross-references to `design.md` accurate. Verified; A4 amendment cross-reference kept in `DETECTION.md:24`-adjacent prose — the link target now points at the "Resolved" note in design.md §Amendments A4.
- [x] **review-code**: run `/kk:review-code` on the P1 diff; address findings. Isolated code-reviewer produced no P0/P1. P2 (A4 monorepo gap), P2 (Chart.lock absence → now covered by assertion `3.9`), P2 (routing-only evals → now covered by `1.8`/`2.7`/`3.9`), P3 (`3607s` non-standard value) all addressed. Findings archived at `.sessions/task10-review-code.txt`.
- [x] **review-spec**: run `/kk:review-spec kubernetes-support` with scope `all`; confirm P1 portion satisfied. Isolated spec-reviewer produced no P0/P1. P2 blocker (A4 monorepo eval) resolved; P2 wording (assertion 2.1) reworded; P3 (`EXPECTED_PROFILES` wording) resolved by aligning design/implementation/tasks prose with the alphabetical-set convention already on disk. Ambiguity (cross-ref to `design.md#...` breaks after feature-close) noted; deferred to Task 19 feature-close housekeeping. Findings archived at `.sessions/task10-review-spec.txt`.
- [x] **Issue #64 closure check**: confirm `review-code` now handles Kubernetes artifacts as designed; the narrow issue-#64 text is satisfied. `profiles/k8s/` exists with seven review-code checklists + index; shared profile-detection from P0 routes to it; five evals cover nominal + regression + false-positive scenarios. Issue #64 closeable at P1 merge.

---

> **Phase 2 — `design` / `implement` / `test` / `document` K8s-awareness.** Each skill gets a profile-aware clause; the corresponding `profiles/k8s/<phase>/index.md` and content files are authored. The four tasks below can proceed in parallel; the P2 verification task runs after all four land.

**Test-file coordination across Tasks 11–14.** Each P2 task authors a new `profiles/k8s/<phase>/index.md`. The structure test's **presence-conditional assertion** (added in Task 5) automatically covers any new phase subdirectory without requiring edits to `test/test-plugin-structure.sh` — the test says "if `<phase>/` exists, assert `<phase>/index.md` exists", which fires naturally as new phase dirs appear. **Tasks 11–14 do NOT need to edit `test/test-plugin-structure.sh`.** This makes the four tasks genuinely parallelizable with no shared-file contention.

## Task 11 — Extend `design` with K8s-aware idea refinement

- **Phase:** P2
- **Status:** done
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.1](implementation.md#step-21--extend-design), [design.md §design — P2 Kubernetes-aware idea refinement](design.md#design--p2-kubernetes-aware-idea-refinement)

Subtasks:

- [x] Update `klaude-plugin/skills/design/idea-process.md` — Step 3 (refine the idea) gains the user-declared / keyword-inference detection model per [design.md §`design` — P2](design.md#design--p2-kubernetes-aware-idea-refinement): check idea prose against the **high-precision auto-trigger set** (`Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`) and ask the user to confirm on any match. If no auto-trigger matches but the idea is **ambiguous** (names infrastructure/deployment/runtime/platform concerns without naming a specific technology, OR includes overloaded tokens like `cluster`/`namespace`/`pod`), ask explicitly. Step 5 (document the design) gains the "for each active profile, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/design/index.md` and apply its section requirements" clause.
- [x] Update `klaude-plugin/skills/design/existing-task-process.md` — equivalent clause in the continue-WIP flow; here the feature directory's files ARE available, so detection falls back to the file-based input model (with idea-prose fallback when the feature directory has no profile-bearing artifacts yet).
- [x] Optional prose touch-up in `klaude-plugin/skills/design/SKILL.md` body (no description change). Added a short Conventions subsection pointer to `shared-profile-detection.md` and the per-profile `design/` slot.
- [x] Create `klaude-plugin/profiles/k8s/design/index.md` — always-load entries: `questions.md`, `sections.md`.
- [x] Create `klaude-plugin/profiles/k8s/design/questions.md` — question bank (cluster topology, GitOps choice, secrets strategy, multi-tenancy, observability stack, rollback posture).
- [x] Create `klaude-plugin/profiles/k8s/design/sections.md` — required design sections for K8s-shaped features (cluster-compat matrix, resource budget, reliability posture, security posture, failure-mode narrative).
- [x] Verify: `bash test/test-plugin-structure.sh` exits 0 — 31 test cases, 121 assertions (up from 109 as the presence-conditional layer picked up `profiles/k8s/design/`). Forward + reverse invariants green for the new phase dir. Synthetic live-session scenarios (K8s keyword auto-activation, ambiguous-idea explicit prompt, pure-Go regression) are deferred to the P2 cumulative verification in Task 15 per the cross-task coordination note above.

## Task 12 — Extend `implement` with K8s per-task gotchas

- **Phase:** P2
- **Status:** done
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.2](implementation.md#step-22--extend-implement), [design.md §implement — P2 per-task K8s gotchas](design.md#implement--p2-per-task-k8s-gotchas)

Subtasks:

- [x] Update `klaude-plugin/skills/implement/SKILL.md` Step 2: add the profile-aware clause and the `dependency-handling` reference for K8s API versions / CRDs / Helm / container images. (Also added a Conventions-subsection pointer to `shared-profile-detection.md` + the per-profile `implement/` slot, mirroring Task 11's pattern in `design/SKILL.md`. The widened dep-handling trigger was phrased as a forward-compatible bullet — its formal description-frontmatter rewrite lands in Task 17 (P3).)
- [x] Create `klaude-plugin/profiles/k8s/implement/index.md` — always-load entry: `gotchas.md`.
- [x] Create `klaude-plugin/profiles/k8s/implement/gotchas.md` — API-version pinning, probe-correctness distinctions, image-tag immutability, resource-limits discipline, namespace/label hygiene, CRD-before-CR ordering. (Scope extended slightly over plan wording: also covers admission-webhook/operator timing, Helm-specific gotchas, and Kustomize-specific gotchas — all authoring-time pitfalls that would otherwise surface post-write in `review-code` checklists. Angle is deliberately pre-write-avoidance, not post-write-review, to stay distinct from `review-code/` content.)
- [x] Verify: structure test passes (presence-conditional covers `profiles/k8s/implement/index.md`). `bash test/test-plugin-structure.sh` → 31 cases, 124 assertions, all pass (up from 121 after Task 11; the new `profiles/k8s/implement/` phase dir adds 3 assertions: presence, forward-index, reverse-index). Synthetic K8s-task / Go-task runtime scenarios deferred to Task 15 P2 verification per the cross-task coordination note at the top of this phase.
- [x] **Isolated code-review checkpoint (2-track × 2 reviewers = 4 parallel agents).** Track 1 (skill implementation, baseline: `review-code` multilang/profile support): corroborated P1 finding — SKILL.md Step 2 bullet order violated ADR 0004 (action bullet preceded pre-write instruction loads). Fixed by reordering: pre-write gotchas + dependency-handling now bullets 2–3; "Follow the plan exactly" is bullet 4; added explicit mandatory-order directive. Also fixed stale `profiles/k8s/overview.md` "Populated phases" inventory (now lists `review-code/`, `design/`, `implement/`). Track 2 (K8s correctness): corroborated P0 — BestEffort QoS claim factually wrong; rewritten to cover both-missing vs limits-without-requests (Burstable) distinction. Additional K8s corrections applied: Guaranteed QoS scope narrowed to CPU+memory with ephemeral-container note; `kubectl apply` CRD-race causal explanation rewritten (server-side async, not client-side ordering); Argo CD SyncWave vs PreSync conflation fixed; Kustomize `labels[].includeSelectors` now notes ≥4.1 requirement; `extensions/v1beta1` removal stagger (1.16 batch + Ingress 1.22) surfaced; `startupProbe` suspension of liveness/readiness made explicit; cert-manager / external-secrets "looks healthy" framing rewritten to GitOps-sync-masks-unreconciled; Helm `<no value>` behavior corrected (empty string default, nil-pointer panic on nested access); Helm `kubeVersion` `-0` suffix documented; index.md summary updated to include Helm + Kustomize. Total: 14 findings, all applied. Re-ran structure test post-fixes — still green. Corroborated P0/P1 findings indexed as `kk:review-findings`.

## Task 13 — Extend `test` with K8s validator guidance

- **Phase:** P2
- **Status:** done
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.3](implementation.md#step-23--extend-test), [design.md §test — P2 validator guidance with policy-hook auto-detection](design.md#test--p2-validator-guidance-with-policy-hook-auto-detection)

Subtasks:

- [x] Update `klaude-plugin/skills/test/SKILL.md` guidelines: add the profile-aware clause. (Also added a Conventions-subsection pointer to `shared-profile-detection.md` + the per-profile `test/` slot, mirroring Task 11's and Task 12's pattern. The profile-aware clause is guideline #4, with explicit "load before running" wording per ADR 0004 since executing a validator is action on subject matter.)
- [x] Create `klaude-plugin/profiles/k8s/test/index.md` — always-load entries: `validators.md`, `policy-hook.md`, `presence-check-protocol.md`. No conditional entries unless a natural split emerges during authoring. (No conditional split emerged — the policy hook is a gate within `policy-hook.md`, not a separate checklist.)
- [x] Create `klaude-plugin/profiles/k8s/test/presence-check-protocol.md` — before running any validator, check that its binary is on `PATH`. If missing, surface per-tool install hint; either fall back to descriptive guidance or mark the check as skipped in the report. Missing a floor binary does NOT block the test run. Apply to floor, menu, and policy tools alike.
- [x] Create `klaude-plugin/profiles/k8s/test/validators.md` — **floor** (mandated when binary present): `kubeconform` on all matched YAML, `helm lint` on each Helm chart dir, `kustomize build` on each Kustomize dir. Include per-tool install hints. **Menu** (suggested, user opts in): `kube-score`, `kube-linter`, `polaris`, `trivy config`, `checkov`, `kics`. **Cluster-dependent optional** (requires live cluster + `kubectl`): `kubectl --dry-run=server`, `popeye`.
- [x] Create `klaude-plugin/profiles/k8s/test/policy-hook.md` — auto-detection rules (each gated by BOTH the project marker AND the binary being on PATH): `.conftest/` or `policies/*.rego` AND `conftest` on PATH → `conftest test`; `kyverno-policies/` or Kyverno resources AND `kyverno` on PATH → `kyverno test`; `.gator/` or Gatekeeper resources AND `gator` on PATH → `gator test`; no markers → skip silently.
- [x] Verify: structure test passes (presence-conditional covers `profiles/k8s/test/index.md`). `bash test/test-plugin-structure.sh` → 31 cases, 127 assertions, all pass (up from 124 after Task 12; the new `profiles/k8s/test/` phase dir adds 3 assertions: presence, forward-index, reverse-index). Synthetic K8s test-plan scenarios (floor prescribed, menu cataloged, policy hook triggered by `.conftest/`, missing floor binary surfaces install hint without crashing) deferred to Task 15 P2 verification per the cross-task coordination note at the top of this phase.
- [x] **Isolated code-review checkpoint (2-lens × 2-reviewer = 4 parallel agents).** Lens A (skill-implementation correctness, baselines: `review-code`, `design`, `implement` skills already profile-aware + ADR 0004): corroborated P1 — test/SKILL.md lacked a Workflow section with the ADR 0004 mandatory-order directive, and guideline #3 ("run existing tests") preceded guideline #4 (load profile content), recreating the subject-matter-before-instructions shortcut ADR 0004 exists to prevent. Fixed by adding `## Workflow` section with explicit mandatory-order directive; renumbered guideline #4 to reference Step 2 of the workflow. Corroborated P2: Conventions-pointer forward-reference added ("See Step 2 of the Workflow"); `profiles/k8s/test/index.md` intro reframed from procedural "read it first" to declarative "this trio prevents shell errors" framing. Corroborated P3: duplicate install-hint list removed from `presence-check-protocol.md`, which now delegates to per-tool entries in `validators.md` / `policy-hook.md`. Lens B (Kubernetes domain correctness): corroborated P0 — `kubeconform -kubernetes-version` failure-direction wording was inverted (default-to-latest risks false passes for newer fields, not false rejections of removed fields); rewritten. Corroborated P1s — `helm lint --strict` mischaracterized (`--strict` promotes warnings to errors; schema validation against `values.schema.json` runs unconditionally), rewritten; Conftest singular/plural policy-dir contradiction resolved by making the marker list explicit (`policy/` singular is default; `policies/` plural requires explicit `-p policies/`) and always injecting `-p <detected-dir>`. Corroborated P2s — `kubectl apply --dry-run=server` RBAC caveat added; security-scanner overreach softened to "pair trivy with one IaC scanner" pattern; `gator test` vs `gator verify` sharpened (prefer `verify` for CI; `test` needs BOTH `-f <constraints>` AND `-f <manifests>`). Corroborated P3s — `.conftest/` flagged as non-standard project-local heuristic; `kube-linter` install now prefers canonical `github.com/stackrox/kube-linter` module path; datreeio CRDs-catalog supply-chain pinning caveat added; `yamllint` + `kubectl validate` added to menu as offline pre-flights. Single-reviewer findings (kubeconform `{{.ResourceAPIVersion}}` template variable, polaris `--audit-path` flag, Kustomization no-extension detection, Kyverno `kind: Policy` ambiguity, kubectl-plugin subcommand edge case, kubectl-kustomize-lag claim, kubeconform version-format example) carried forward to post-review note — re-verify before further edits. Structure test still green (31 cases, 127 assertions). Corroborated P0/P1 findings indexed as `kk:review-findings` for future recurrence detection.

## Task 14 — Extend `document` with K8s doc rubric

- **Phase:** P2
- **Status:** done
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 2.4](implementation.md#step-24--extend-document), [design.md §document — P2 rubric for K8s artifacts](design.md#document--p2-rubric-for-k8s-artifacts)

Subtasks:

- [x] Update `klaude-plugin/skills/document/SKILL.md` guidelines: add the profile-aware clause. (Also added a Conventions-subsection pointer to `shared-profile-detection.md` + the per-profile `document/` slot, and a `## Workflow` section with the ADR 0004 mandatory-order directive — mirroring the Task 12/13 pattern. Writing documentation is action on subject matter; the mandatory-order directive ensures profile content is loaded before docs are written. Guideline #3 is the profile-aware clause with explicit "loaded in Step 2 of the Workflow" back-reference.)
- [x] Create `klaude-plugin/profiles/k8s/document/index.md` — always-load entry: `rubric.md`.
- [x] Create `klaude-plugin/profiles/k8s/document/rubric.md` — RBAC decision rationale, rollback runbook, resource-baseline documentation, cluster-compat matrix, NetworkPolicy/egress posture. (Each section includes required subsections; "Applying the rubric" closing section mandates explicit `N/A — <reason>` for inapplicable topics rather than silent omission. Also updated `profiles/k8s/overview.md` Populated-phases list to include `document/` and removed it from the deferred-phases note.)
- [x] Verify: structure test passes (presence-conditional covers `profiles/k8s/document/index.md`). `bash test/test-plugin-structure.sh` → 31 cases, 130 assertions, all pass (up from 127 after Task 13; the new `profiles/k8s/document/` phase dir adds 3 assertions: presence, forward-index, reverse-index). Synthetic K8s-documentation / Go-documentation runtime scenarios deferred to Task 15 P2 verification per the cross-task coordination note at the top of this phase.
- [x] **Isolated code-review checkpoint (2-track × 2-reviewer = 4 parallel agents).** Track A (skill-implementation correctness, baselines: existing profile-aware skills): corroborated P1 — ADR 0004 directive gated only `write or edit documentation files`, leaving feature-tree reading ungated. Fix applied: directive widened to `Do not read feature-tree content, write, or edit documentation files…`; Workflow restructured to explicit 5-step flow (minimal-scope listing → detect → load profile content → read feature tree → apply guidelines) so content-level reads appear exactly once, after instruction load. Corroborated P2 — rubric.md `Applying the rubric` section duplicated SKILL.md guideline #3 cases 1–2 with small additive delta (inherited-source case). Consolidated: SKILL.md guideline #3 now carries all three cases (write / N/A / inherit); rubric.md removed "Applying the rubric" section and refers to the guideline. Corroborated LOW — Capy-search moved to bottom of Guidelines for symmetry with `test`/`implement`. Track B (Kubernetes correctness, 4 HIGH + 7 MEDIUM + 3 LOW corroborated): §4 feature-gate example replaced (`ServerSideApply` → `SidecarContainers`/`InPlacePodVerticalScaling`/`DynamicResourceAllocation`) with admission-plugin ordering separated to a new "Admission-configuration dependencies" subsection; §4 version range example updated (1.28–1.31 → 1.31–1.33); §1 `impersonate` expanded to name all five resources (`users`, `groups`, `userextras/<key>`, `uids`, `serviceaccounts`); §1 gained Pod Security Standards posture subsection (aligns with `security-checklist.md`); §1 escalation list gained `create serviceaccounts/token`, `update */finalizers`, `approve certificatesigningrequests`, `use podsecuritypolicies/scc`, and differentiated `secrets` verb commentary; §1 `*/exec|portforward|proxy` broadened from `create` to "any verb"; §2 rollback irreversible-step list gained StatefulSet replica-shrink PVC orphaning, in-flight Job side effects, `--cascade=orphan` orphaning, secret-rotation consumption, DB-migration-via-Job; §2 rollback Steps subsection gained Argo CD `argocd app rollback` + Flux `flux suspend` + `kubectl rollout undo` + raw-kubectl guidance; §3 headroom split into memory (non-compressible, 1.2–1.5×) vs CPU (compressible, three-pattern enumeration); §3 QoS class framing tightened (init containers explicit; both dimensions must be named); §3 OOM behavior gained exit-137/SIGKILL/no-preStop/OOMKilled-reason concrete signals; §4 gained cluster-runtime dependencies subsection; §5 default-deny shape specified (`podSelector: {}` + `policyTypes: [Ingress, Egress]` + no rule arrays); §5 DNS allowance specified with full selector shape; §5 cloud metadata endpoint (169.254.169.254) added; §5 CNI enforcement model subsection added (Cilium/Calico CRD extensions); §5 mesh-vs-NetworkPolicy reframed as defense-in-depth L4+L7. All 14 corroborated findings + 2 single-reviewer findings applied. Structure test: 31 cases, 130 assertions, green. Corroborated P1 findings indexed as `kk:review-findings` for recurrence detection. Note: the Track-A ADR 0004 gate breadth pattern likely also affects `test/SKILL.md` (Task 13 missed the same thing); tracking as part of amendment A2 in design.md — not modified in this task per scope.

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
- [ ] Apply the **threshold rule** from [design.md §`review-spec` — P3](design.md#review-spec--p3-k8s-awareness-polish): create `klaude-plugin/profiles/k8s/review-spec/index.md` and supporting files when the drafted K8s-specific guidance comprises **≥2 distinct checklists** OR includes **any conditional trigger** (diff-property-dependent loading). Otherwise inline a single paragraph into the three `review-spec` files and skip the `profiles/k8s/review-spec/` subdirectory. If the directory is created, the presence-conditional assertion in `test/test-plugin-structure.sh` automatically covers its `index.md` (no test edit needed).
- [ ] Verify: synthetic scenario — a K8s feature whose design specifies a PDB but whose implementation omits the PDB — produces a `missing_impl` finding.

## Task 17 — Widen `dependency-handling` description and body for IaC

- **Phase:** P3
- **Status:** pending
- **Depends on:** Task 7
- **Links:** [implementation.md §Step 3.2](implementation.md#step-32--widen-dependency-handling), [design.md §dependency-handling integration](design.md#dependency-handling-integration), [design.md §Skill description budget](design.md#skill-description-budget-applied-in-this-feature)

Subtasks:

- [ ] Rewrite the description frontmatter of `klaude-plugin/skills/dependency-handling/SKILL.md` to the 223-character form specified in design.md (covers library/SDK/framework/API + IaC API version + CRD + container image; leads with TRIGGER keyword; preserves "Use BEFORE writing the call").
- [ ] Update the body: short paragraph noting that the cascade rule (capy-first, context7-second, web-last) applies uniformly to all listed dep categories; per-domain lookup targets live in each profile's `overview.md`.
- [ ] Cross-check `klaude-plugin/profiles/k8s/overview.md`'s "Looking up Kubernetes dependencies" section (authored in Task 8) is consistent with the new body paragraph. The body paragraph should reference the overview section by heading anchor; the anchor must resolve.
- [ ] Add a description-length assertion to `test/test-plugin-structure.sh`: parse the `description:` field of `klaude-plugin/skills/dependency-handling/SKILL.md`'s YAML frontmatter, measure its length, assert ≤1,536 characters (the documented per-entry cap).
- [ ] Verify: description-length assertion in the structure test passes. The description contains "IaC API version", "Helm", "container image" (or equivalent covering terms). "Use BEFORE writing the call" is present in the description and not truncated. The body paragraph's anchor reference to `profiles/k8s/overview.md` resolves to an existing heading.

## Task 18 — Phase 3 verification

- **Phase:** P3
- **Status:** pending
- **Depends on:** Task 16, Task 17
- **Links:** [implementation.md §Step 3.V](implementation.md#step-3v--p3-verification-task)

Subtasks:

- [ ] **test**: `bash test/test-plugin-structure.sh` exits 0 — all presence-conditional per-phase assertions green, both directions of the index invariant pass, symlink assertions pass, description-length assertion passes.
- [ ] **test**: end-to-end synthetic smoke — design a hypothetical K8s feature, implement a slice of it, run review-code, run test, run document, run review-spec; each skill applies profile-aware behavior where applicable.
- [ ] **Deferred-decision branch check (Task 16).** If `profiles/k8s/review-spec/` was created, confirm the structure test covers its `index.md` via the presence-conditional assertion. If the K8s review-spec guidance was inlined into the three `review-spec` skill files instead, confirm the IaC clause is actually present in `SKILL.md`, `review-process.md`, and `review-isolated.md` — and that no orphan `profiles/k8s/review-spec/` subdirectory exists. Either branch must yield a green structure test.
- [ ] **Cross-reference check (overview.md ↔ dependency-handling).** For each profile that declares a "Looking up Kubernetes dependencies" (or equivalent) section in its `overview.md`, verify: (a) the heading exists with the exact wording the `dependency-handling/SKILL.md` body paragraph cites, and (b) the anchor (slug) resolves.
- [ ] **document**: review `CLAUDE.md` for accuracy with all phases landed. CLAUDE.md is outside the plugin tree and therefore not subject to `${CLAUDE_PLUGIN_ROOT}` substitution — no escape-form constraint applies there. Spot-check instead that any prose UNDER `klaude-plugin/` that references the variable *by name* (explaining it, not using it as a path) uses the bare form `$CLAUDE_PLUGIN_ROOT` or `&#36;{CLAUDE_PLUGIN_ROOT}`, per [ADR 0003 §Verification](../../adr/0003-plugin-root-referenced-content.md).
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
- [ ] Update this `tasks.md`'s header status to `done`; confirm every task above is `done`. Task 20 is a post-close handoff pointer and is EXEMPT from this gate — it intentionally remains `pending` in the frozen feature dir until a follow-up cycle picks it up.
- [ ] Verify: `docs/done/kubernetes-support/` exists; `docs/wip/kubernetes-support/` does not; `git log --stat docs/done/kubernetes-support/` shows history preserved.

---

## Task 20 — Design amendments follow-up (post-feature handoff)

- **Phase:** post-feature
- **Status:** pending
- **Depends on:** Task 19
- **Links:** [design.md §Amendments](design.md#amendments-post-review-deferrals)

Handoff pointer — NOT a gate on Task 19 closure. Remains `pending` in the frozen feature dir (`docs/done/kubernetes-support/`) until a follow-up session picks up the amendment backlog. A future contributor starts here when the prerequisites described in each amendment's "When to apply" clause are met.

Subtasks:

- [ ] Read `design.md §Amendments` (post-close: `docs/done/kubernetes-support/design.md`) and enumerate every amendment entry (A1, A2, …).
- [ ] Confirm no new review findings have accumulated since feature close that warrant inclusion in the same follow-up cycle.
- [ ] Invoke `/kk:design` with the amendment list as the scope. The session decides feature-directory placement per prevailing `design` skill conventions (new `docs/wip/kubernetes-support-v2/` is the default; a versioned-in-place approach is acceptable if the skill convention permits).
- [ ] Produce `design-v2.md`, `implementation-v2.md`, `tasks-v2.md` as a versioned follow-up bundle. The v2 docs refine or extend the current design; they do NOT replace `docs/done/kubernetes-support/design.md`, which remains frozen history.
- [ ] For each amendment: either (a) include a concrete implementation plan in the v2 docs, or (b) record the amendment as declined with rationale in v2 `design.md`.
- [ ] Cross-link: each v2 doc cites the originating amendment entry by ID (`A1`, `A2`, …). The original §Amendments section is NOT edited (frozen history); amendment lifecycle (planned / in-progress / done / declined) is tracked in the v2 tasks bundle.
- [ ] Verify: every amendment in the source list appears in the v2 docs with an explicit disposition; the v2 bundle builds a complete picture without requiring the reader to cross-reference the frozen source for any load-bearing detail.
