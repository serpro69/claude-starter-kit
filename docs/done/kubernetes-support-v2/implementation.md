# Kubernetes support v2 — implementation plan

- **Feature:** kubernetes-support-v2
- **Design:** [design.md](design.md)
- **Tasks:** [tasks.md](tasks.md)
- **Status:** done

This document is a step-by-step guide for implementing the v2 design amendments. Each step is paired with an explicit verification. Tasks in [tasks.md](tasks.md) reference the corresponding steps here.

## Conventions

- All file paths are relative to the repository root unless noted otherwise.
- Each step's **verify** clause specifies how the implementer confirms success.
- Commits are atomic per task in [tasks.md](tasks.md).
- The implementer should re-audit the current state of each skill at execution time — files may have changed since this plan was written.

## Prerequisites

Before starting:

1. The kubernetes-support feature (P0–P3) is fully landed and Task 19 (feature close) is complete.
2. `bash test/test-plugin-structure.sh` passes on the current branch.
3. The four ADRs (0001–0004) exist in `docs/adr/`.

## Phase 1 — A1: Design signal generification

### Step 1.1 — Add `## Design signals` to K8s `DETECTION.md`

Edit `klaude-plugin/profiles/k8s/DETECTION.md`. After the three existing mandatory sections, add:

```markdown
## Design signals

display_name: Kubernetes
tokens:
  - Kubernetes
  - K8s
  - Helm chart
  - kubectl
  - kustomize
  - manifest.yaml
  - Deployment resource
  - StatefulSet
  - DaemonSet
  - CronJob
```

The token list is the exact set currently hard-coded in `_shared/profile-detection.md` §The design interaction pattern. Moving it here is a relocation, not an authoring task.

**Verify.** `grep -c '## Design signals' klaude-plugin/profiles/k8s/DETECTION.md` returns 1. The token list matches the current hard-coded list in `_shared/profile-detection.md` exactly.

### Step 1.2 — Rewrite the shared procedure's design interaction pattern

Edit `klaude-plugin/skills/_shared/profile-detection.md` §The `design` interaction pattern. Replace the current K8s-specific content with a generic iteration:

1. State that the design phase has no file list — detection uses idea-prose keyword matching.
2. Describe the algorithm: iterate §Known profiles; for each, `Read` its `DETECTION.md`; if `## Design signals` is absent, skip; collect all declared tokens tagged by source profile.
3. On match: surface *"This appears to be a {profile.display_name} feature. Activate the {profile.name} profile?"*
4. On no match + ambiguous idea: build fallback dynamically from profiles that declare Design signals: *"Does this feature involve {display_name_1, display_name_2, ...}? If yes, which?"*
5. The confirmation requirement is retained — never auto-activate.

Remove all K8s-specific literals (the token list, the hard-coded prompt mentioning "Kubernetes"). The K8s tokens now live in `profiles/k8s/DETECTION.md` §Design signals.

**Authoring note.** This file is inside the plugin tree and subject to `${CLAUDE_PLUGIN_ROOT}` substitution. When referring to the variable by name, use bare `$CLAUDE_PLUGIN_ROOT`; when using it as a path, use brace form `${CLAUDE_PLUGIN_ROOT}/...`. Both conventions coexist per ADR 0003.

**Verify.** `grep -c 'Kubernetes' klaude-plugin/skills/_shared/profile-detection.md` returns 0 (no K8s-specific literals remain). The file describes a generic iteration over profiles. The fallback prompt construction is described as dynamic.

### Step 1.3 — Update `design` skill files

Edit `klaude-plugin/skills/design/idea-process.md` Step 3: remove the hard-coded K8s token list and the hard-coded confirmation prompt. Replace with a reference to the shared procedure's generic design interaction pattern. The step should say: "Run the design interaction pattern from `shared-profile-detection.md` — it iterates all profiles with `## Design signals` and handles token matching + confirmation."

Edit `klaude-plugin/skills/design/existing-task-process.md`: equivalent change in the continue-WIP flow. Here, file-based detection is available as a primary signal with idea-prose fallback when the feature directory has no profile-bearing artifacts.

