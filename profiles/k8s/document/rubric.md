# Kubernetes documentation rubric

Required topics for documentation that ships alongside Kubernetes artifacts. The rubric is opinionated: each section exists because its absence has bitten real operators. The three-case **write / N/A / inherit** rule governing how to satisfy each section lives in `document/SKILL.md` guideline #3 — apply it to every rubric section below. Silent omission is indistinguishable from oversight when someone reads the docs under incident pressure.

Scope: apply the rubric to documentation that accompanies manifests, Helm charts, Kustomize overlays, or any YAML that will be reconciled against a cluster. For Kubernetes-adjacent code (operators, controllers, admission webhooks), apply it to the resources they produce, not to their source code.

---

## 1. RBAC decision rationale

Document the **reasoning**, not just the grants. A `ClusterRole` named "reader" with `get,list,watch` on every resource kind is a paragraph of prose — who needs it, why cluster-scoped rather than namespaced, what would break if you narrowed the verbs.

Required subsections:

- **Subject.** Which `ServiceAccount` (or human identity) holds the permissions. Namespace if applicable.
- **Scope.** Namespaced vs cluster-scoped, and why. "Cluster-scoped because X needs cross-namespace visibility" beats "cluster-scoped".
- **Verbs and resources.** The actual grant, with one line per non-obvious verb or resource. Name resource aggregation groups (`*/scale`, `*/status`, `*/finalizers`) explicitly — a reader should not need to re-read the Kubernetes RBAC docs to understand the grant.
- **Escalation-shaped permissions called out by name.** Specifically:
  - `escalate` and `bind` on RBAC resources (`roles`, `clusterroles`, `rolebindings`, `clusterrolebindings`) — grants role-authoring or role-assignment privileges that can create arbitrary elevated roles.
  - `impersonate` on any of `users`, `groups`, `userextras/<key>`, `uids`, or `serviceaccounts`. Document **which of the five resources** are granted and under what resource-name scoping — partial grants combine to full impersonation in specific configurations, so the dimensions matter.
  - `create` on `serviceaccounts/token` (TokenRequest API) — mints tokens for any ServiceAccount scoped to any audience; direct controller-SA impersonation primitive.
  - Any verb on `*/exec`, `*/portforward`, `*/proxy` — confers interactive shell / port tunnel; narrowing to `create` is insufficient (the API surface accepts GET upgrades for some clients).
  - `patch` or `update` on `nodes`, `mutatingwebhookconfigurations`, `validatingwebhookconfigurations` — admission-layer and node-object edits bypass most authorization.
  - `update`/`patch` on `*/finalizers` — blocks or unblocks resource deletion cluster-wide.
  - `approve` on `certificatesigningrequests` — mints arbitrary cluster identities.
  - `use` on `podsecuritypolicies` (deprecated) or `securitycontextconstraints` (OpenShift) — bypasses workload-level security gates.
  - Any verb on `secrets` — differentiate: `get`/`list`/`watch` exfiltrates immediately; `create`/`update` enables injection attacks; `delete` enables denial-of-service on dependent workloads.
- **Alternatives considered.** If a narrower RBAC shape was rejected, state why (e.g., "scoped `Role` would require N-per-namespace reconciliation that the controller cannot currently perform").
- **Pod Security Standards posture (if the feature creates or occupies a namespace).** Document the `pod-security.kubernetes.io/enforce` level (`privileged` / `baseline` / `restricted`) and version label on the namespace. Record whether `warn` and `audit` modes are independently configured. If the feature requires an exception (e.g., `privileged` for a kernel module loader), document the exception and its justification. Cross-check: the profile's `review-code/security-checklist.md` flags missing PSS labels — keep doc and checklist aligned.

## 2. Rollback runbook

A declarative rollback plan that an on-call engineer can execute without reading the source.

Required subsections:

- **Trigger conditions.** What observable symptoms indicate rollback is warranted (SLO breach, error rate, specific alert).
- **Steps.** The concrete commands or GitOps actions, in order. Cover the deployment model in use:
  - **Helm:** `helm history <release>` to find the prior revision, then `helm rollback <release> <revision>`. Note: atomic installs (`--atomic`) auto-rollback on failure, leaving no manual-rollback target; hook-failed releases may sit in a `failed` state and require `--cleanup-on-fail` or manual release deletion before re-installing. Document which mode the release uses.
  - **Argo CD:** `argocd app rollback <app> <history-id>` for immediate rollback to a prior synced revision; follow with a git revert to keep the repo canonical. Without the git revert, the next auto-sync will re-apply the broken state.
  - **Flux:** `flux suspend hr <name>` (or `flux suspend ks <name>` for Kustomize) to freeze reconciliation, then git revert, then `flux resume`. Omitting the suspend risks a partial reconciliation against the in-flight revert.
  - **Raw `kubectl apply`:** document the prior manifest location and the apply command. For `Deployment`/`StatefulSet`/`DaemonSet`, `kubectl rollout undo <kind>/<name>` is faster than re-applying a prior manifest.
  - **GitOps (push-based) without a tool:** the revert-commit SHA or tag to roll back to.
