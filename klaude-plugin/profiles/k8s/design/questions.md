# Kubernetes — design question bank

Questions used during idea refinement when the `k8s` profile is active. Ask one per message, per the skill's rule. Order is risk-first — start with questions whose answers most constrain subsequent design choices (cluster topology usually does). Skip any question the user or the codebase has already answered (check `kk:arch-decisions`, `kk:project-conventions`, and any existing `design.md` before asking).

## Cluster topology

- Which Kubernetes minor versions must this feature support? Name the minor (e.g., `1.29`) — "latest" is not a supported-version statement. For Helm charts, set `kubeVersion` in `Chart.yaml` with a semver constraint (e.g., `>=1.28.0-0`); note `kubeVersion` is a Helm `Chart.yaml` field, not a Kubernetes API field.
- Single cluster, multi-cluster, or multi-region? How does CI reach each cluster (kubeconfig secret, OIDC-federated token, bastion)?
- Managed (EKS, GKE, AKS, DOKS) or self-hosted? Any vendor addons the design must coexist with (AWS VPC CNI, GKE Autopilot constraints, Azure Policy, etc.)?
- API deprecations — for the target minor version, which API versions used in this design are already `Deprecated` or scheduled for removal (e.g., `policy/v1beta1/PodDisruptionBudget` removed in 1.25, `batch/v1beta1/CronJob` removed in 1.25)? Name the migration API for each.
- Third-party CRDs — which CRDs does this feature install or consume (cert-manager, Prometheus Operator, Argo CD, Flux, external-secrets)? What exact operator release version pins the CRD schema?
- Stateful workload? If yes: `StorageClass` name and provisioner, access mode (`ReadWriteOnce` / `ReadWriteOncePod` / `ReadWriteMany`), `reclaimPolicy` (`Retain` preferred for production data — `Delete` destroys the backing volume on PVC deletion and is irreversible once bound), and backup/restore SLO.
- `dnsPolicy` — default (`ClusterFirst`) or non-default (`Default` for node DNS only, `ClusterFirstWithHostNet` for `hostNetwork: true` pods, `None` with custom `dnsConfig`)? When is the default insufficient, and what resolution pipeline does this workload expect?

## GitOps and delivery

- GitOps stack: Argo CD, Flux, or imperative (`kubectl apply` / `helm upgrade` from CI)? If GitOps, which `Application` / `Kustomization` / `HelmRelease` owns these manifests?
- Promotion model — per-env branches, per-env overlays, per-env values files, or an ApplicationSet with a single source of truth?
- Sync posture — prune-on-delete, sync waves / phases? (Rollback trigger is asked separately under "Reliability and rollback".)

## Secrets strategy

- Secret source: External Secrets Operator, Sealed Secrets, Vault Agent Injector, cluster-native `Secret` resources, or cloud-provider-integrated (IRSA / GKE Workload Identity / Azure AD Workload Identity)? These are distinct federation mechanisms; each requires its own OIDC audience binding and trust-policy configuration — document the chosen mechanism's federation binding (OIDC provider registration, ServiceAccount annotation, IAM trust policy).
- Rotation frequency and rotation owner — human-driven, operator-managed, or credential-less (workload identity, which still requires the federation binding above)?
- Blast radius — per-namespace, per-cluster, cross-cluster? Who has read access to the decrypted secret at rest?
- `imagePullSecrets` — does this workload pull from a private registry? If yes: which secret, how is it provisioned per namespace (manual, synced by ESO, bound to a `ServiceAccount`), and what is the rotation procedure?

## Multi-tenancy

- Single namespace, namespace-per-tenant, or shared namespace with RBAC boundaries?
- NetworkPolicy posture — default-deny plus explicit allow edges (across ingress AND egress), default-allow, or no NetworkPolicy (accepted risk)?
- `LimitRange` defaults — if containers omit `resources.requests` / `limits`, what does the namespace `LimitRange` inject (`default` and `defaultRequest`)? Or does the namespace have no `LimitRange`, meaning all containers must set explicit requests/limits?
- Admission-time guardrails — `ResourceQuota` per namespace, PSA labels (`restricted` / `baseline` / `privileged`) AND enforcement mode (`enforce` / `audit` / `warn` — `warn`/`audit` alone provide no enforcement), policy engine (Kyverno, Gatekeeper) with enforced rules?
- Service mesh — is a service mesh (Istio, Linkerd, Cilium Service Mesh) active in the target namespace? If yes: is sidecar injection enabled for this workload, and does the design account for mTLS, mesh-aware NetworkPolicy, and sidecar DNS interception (mesh sidecars may override the pod's DNS resolution pipeline — confirm the mesh's DNS behavior is compatible with the workload's expected resolution path)?

## Observability

- Logs — cluster-scoped collector (Fluent Bit, Vector) or per-app sidecar? JSON structured output required for the log pipeline to parse fields?
- Metrics — Prometheus scrape via `ServiceMonitor` / `PodMonitor`, annotation-based pull, or push to a collector? Custom metrics beyond the Go/JVM/Node defaults?
- Traces — OpenTelemetry SDK, vendor agent (Datadog, New Relic), or none? Sampling target and propagation format?
- Alerts — delivery channel (on-call rotation, Slack, paging) and runbook owner. An alert without a runbook is toil, not signal.

## Reliability and rollback

- SLO targets — explicit availability and latency numbers, or inherited from a parent service? How is SLO burn measured and alerted?
- QoS class — target `Guaranteed` (requests == limits on all containers — strongest eviction protection), `Burstable`, or `BestEffort`?
- `PriorityClass` — what priority class does this workload use (`system-cluster-critical`, `system-node-critical`, custom application tier, or default / none — BestEffort under node pressure)? Is preemption of lower-priority workloads acceptable?
- Container lifecycle — does this workload need init-containers for pre-start tasks (DB schema migrations, TLS cert fetching, file-permission setup, dependency health gating)? If yes: list each init-container's concern and resource budget, and confirm the main container's readiness expectations still hold once all init-containers complete.
- Rollback trigger — `helm rollback`, GitOps sync disable + revert, canary flip, or blue-green cutover?
- Rollout tolerance — RollingUpdate `maxSurge` / `maxUnavailable`, PodDisruptionBudget (choose EITHER `minAvailable` OR `maxUnavailable` — not both; the API rejects co-declaration), graceful-shutdown window (`terminationGracePeriodSeconds`, `preStop` hook)?
- Failure modes designed against — which of (control-plane outage, single-node loss, zone loss, DNS failure, noisy neighbor) are in scope, which are explicitly accepted risks? (`etcd degradation` is a platform concern; application response is limited to read-only degradation posture or circuit-breaking, usually accepted risk at the application layer.)