**Verify.** `grep -c 'Kubernetes\|K8s\|kubectl\|kustomize\|Helm chart\|StatefulSet\|DaemonSet\|CronJob' klaude-plugin/skills/design/idea-process.md` returns 0. The file references the shared procedure instead.

### Step 1.4 — Update CLAUDE.md

Edit `CLAUDE.md` §Profile Conventions → `DETECTION.md` three-section schema description. Add a note that a fourth optional section `## Design signals` may be present. State that it is not required, not asserted by the structure test, and only relevant to profiles that participate in design-phase detection.

**Verify.** `CLAUDE.md` mentions `## Design signals` as optional. The description is consistent with design.md §A1.

### Step 1.V — A1 verification

- `bash test/test-plugin-structure.sh` passes (no new assertions needed — Design signals is optional).
- Synthetic scenario: design session with K8s keywords → profile activates via generic iteration, not hard-coded token match.
- Regression: design session for pure Go feature → no profile activates; behavior unchanged.
- `grep -rn 'Kubernetes.*auto-trigger\|Helm chart.*auto-trigger' klaude-plugin/skills/` returns 0 (no hard-coded K8s trigger references in skill files).

## Phase 2 — A3: Review output metadata

### Step 2.1 — Update `review-process.md` output template

Edit `klaude-plugin/skills/review-code/review-process.md` Step 10 output template (lines ~132–175). Add per-finding sub-labels:

```markdown
- **[file:line]** Brief title
  - Profile: {profile_name} · Checklist: {checklist_filename}
  - Triggered by: {signal_type} — {signal_description}
  - Description of issue
  - Confidence: {N}% — {reasoning}
  - Suggested fix
```

For generic findings (SOLID, security, code quality, removal) not sourced from a profile checklist, use: `Profile: generic · Checklist: —` and `Triggered by: —`.

Also update the instruction at Step 7 (line ~96) that says "Emit findings using `(profile, checklist)` as the grouping key so the report in Step 10 can organize them" — clarify that the grouping key materializes as sub-labels inside the severity-major template, not as separate sections.

**Verify.** The template shows Profile/Checklist/Triggered-by fields. The instruction at Step 7 is consistent with the template shape.

### Step 2.2 — Update `code-reviewer.md` output template

Edit `klaude-plugin/agents/code-reviewer.md` Output Format section (lines ~101–137). Add the same per-finding sub-labels. The agent receives `triggered_by` data in its input payload (from the detection output) — instruct it to carry that data through to each finding.

**Verify.** The output template includes Profile/Checklist/Triggered-by. The instruction text tells the agent where `triggered_by` comes from (detection output in the input payload).

### Step 2.3 — Update `review-isolated.md` output template

Edit `klaude-plugin/skills/review-code/review-isolated.md` Step 5 template (lines ~193–228). Add profile/checklist metadata alongside the existing reviewer-source grouping (Corroborated / Code Reviewer / External / Author-Sourced). Each finding in each reviewer-source section gains the same sub-labels.

**Verify.** The template shows Profile/Checklist/Triggered-by in each reviewer-source subsection.

### Step 2.V — A3 verification

- Synthetic scenario: multi-profile review (Go + k8s diff) → findings show Profile/Checklist/Triggered-by sub-labels. K8s findings show `Profile: k8s` with the appropriate checklist name; Go findings show `Profile: go`.
- Synthetic scenario: single-profile Go-only review → findings show `Profile: go` sub-labels with no regression in content or severity assignment.
- Generic findings (SOLID, security) show `Profile: generic · Checklist: —`.
- All three templates are consistent in their sub-label format.

## Phase 3 — A5: DNS policy + `k8s-operator` profile

### Step 3.1 — Extract standalone DNS policy question

Edit `klaude-plugin/profiles/k8s/design/questions.md`. Find the Multi-tenancy category's service-mesh bullet (line ~33) where `dnsPolicy` is embedded. Extract the DNS policy content to a standalone question in the Cluster topology category:

> `dnsPolicy` — default (`ClusterFirst`) or non-default (`Default` for node DNS only, `ClusterFirstWithHostNet` for `hostNetwork: true` pods, `None` with custom `dnsConfig`)? When is the default insufficient, and what resolution pipeline does this workload expect?

The service-mesh bullet retains its mesh-specific DNS concerns (sidecar DNS interception, mTLS resolver behavior).

