# Kubernetes validators — floor, menu, cluster-dependent

Three tiers. The **floor** is mandated when the `k8s` profile is active AND the binary is on `PATH` (per [presence-check-protocol.md](presence-check-protocol.md)). The **menu** is suggested and run only when the user opts in and the binary is present. **Cluster-dependent** tools need a reachable cluster and configured `kubectl`; they are never part of the floor because they cannot run offline.

For each tool, the "What it catches" line names the failure mode the check prevents — useful when a missing binary forces a fallback to descriptive guidance (see [presence-check-protocol.md](presence-check-protocol.md)).

## Floor (mandated when binary present)

### `kubeconform` — offline schema validation

Run against every matched Kubernetes YAML file (everything the detection rule activated on). Prefer `kubeconform` over `kubeval`; `kubeval` is unmaintained.

- **Command**: `kubeconform -summary -strict -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' <files>`. The extra `-schema-location` allows it to validate common third-party CRDs (cert-manager, Argo, Istio, etc.); without it, CRD kinds are reported as unknown.
- **Supply-chain note**: the catalog URL pins to `main`, so schemas can shift. Supply-chain-sensitive environments should pin to a specific commit SHA (replace `/main/` in the URL) or mirror the catalog locally.
- **Target the cluster's minor version** with `-kubernetes-version <minor>` when known (e.g., `-kubernetes-version 1.29`). Defaults to the latest bundled schema — the real risk is **false passes** for newly-introduced fields the target cluster does not yet support (not false rejections of removed fields). Validating a 1.26 cluster's manifests without `-kubernetes-version` will accept 1.30+ fields that would be rejected by the actual API server.
- **What it catches**: typos in field names, wrong types, wrong `apiVersion`/`kind` combinations, fields removed in the target Kubernetes version.
- **What it does NOT catch**: semantic issues (a Deployment without a PDB, a CronJob with a broken schedule), policy violations, RBAC over-permission. Those belong to `review-code/` checklists and the policy hook.
- **Install**: `brew install kubeconform` or `go install github.com/yannh/kubeconform/cmd/kubeconform@latest`.

### `helm lint` — Helm chart sanity

For each Helm chart directory in the diff (identified by `Chart.yaml`), run `helm lint <chart-dir>`. When the chart ships a `values.schema.json`, `helm lint` already validates `values` against it automatically — that validation is **not** gated on `--strict`. Add `helm lint --strict <chart-dir>` when you want warnings (missing `NOTES.txt`, deprecated APIs) promoted to errors.

- **Command**: `helm lint <chart-dir>`; optionally `helm lint --strict <chart-dir>` to elevate warnings.
- **What it catches**: invalid `Chart.yaml` metadata, broken Go-template syntax in `templates/`, malformed YAML after render, `values.schema.json` violations (when the schema file is present — unconditionally), deprecated-API warnings. `--strict` promotes those warnings to errors.
- **What it does NOT catch**: Kubernetes-schema errors in the rendered output — `helm lint` validates the chart, not the cluster-side artifacts. Follow with `helm template <chart-dir> | kubeconform -` for schema coverage over the rendered manifests.
- **Install**: `brew install helm` or https://helm.sh/docs/intro/install/.

### `kustomize build` — Kustomize render check

For each Kustomize directory in the diff (identified by `kustomization.yaml` / `kustomization.yml` / `Kustomization`), run `kustomize build <kustomize-dir>` and confirm it exits 0. Pipe the rendered output into `kubeconform` so Kustomize changes are schema-checked too.

- **Command**: `kustomize build <kustomize-dir>` (exit 0 check) and `kustomize build <kustomize-dir> | kubeconform -summary -strict -`.
- **What it catches**: patch target mismatches, broken `resources:` references, missing bases, generator errors.
- **What it does NOT catch**: semantic issues in the rendered output; that is what piping into `kubeconform` (and the `review-code/kustomize-checklist.md` checks) is for.
- **Install**: `brew install kustomize` or `go install sigs.k8s.io/kustomize/kustomize/v5@latest`. `kubectl kustomize` is an acceptable fallback for older workflows — it is bundled inside `kubectl` and does not require a separate install, but the bundled version lags standalone Kustomize. Prefer standalone when available.

## Menu (suggested, run when user opts in and binary present)

These tools overlap in coverage; projects typically adopt one of the best-practices linters and one of the security scanners rather than all of them. Surface the list as a menu so the user can opt in explicitly.

