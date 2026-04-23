# Kubernetes Operator profile

## What this profile covers

Kubernetes controller and operator authoring using kubebuilder, operator-sdk, or raw controller-runtime. The profile is concerned with the design and implementation of custom controllers that reconcile Custom Resource Definitions (CRDs) — not with the manifests those controllers generate or consume (that's the `k8s` profile's domain).

Adjacent-but-out-of-scope: plain Kubernetes manifests, Helm charts, Kustomize overlays (owned by `k8s`), application business logic that happens to run in a pod but is not a controller, generic Go code (owned by `go`).

## When it activates

Any of the following in the current scope:

- A `PROJECT` file (kubebuilder marker) in the repository.
- Files under `config/crd/` or `config/webhook/` (generated CRD/webhook kustomize configuration).
- A `Makefile` containing `controller-gen` or a `manifests:` target.
- Go source files importing `sigs.k8s.io/controller-runtime`.

Path signals (`internal/controller/`, `api/`, `controllers/`) are candidate pre-filters only — path alone never activates. See [DETECTION.md](DETECTION.md) for the full rule.

## Relationship to the `k8s` profile

Activation is **additive**. An operator project typically activates both profiles: `k8s-operator` for the controller code it authors, and `k8s` for the manifests it generates or deploys (CRD YAMLs, RBAC manifests, webhook configurations). Downstream skills consult both profiles and emit findings grouped by `(profile, checklist)`.

## Populated phases

- `design/` — operator-specific question bank (leader election, admission webhooks, CRD conversion, reconciliation design) and required design sections, loaded via `index.md`.

Not populated initially: `review-code/`, `implement/`, `test/`, `document/`, `review-spec/`. Content follows when real demand surfaces.

## Architecture in one paragraph

A Kubernetes operator extends the API server with Custom Resource Definitions and runs a controller that watches those CRDs (and optionally built-in resources) via informers. The controller's reconciliation loop receives a `Request` (namespace + name), reads the current state, computes the desired state, and writes the delta — all idempotently. The kubebuilder scaffolding generates `PROJECT` metadata, `api/` type definitions, `internal/controller/` reconciler stubs, `config/` kustomize bases (CRDs, RBAC, webhooks), and a `Makefile` with `controller-gen` targets. Admission webhooks (mutating, validating) and conversion webhooks are optional extensions. Leader election ensures only one replica reconciles at a time in HA deployments.

## Looking up operator dependencies

When adding, modifying, or upgrading an operator-facing dependency, follow the `dependency-handling` skill's cascade (capy-first, context7-second, web-last) against the targets below.

1. **controller-runtime** (core operator library)
   - capy: prior project fetches for controller-runtime APIs.
   - context7: `sigs.k8s.io/controller-runtime` documentation.
   - web: [controller-runtime GoDoc](https://pkg.go.dev/sigs.k8s.io/controller-runtime) and the project's GitHub releases for version-specific API changes.

2. **kubebuilder** (scaffolding and project layout)
   - capy: prior fetches for kubebuilder CLI usage and project layout.
   - context7: kubebuilder book documentation.
   - web: [kubebuilder book](https://book.kubebuilder.io/) for the project layout version the `PROJECT` file declares.

3. **operator-sdk** (alternative scaffolding, OLM integration)
   - capy: prior fetches for operator-sdk CLI and OLM bundle format.
   - context7: operator-sdk documentation.
   - web: [sdk.operatorframework.io](https://sdk.operatorframework.io/) for the installed SDK version.

4. **controller-gen** (CRD/RBAC/webhook manifest generation)
   - capy: prior fetches for controller-gen marker syntax.
   - context7: controller-tools documentation.
   - web: [controller-tools GitHub](https://github.com/kubernetes-sigs/controller-tools) — marker syntax is version-pinned; verify against the `CONTROLLER_TOOLS_VERSION` in the project's Makefile.
