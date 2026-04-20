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
- Any filename starting with `values` (e.g., `values.yaml`, `values.yml`, `values-prod.yaml`, `values-prod-v2-final.yaml`) when the containing directory also contains `Chart.yaml` → Helm values by adjacency. The `values*` glob has no upper bound on the wildcard; the adjacency rule (sibling `Chart.yaml` in the same directory) is the binding constraint. The match is filename-plus-adjacency only — file content is not inspected, so a file named `values-backup.yaml` next to a `Chart.yaml` activates regardless of what it actually contains.
- Any file with extension `.yaml`, `.yml`, or `.tpl` inside `<dir>/templates/` where `<dir>` itself contains a `Chart.yaml` as a direct child → Helm template. The binding constraint is that the `templates/` directory must sit *directly* next to a `Chart.yaml` — i.e., at a chart root or a subchart root under `<parent>/charts/<subchart>/`. A `templates/` nested elsewhere in the tree (e.g., `docs/templates/`, `ci/templates/`) does NOT activate this rule even when a `Chart.yaml` sits at the repository root, because `docs/` and `ci/` do not themselves contain a `Chart.yaml`. This avoids the monorepo false-positive where a repo-root umbrella `Chart.yaml` would otherwise claim every `templates/` directory in the tree. It still avoids the trap where a standalone edit to `<chart-root>/templates/deployment.yaml` contains `{{ if ... }}` directives before any `apiVersion:` and would otherwise fail the content signal.
- Exact filenames `kustomization.yaml`, `kustomization.yml`, or `Kustomization` → Kustomize.

## Content signals

Authoritative for generic YAML files (`.yaml` or `.yml`) not already caught by a filename signal. Inspection is bounded to the first ~16 KB per file; large generated manifests beyond that bound are not inspected.

- Split the file on `---` document separators. For each `---`-separated document block, check for a top-level `apiVersion:` AND a top-level `kind:` — parsed as YAML mapping keys at zero indent, not as substrings inside block scalars (`|`, `>`) or comments. A block satisfying both is a Kubernetes manifest document.
- One matching document activates the profile for that file. The first document need not match — a file whose second or later document is the only K8s document still activates.
- A `.yaml` / `.yml` file with no matching document in any block → not Kubernetes. (It may still match another profile; generic YAML belongs to no profile by default.)

---

## Multi-profile behavior

The Kubernetes profile is **additive**. It coexists with programming-language profiles or any other IaC profile on the same diff. When Go source files sit alongside Kubernetes manifests, both `go` and `k8s` activate; downstream skills consult both profiles' content and emit findings grouped by `(profile, checklist)`.

## Dockerfile non-trigger

A Dockerfile on its own — even under a `deploy/` or `k8s/` directory — does NOT activate the `k8s` profile. Dockerfiles match no filename signal here (they are not `Chart.yaml` / `values*.yaml` / `kustomization.yaml`) and no content signal (they do not contain `apiVersion:` + `kind:`). When a Dockerfile appears in the same diff as Kubernetes manifests, `k8s` activates on the manifests' signals; the Dockerfile itself is not reviewed by this profile. A future container profile may own Dockerfiles independently.
