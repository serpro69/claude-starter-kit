# Kubernetes — per-task gotchas

Read before editing Kubernetes manifests, Helm charts, or Kustomize overlays. These are authoring-time pitfalls — situations where the naive choice compiles, lints, and applies cleanly but fails in production or at the next cluster upgrade. Reviewers catch most of these post-write via `review-code`; the point here is to avoid them at the keyboard.

When in doubt about an API field, version, CRD schema, Helm chart behavior, or container image digest, invoke the `dependency-handling` skill BEFORE writing — do not guess. See [`../overview.md` §Looking up Kubernetes dependencies](../overview.md#looking-up-kubernetes-dependencies) for the per-category cascade.

## API-version pinning

- Target the cluster's minor version, not `latest`. `kubectl api-versions` and `kubectl explain <resource>` on the target cluster are the authoritative checks for what is actually served.
- Do not use removed APIs. Common traps when copying from old examples: `extensions/v1beta1` (all removed by 1.22), `policy/v1beta1/PodDisruptionBudget` (removed in 1.25 — use `policy/v1`), `batch/v1beta1/CronJob` (removed in 1.25 — use `batch/v1`), `autoscaling/v2beta2/HorizontalPodAutoscaler` (removed in 1.26 — use `autoscaling/v2`), `networking.k8s.io/v1beta1/Ingress` (removed in 1.22 — use `networking.k8s.io/v1`).
- Deprecated ≠ removed — deprecated APIs still work but signal an upcoming removal. If the design names a target minor, check each `apiVersion` against that minor's deprecation guide before writing.
- For CRDs, the group/version is pinned to the installed operator release, not to the Kubernetes minor. Confirm with `kubectl api-resources --api-group=<group>` against the target cluster.

## Probe correctness

- Readiness ≠ liveness. A failing `readinessProbe` removes the Pod from Service endpoints (traffic stops); a failing `livenessProbe` kills the container (restart). Using a liveness probe that blocks on a dependency (DB, external API) turns a transient upstream outage into a restart loop.
- Add a `startupProbe` for slow-starting apps (JVMs, apps with large warm caches, DB migrations on boot). Without one, the liveness probe's `initialDelaySeconds` competes with startup time — set it too low and the Pod is killed before it is ready; set it too high and genuine liveness failures take minutes to act on.
- `failureThreshold`, `periodSeconds`, `timeoutSeconds` are independent knobs. A 1s `timeoutSeconds` on an HTTP probe against a lightly-loaded endpoint is a common source of flakiness on busy nodes.
- Exec probes fork a process every period — cheap for one container, expensive at fleet scale. Prefer HTTP or TCP probes where possible.

## Image-tag immutability

- Prefer digests (`image: repo/name@sha256:...`) over tags for any image that ships to production. Tags are mutable; the image behind `:1.2.3` can be replaced without the manifest changing.
- Never ship `:latest` — it pins nothing and disables rollback reasoning. This is flagged by `quality-checklist.md` post-write; fixing it at review time means re-tagging and re-testing.
- When adding a new image, record the digest you pulled alongside the tag in the design/ADR. If `skopeo`/`crane` is unavailable locally, the registry's web UI lists the digest; do not invent one.
- Private registries: `imagePullSecrets` must be attached to the workload's `ServiceAccount` (preferred) or the Pod spec. Attaching it only to the namespace's `default` SA surprises people writing new workloads that opt into a different SA.

## Resource requests and limits

- Missing `resources.requests` → Pod is treated as `BestEffort` and is the first thing the kubelet evicts under memory pressure. Critical workloads must set requests.
- Missing `resources.limits.memory` → no hard ceiling; a leak takes the node with it. Missing `resources.limits.cpu` is an **intentional** choice on some clusters (to avoid throttling latency-sensitive apps); missing `limits.memory` almost never is.
- CPU limits cause throttling, not OOMKill. If latency matters more than noisy-neighbor protection, prefer `requests` + no `limits.cpu`, enforced by quota at the namespace level.
- Guaranteed QoS requires requests==limits for all resources on all containers, including init containers. Partial matches fall back to Burstable.
- Java/JVM: set `-XX:MaxRAMPercentage` or `-Xmx` based on the container's memory limit; older JVMs default to host memory, which OOMKills immediately.

## Namespace and label hygiene

- Every workload resource must set `metadata.namespace` explicitly (or live in a Kustomize base / Helm chart that pins it) — relying on `kubectl`'s `--namespace` default makes the manifest context-dependent and breaks GitOps.
- Labels: follow the project's existing scheme (usually some subset of `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`). The `quality-checklist.md` names the recommended set.
- Selectors (`spec.selector.matchLabels` on Deployment/StatefulSet/DaemonSet) are **immutable after creation**. Pick the label set deliberately — a later change forces delete-and-recreate, which is downtime.
- `Service.spec.selector` is mutable but must match the Pod labels the workload actually emits; a typo routes traffic to zero endpoints and no error is surfaced until someone checks `kubectl get endpoints`.

## CRD-before-CR ordering

- A Custom Resource (`Certificate`, `ClusterIssuer`, `PrometheusRule`, `Application`, etc.) cannot apply until its CRD is installed. In a single `kubectl apply -f dir/`, the CRD and CR are applied in unspecified order — the CR apply fails with `no matches for kind`.
- Fixes: install CRDs via a prior `kubectl apply` pass, a Helm chart that uses `crds/` or `--skip-crds=false`, or Argo CD `SyncWave`/`SyncPhase` (`PreSync` for CRDs). Kustomize does not solve this — ordering must come from the apply tool.
- Helm specifically: CRDs placed in the chart's `crds/` directory are applied before templates but are **not** upgraded on `helm upgrade`. If the chart's CRD schema evolves, ship CRDs via a separate chart or a dedicated `kubectl apply`.
- Deletion order is the reverse: delete CRs (and anything with a finalizer) before the CRD, or the finalizer controller is gone and the CR blocks forever. This is the top cause of "namespace stuck in Terminating".

## Admission webhook and operator timing

- New ValidatingWebhookConfiguration / MutatingWebhookConfiguration with `failurePolicy: Fail` can lock out the cluster if the webhook backend is unreachable. For first rollout, start with `failurePolicy: Ignore`, watch for acceptance, then flip to `Fail`.
- Avoid selecting `kube-system` in webhook scopes unless deliberate — locking out the control plane is hard to recover from.
- Operators that install CRDs and then reconcile CRs they own (cert-manager, external-secrets) need to be fully ready before the first CR apply — otherwise the CR is created but not reconciled and looks healthy.

## Helm specifics

- `Chart.yaml.kubeVersion` is a Helm field with semver-range semantics (e.g., `>=1.28.0-0`). It is not enforced by the cluster — it gates `helm install` / `helm upgrade` against the cluster's server version.
- `dependencies[]` must be pinned to a strict semver; floating ranges (`~1.2`, `^1.0`) are reproducibility hazards. Lock the exact versions in `Chart.lock` by running `helm dependency update` and committing both files.
- Templates render Go templates BEFORE Kubernetes sees the output — `{{ ... }}` errors fail at `helm template` / `helm lint` time, not at cluster-apply time. Run `helm lint` locally before committing.
- `required` and `fail` in templates are the only way to make a missing value break rendering; plain `{{ .Values.foo }}` silently emits `<no value>`.

## Kustomize specifics

- `kustomization.yaml` patches are applied in list order. Strategic-merge patches merge; JSON 6902 patches target by path. Using the wrong `patches[].patch` type is the common source of "the patch didn't do anything".
- `commonLabels` are applied to every resource **and to selectors**, which can collide with the workload's own selector and trigger the immutable-selector failure above. Prefer `labels[].pairs` with `includeSelectors: false` unless you have audited every selector.
- `namePrefix` / `nameSuffix` also mutate references (`configMapRef.name`, etc.), but only those Kustomize knows how to follow. Raw string references inside annotations or CR spec fields are **not** rewritten — check the rendered output (`kustomize build`) before committing.
