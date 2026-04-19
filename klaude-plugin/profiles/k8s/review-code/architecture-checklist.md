# Kubernetes — Architecture Checklist

Declarative-resource shape, separation of concerns, and cluster-vs-application boundaries. Applied whenever the `k8s` profile is active.

## Contents

- One primary concern per resource
- Config injection vs hardcoded values
- No hardcoded cluster assumptions
- Explicit selectors and labels
- Cluster vs application separation

## One primary concern per resource

- Each resource manifest addresses a single concern. A `Deployment` that bundles two unrelated workloads (e.g., API server + batch worker) under one Pod template is a P1 finding — split into two Deployments.
- Init containers are for setup that the main container cannot do itself (schema migration, secret templating, permission fix-ups). An init container doing actual application work should be its own Pod.
- Sidecars carry one cross-cutting concern each (log shipper, metrics exporter, proxy). A sidecar that shares application business logic is a design smell.
- `Service` resources expose one logical endpoint. A `Service` routing traffic to Pods from multiple unrelated workloads via clever label selectors is fragile.
- `ConfigMap` and `Secret` resources are scoped to one consumer when possible. A "shared config" `ConfigMap` mounted by many unrelated workloads creates hidden coupling.

## Config injection vs hardcoded values

- Configuration values (URLs, flags, tuning parameters, connection strings) flow through `env`, `envFrom`, or volume-mounted `ConfigMap` / `Secret` — never hardcoded in the container image or in static manifest literals that should differ per environment.
- Hostnames: use cluster-local DNS (`svc.cluster.local`) by name, not by IP. IP literals in manifests are a P1 finding — they break on cluster migration.
- URLs pointing to cluster-internal services use the short form (`myservice` or `myservice.ns`), not hardcoded fully qualified domain names tied to a specific cluster domain.
- Boolean/enum flags that change per environment (debug vs prod, feature toggles) come from `ConfigMap`, not compile-time constants.
- `ConfigMap` vs `Secret` choice: secret material → `Secret`; non-secret config → `ConfigMap`. Mixing sensitive values into `ConfigMap` is a security finding (see security-checklist.md) but also an architectural one: it conflates two concerns.

## No hardcoded cluster assumptions

- No hardcoded namespace strings in resource `spec` (outside `metadata.namespace` which is the resource's own namespace). If a Pod references another workload, use `Service` DNS, not `http://other-svc.prod-env/...`.
- No hardcoded node names, node-pool identifiers, or availability-zone names — use `nodeSelector` / `nodeAffinity` / `topologySpreadConstraints` with semantic labels (`topology.kubernetes.io/zone`, `node.kubernetes.io/instance-type`).
- No hardcoded image registry hosts in multiple places; prefer a single templated or generated value (Helm `.Values.image.registry`, Kustomize image transformer).
- Cluster domain (`cluster.local`) not hardcoded in FQDNs — workloads that need the full domain should read it from the Pod's resolv.conf or the `spec.dnsConfig`.
- PersistentVolume / StorageClass names pulled from a template value or an overlay, not literal `gp2-us-east-1` strings inside generic workload manifests.

## Explicit selectors and labels

- `Deployment.spec.selector.matchLabels` matches `Deployment.spec.template.metadata.labels` exactly. A drift between the two is accepted by the API server in some versions and rejected in others — always a finding.
- `Service.spec.selector` names the labels that identify the intended Pods — no wildcard-ish matching by overly broad selectors (e.g., selecting only on `app.kubernetes.io/part-of`).
- Selectors pin to **immutable** labels on the Pod template. Labels that change over time (version, build hash) should not be in the selector — they'd break the Deployment's own rollout.
- Recommended label set applied consistently (see quality-checklist.md for the full set): `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`.
- No reliance on auto-generated labels (e.g., `pod-template-hash`) in selectors authored by humans — they are controller-managed.

## Cluster vs application separation

- Application code does not assume it is running in Kubernetes — the manifests inject the Kubernetes-specific concerns (service discovery via env, secrets via files, config via mounts). Code that calls the Kubernetes API from the application path is a design decision that needs rationale.
- Conversely, Kubernetes-specific operational concerns (probes, lifecycle hooks, graceful shutdown) are driven by the manifests, not by hardcoding cluster topology into application config files.
- Infrastructure resources (CRDs, operators, storage classes, network policies that apply cluster-wide) live in their own manifests, not mixed with application workload manifests. A `Deployment` next to a `CustomResourceDefinition` in the same file is a composition smell.
- Don't conflate platform concerns (ingress controller, cert-manager, monitoring stack) with application concerns in the same chart or kustomization — platform lifecycle and application lifecycle differ.

## Questions to ask

- "If I applied this manifest to a different cluster, what would break?" — surfaces hardcoded assumptions.
- "If I split this resource into two, would each half still make sense?" — surfaces violated single-concern scope.
- "What does the application know about Kubernetes, and what does Kubernetes know about the application?" — clarifies the boundary.
