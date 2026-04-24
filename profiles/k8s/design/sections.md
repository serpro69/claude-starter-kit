# Kubernetes — required design sections

Every `design.md` for a K8s-shaped feature must include the five sections below. Omit none; if a section genuinely does not apply, state so explicitly with a one-line justification — silent omissions hide scope gaps, and a reviewer (or `review-spec`) cannot tell absence-by-intent from absence-by-oversight.

Section order is not mandated; the sections must all be present. Cross-reference between sections liberally where a decision in one drives a constraint in another (e.g., a PSA level in **Security posture** constrains `readOnlyRootFilesystem` defaults in **Reliability posture**).

## Cluster-compat matrix

- Minimum and maximum Kubernetes minor versions supported, with rationale. Pin to a specific minor (`1.28` / `1.29`) — "latest" is not a support statement.
- Required in-cluster addons with pinned minimum versions (e.g., `cert-manager ≥ 1.13`, `metrics-server ≥ 0.7`, `CNI with NetworkPolicy support`).
- Third-party CRDs the feature installs or consumes, with exact installed versions. CRD schemas are version-pinned per operator release.
- Deprecation horizon — which API versions used by the feature are already `Deprecated` in the target minor, and the planned migration path before they are removed (e.g., `policy/v1beta1/PodDisruptionBudget` removed in 1.25, `batch/v1beta1/CronJob` removed in 1.25).

## Resource budget

- Workload sizing — replica count range, requests and limits per container (CPU, memory). Justify the request (baseline steady-state) and the limit (burst ceiling / OOM guard) separately. Declare the intended QoS class: `Guaranteed` (requests == limits on all containers — strongest eviction protection), `Burstable`, or `BestEffort`.
- Ephemeral storage — for workloads writing to `emptyDir` or the container writable layer (log buffers, scratch files, temp dirs), declare `ephemeral-storage` requests and limits — prevents node disk exhaustion and surprise eviction.
- Priority and overhead — `PriorityClass` name/value (`system-cluster-critical`, `system-node-critical`, custom application tier, or default / BestEffort). State whether preemption of lower-priority workloads is acceptable. Pod-overhead accounting if using non-default `RuntimeClass`es.
- Autoscaling bounds — HPA `minReplicas` / `maxReplicas` with scale signal (CPU, memory, custom metric); `behavior.scaleDown.stabilizationWindowSeconds` and `behavior.scaleUp.policies` tuned to prevent flapping under variable load. VPA mode (`Off` / `Auto` / `Recreate` / `Initial`) if enabled — note `Auto` and `Recreate` both evict Pods to apply recommendations; `Initial` sets requests only at Pod creation.
- Storage — `PersistentVolumeClaim` class, size, access mode (`ReadWriteOnce` / `ReadWriteOncePod` / `ReadWriteMany`), and `reclaimPolicy` (`Retain` preferred for production data — `Delete` destroys the backing volume on PVC deletion; the policy is irreversible once the PV is bound). Expected growth rate; backup/restore SLO for stateful data.
- Blast-radius estimate — if this feature consumes its whole budget (bad deploy, autoscaling runaway), which other workloads in the cluster starve first? Name them or declare the headroom.

## Reliability posture

- `PodDisruptionBudget` declaration — choose **either** `minAvailable` **or** `maxUnavailable` (not both — the Kubernetes API rejects co-declaration with a 422). State the chosen value and the rationale tying it to the SLO.
- Probes — `readinessProbe`, `livenessProbe`, and (for slow-starting workloads) `startupProbe` with thresholds. Distinguish the three roles: readiness gates traffic; liveness restarts; startup delays liveness enforcement until the app is up.
- Graceful shutdown — `terminationGracePeriodSeconds` value and `preStop` hook semantics (drain, flush, deregister).
- Spreading — prefer `topologySpreadConstraints` over `podAntiAffinity` (GA since K8s 1.19, more expressive for zone / node distribution) with concrete `topologyKey` and `maxSkew` values; if `podAntiAffinity` is chosen instead, state the rationale.
- Container roles — separate concerns between init-containers (bootstrapping, migrations), sidecars (cross-cutting: log shippers, proxies, secret fetchers), and the application container. Document resource budget and restart semantics for each.
- Network routing — Service traffic distribution (`sessionAffinity`, `internalTrafficPolicy`, `externalTrafficPolicy`) and topology-aware routing hints (`service.kubernetes.io/topology-mode: auto` — GA in 1.27) for multi-zone designs.
- Rollout strategy — `RollingUpdate` with `maxSurge` / `maxUnavailable` tuned for the workload, plus `minReadySeconds` and `progressDeadlineSeconds` for early-failure detection; or `Recreate` with declared downtime window. Include rollback procedure and the observable signal that confirms rollback success.

## Security posture

- RBAC — ServiceAccount scope (namespace, cluster); enumerated Role/ClusterRole verbs with a one-line justification per verb; explicit list of rejected over-privileged alternatives (e.g., "not granting `*` on `secrets` because X").
- NetworkPolicy — default-deny baseline across both ingress and egress, plus explicit allowed edges; cross-namespace allows called out individually; egress policy for external-facing traffic (DNS, vendor APIs).
- Pod Security — PSA level (`restricted` / `baseline` / `privileged`; prefer `restricted`) **and** enforcement mode (`enforce` / `audit` / `warn` — a namespace in `warn`/`audit` only provides no actual enforcement); `runAsNonRoot: true`; `runAsUser` set to a non-zero UID (non-zero at the pod level overrides a container image's own USER instruction); `readOnlyRootFilesystem: true`; `allowPrivilegeEscalation: false`; dropped capabilities (`drop: [ALL]` + minimal `add:`); `seccompProfile` (`RuntimeDefault` preferred; `Localhost` for custom profiles). State the `fsGroup` strategy for any PVC-attached container.
- Secrets — source (ESO / Sealed / native / workload identity); rotation frequency and owner; read access at rest (who / what service accounts). `imagePullSecrets` provisioning and rotation for private registries.
- Supply chain — image digest-pinning policy (prefer digests over mutable tags); signature verification (cosign, notary); base-image selection and CVE-gating workflow; admission-time enforcement (if any).

## Failure-mode narrative

- At least three concrete failure modes the feature must survive. For each: expected user-visible impact, detection signal (metric, log, alert), recovery path, and the person or team on the hook.
  - Examples: one node drained during rollout; one zone lost; stateful backend latency spike; CRD controller unreachable; image-pull throttling at registry.
- Explicit out-of-scope failure modes — what the feature does NOT promise to handle, with the risk accepted and by whom.
- Rollback procedure — who triggers it (on-call, release engineer), how (GitOps revert, `helm rollback`, canary flip), and the observable signal that confirms rollback succeeded. "Revert the commit" is not a rollback procedure; name the mechanism and the verification.
