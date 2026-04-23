# Kubernetes support v2 — design amendments follow-up

- **Feature:** kubernetes-support-v2
- **Status:** done
- **Parent feature:** [kubernetes-support](../kubernetes-support/design.md) (frozen history after Task 19)
- **Originating amendments:** [design.md §Amendments](../kubernetes-support/design.md#amendments-post-review-deferrals) — A1, A2, A3, A4 (resolved), A5
- **Implementation plan:** [implementation.md](implementation.md)
- **Task list:** [tasks.md](tasks.md)
- **ADRs:** [0004 — Skill workflow ordering](../../adr/0004-skill-workflow-ordering.md) (A2's foundation)

## Overview

This feature addresses four open amendments surfaced by reviews during the kubernetes-support implementation. Each amendment was explicitly deferred — it required changes beyond the original feature's scope. A4 was resolved in-feature (Task 10) and is recorded here as done.

The four open amendments are architecturally independent: different file sets, no merge contention. They proceed as four parallel workstreams (A1, A3, A5, A2) plus a verification phase.

## Amendment disposition

| ID | Title | Disposition | Phase |
|----|-------|-------------|-------|
| A1 | Generify the `design` auto-trigger set across profiles | **Planned** | P1 |
| A2 | Apply mandatory-order directive to all skills | **Planned** | P4 |
| A3 | Surface `(profile, checklist)` grouping in review output | **Planned** | P2 |
| A4 | Bound Helm-template ancestor search to nearest `Chart.yaml` | **Done** — resolved in kubernetes-support Task 10 | — |
| A5 | DNS policy + `k8s-operator` profile | **Planned** | P3 |

## A1 — Profile-driven design signals

**Originating amendment:** [A1](../kubernetes-support/design.md#a1--generify-the-design-auto-trigger-set-across-profiles)

### Problem

The shared detection procedure (`_shared/profile-detection.md`) hard-codes K8s auto-trigger tokens and a K8s-specific confirmation prompt in a file whose purpose is to prevent per-profile drift. `design/idea-process.md` duplicates the same literal token list. Adding a second IaC profile (Terraform, Ansible) requires editing both the shared file and the skill file — the exact duplication the shared file was designed to eliminate.

### Solution

Extend `DETECTION.md`'s mandatory three-section schema with a fourth **optional** section: `## Design signals`. Profiles that participate in the design phase declare two fields:

- `display_name:` — human-readable label for the confirmation prompt (e.g., `Kubernetes`, `Terraform`).
- `tokens:` — a list of high-precision auto-trigger strings. Matching is case-insensitive, whole-word (so `pod` in "podcast" doesn't fire).

The shared procedure's §design interaction pattern rewrites from "check against this literal K8s list" to:

1. Iterate §Known profiles. For each, `Read` its `DETECTION.md`. If `## Design signals` is absent, skip (most programming-language profiles won't have one).
2. Collect the union of all declared tokens, tagged by source profile.
3. Check idea prose against the union. On match, surface: *"This appears to be a {profile.display_name} feature. Activate the {profile.name} profile?"*
4. If no match but idea is ambiguous (names infrastructure/deployment/runtime/platform concerns without naming a specific technology), build the fallback prompt dynamically from all profiles that declare Design signals: *"Does this feature involve {Kubernetes, Terraform, ...}? If yes, which?"*

`design/idea-process.md` and `existing-task-process.md` consume this generic iteration — zero profile-specific literals in skill prose.

### Files touched

- `klaude-plugin/profiles/k8s/DETECTION.md` — add `## Design signals` with the existing K8s token set (`Kubernetes`, `K8s`, `Helm chart`, `kubectl`, `kustomize`, `manifest.yaml`, `Deployment resource`, `StatefulSet`, `DaemonSet`, `CronJob`) and `display_name: Kubernetes`.
- `klaude-plugin/skills/_shared/profile-detection.md` §The `design` interaction pattern — rewrite to iterate profiles generically. Remove all K8s-specific literals and the hard-coded confirmation prompt.
- `klaude-plugin/skills/design/idea-process.md` Step 3 — remove K8s-specific token list; consume the shared procedure's generic iteration.
- `klaude-plugin/skills/design/existing-task-process.md` — equivalent change in the continue-WIP flow.
- `CLAUDE.md` §Profile Conventions — document the optional `## Design signals` section in the `DETECTION.md` schema description; note it is not required and triggers no structure-test assertion when absent.

### Conventions

- `## Design signals` is optional. The DETECTION.md three-section schema (`Path signals`, `Filename signals`, `Content signals`) remains mandatory; `Design signals` is a fourth section that profiles MAY declare.
- The structure test does NOT assert `## Design signals` presence — it would fail for all programming-language profiles that don't participate in design-phase detection.
- Token matching is case-insensitive and whole-word to avoid false positives from substring collisions.

## A2 — Universal mandatory-order directive

**Originating amendment:** [A2](../kubernetes-support/design.md#a2--apply-the-mandatory-order-directive-to-all-skills)

### Problem

[ADR 0004](../../adr/0004-skill-workflow-ordering.md) establishes the rule: every plugin skill must fully load its instructions before acting on subject matter. The ADR binds future authoring but the retrofit is incomplete. The compliance matrix from the original amendment shows gaps in two dimensions: missing Workflow sections, and existing Workflow sections whose directive doesn't gate all subject-matter actions.

### Solution — three waves

**Wave 1 — Skills with no Workflow section.** As of the original audit: `design`, `implement`, `dependency-handling`, `chain-of-verification`. (`implement` has `## The Process` which serves a similar role but lacks the mandatory-order directive.) For each: add a `## Workflow` section to SKILL.md with the mandatory-order directive naming the rule by intent, and an explicit minimal-scope step before profile detection.

The implementer must **re-audit at execution time** — skills may have gained Workflow sections since the amendment was written (e.g., `review-spec`, `review-design`, `merge-docs` were listed as missing but may have been updated during P3). Any skill that already has a compliant Workflow section shifts to Wave 2's "audit only" track.

What constitutes "subject matter" and "minimal early scope" differs per skill. The ADR's table defines these per-skill:

| Skill | Subject matter | Minimal early scope |
|-------|---------------|-------------------|
| `design` | Idea prose content analysis, feature-tree reading | Keyword scan of first sentence |
| `implement` | Code reading/writing, test execution | `git diff --stat`, task file list |
| `dependency-handling` | API docs, library code, version lookups | Dependency name extraction |
| `chain-of-verification` | Claim verification, source reading | Claim list enumeration |
| `review-spec` | Diff content, feature-tree content | `git diff --stat` |
| `review-design` | Design doc content | File listing |
| `merge-docs` | Doc content merging | File listing |

**Wave 2 — Partial compliance.** Skills that have a Workflow section but whose directive breadth is insufficient or whose process files have content-read instructions appearing before instruction-load steps. Known from the original audit:
- `implement` — "act on the sub-task" breadth ambiguous; no explicit filename-only step.
- `test` — gates validators but not code-under-test reading; no filename-only step.
- `design` — partial; process files need breadth and scope-step audit.

For each: widen the directive to gate all subject-matter reading; insert a minimal-scope step if missing; dedup any repeated `git diff` / `Read` instructions.

**Wave 3 — Sub-agent audit.** For every agent file under `klaude-plugin/agents/` referenced by a skill: verify the agent's own workflow reads instructions before acting on subject matter. Payload delivery order (the spawning skill passing instructions in the prompt) is not sufficient — the sub-agent's internal workflow must independently order instructions before action.

### Files touched

**Wave 1** (per skill): `SKILL.md` gains `## Workflow` section.
**Wave 2** (per skill): `SKILL.md` directive widened; process/rubric files reordered.
**Wave 3**: `agents/*.md` — each agent file audited and fixed if needed.

### Conventions

- The mandatory-order directive names the rule **by intent**, not by step numbers — step numbers drift; intent does not.
- Every Workflow section's directive must explicitly list what it gates (reading, writing, executing) rather than a vague "do not act."
- After each wave, a dedup pass greps the skill directory for repeated content-read instructions and collapses them to one instance at the post-instruction position.

## A3 — Surface profile/checklist grouping in review output

**Originating amendment:** [A3](../kubernetes-support/design.md#a3--surface-profile-checklist-grouping-and-triggered_by-in-review-output)

### Problem

Three files instruct the reviewer to emit findings grouped by `(profile, checklist)`: `review-process.md:96`, `code-reviewer.md:79`, and `review-isolated.md` Step 5. But all three output templates group by severity only (P0–P3). The `triggered_by` field — computed by detection and documented as "for debugging and explaining detection to the user" — never reaches the user.

### Solution — severity-major with per-finding metadata

The existing P0/P1/P2/P3 heading structure is preserved. Each finding gains visible sub-labels:

```markdown
### P1 - High

- **[deploy/templates/deployment.yaml:42]** Missing resource limits
  - Profile: k8s · Checklist: quality-checklist.md
  - Triggered by: filename — Chart.yaml in parent directory
  - Description of issue
  - Confidence: 85% — resource limits absent on all containers
  - Suggested fix
```

Field semantics:
- `Profile` + `Checklist` identify which profile and which checklist surfaced the finding. For generic findings (SOLID, security, code quality) not sourced from a profile checklist: `Profile: generic · Checklist: —`.
- `Triggered by` shows the detection signal that activated the profile for the file under review. Sourced from the detection output's `triggered_by` field. One line per finding.

### Files touched

1. `klaude-plugin/skills/review-code/review-process.md` Step 10 output template — add Profile/Checklist/Triggered-by sub-label fields to the finding format.
2. `klaude-plugin/agents/code-reviewer.md` Output Format section — same addition.
3. `klaude-plugin/skills/review-code/review-isolated.md` Step 5 template — add profile/checklist metadata alongside the existing reviewer-source grouping.

### Conventions

- `_shared/profile-detection.md` §Output shape is unchanged — `triggered_by` is already in the detection record. This amendment gives it a user-visible channel in the review output, not a new field in the detection output.
- The severity-major nesting preserves the existing reviewer scanning habit. Profile-major was rejected to avoid breaking workflows.

## A5 — Standalone DNS policy + `k8s-operator` profile

**Originating amendment:** [A5](../kubernetes-support/design.md#a5--extend-k8s-design-question-bank-with-standalone-dns-policy-and-operator-authoring-patterns)

### 5a — Standalone DNS policy question

**Problem.** In `profiles/k8s/design/questions.md`, the `dnsPolicy` question is embedded inside the service-mesh bullet (Multi-tenancy category). Non-mesh workloads needing non-default DNS policy (`ClusterFirstWithHostNet` for `hostNetwork` pods, `None` with custom `dnsConfig`) are never prompted because the question gates on mesh presence.

**Fix.** Extract to a standalone question in the Cluster topology category: *"`dnsPolicy` — default (`ClusterFirst`) or non-default (`Default` for node DNS only, `ClusterFirstWithHostNet` for `hostNetwork: true` pods, `None` with custom `dnsConfig`)? When is the default insufficient, and what resolution pipeline does this workload expect?"* The service-mesh bullet retains its mesh-specific DNS concerns.

### 5b — `k8s-operator` profile

**Problem.** The K8s design profile is optimized for the common case (application deployment). When the designed feature is a controller or operator, critical design decisions (leader election, admission webhooks, CRD conversion) are not prompted. The profile assumes "application" without discriminating.

**Solution.** A new profile at `klaude-plugin/profiles/k8s-operator/`.

**Detection** (`DETECTION.md`):
- `## Path signals` (pre-filter): `internal/controller/`, `api/`, `controllers/`.
- `## Filename signals` (authoritative): `PROJECT` file (kubebuilder marker), `config/crd/` directory presence, `config/webhook/` directory presence.
- `## Content signals` (authoritative): `Makefile` containing `controller-gen` or `manifests` target; Go files importing `sigs.k8s.io/controller-runtime`.
- `## Design signals`: `display_name: Kubernetes Operator`; tokens: `operator`, `controller`, `kubebuilder`, `controller-runtime`, `CRD authoring`, `custom resource definition authoring`, `reconciliation loop`.

**Phases populated:**
- `design/` — `index.md` with always-load entries for `questions.md` and `sections.md`.
- `questions.md` — leader-election mode (`Lease`-based preferred), admission-webhook ordering and `failurePolicy`, CRD conversion webhooks, multi-version storage migration plan.
- `sections.md` — required design sections: CRD schema design, reconciliation loop architecture, RBAC generation scope, webhook topology.

**Not populated initially:** `review-code/`, `implement/`, `test/`, `document/`. Content follows when real demand surfaces.

**Additive with `k8s`.** An operator project typically activates both profiles: `k8s` for the manifests it generates/deploys, `k8s-operator` for the controller code it authors. Detection is additive per ADR 0001.

### Files touched (A5 combined)

- `klaude-plugin/profiles/k8s/design/questions.md` — extract DNS policy to standalone question.
- New tree: `klaude-plugin/profiles/k8s-operator/` with `DETECTION.md`, `overview.md`, `design/index.md`, `design/questions.md`, `design/sections.md`.
- `klaude-plugin/skills/_shared/profile-detection.md` §Known profiles — append `k8s-operator`.
- `test/test-plugin-structure.sh` `EXPECTED_PROFILES` — append `k8s-operator` (alphabetical position).

## Phasing

| Phase | Amendment | Depends on | Summary |
|-------|-----------|-----------|---------|
| P1 | A1 | — | Design signal generification |
| P2 | A3 | — | Review output metadata |
| P3 | A5 | A1 (recommended) | DNS question + k8s-operator profile |
| P4 | A2 | — | Mandatory-order directive retrofit (3 waves) |
| P5 | Verify | P1–P4 | Structure test, synthetic scenarios, review-code, review-spec |

**Recommended execution order:** A1 → A3 → A5 → A2 → verify. A1 first because A5's new profile benefits from shipping with `## Design signals` from day one. A2 last because it's the broadest refactor and benefits from a stable baseline. A3 is independent and slots anywhere.

Phases P1, P2, and the first two waves of P4 can technically run in parallel since they touch different file sets. The recommended serial order optimizes for review clarity over parallelism.

## Test suite updates

- **Structure test** (`test/test-plugin-structure.sh`):
  - `EXPECTED_PROFILES` gains `k8s-operator` (P3, alphabetical position between `k8s` and `kotlin`).
  - The existing presence-conditional per-phase assertion automatically covers `k8s-operator/design/index.md` — no new assertion logic needed.
  - No new assertion for `## Design signals` — the section is optional.
  - Description-length assertion (added in kubernetes-support Task 17) continues to cover `dependency-handling/SKILL.md`.

- **Eval scenarios** (P5):
  - A1: design session with K8s keywords → profile activates via generic iteration (not hard-coded tokens). Design session with no keywords + ambiguous idea → dynamic fallback prompt lists all profiles with Design signals.
  - A3: multi-profile review (Go + k8s diff) → findings show Profile/Checklist/Triggered-by sub-labels. Single-profile review → same sub-labels with no regression.
  - A5: design session mentioning "operator" or "kubebuilder" → `k8s-operator` profile activates alongside `k8s`. Design session for plain K8s app → `k8s-operator` does NOT activate.
  - A2: per-wave, invoke each retrofitted skill and verify instructions load before subject-matter action.

## References

- [kubernetes-support design.md §Amendments](../kubernetes-support/design.md#amendments-post-review-deferrals) — originating amendment text (frozen history).
- [ADR 0004 — Skill workflow ordering](../../adr/0004-skill-workflow-ordering.md) — A2's foundation.
- [ADR 0001 — Profile detection model](../../adr/0001-profile-detection-model.md) — additive detection (A5's `k8s-operator` coexists with `k8s`).
- [ADR 0002 — Profile content organization](../../adr/0002-profile-content-organization.md) — profile directory layout (A5's new profile).
- [ADR 0003 — Plugin-root referenced content](../../adr/0003-plugin-root-referenced-content.md) — `${CLAUDE_PLUGIN_ROOT}` usage in profile content.
