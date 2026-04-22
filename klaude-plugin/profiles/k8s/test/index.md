# Kubernetes — test artifacts

Consumed by the `test` skill when the `k8s` profile is active. The three files below are always-loaded; they cooperate — the presence-check protocol gates every validator named in `validators.md` and `policy-hook.md`, so read it first.

## Always load

- [presence-check-protocol.md](presence-check-protocol.md) — before running any validator, check that its binary is on `PATH`. If missing, surface a per-tool install hint and fall back to descriptive guidance or a "skipped" note — never attempt blind execution. Applies to floor, menu, and policy tools alike; a missing floor binary does NOT block the test run.
- [validators.md](validators.md) — the **floor** (mandated when a binary is present): `kubeconform` on matched YAML, `helm lint` on each Helm chart directory, `kustomize build` on each Kustomize directory. The **menu** (opt-in, binary present): `kube-score`, `kube-linter`, `polaris`, `trivy config`, `checkov`, `kics`. Cluster-dependent optional tools (`kubectl --dry-run=server`, `popeye`) require a reachable cluster and configured `kubectl`.
- [policy-hook.md](policy-hook.md) — auto-detection rules for project-local policy toolchains (Conftest / OPA, Kyverno, Gatekeeper). Each rule is gated by BOTH a project marker AND the binary being on `PATH`. No markers → skipped silently, no install hints surfaced.
