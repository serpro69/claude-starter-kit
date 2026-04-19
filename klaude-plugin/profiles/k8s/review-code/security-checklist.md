# Kubernetes — Security Checklist

Applied whenever the `k8s` profile is active. Findings reference specific resource kinds and manifest fields. Flag violations at the appropriate severity and propose the concrete change.

## Contents

- RBAC and identity
- Pod Security Standards and SecurityContext
- NetworkPolicy posture
- Secret handling
- Image provenance and pull-secret hygiene
- Host namespaces and privilege
- Admission and supply-chain signals

## RBAC and identity

- Workloads must run under a **named, minimum-scope `ServiceAccount`** — never under `default`. A dedicated SA per workload keeps RBAC scoped.
- `Role` / `ClusterRole` grants apply **least privilege**: no `"*"` verbs, no `"*"` resources, no `"*"` apiGroups. Each rule should name concrete verbs (`get`, `list`, `watch`, `create`, ...) and concrete resources.
- `cluster-admin` or any `ClusterRoleBinding` to a broad role is a P0/P1 finding unless the resource is an installer Job with a documented teardown path.
- `Role`/`RoleBinding` preferred over `ClusterRole`/`ClusterRoleBinding` when the workload is namespace-scoped. Cluster-wide bindings should justify why namespace scope is insufficient.
- No binding to the `system:masters` group; no grants of `impersonate`, `escalate`, or `bind` verbs unless the workload is an RBAC management operator with explicit rationale.
- `automountServiceAccountToken: false` on the Pod spec (or ServiceAccount) when the workload does not call the API server. Since K8s 1.22 (GA), tokens are mounted as short-lived projected volumes via the `BoundServiceAccountTokenVolume` admission plugin — explicitly disabling automount is still required for workloads that do not need API access. K8s 1.24+ additionally stopped auto-generating long-lived Secret-backed tokens for the default ServiceAccount.
- When a token IS needed, use an explicit `projected` volume with `serviceAccountToken`: set an **`audience`** to the exact audience the receiver validates (prevents token reuse across services) and an **`expirationSeconds`** at or below the cluster's kubelet refresh window (default 3607s / ~1h; values above ~7200s are silently reduced).

## Pod Security Standards and SecurityContext

Workloads should satisfy the **restricted** Pod Security Standard unless explicitly justified:

- `securityContext.runAsNonRoot: true`
- `securityContext.runAsUser` set to a non-zero UID
- `securityContext.readOnlyRootFilesystem: true` (mount emptyDir for writable paths when needed)
- `securityContext.allowPrivilegeEscalation: false`
- `securityContext.capabilities.drop: ["ALL"]`; add back only the specific capabilities required (`NET_BIND_SERVICE` etc.), never `SYS_ADMIN`.
- `securityContext.seccompProfile.type: RuntimeDefault` (or `Localhost` with a pinned profile).
- Pod-level `securityContext.fsGroup` set when volumes need group-writable access — avoid `fsGroup: 0`.
- Namespaces that host these workloads carry `pod-security.kubernetes.io/enforce: restricted` (preferred). `baseline` enforcement is acceptable only when the workload's SecurityContext genuinely needs baseline-only capabilities; a namespace enforcing `baseline` while the workload satisfies `restricted` is a P3 finding — upgrade the label. Pod Security Admission has three modes: `enforce` (admission-blocking), `warn` (surfaces warnings but admits), and `audit` (records without blocking). **A namespace with only `warn` / `audit` labels and no `enforce` provides no actual enforcement** — flag as P2.

## NetworkPolicy posture

- Namespaces with workloads must have a **default-deny NetworkPolicy** for both ingress and egress; explicit allow rules layer on top. Workload manifests without a corresponding NP in the same diff (or clearly present already) are a P1/P2 finding.
- Ingress rules name selectors (`podSelector` / `namespaceSelector`) — never `{}` (empty selector = "all") in a default-allow direction.
- Egress rules cap external reach: DNS (CoreDNS, UDP/TCP port 53), the **Kubernetes API server** (typically port 443) when the workload uses client-go / `kubectl` / an operator pattern, the specific Service CIDRs or external FQDN-equivalents needed, and nothing else. `to: []` with no selector is allow-all and is almost always a mistake. Omitting API-server egress on a workload that talks to the API (controllers, kube-state-metrics, the cluster autoscaler, custom operators) breaks the workload silently under default-deny — flag as P1.
- Service-mesh sidecars do not substitute for NetworkPolicy — both should coexist.

