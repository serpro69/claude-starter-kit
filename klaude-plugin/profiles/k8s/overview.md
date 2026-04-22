# Kubernetes profile

## What this profile covers

Kubernetes declarative artifacts: plain manifests, Helm charts (`Chart.yaml`, `values*.yaml`, `templates/`), and Kustomize overlays (`kustomization.yaml`, bases, overlays). The profile is concerned with the shape, safety, and reliability of resources that will be applied to a cluster — not with application source code running inside pods.

Adjacent-but-out-of-scope: Dockerfiles (future container profile), cloud-provider IaC (Terraform, Pulumi, CloudFormation), generic YAML (CI config, linter rules). See [DETECTION.md](DETECTION.md) for the authoritative activation rule and the Dockerfile non-trigger note.

## When it activates

Any of the following in the current scope:

- A file whose filename matches a Helm or Kustomize signal (`Chart.yaml`, `values*.yaml` adjacent to a `Chart.yaml`, `kustomization.yaml`, `.yaml`/`.yml`/`.tpl` under a chart's `templates/` directory).
- A `.yaml` / `.yml` file with a document containing both top-level `apiVersion:` and `kind:` at zero indent in any `---`-separated block (bounded inspection ~16 KB).

Path signals (`k8s/`, `manifests/`, `charts/`, `kustomize/`, `deploy/`, `templates/`) are candidate pre-filters only — path alone never activates the profile. See [DETECTION.md](DETECTION.md) for the full rule.

Activation is additive with other profiles on the same diff (e.g., a Go service repo with a Helm chart activates both `go` and `k8s`).

## Populated phases

- `review-code/` — security, architecture, quality, reliability checklists plus Helm/Kustomize-specific checklists and a `removal-plan.md` template, loaded via `index.md`.
- `design/` — idea-refinement question bank and required-sections list, loaded via `index.md`.
- `implement/` — per-task pre-write gotchas, loaded via `index.md`.
- `test/` — validator catalog (floor / menu / cluster-dependent), policy-toolchain auto-detection, and a binary-presence protocol, loaded via `index.md`.
- `document/` — doc rubric enumerating required topics for Kubernetes artifacts (RBAC rationale, rollback runbook, resource baseline, cluster-compat matrix, NetworkPolicy posture), loaded via `index.md`.

Phase `review-spec/` may be populated in a later phase of the profile's rollout; consult its `index.md` when present.

## Architecture in one paragraph

Kubernetes is declarative: every resource is a desired-state document (`apiVersion`, `kind`, `metadata`, `spec`) reconciled by a controller. Workloads (`Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`) create Pods; config is injected via `ConfigMap` / `Secret` / env; traffic flows through `Service` / `Ingress` / `NetworkPolicy`; access is mediated by `ServiceAccount` / `Role` / `RoleBinding` / `ClusterRole*`. Helm packages a parameterized bundle of these documents (`Chart.yaml` metadata + `values*.yaml` inputs + `templates/` Go-template manifests). Kustomize composes them via base + overlay patching without templating. Reviews should treat missing resources (e.g., a workload without a `PodDisruptionBudget`) as a potential spec gap, not a neutral omission — absence is meaningful in declarative systems.

## Looking up Kubernetes dependencies

When adding, modifying, or upgrading a Kubernetes-facing dependency, follow the `dependency-handling` skill's cascade (capy-first, context7-second, web-last) against the target below. Per-category targets:

1. **Kubernetes API versions** (built-in resources and their fields)
   - capy: project's indexed API-version decisions and prior context7 fetches.
   - context7: `kubernetes.io` docs; target the cluster's minor version, not the latest.
   - Local fallback: `kubectl explain <resource>` / `kubectl explain <resource>.<field> --recursive` against the cluster the manifests target.
   - web: [kubernetes.io/docs/reference](https://kubernetes.io/docs/reference/) for the specific minor version.

2. **Third-party CRDs** (operators, service meshes, controllers)
   - capy: prior project fetches for the operator's CRDs.
   - context7: the operator/controller project's documentation (e.g., cert-manager, external-secrets, Argo CD).
   - web: the operator's GitHub repository README, `config/crd/bases/*.yaml`, and release notes for the installed version. CRD schemas are version-pinned per operator release — always verify against the actually-installed version.

3. **Helm chart versions** (chart authors + chart dependencies)
   - capy: prior fetches for the chart's README and values reference.
   - Local: `helm show chart <chart>`, `helm show values <chart>`, and the chart's `Chart.yaml`/`values.yaml` themselves.
   - web: the chart's repository README and `CHANGELOG.md`. Pin `dependencies[]` in `Chart.yaml` by strict semver or digest; treat floating tags as unsafe.

4. **Container images** (tags, digests, supply-chain metadata)
   - capy: prior indexed image-digest decisions and registry metadata fetches for this project.
   - context7: n/a — container registries have no context7 entry; registry APIs are the authoritative source.
   - Local: `skopeo inspect docker://<image>:<tag>` or `crane manifest <image>:<tag>` to read the manifest and retrieve the digest.
   - Registry metadata: pull digest (`sha256:...`) and record alongside the tag; prefer digests over mutable tags in manifests.
   - web: the image's registry listing page and upstream release notes for the underlying software.

Version-specific behavior must always be verified against the version the cluster/chart/image actually resolves to, not the latest available.