- **Verification.** How to confirm the rollback took effect. Minimum: the resource version / image tag / replicas count to expect post-rollback, and one `kubectl` command to check it.
- **Owner.** A team or on-call rotation, not a named individual that might change roles.
- **Blast radius.** What downstream systems depend on the rolled-back state. If the rollback also requires rolling back a database migration or a feature flag, name them here.
- **Irreversible-step callouts.** Any step the rollback *cannot* undo on its own:
  - PVC deletion — data loss unless the PV has a retention policy.
  - CRD removal — triggers finalizers on every CR of that kind; cluster-wide impact.
  - Namespace deletion — cascades to all contained resources.
  - Image-tag repointing with stateful consumers — old pods referencing the old tag may keep running until restart.
  - `StatefulSet` replica-count reduction — PVCs from `volumeClaimTemplates` for removed ordinals are orphaned per the default `persistentVolumeClaimRetentionPolicy.whenScaled: Retain` (configurable; GA in 1.32). Scale-back-up reuses the PVCs; manual cleanup is required for genuine deletion.
  - In-flight `Job` / `CronJob` side effects — rolling back the spec does not cancel dispatched pod runs; external API calls, DB writes, or notifications cannot be un-sent.
  - `kubectl delete --cascade=orphan` on a parent resource — leaves children adoption-ready for the next matching selector; re-applying the parent may re-adopt orphans with unexpected state.
  - Secret rotation already consumed — rotating a Secret forward and then reverting does not invalidate tokens already minted from the new value by downstream consumers.
  - DB migrations dispatched via a `Job` or init container — the Job exits, the schema stays migrated.

## 3. Resource-baseline documentation

Requests and limits are not self-documenting. A `resources.limits.memory: 512Mi` line raises no flag in isolation; the reader cannot tell if it is twice or half the actual working set.

Required subsections:

- **Measured baseline.** The observed working set the requests are derived from: peak memory under representative load, CPU under P99 load, a link or citation to the measurement (benchmark run, load test, `kubectl top` sample window).
- **Headroom rationale (split by resource type — CPU and memory behave differently).**
  - **Memory (non-compressible).** 1.2–1.5× measured peak is a reasonable minimum; exceeding the limit triggers OOM kill, not throttling. Err toward more headroom when peaks are bursty, unmeasured, or workload-language-dependent (JVM heap vs non-heap, Go `GOMEMLIMIT`, Python-with-glibc). Document which runtime behavior applies.
  - **CPU (compressible).** Exceeding the request causes throttling, not kill. Three patterns are common and all legitimate — state which one applies and why: (a) `requests == limits` for latency-sensitive workloads (Guaranteed QoS; avoids throttling-induced jitter), (b) request set, limit omitted (rely on namespace `LimitRange` or `ResourceQuota`; common for batch/IO-bound workloads where throttling is benign), (c) neither set (BestEffort; batch only, no prioritization guarantees).
- **Limit policy and QoS class.** Document the QoS class the pod lands in — `Guaranteed` (requests == limits for **both** CPU and memory on every container, init containers included), `Burstable` (requests set on at least one container but not Guaranteed for all), or `BestEffort` (no requests/limits anywhere on any container). Name both dimensions (requests and limits) when describing the class — the class is a consequence of both.
- **Capacity-planning assumptions.** Expected replica count at steady state and at peak; autoscaling inputs (HPA metric, target, min/max replicas). If no autoscaler is defined, say so explicitly and document the manual scaling trigger.
- **OOM behavior.** What the workload does when the memory limit is hit. Include the concrete operator-observable signals: container exit code **137** (SIGKILL), no grace period, no `preStop` hook execution, no SIGTERM — the container is killed immediately; the pod restart counter increments; `kubectl describe pod` shows `lastState.terminated.reason: OOMKilled`. Document any stateful consequence (lost in-flight request, corrupted buffer, DB connection left open). For stateful workloads, name the recovery procedure.

## 4. Cluster-compat matrix

Which Kubernetes minor versions the manifests have been validated against, and which API versions they rely on.

Required subsections:

