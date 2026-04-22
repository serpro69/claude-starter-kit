# Kubernetes documentation rubric

Required topics for documentation that ships alongside Kubernetes artifacts. The rubric is opinionated: each section exists because its absence has bitten real operators. If a topic is genuinely inapplicable to the feature being documented (e.g., no new permissions, no new workload), say so explicitly — silent omission is indistinguishable from oversight when someone reads the docs under incident pressure.

Scope: apply the rubric to documentation that accompanies manifests, Helm charts, Kustomize overlays, or any YAML that will be reconciled against a cluster. For Kubernetes-adjacent code (operators, controllers, admission webhooks), apply it to the resources they produce, not to their source code.

---

## 1. RBAC decision rationale

Document the **reasoning**, not just the grants. A `ClusterRole` named "reader" with `get,list,watch` on every resource kind is a paragraph of prose — who needs it, why cluster-scoped rather than namespaced, what would break if you narrowed the verbs.

Required subsections:

- **Subject.** Which `ServiceAccount` (or human identity) holds the permissions. Namespace if applicable.
- **Scope.** Namespaced vs cluster-scoped, and why. "Cluster-scoped because X needs cross-namespace visibility" beats "cluster-scoped".
- **Verbs and resources.** The actual grant, with one line per non-obvious verb or resource. Name resource aggregation groups (`*/scale`, `*/status`, `*/finalizers`) explicitly — a reader should not need to re-read the Kubernetes RBAC docs to understand the grant.
- **Escalation-shaped permissions called out by name.** Specifically: `escalate` and `bind` on RBAC resources; `impersonate`; `create` on `*/exec`, `*/portforward`, `*/proxy`; `patch` on `nodes`, `*.mutatingwebhookconfigurations`, `*.validatingwebhookconfigurations`; any verb on `secrets`. Each of these can confer cluster-admin via a second hop; document the justification.
- **Alternatives considered.** If a narrower RBAC shape was rejected, state why (e.g., "scoped `Role` would require N-per-namespace reconciliation that the controller cannot currently perform").

## 2. Rollback runbook

A declarative rollback plan that an on-call engineer can execute without reading the source.

Required subsections:

- **Trigger conditions.** What observable symptoms indicate rollback is warranted (SLO breach, error rate, specific alert).
- **Steps.** The concrete commands or GitOps actions, in order. For Helm: `helm rollback <release> <revision>` with the specific prior revision or how to find it (`helm history`). For Kustomize/plain manifests under GitOps: the revert-commit SHA or the tag to roll back to. For raw `kubectl apply`: the prior manifest location.
- **Verification.** How to confirm the rollback took effect. Minimum: the resource version / image tag / replicas count to expect post-rollback, and one `kubectl` command to check it.
- **Owner.** A team or on-call rotation, not a named individual that might change roles.
- **Blast radius.** What downstream systems depend on the rolled-back state. If the rollback also requires rolling back a database migration or a feature flag, name them here.
- **Irreversible-step callouts.** PVC deletion, CRD removal (triggers finalizers on every CR), namespace deletion (cascades to all contained resources), image-tag repointing with stateful consumers — any step the rollback *cannot* undo on its own.

## 3. Resource-baseline documentation

Requests and limits are not self-documenting. A `resources.limits.memory: 512Mi` line raises no flag in isolation; the reader cannot tell if it is twice or half the actual working set.

Required subsections:

- **Measured baseline.** The observed working set the requests are derived from: peak memory under representative load, CPU under P99 load, a link or citation to the measurement (benchmark run, load test, `kubectl top` sample window).
- **Headroom rationale.** Why requests sit where they sit relative to the measured baseline (typically 1.2–1.5×). If requests equal limits (Guaranteed QoS), state the reason — latency-sensitive, kubelet CPU-pinning, memory-predictable workload.
- **Limit policy.** Whether limits are set and why. Document the QoS class the pod lands in (Guaranteed / Burstable / BestEffort) as a consequence of the requests/limits combination — don't describe the class without naming both dimensions.
- **Capacity-planning assumptions.** Expected replica count at steady state and at peak; autoscaling inputs (HPA metric, target, min/max replicas). If no autoscaler is defined, say so explicitly and document the manual scaling trigger.
- **OOM behavior.** What the workload does when the memory limit is hit. For stateful workloads, name the consequence (lost in-flight request, corrupted buffer, etc.).

## 4. Cluster-compat matrix

Which Kubernetes minor versions the manifests have been validated against, and which API versions they rely on.

Required subsections:

- **Supported Kubernetes minor versions.** A closed range, not "latest" — e.g., "1.28–1.31". Tie each entry to a clear validation signal (kubeconform-checked against that minor's schemas, CI job name, cluster fleet this ships to).
- **API versions used.** The non-default `apiVersion`s the manifests reference, with the minor version in which each graduated to stable. Flag any `v1beta1` / `v1alpha1` use explicitly.
- **Deprecation horizon.** For each API version in use, the Kubernetes minor where it is deprecated and the minor where removal is scheduled (see [kubernetes.io/docs/reference/using-api/deprecation-guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)). If any used API is within one minor of removal, call it out in bold.
- **CRD dependencies.** Any third-party CRDs the manifests assume are installed, with the minimum operator version that provides the CRD schema in use. CRD schemas are version-pinned per operator release — pin by operator version, not just CRD name.
- **Feature-gate dependencies.** If the manifests rely on a non-default feature gate being enabled on the cluster (e.g., `ServerSideApply` defaults, admission-plugin ordering), name the gate and the minor in which it graduated.

## 5. NetworkPolicy / egress posture narrative

Prose, not YAML. The manifests already say what is allowed; documentation must say what **stance** the policies implement.

Required subsections:

- **Default posture.** Allow-all, deny-all, or segmented. For deny-all (recommended for production namespaces), state it explicitly and note the default-deny `NetworkPolicy` object that enforces it.
- **Allowed ingress.** Which pods may reach this workload, with the selector shape. Name the producer — "allowed from `app=web` pods in the same namespace" beats "allowed from `app=web`".
- **Allowed egress.** Which endpoints this workload may reach, with purpose: each allowed destination paired with one-line justification. Document explicit allowances for `kube-dns` (port 53 UDP/TCP) and for any managed-service endpoint (cloud metadata, database, object store) — otherwise silently-blocked DNS is the first breakage a reader must debug.
- **External-service policy interaction.** If the cluster runs a service mesh (Istio, Linkerd, Cilium) with its own L7 policy layer, document how NetworkPolicy and mesh policy interact here (mesh-enforced vs NetworkPolicy-enforced; fail-closed vs fail-open).
- **Known gaps.** Any traffic path that is knowingly unrestricted (e.g., inter-pod within the namespace) and the justification, so a future reader can tell an intentional omission from a missed one.

---

## Applying the rubric

For each rubric section above:

1. If the documented feature **touches** the topic (adds RBAC, defines resources, alters egress, etc.), write the section.
2. If the feature **does not** touch the topic, state "N/A — <reason>" in one line rather than omitting the heading. ("N/A — feature introduces no new ServiceAccount or RBAC binding.")
3. If the feature **assumes** the topic but inherits it from elsewhere (e.g., NetworkPolicy defined in a platform repo), cite the inherited source explicitly.

Silent omission is the failure mode this rubric exists to prevent. An explicit "N/A" communicates that the author considered the topic; an absent heading communicates nothing.
