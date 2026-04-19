# Kubernetes — detection

Declares when the `k8s` profile activates on a given set of files. Consumed by `klaude-plugin/skills/_shared/profile-detection.md`. Detection is additive: multiple profiles may activate on the same diff (e.g., `go` + `k8s`).

Evaluation follows the shared cost-ordered procedure (path → filename → content). Authority runs filename ≈ content > path: filename or content signals activate the profile; path alone never does, it only promotes a file to a candidate.

## Path signals

Case-insensitive substring match anywhere in the file's path. Pre-filter only — a path hit alone does NOT activate the profile.

- `k8s/`
- `manifests/`
- `charts/`
- `kustomize/`
- `deploy/`
- `templates/`

## Filename signals

Authoritative: any match activates the profile. Filename matches short-circuit content inspection for the matched file.

- `Chart.yaml` (exact) → Helm chart root.
- Any filename starting with `values` (e.g., `values.yaml`, `values.yml`, `values-prod.yaml`, `values-prod-v2-final.yaml`) when the containing directory also contains `Chart.yaml` → Helm values by adjacency. The `values*` glob has no upper bound on the wildcard; the adjacency rule (sibling `Chart.yaml` in the same directory) is the binding constraint.
- Any file with extension `.yaml`, `.yml`, or `.tpl` inside a directory named `templates/` whose chart root ancestor (any ancestor directory that contains `Chart.yaml`) is present → Helm template. This rule avoids the trap where a standalone edit to `templates/deployment.yaml` contains `{{ if ... }}` directives before any `apiVersion:` and would otherwise fail the content signal.
- Exact filenames `kustomization.yaml`, `kustomization.yml`, or `Kustomization` → Kustomize.

## Content signals

Authoritative for generic YAML files (`.yaml` or `.yml`) not already caught by a filename signal. Inspection is bounded to the first ~16 KB per file; large generated manifests beyond that bound are not inspected.

- Split the file on `---` document separators. For each `---`-separated document block, check for a top-level `apiVersion:` AND a top-level `kind:` key at zero indent. A block satisfying both is a Kubernetes manifest document.
- One matching document activates the profile for that file. The first document need not match — a file whose second or later document is the only K8s document still activates.
- A `.yaml` / `.yml` file with no matching document in any block → not Kubernetes. (It may still match another profile; generic YAML belongs to no profile by default.)

---

## Multi-profile behavior

The Kubernetes profile is **additive**. It coexists with programming-language profiles or any other IaC profile on the same diff. When Go source files sit alongside Kubernetes manifests, both `go` and `k8s` activate; downstream skills consult both profiles' content and emit findings grouped by `(profile, checklist)`.

## Dockerfile non-trigger

A Dockerfile on its own — even under a `deploy/` or `k8s/` directory — does NOT activate the `k8s` profile. Dockerfiles match no filename signal here (they are not `Chart.yaml` / `values*.yaml` / `kustomization.yaml`) and no content signal (they do not contain `apiVersion:` + `kind:`). When a Dockerfile appears in the same diff as Kubernetes manifests, `k8s` activates on the manifests' signals; the Dockerfile itself is not reviewed by this profile. A future container profile may own Dockerfiles independently.