- **Supported Kubernetes minor versions.** A closed range, not "latest". Track the project's actual cluster fleet. An example shape: "1.31–1.33" (the example should be adjusted to your current supported window; Kubernetes minor versions have ~14-month support from release). Tie each entry to a clear validation signal (kubeconform-checked against that minor's schemas, CI job name, cluster fleet this ships to).
- **API versions used.** The non-default `apiVersion`s the manifests reference, with the minor version in which each graduated to stable. Flag any `v1beta1` / `v1alpha1` use explicitly.
- **Deprecation horizon.** For each API version in use, the Kubernetes minor where it is deprecated and the minor where removal is scheduled (see [kubernetes.io/docs/reference/using-api/deprecation-guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)). If any used API is within one minor of removal, call it out in bold.
- **CRD dependencies.** Any third-party CRDs the manifests assume are installed, with the minimum operator version that provides the CRD schema in use. CRD schemas are version-pinned per operator release — pin by operator version, not just CRD name.
- **Feature-gate dependencies.** If the manifests rely on a non-default feature gate being enabled on the cluster, name the gate and the minor in which it graduated. Currently gate-controlled examples to cross-check against the target fleet: `SidecarContainers` (alpha 1.28, beta 1.29, GA 1.33), `InPlacePodVerticalScaling` (alpha 1.27, beta 1.33), `DynamicResourceAllocation` (alpha 1.26, beta 1.32), `UserNamespacesSupport` (alpha 1.25, beta 1.30). Re-verify gate state against current kubernetes.io docs when authoring — gates graduate and lock.
- **Admission-configuration dependencies (not feature gates).** If the manifests rely on a specific `--enable-admission-plugins` list, admission-webhook ordering, or `--admission-control-config-file` shape, document that separately — these are cluster-configuration concerns, not feature gates.
- **Cluster-runtime dependencies.** Where load-bearing: container runtime (containerd/CRI-O version for specific features), CNI (e.g., Cilium ≥1.14 for BGP), architecture matrix (x86/ARM), Windows-node compatibility.

## 5. NetworkPolicy / egress posture narrative

Prose, not YAML. The manifests already say what is allowed; documentation must say what **stance** the policies implement.

Required subsections:

- **Default posture.** Allow-all, deny-all, or segmented. For deny-all (recommended for production namespaces), state it explicitly and document the shape of the enforcing object — a NetworkPolicy with `podSelector: {}` (match all pods), `policyTypes: [Ingress, Egress]`, and **no** `ingress:` or `egress:` rule arrays denies both directions. A partial default-deny (`policyTypes: [Ingress]` only) denies only ingress; state which applies. The profile's `security-checklist.md` expects both-direction default-deny in production.
- **Allowed ingress.** Which pods may reach this workload, with the selector shape. Name the producer — "allowed from `app=web` pods in the same namespace" beats "allowed from `app=web`".
- **Allowed egress.** Each allowed destination paired with one-line justification. Specifically required:
  - **DNS (kube-dns / CoreDNS):** port 53 UDP/TCP scoped to `namespaceSelector: kubernetes.io/metadata.name=kube-system` + `podSelector: k8s-app=kube-dns`. A port-only allowance permits egress to any pod listening on 53 — including attacker-controlled pods.
  - **Managed-service endpoints** (cloud-managed databases, object stores, message buses) — named endpoint + justification.
  - **Cloud instance metadata endpoint (`169.254.169.254`):** document whether this is implicitly blocked under default-deny egress, explicitly blocked by rule, or intentionally allowed (e.g., IRSA/WI pattern with IMDSv2 hop-limit enforced). This endpoint is a well-known SSRF target for credential theft.
- **CNI enforcement model.** Which CNI enforces `NetworkPolicy` in this cluster (Cilium / Calico / AWS VPC CNI / Azure CNI / …). Some CNIs extend standard NetworkPolicy via CRDs (`CiliumNetworkPolicy`, Calico `GlobalNetworkPolicy`) with L7 rules and cluster-scope; if either is in use here, document the extension alongside the standard policies. Some CNIs historically do not enforce standard `NetworkPolicy` at all — if that applies, the "policies exist" assertion means nothing and the reader needs to know.
- **Service-mesh interaction (defense-in-depth).** If the cluster runs a service mesh (Istio, Linkerd, Cilium service mesh) with its own L7 authorization policy, document **both** layers: NetworkPolicy operates at L4 (IP/port) and mesh authorization operates at L7 (service identity, HTTP method/path). They are complementary, not alternatives — a namespace running both has defense-in-depth. Do not drop NetworkPolicy in mesh-enabled namespaces; mesh policy can fail-open on non-mesh traffic, and a pod without an mTLS sidecar loses mesh enforcement entirely.
- **Known gaps.** Any traffic path that is knowingly unrestricted (e.g., inter-pod within the namespace) and the justification, so a future reader can tell an intentional omission from a missed one.