## Secret handling

- `Secret` manifests with plaintext sensitive values (API keys, passwords, tokens, TLS private keys) committed to git — base64 is encoding, not encryption — are a P0 finding. Secrets live in an external manager (External Secrets Operator, HashiCorp Vault, cloud KMS) and are synced in, OR are committed as Sealed Secrets / SOPS-encrypted payloads. **If a value is non-sensitive, it belongs in `ConfigMap`, not `Secret`** — the `Secret` kind exists specifically to hold sensitive material, so there is no valid "non-sensitive bootstrap" carve-out for committed `Secret.data` / `stringData`.
- No secrets passed via `env` when a file mount would do — env values leak into process listings and crash dumps. Prefer `envFrom.secretRef` + `volumeMounts` of projected secrets where possible.
- `immutable: true` on `Secret` and `ConfigMap` when the value is not expected to change — prevents accidental edits and enables kubelet caching.
- No secrets in `ConfigMap` (they are not encrypted at rest by default in most clusters).
- Avoid committing `Secret` YAML with real values to git — flag sealed-secrets/external-secrets references as the expected shape.

## Image provenance and pull-secret hygiene

- `imagePullPolicy: IfNotPresent` or `Always` — never rely on the default for `:latest` tags. Mutable tags (`:latest`, `:main`, `:stable`) are a P1 finding; pin to immutable tags or digests (`@sha256:...`).
- `imagePullSecrets` reference secrets that actually exist in the namespace; the registries listed there match the images used.
- Images come from a trusted registry (internal registry, vendor official, known OSS mirror). `docker.io/library/*` with no digest is a supply-chain risk.
- Sidecar/init-container images follow the same pinning and registry rules as the main container.

## Host namespaces and privilege

The following are P0/P1 findings unless the manifest includes a rationale comment AND the workload is a system-level agent (CNI, CSI driver, node exporter):

- `hostNetwork: true`
- `hostPID: true`
- `hostIPC: true`
- `privileged: true` on any container
- `hostPath` volumes — use `emptyDir`, `projected`, PVC, or CSI ephemeral volumes for application workloads. The "system-level agent" carve-out applies to CSI drivers, CNI agents, node exporters, and similar DaemonSets that legitimately need node-local paths (e.g., `/run/containerd/containerd.sock`, `/etc/cni/net.d`). For those, review the specific path and writability (prefer `type: File` / `type: Socket` + `readOnly: true`), not just the presence of `hostPath`.
- Ports bound below 1024 without `NET_BIND_SERVICE` capability and otherwise non-root user.

## Admission and supply-chain signals

- If the project uses image-signing (Cosign, Notary), verify the admission webhook / policy is in place and the images have signatures.
- ValidatingAdmissionPolicy, OPA/Gatekeeper, or Kyverno policies in the repo should be reviewed together with the workloads they gate.
- `seccomp`, `AppArmor` annotations match the intended profile and that profile exists on the target nodes.
- **Image vulnerability scanning** run in CI against all container images (Trivy, Grype, or equivalent); critical/high CVEs gate deployment. For production images, generate an **SBOM** (`syft`, `cosign attest --type spdx`) and verify it at admission time when the compliance posture requires it.
- **`ephemeralContainers`**: GA since K8s 1.25. They can bypass some `SecurityContext` restrictions because they are injected post-admission and cannot declare `resources` or modify many Pod-level security fields. Review: (a) RBAC on the `ephemeralcontainers` subresource is scoped to humans/operators, not workload identities; (b) debug-image hygiene (pinned digests, scanned); (c) admission policy gates ephemeral containers the same as regular ones where possible.

## Questions to ask

- "Who is this ServiceAccount, and what does it need to do?" — drive the RBAC scope.
- "What talks to this Pod, and what does this Pod talk to?" — drive the NetworkPolicy rules.
- "Where does each secret value come from, and who can write to that source?" — drive the Secret-handling review.
- "If this Pod is compromised, what is the blast radius?" — sanity-check privilege/host settings.