**Verify.** The DNS policy question appears as a standalone bullet, not gated behind service-mesh. The service-mesh bullet no longer contains `dnsPolicy` guidance for the non-mesh case.

### Step 3.2 — Author `profiles/k8s-operator/DETECTION.md` and `overview.md`

Create `klaude-plugin/profiles/k8s-operator/DETECTION.md` using the mandatory three-section schema plus the optional `## Design signals`:

**`## Path signals`** (pre-filter): `internal/controller/`, `api/`, `controllers/`.

**`## Filename signals`** (authoritative): `PROJECT` file (kubebuilder marker), `config/crd/` directory, `config/webhook/` directory.

**`## Content signals`** (authoritative): `Makefile` containing `controller-gen` or `manifests` target (literal string match, not substring of unrelated targets); Go source files importing `sigs.k8s.io/controller-runtime`.

**`## Design signals`**: `display_name: Kubernetes Operator`; tokens: `operator`, `controller`, `kubebuilder`, `controller-runtime`, `CRD authoring`, `custom resource definition authoring`, `reconciliation loop`.

Create `klaude-plugin/profiles/k8s-operator/overview.md`: what the profile covers (Kubernetes controller/operator authoring using kubebuilder, operator-sdk, or raw controller-runtime), when it activates, relationship to the `k8s` profile (additive — operator projects also activate `k8s` for their manifests), and "Looking up operator dependencies" cascade targets (controller-runtime docs via context7, kubebuilder docs, operator-sdk docs).

**Verify.** `test -f klaude-plugin/profiles/k8s-operator/DETECTION.md`. `grep -c '## Path signals\|## Filename signals\|## Content signals\|## Design signals' DETECTION.md` returns 4. `test -f klaude-plugin/profiles/k8s-operator/overview.md`.

### Step 3.3 — Author `profiles/k8s-operator/design/` content

Create `klaude-plugin/profiles/k8s-operator/design/index.md` with always-load entries: `questions.md`, `sections.md`.

Create `klaude-plugin/profiles/k8s-operator/design/questions.md`:
- Leader-election mode: `Lease`-based preferred; deprecated modes (`configmaps`, `endpoints`); tuning parameters (`lease-duration`, `renew-deadline`, `retry-period`).
- Admission-webhook ordering: `MutatingAdmissionWebhook` before `ValidatingAdmissionWebhook`; `failurePolicy` choice (`Ignore` vs `Fail`); `sideEffects` declaration; `timeoutSeconds`.
- CRD conversion webhooks: webhook-backed vs `None` strategy; `storage: true` version migration plan.
- Reconciliation design: idempotency guarantees, status subresource usage, finalizer patterns, error backoff.

Create `klaude-plugin/profiles/k8s-operator/design/sections.md` — required design sections:
- CRD schema design (API group, versions, validation, printer columns).
- Reconciliation loop architecture (trigger sources, requeue strategy, status conditions).
- RBAC generation scope (what the controller needs access to; principle of least privilege).
- Webhook topology (which webhooks, ordering, failure mode, TLS certificate management).

**Verify.** Forward index invariant: every link in `index.md` resolves. Reverse index invariant: every `.md` in the directory (except `index.md`) is referenced.

### Step 3.4 — Register the new profile

Append `k8s-operator` to `klaude-plugin/skills/_shared/profile-detection.md` §Known profiles (alphabetical position between `k8s` and `kotlin`).