### Best-practices linters

- **`kube-score`** — scores manifests against a fixed best-practices ruleset (probes, resource limits, `imagePullPolicy`, `runAsNonRoot`, etc.). Command: `kube-score score <files>`. Install: `brew install kube-score` or https://github.com/zegl/kube-score/releases.
- **`kube-linter`** — pluggable linter with a built-in check catalog; disable/enable specific checks via config. Command: `kube-linter lint <files>`. Install: `brew install kube-linter` or `go install github.com/stackrox/kube-linter/cmd/kube-linter@latest` (the `golang.stackrox.io` vanity path also resolves but the GitHub module path is canonical).
- **`polaris`** — opinionated auditor with a web UI for cluster-level auditing and a CLI for manifest mode. Command: `polaris audit --audit-path <dir>` (flag verified against FairwindsOps/polaris docs). Install: `brew tap FairwindsOps/tap && brew install FairwindsOps/tap/polaris` or https://github.com/FairwindsOps/polaris/releases — note: a bare `brew install polaris` resolves to an unrelated Homebrew formula; the FairwindsOps tap is required.

Overlap note: `kube-score` and `kube-linter` and `polaris` raise materially different subsets; pick one as the primary and revisit only if the project outgrows it.

### Security scanners

- **`trivy config`** — Trivy's IaC scanner, covers Kubernetes, Dockerfile, Terraform, and more. Command: `trivy config <dir-or-file>`. Install: `brew install trivy` or https://github.com/aquasecurity/trivy/releases.
- **`checkov`** — Python-based IaC scanner; deep ruleset for Kubernetes. Command: `checkov --directory <dir> --framework kubernetes`. Install: `pip install checkov` or `brew install checkov`.
- **`kics`** — Checkmarx's IaC scanner; overlaps with `trivy` / `checkov`. Command: `kics scan --path <dir>`. Install: `brew install kics` or https://github.com/Checkmarx/kics/releases.

Significant rule overlap exists between `checkov` and `kics` — running both against the same manifests is mostly redundant. A common mature-pipeline pattern is `trivy` (container/CVE scanning) paired with one IaC scanner (`checkov` or `kics`); the two serve complementary audiences rather than overlapping ones, so that pairing is typically cheap.

### Offline pre-flights (optional, complement `kubeconform`)

- **`yamllint`** — generic YAML syntax / style linter; catches malformed YAML before schema validation fires. Especially useful when `kubeconform` produces confusing parse errors. Command: `yamllint <dir-or-file>`. Install: `brew install yamllint` or `pip install yamllint`.
- **`kubectl validate`** — Kubernetes 1.28+ offline schema validation using the built-in OpenAPI schemas. An alternative when `kubeconform` is not installed; does not cover third-party CRDs out of the box. Command: `kubectl validate -f <files>` (requires kubectl 1.28+).

## Cluster-dependent optional (requires live cluster + `kubectl`)

Excluded from the floor because they cannot run offline. Mention them only if the user states a cluster is available.

- **`kubectl --dry-run=server`** — server-side validation using the actual cluster's API server. Catches admission-controller rejections and CRD-version mismatches that offline tools cannot see. Command: `kubectl apply --dry-run=server -f <files>`. **RBAC caveat**: the calling identity still needs `get` / `create` / `patch` permissions on every kind touched — the dry-run flag does not bypass authorization. In restricted CI environments the call 403s silently, producing "forbidden" errors that look like validation failures; verify the kubeconfig's context has sufficient privileges before inferring that a dry-run failure is a manifest bug. Install: `kubectl` ships with most Kubernetes installs; `brew install kubectl` otherwise.
- **`popeye`** — sanitizer that checks a running cluster for dead code, unhealthy resources, and config smells. Not a pre-merge validator; useful for cluster health audits. Command: `popeye`. Install: `brew install derailed/popeye/popeye` or https://github.com/derailed/popeye/releases.

## What to report

For each floor validator: run-summary line naming tool + status (`[OK]`, `[FAIL]`, `[SKIP — binary not installed]`). For `[FAIL]`, include the tool's own output. For missing binaries, include the install hint from [presence-check-protocol.md](presence-check-protocol.md).

For menu and cluster-dependent tools: only report what ran. Do not list skipped menu tools — the user did not opt in, so listing them as `[SKIP]` is noise.
