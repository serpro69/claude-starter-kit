# Kubernetes — review checklists

Consumed by the `review-code` skill. When the `k8s` profile is active, every checklist in **Always load** is applied to the diff. **Conditional** checklists load only when their `Load if:` predicate matches the current diff.

Conditional triggers are stated as predicates keyed to concrete diff properties (field values, filenames, directory names) — not vague category labels. Two reviewers evaluating the same diff against the same trigger must reach the same conclusion.

## Always load

- [security-checklist.md](security-checklist.md) — RBAC least privilege, Pod Security Standards, NetworkPolicy default-deny posture, secret handling, image provenance, host-namespace avoidance, admission signals.
- [architecture-checklist.md](architecture-checklist.md) — single-concern resources, config injection via env/ConfigMap/Secret, no hardcoded cluster assumptions, explicit labels/selectors, cluster-vs-application separation.
- [quality-checklist.md](quality-checklist.md) — recommended label set, immutable image tags (digests preferred), resource requests+limits, probe correctness, declarative patterns.
- [removal-plan.md](removal-plan.md) — staged-removal template for Kubernetes resources and CRDs.

## Conditional

- [reliability-checklist.md](reliability-checklist.md) — PodDisruptionBudget, probe semantics, graceful shutdown, anti-affinity and topology spread, rollout strategies, Job/CronJob reliability.
  **Load if:** the diff contains any file with a top-level YAML document whose `kind:` is `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, or `CronJob`. Evaluate `kind:` as a YAML mapping key at zero indent inside each `---`-separated document block — not as a substring in comments or block scalars.

- [helm-checklist.md](helm-checklist.md) — `Chart.yaml` metadata, `values.yaml` schema, template correctness, dependency pinning, `helm lint` cleanliness, `NOTES.txt`.
  **Load if:** the diff contains a file named `Chart.yaml`; OR a file whose name starts with `values` (e.g., `values.yaml`, `values-prod.yaml`) in a directory that also contains `Chart.yaml`; OR a file with extension `.yaml`, `.yml`, or `.tpl` under a directory named `templates/` whose ancestor contains `Chart.yaml`.

- [kustomize-checklist.md](kustomize-checklist.md) — base/overlay separation, patch precision, generator stability, common-labels discipline, patch-type clarity.
  **Load if:** the diff contains a file named `kustomization.yaml`, `kustomization.yml`, or `Kustomization` (exact); OR a file under a directory named `bases/` or `overlays/`; OR a patch file referenced by a nearby `kustomization.*` (strategic merge patch or JSON 6902 patch target).

## Edge-case clarifications

Avoid common mis-triggers. These are explicit to keep reviewers aligned:

- A standalone `values.yaml` with **no sibling `Chart.yaml`** does NOT trigger `helm-checklist.md`. It is treated as a generic file of that name — possibly matched by another profile, possibly unmatched; Helm semantics require the chart context.
- A `deployment.yaml` **outside any `templates/` directory** and **without any `{{ ... }}` template directives**, even if its content matches the Kubernetes content signal (`apiVersion:` + `kind:`), is a plain manifest, not a Helm template. `helm-checklist.md` does not apply to it; `reliability-checklist.md` may, per its own predicate.
- A `kustomization.yaml` inside a Helm chart's `templates/` directory is unusual; treat it per the matching signals — both `helm-checklist.md` and `kustomize-checklist.md` may load, and findings are grouped per checklist as usual.