Append `"k8s-operator"` to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh` (alphabetical position between `k8s` and `kotlin`).

**Verify.** `bash test/test-plugin-structure.sh` passes with `k8s-operator` in `EXPECTED_PROFILES`. The presence-conditional assertion covers `k8s-operator/design/index.md`.

### Step 3.V — A5 verification

- `bash test/test-plugin-structure.sh` passes.
- DNS policy question is standalone in `profiles/k8s/design/questions.md`.
- Synthetic scenario: design session mentioning "kubebuilder" or "operator" → `k8s-operator` profile activates (via Design signals if A1 has landed, or via the shared procedure's existing pattern if running before A1). `k8s` also activates if K8s keywords are present.
- Regression: design session for plain K8s application → `k8s-operator` does NOT activate.

## Phase 4 — A2: Mandatory-order directive retrofit

### Step 4.1 — Wave 1: Add Workflow sections to skills missing them

**Re-audit first.** Before editing, `grep -n '## Workflow' klaude-plugin/skills/*/SKILL.md` to determine the current state. The original A2 matrix listed `design`, `implement`, `dependency-handling`, `chain-of-verification` as missing; others may have been updated since.

For each skill confirmed missing a `## Workflow` section:

1. Add `## Workflow` to SKILL.md with a mandatory-order directive at the top, naming the rule by intent: *"Do not {skill-specific subject-matter actions} until all instructions — SKILL.md, referenced process files, and resolved profile content — are fully loaded."*
2. Define the workflow steps. The first step must be a minimal-scope step (per the ADR 0004 table) that provides enough context for profile detection without reading subject-matter content.
3. Profile detection (if the skill is profile-aware) comes after the minimal-scope step.
4. Profile content loading comes after detection.
5. Subject-matter action comes after all instructions are loaded.

The directive wording is tailored per skill — what constitutes "subject matter" and "minimal scope" varies. Do not copy-paste identical wording across skills.

**Verify.** `grep -n '## Workflow' klaude-plugin/skills/*/SKILL.md` returns a match for every skill. Each Workflow section starts with a mandatory-order directive.

### Step 4.2 — Wave 2: Widen directive breadth in partially-compliant skills

For each skill identified as partially compliant (original audit: `implement`, `test`, `design`; re-audit at execution time):

1. **Audit directive breadth.** Read the mandatory-order directive. Does it gate ALL subject-matter-reading actions, or only the primary action (writing code, running tests, etc.)? If it only gates the primary action, widen it.
2. **Audit minimal-scope step.** Is there an explicit filename-only / stat-only step before profile detection? If not, insert one.
3. **Audit process files.** Read each process/rubric file the skill references. If content-level read instructions (`git diff`, `Read` of subject-matter files) appear before instruction-loading steps, reorder so content reads happen once, after instructions are loaded.
4. **Dedup pass.** `grep -n 'git diff\|Read.*content\|Read.*subject' klaude-plugin/skills/<skill>/` — if the same read instruction appears twice, collapse to one at the post-instruction position.

**Verify.** Per skill: the directive explicitly gates all subject-matter reading (not just the primary action). A minimal-scope step precedes profile detection. No content-read instruction appears before instruction loading in any process file.

### Step 4.3 — Wave 3: Sub-agent audit

For each agent file under `klaude-plugin/agents/`:

1. Identify which skill(s) reference this agent.
2. Read the agent file. Does it have an internal workflow that loads instructions before acting on subject matter?
3. If not, add one. The agent may receive instructions in its payload, but it must still read them (e.g., profile checklists) before acting.
4. Payload delivery order (the spawning skill passing data in the prompt) is not sufficient — the agent must independently enforce the ordering.

**Verify.** Each agent file under `agents/` has an explicit instruction-before-action ordering in its workflow, or is documented as not needing one (e.g., agents that receive no profile content and perform no subject-matter reading).

### Step 4.V — A2 verification

- `bash test/test-plugin-structure.sh` passes.
- Per-wave: invoke each retrofitted skill on a synthetic scenario; verify instructions load before subject-matter action. (The exact scenarios are skill-specific — the implementer chooses appropriate ones.)
- `grep -rn '## Workflow' klaude-plugin/skills/*/SKILL.md` returns a match for every skill.
- `review-code` on the A2 diff: no ADR 0004 violations in the new Workflow sections.

## Phase 5 — Final verification

### Step 5.V — End-to-end verification

1. **test**: `bash test/test-plugin-structure.sh` passes with all changes from P1–P4.
2. **document**: CLAUDE.md accurate; no stale references.
3. **review-code**: run `/kk:review-code` on the full v2 diff. Address findings.
4. **review-spec**: run `/kk:review-spec kubernetes-support-v2` with scope `all`. Confirm all amendments are satisfied.

## Feature close

Move the WIP docs to completed:

```
git mv docs/wip/kubernetes-support-v2 docs/done/kubernetes-support-v2
```

Update feature-status metadata in the moved files (status → `done`).
