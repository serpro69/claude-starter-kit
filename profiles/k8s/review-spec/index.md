# Kubernetes review-spec content

Verification patterns for comparing Kubernetes implementations against their design specifications. The core IaC semantic shift — declarative artifacts ARE the implementation — is documented in the `review-spec` skill files; this index provides K8s-specific verification targets.

## Always load

- [type-mapping.md](type-mapping.md) — K8s-specific finding-type mapping: how to verify resource presence, field values, and relationship chains against design specs. Applies to all K8s artifacts (plain manifests, Helm, Kustomize).

## Conditional

- [helm-verification.md](helm-verification.md) — Helm-specific spec verification patterns for Chart.yaml metadata, values.yaml defaults, template conditionals, and chart dependencies. **Load if:** the diff contains a file named `Chart.yaml`; OR a file named `values*.yaml` in a directory that also contains `Chart.yaml`; OR a file under a `templates/` directory whose parent contains `Chart.yaml`.

- [kustomize-verification.md](kustomize-verification.md) — Kustomize-specific spec verification patterns for base/overlay structure, patch targets, and generator usage. **Load if:** the diff contains a file named `kustomization.yaml`, `kustomization.yml`, or `Kustomization`; OR a file under a `bases/` or `overlays/` directory.
