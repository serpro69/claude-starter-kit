# Kubernetes Operator — required design sections

Every `design.md` for an operator-shaped feature must include the four sections below. Omit none; if a section genuinely does not apply, state so explicitly with a one-line justification — silent omissions hide scope gaps, and a reviewer (or `review-spec`) cannot tell absence-by-intent from absence-by-oversight.

These sections complement the `k8s` profile's required sections. When both profiles are active, the design document must include sections from both profiles.

## CRD schema design

- API group, domain, and version(s) with graduation plan (alpha → beta → stable).
- Resource scope — namespaced or cluster-scoped? Justify the choice against multi-tenancy requirements.
- Structural schema — top-level spec/status split; key fields with types, validation rules (minimum, maximum, enum, pattern), and default values. Printer columns for `kubectl get` output.
- Subresources — `/status` (required for most controllers), `/scale` (if the CR represents a scalable workload).
- Short names and categories for kubectl discoverability.
- Version strategy — if multiple versions exist: which is the storage version, the hub version for conversion, and the deprecation timeline for older versions.

## Reconciliation loop architecture

- Trigger sources — which resources does the controller watch (owned CRs, child resources via `Owns()`, related resources via `Watches()`)? Map each watch to the reconciliation action it triggers.
- State machine — enumerate the reconciliation states (e.g., Pending → Provisioning → Ready → Degraded → Deleting) and the transitions between them. Each state must have: entry condition, exit condition, and the status condition(s) it sets.
- Requeue strategy — for each state, specify whether reconciliation requeues (and at what interval) or waits for the next watch event. Document the maximum requeue delay and the alert threshold for stuck reconciliations.
- External dependencies — cloud APIs, databases, DNS providers, or other operators this controller calls during reconciliation. For each: timeout, retry policy, circuit-breaker threshold, and the reconciliation behavior when the dependency is unavailable.
- Idempotency contract — state explicitly which operations are idempotent and which require guard checks (create-if-not-exists, update-if-changed). Document the drift-detection mechanism for external state.
- Finalizer lifecycle — which finalizers the controller adds, when they are added (at creation or first reconciliation), what cleanup each performs, and the failure/timeout behavior for each cleanup action.

## RBAC generation scope

- ClusterRole vs Role — does the controller need cluster-wide permissions or namespace-scoped only? If cluster-wide: justify each cluster-scoped verb.
- Generated RBAC markers — list each `// +kubebuilder:rbac:` marker with its group, resource, and verbs. For each verb beyond `get`, `list`, `watch`: one-line justification.
- Least-privilege audit — enumerate which permissions the controller does NOT need and why they were excluded (e.g., "no `delete` on `secrets` because the controller reads but never removes secrets").
- ServiceAccount — dedicated ServiceAccount name, namespace, and any annotations required for cross-service authentication (workload identity, IRSA, GKE WI).
- Aggregated ClusterRoles — if the operator defines ClusterRoles for end-users (admin, editor, viewer) via aggregation labels, document each role's permission set.

## Webhook topology

- Webhook inventory — for each webhook (mutating, validating, conversion): target resource, operations, `failurePolicy`, `sideEffects`, `timeoutSeconds`, and `matchPolicy` (Exact or Equivalent).
- Ordering and dependencies — when multiple webhooks exist, document the execution order (mutating before validating is Kubernetes-enforced; within each category, ordering is undefined unless `reinvocationPolicy` is set). State whether any validating webhook depends on mutations applied by a mutating webhook.
- Certificate management — how the webhook's TLS certificate is provisioned (cert-manager `Certificate`, self-signed CA, manual rotation), how `caBundle` in the webhook configuration is kept in sync, and the certificate rotation procedure.
- Availability and blast radius — what happens when the webhook pod is unavailable? Combine with `failurePolicy` to state the user-visible impact (e.g., "`Fail` + webhook down = all CREATE/UPDATE on the CR are rejected cluster-wide until the webhook recovers").
- Dry-run handling — do the webhooks correctly handle `dryRun: true` requests? Webhooks with `sideEffects: None` must be pure functions; `NoneOnDryRun` webhooks must skip side effects when `dryRun` is set.
