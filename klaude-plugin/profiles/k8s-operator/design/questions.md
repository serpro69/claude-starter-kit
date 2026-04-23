# Kubernetes Operator — design question bank

Questions used during idea refinement when the `k8s-operator` profile is active. Ask one per message, per the skill's rule. Order is risk-first — start with questions whose answers most constrain subsequent design choices. Skip any question the user or the codebase has already answered (check `kk:arch-decisions`, `kk:project-conventions`, and any existing `design.md` before asking).

These questions complement the `k8s` profile's question bank. When both profiles are active, ask `k8s` questions for the deployment/manifest layer and these questions for the controller/operator layer.

## Leader election

- Leader-election mode — `Lease`-based (preferred; lowest API server load) or legacy `configmaps`/`endpoints` (deprecated in controller-runtime ≥ 0.16)? If `Lease`-based: tuning parameters (`lease-duration`, `renew-deadline`, `retry-period`) and the acceptable failover window when the leader dies.
- Replica count for HA — how many controller replicas run, and what does a non-leader replica do (idle standby, read-only cache warming, webhook serving)?
- Leader-election namespace — same namespace as the controller deployment, or a dedicated namespace? Who has RBAC to the Lease object?

## Admission webhooks

- Which webhooks does this operator expose — `MutatingAdmissionWebhook`, `ValidatingAdmissionWebhook`, or both? For each: which resources and operations (CREATE, UPDATE, DELETE) does it intercept?
- Ordering — when both mutating and validating webhooks exist, confirm the Kubernetes-enforced ordering: mutating runs first, then validating. Does the validating webhook depend on fields the mutating webhook sets?
- `failurePolicy` — `Fail` (reject the request if the webhook is unreachable — safer but risks blocking the API server) or `Ignore` (allow the request through — riskier but prevents webhook outages from blocking cluster operations)? State the rationale for each webhook independently.
- `sideEffects` — `None` (no side effects; safe for dry-run) or `NoneOnDryRun`? Webhooks that write to external systems on admission must declare `NoneOnDryRun` and handle the `dryRun: true` flag.
- `timeoutSeconds` — default is 10s; what is the expected p99 latency of the webhook handler? Set the timeout to 2–3x the expected p99 to allow for transient slowdowns without unnecessary rejections.
- TLS certificate management — cert-manager `Certificate` resource, manual secret rotation, or the operator's own self-signed CA? How is the `caBundle` in the webhook configuration kept in sync with the serving certificate?

## CRD design and conversion

- API group and version strategy — what is the API group (`<domain>/<group>`) and initial version (`v1alpha1`, `v1beta1`, `v1`)? What is the graduation plan (alpha → beta → stable) and the deprecation policy for older versions?
- Conversion webhooks — `None` strategy (all versions share the same schema) or webhook-backed conversion? If webhook-backed: which version is the hub (storage version), and how does the spoke converter handle field additions/removals/renames across versions?
- Storage version migration — when promoting a new storage version, how are existing objects migrated? Manual `kubectl get --all-namespaces | kubectl apply`, storage-version-migrator controller, or accepted risk of mixed-version objects in etcd?
- Validation — CRD structural schema validation (OpenAPI v3) only, or admission webhook validation for cross-field and external-state constraints? Which invariants are enforced at which layer?
- Status subresource — is `/status` enabled? What conditions does the controller set (types, reason codes, message format), and does the controller use `ObservedGeneration` to distinguish stale status from current?

## Reconciliation design

- Idempotency — can the reconciler be called twice with the same state and produce no side effects on the second call? What external state (cloud resources, databases, DNS records) does the reconciler manage, and how is drift detected?
- Finalizer strategy — which external resources require cleanup on CR deletion? Name each finalizer and the cleanup action it performs. What happens if cleanup fails (retry with backoff, orphan with warning, block deletion indefinitely)?
- Error backoff — on reconciliation failure, what is the requeue strategy? Fixed interval, exponential backoff with cap, or controller-runtime's default rate limiter? What is the maximum requeue delay before the operator alerts?
- Event emission — which reconciliation outcomes produce Kubernetes Events (Normal for success milestones, Warning for transient failures)? Events are the operator's primary observability channel for cluster administrators.
- Reconciliation scope — does the controller watch a single namespace, a fixed set of namespaces, or cluster-wide? What RBAC implications does each scope carry?
