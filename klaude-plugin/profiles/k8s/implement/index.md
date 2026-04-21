# Kubernetes — implement artifacts

Consumed by the `implement` skill when the `k8s` profile is active for the current sub-task. These are **pre-write** gotchas — read them before editing manifests, not after, so the post-write `review-code` pass does not have to catch avoidable mistakes.

## Always load

- [gotchas.md](gotchas.md) — per-task pitfalls: API-version pinning, probe correctness, image-tag immutability, resource limits discipline, namespace + label hygiene, CRD-before-CR ordering, webhook timing.
