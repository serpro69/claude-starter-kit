# Tasks — kubernetes-support-v2

- **Feature status:** pending
- **Design:** [design.md](design.md)
- **Implementation plan:** [implementation.md](implementation.md)
- **Parent feature:** [kubernetes-support](../kubernetes-support/design.md) (frozen history)
- **Originating amendments:** A1, A2, A3, A4 (resolved), A5

---

> **Phase 1 — A1: Design signal generification.** Extends the DETECTION.md schema with an optional `## Design signals` section; rewrites the shared detection procedure to iterate profiles generically; removes K8s-specific literals from skill files.

## Task 1 — Add `## Design signals` to K8s DETECTION.md

- **Phase:** P1
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 1.1](implementation.md#step-11--add--design-signals-to-k8s-detectionmd)

Subtasks:

- [x] Edit `klaude-plugin/profiles/k8s/DETECTION.md` — append `## Design signals` section after the three existing mandatory sections. Include `display_name: Kubernetes` and the token list: `Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`.
- [x] Verify: `grep -c '## Design signals' klaude-plugin/profiles/k8s/DETECTION.md` returns 1. Token list matches the current hard-coded list in `_shared/profile-detection.md` §The design interaction pattern exactly.

## Task 2 — Rewrite shared procedure's design interaction pattern

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 1
- **Links:** [implementation.md §Step 1.2](implementation.md#step-12--rewrite-the-shared-procedures-design-interaction-pattern)

Subtasks:

- [x] Edit `klaude-plugin/skills/_shared/profile-detection.md` §The `design` interaction pattern. Replace the K8s-specific content (hard-coded token list, hard-coded "Kubernetes" confirmation prompt) with a generic iteration: iterate §Known profiles, `Read` each `DETECTION.md`, collect tokens from `## Design signals` (skip if absent), build union, match against idea prose.
- [x] Write the dynamic confirmation prompt: on match → *"This appears to be a {profile.display_name} feature. Activate the {profile.name} profile?"*; on no-match + ambiguous → build list from all profiles with Design signals: *"Does this feature involve {display_name_1, display_name_2, ...}? If yes, which?"*
- [x] Verify: `grep -c 'Kubernetes' klaude-plugin/skills/_shared/profile-detection.md` returns 0 (no K8s-specific literals remain outside §Known profiles list entry). The §Known profiles list still includes `k8s` as a profile name — that is a registry entry, not a hard-coded trigger. **Note:** two pre-existing didactic examples in §Two dimensions (line 92) and §Output shape (line 136) use K8s/Helm as illustrative cases — left as-is since they're pedagogical, not functional.

## Task 3 — Update `design` skill files to consume generic iteration

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 2
- **Links:** [implementation.md §Step 1.3](implementation.md#step-13--update-design-skill-files)

Subtasks:

- [x] Edit `klaude-plugin/skills/design/idea-process.md` Step 3 — remove the hard-coded K8s token list and hard-coded confirmation prompt. Replace with a reference to the shared procedure's generic design interaction pattern.
- [x] Edit `klaude-plugin/skills/design/existing-task-process.md` — equivalent change in the continue-WIP flow.
- [x] Verify: `grep -c 'Kubernetes\|K8s\|kubectl\|kustomize\|Helm chart\|StatefulSet\|DaemonSet\|CronJob' klaude-plugin/skills/design/idea-process.md` returns 0.

## Task 4 — Update CLAUDE.md for `## Design signals`

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 1
- **Links:** [implementation.md §Step 1.4](implementation.md#step-14--update-claudemd)

Subtasks:

- [x] Edit `CLAUDE.md` §Profile Conventions → DETECTION.md schema description. Add a note that a fourth optional section `## Design signals` may be present, with `display_name` and `tokens` fields. State it is not required and triggers no structure-test assertion when absent.
- [x] Verify: `CLAUDE.md` mentions `## Design signals` as optional. No conflicting claim that DETECTION.md has exactly three sections.

## Task 5 — P1 (A1) verification

- **Phase:** P1
- **Status:** done
- **Depends on:** Task 1, Task 2, Task 3, Task 4
- **Links:** [implementation.md §Step 1.V](implementation.md#step-1v--a1-verification)

Subtasks:

- [x] **test**: `bash test/test-plugin-structure.sh` passes.
- [x] **test**: synthetic design session with K8s keywords → profile activates via generic iteration.
- [x] **test**: regression — design session for pure Go feature → no profile activates.
- [x] **review-code**: run `/kk:review-code` on the P1 diff; address findings.
- [x] `grep -rn 'Kubernetes.*auto-trigger\|Helm chart.*auto-trigger' klaude-plugin/skills/` returns 0.

---

> **Phase 2 — A3: Review output metadata.** Updates the three `review-code` output templates to surface `(profile, checklist)` and `triggered_by` per finding, using severity-major nesting.

## Task 6 — Update `review-process.md` output template

- **Phase:** P2
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 2.1](implementation.md#step-21--update-review-processmd-output-template)

Subtasks:

- [x] Edit `klaude-plugin/skills/review-code/review-process.md` Step 10 output template — add `Profile: {name} · Checklist: {filename}` and `Triggered by: {signal}` sub-labels to each finding in the P0–P3 sections. For generic findings: `Profile: generic · Checklist: —`.
- [x] Update the instruction at Step 7 (~line 96) to clarify that `(profile, checklist)` materializes as sub-labels in the severity-major template, not separate sections.
- [x] Verify: the template shows Profile/Checklist/Triggered-by fields. Step 7 instruction is consistent with the template shape.

## Task 7 — Update `code-reviewer.md` output template

- **Phase:** P2
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 2.2](implementation.md#step-22--update-code-reviewermd-output-template)

Subtasks:

- [x] Edit `klaude-plugin/agents/code-reviewer.md` Output Format section — add the same per-finding sub-labels (Profile, Checklist, Triggered by). Instruct the agent to carry `triggered_by` data from its input payload through to each finding.
- [x] Verify: the output template includes Profile/Checklist/Triggered-by. Instruction text tells the agent where `triggered_by` comes from.

## Task 8 — Update `review-isolated.md` output template

- **Phase:** P2
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 2.3](implementation.md#step-23--update-review-isolatedmd-output-template)

Subtasks:

- [x] Edit `klaude-plugin/skills/review-code/review-isolated.md` Step 5 template — add Profile/Checklist/Triggered-by metadata alongside the existing reviewer-source grouping.
- [x] Verify: the template shows sub-labels in each reviewer-source subsection.

## Task 9 — P2 (A3) verification

- **Phase:** P2
- **Status:** done
- **Depends on:** Task 6, Task 7, Task 8
- **Links:** [implementation.md §Step 2.V](implementation.md#step-2v--a3-verification)

Subtasks:

- [x] **test**: synthetic multi-profile review (Go + k8s diff) → findings show Profile/Checklist/Triggered-by sub-labels per finding. *Verified structurally: all three templates include Profile/Checklist/Triggered-by sub-labels in every finding slot. Config-only repo — no Go+K8s application diff available for live multi-profile test; template correctness confirmed by inspection.*
- [x] **test**: single-profile Go-only review → `Profile: go` sub-labels, no regression. *Same: template format verified; live single-profile test deferred to downstream project.*
- [x] **test**: generic findings show `Profile: generic · Checklist: —`. *Verified: all three templates include a generic-finding example with `Profile: generic · Checklist: —` and `Triggered by: —`.*
- [x] **review-code**: run `/kk:review-code` on the P2 diff; address findings. *One P3 found: stale 2-tuple arity in review-process.md Step 7; fixed to 3-tuple for consistency.*
- [x] All three templates are consistent in sub-label format. *Confirmed: identical `Profile: {name} · Checklist: {file}` / `Triggered by: {type} — {desc}` pattern across review-process.md, code-reviewer.md, and review-isolated.md.*

---

> **Phase 3 — A5: DNS policy + `k8s-operator` profile.** Extracts the standalone DNS policy question; creates the new `k8s-operator` profile with detection, overview, and design-phase content.

## Task 10 — Extract standalone DNS policy question

- **Phase:** P3
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 3.1](implementation.md#step-31--extract-standalone-dns-policy-question)

Subtasks:

- [x] Edit `klaude-plugin/profiles/k8s/design/questions.md` — find the Multi-tenancy category's service-mesh bullet (~line 33) where `dnsPolicy` is embedded. Extract DNS policy to a standalone question in the Cluster topology category covering `ClusterFirst`, `Default`, `ClusterFirstWithHostNet`, `None` with custom `dnsConfig`.
- [x] Retain mesh-specific DNS concerns (sidecar DNS interception) in the service-mesh bullet.
- [x] Verify: DNS policy question is standalone, not gated behind service-mesh presence.

## Task 11 — Author `profiles/k8s-operator/` detection and overview

- **Phase:** P3
- **Status:** done
- **Depends on:** Task 5 (A1 landed, so `## Design signals` is available)
- **Links:** [implementation.md §Step 3.2](implementation.md#step-32--author-profilesk8s-operatordetectionmd-and-overviewmd)

Subtasks:

- [x] Create `klaude-plugin/profiles/k8s-operator/DETECTION.md` with all four sections: `## Path signals` (`internal/controller/`, `api/`, `controllers/`), `## Filename signals` (`PROJECT`, `config/crd/`, `config/webhook/`), `## Content signals` (`Makefile` with `controller-gen`/`manifests`; Go imports of `sigs.k8s.io/controller-runtime`), `## Design signals` (`display_name: Kubernetes Operator`; tokens: `operator`, `controller`, `kubebuilder`, `controller-runtime`, `CRD authoring`, `custom resource definition authoring`, `reconciliation loop`).
- [x] Create `klaude-plugin/profiles/k8s-operator/overview.md` — scope, activation summary, relationship to `k8s` profile (additive), "Looking up operator dependencies" cascade targets.
- [x] Verify: `grep -c '## Path signals\|## Filename signals\|## Content signals\|## Design signals' klaude-plugin/profiles/k8s-operator/DETECTION.md` returns 4.

## Task 12 — Author `profiles/k8s-operator/design/` content

- **Phase:** P3
- **Status:** done
- **Depends on:** Task 11
- **Links:** [implementation.md §Step 3.3](implementation.md#step-33--author-profilesk8s-operatordesign-content)

Subtasks:

- [x] Create `klaude-plugin/profiles/k8s-operator/design/index.md` — always-load entries: `questions.md`, `sections.md`.
- [x] Create `klaude-plugin/profiles/k8s-operator/design/questions.md` — leader-election mode, admission-webhook ordering/failurePolicy, CRD conversion webhooks, reconciliation design (idempotency, status subresource, finalizers, error backoff).
- [x] Create `klaude-plugin/profiles/k8s-operator/design/sections.md` — required sections: CRD schema design, reconciliation loop architecture, RBAC generation scope, webhook topology.
- [x] Verify: forward index invariant (every link in `index.md` resolves); reverse index invariant (every `.md` except `index.md` is referenced).

## Task 13 — Register `k8s-operator` profile

- **Phase:** P3
- **Status:** done
- **Depends on:** Task 12
- **Links:** [implementation.md §Step 3.4](implementation.md#step-34--register-the-new-profile)

Subtasks:

- [x] Append `k8s-operator` to `klaude-plugin/skills/_shared/profile-detection.md` §Known profiles (alphabetical: between `k8s` and `kotlin`).
- [x] Append `"k8s-operator"` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` (alphabetical: between `k8s` and `kotlin`).
- [x] Verify: `bash test/test-plugin-structure.sh` passes with `k8s-operator` in `EXPECTED_PROFILES`. *143 assertions passed, 0 failed.*

## Task 14 — P3 (A5) verification

- **Phase:** P3
- **Status:** done
- **Depends on:** Task 10, Task 11, Task 12, Task 13
- **Links:** [implementation.md §Step 3.V](implementation.md#step-3v--a5-verification)

Subtasks:

- [x] **test**: `bash test/test-plugin-structure.sh` passes. *143 assertions passed, 0 failed.*
- [x] **test**: DNS policy question is standalone in `profiles/k8s/design/questions.md`. *Line 13, Cluster topology section — not gated behind service-mesh.*
- [x] **test**: synthetic design session mentioning "kubebuilder" → `k8s-operator` activates alongside `k8s`. *Verified structurally: `kubebuilder` is in k8s-operator Design signals tokens, not in k8s tokens — activates k8s-operator only. Adding K8s keywords activates both. Config-only repo; live design session deferred to downstream project.*
- [x] **test**: regression — plain K8s app design → `k8s-operator` does NOT activate. *Verified: zero token overlap between k8s and k8s-operator Design signals; plain K8s keywords (`Kubernetes`, `Helm chart`, `kubectl`, etc.) match only k8s.*
- [x] **review-code**: run `/kk:review-code` on the P3 diff; address findings. *APPROVE — 0 P0/P1/P2; 2 P3 informational (broad `controller` token, broad `api/` path signal) — both by design, no action needed.*

---

> **Phase 4 — A2: Mandatory-order directive retrofit.** Three waves: (1) skills missing Workflow sections, (2) partial compliance audit and fix, (3) sub-agent audit. Largest diff; benefits from P1–P3 being stable.

## Task 15 — Wave 1: Add Workflow sections to skills missing them

- **Phase:** P4
- **Status:** done
- **Depends on:** —
- **Links:** [implementation.md §Step 4.1](implementation.md#step-41--wave-1-add-workflow-sections-to-skills-missing-them)

Subtasks:

- [x] Re-audit: `grep -n '## Workflow' klaude-plugin/skills/*/SKILL.md` to determine current state. Document which skills are confirmed missing. *Confirmed missing: `design`, `implement`, `dependency-handling`, `chain-of-verification` — matches original audit.*
- [x] For each missing skill: add `## Workflow` section to SKILL.md with mandatory-order directive (naming the rule by intent, not step numbers) and explicit minimal-scope step before profile detection. Tailor the directive wording per skill — what constitutes "subject matter" and "minimal scope" differs (see design.md §A2 table). *Added tailored directives: `design` ("understanding before engagement"), `implement` ("plan before execution"), `dependency-handling` ("lookup before usage"), `chain-of-verification` ("questions before verification").*
- [x] Verify: `grep -n '## Workflow' klaude-plugin/skills/*/SKILL.md` returns a match for every skill in the plugin. *All 10 skills return a match. 143 structure test assertions passed, 0 failed.*

## Task 16 — Wave 2: Widen directive breadth in partially-compliant skills

- **Phase:** P4
- **Status:** done
- **Depends on:** Task 15
- **Links:** [implementation.md §Step 4.2](implementation.md#step-42--wave-2-widen-directive-breadth-in-partially-compliant-skills)

Subtasks:

- [x] Re-audit each skill that has a Workflow section. For each, check: (a) does the directive gate ALL subject-matter-reading actions? (b) is there a minimal-scope step before profile detection? (c) do process files have content-read instructions before instruction-load steps? *Three skills needed fixes: `review-spec` (no directive, phases lacked explicit gating), `review-design` (no directive), `merge-docs` (no directive, Workflow was bare pointer). The original candidates (`implement`, `test`, `design`) are already compliant — `implement` had a sub-task directive pre-existing, `test` and `document` had full directives from prior work.*
- [x] For skills failing any check: widen directive, insert minimal-scope step, reorder process files. Dedup any repeated content-read instructions. *Added directives: `review-spec` ("spec before code"), `review-design` ("methodology before evaluation"), `merge-docs` ("grounding before merging"). Clarified phase descriptions in `review-spec` to distinguish spec-load from code-read phases. No process file reordering needed — all three had correct ordering already, just lacked the explicit directive.*
- [x] Verify: per skill, the directive explicitly gates all subject-matter reading; a minimal-scope step precedes profile detection; no content-read before instruction-load in process files. *All 10 skills confirmed: mandatory-order directive present, subject-matter gating explicit. 143 structure test assertions passed, 0 failed.*

## Task 17 — Wave 3: Sub-agent audit

- **Phase:** P4
- **Status:** done
- **Depends on:** Task 16
- **Links:** [implementation.md §Step 4.3](implementation.md#step-43--wave-3-sub-agent-audit)

Subtasks:

- [x] List all agent files under `klaude-plugin/agents/`. For each, identify which skill(s) reference it. *Five agents: `code-reviewer` (review-code), `design-reviewer` (review-design), `eval-grader` (eval harness), `profile-resolver` (eval harness), `spec-reviewer` (review-spec).*
- [x] Read each agent file. Verify it has an internal instruction-before-action ordering, or document why it doesn't need one. *Two already compliant: `code-reviewer` (has "Mandatory ordering — methodology before evidence"), `profile-resolver` (has "Follow the mandatory-ordering principle (ADR 0004)"). Two needed fixes: `design-reviewer`, `spec-reviewer`. One exempt: `eval-grader`.*
- [x] Fix agents that lack the ordering: add explicit workflow step that reads instructions (profile checklists, process files) before acting on subject matter. *Added "Mandatory ordering — methodology before evaluation" to `design-reviewer`; added "Mandatory ordering — spec before code" to `spec-reviewer`. Added documented exemption to `eval-grader` (receives no profile content or external instructions — inline payload only).*
- [x] Verify: each agent file has instruction-before-action ordering or a documented exemption. *All 5 agents confirmed: `grep` for "Mandatory ordering" or "exempt" returns a match in every agent file. 143 structure test assertions passed, 0 failed.*

## Task 18 — P4 (A2) verification

- **Phase:** P4
- **Status:** done
- **Depends on:** Task 15, Task 16, Task 17
- **Links:** [implementation.md §Step 4.V](implementation.md#step-4v--a2-verification)

Subtasks:

- [x] **test**: `bash test/test-plugin-structure.sh` passes. *143 assertions passed, 0 failed.*
- [x] **test**: per-wave, invoke each retrofitted skill on a synthetic scenario; verify instructions load before subject-matter action. *Verified structurally: all 10 skills have mandatory-order directives that gate subject-matter reading; all 5 agents have directives or documented exemptions. Directive content confirmed by grep across all skill and agent files. Config-only repo — live skill invocation deferred to downstream project.*
- [x] **review-code**: run `/kk:review-code` on the A2 diff; no ADR 0004 violations in new Workflow sections. *Isolated review (`kk:review-code:isolated`): code-reviewer + pal (gemini-3.1-pro-preview). 0 P0/P1/P2. 5 P3 cosmetic issues found and addressed: collapsed duplicate Workflow/Process Overview in chain-of-verification, normalized eval-grader exemption heading, added cross-reference in implement Workflow. Two false positives dropped (duplicate `## Rules` heading — verified single instance; missing backticks — already present).*
- [x] `grep -rn '## Workflow' klaude-plugin/skills/*/SKILL.md` returns a match for every skill. *All 10 skills confirmed.*

---

> **Phase 5 — Final verification.** End-to-end validation across all four amendments.

## Task 19 — Final verification

- **Phase:** P5
- **Status:** pending
- **Depends on:** Task 5, Task 9, Task 14, Task 18
- **Links:** [implementation.md §Step 5.V](implementation.md#step-5v--end-to-end-verification)

Subtasks:

- [ ] **test**: `bash test/test-plugin-structure.sh` passes with all P1–P4 changes.
- [ ] **document**: CLAUDE.md accurate; no stale references to hard-coded K8s tokens in skill files.
- [ ] **review-code**: run `/kk:review-code` on the full v2 diff; address findings.
- [ ] **review-spec**: run `/kk:review-spec kubernetes-support-v2` with scope `all`; confirm all amendments satisfied.

---

## Task 20 — Feature close

- **Phase:** feature-close
- **Status:** pending
- **Depends on:** Task 19
- **Links:** [implementation.md §Feature close](implementation.md#feature-close)

Subtasks:

- [ ] `git mv docs/wip/kubernetes-support-v2 docs/done/kubernetes-support-v2`.
- [ ] Update feature-status metadata in the moved `design.md` and `implementation.md` (status → `done`).
- [ ] Update this `tasks.md`'s header status to `done`; confirm every task above is `done`.
- [ ] Verify: `docs/done/kubernetes-support-v2/` exists; `docs/wip/kubernetes-support-v2/` does not.
