# Kubernetes — document artifacts

Consumed by the `document` skill when the `k8s` profile is active. The rubric below enumerates topics that documentation for Kubernetes artifacts must cover. Declarative infrastructure has no runtime self-documentation — an operator looking at a broken cluster at 03:00 needs the documentation to tell them what was intended, why it was intended, and how to roll back. Missing any rubric item is a documentation gap; if a topic is genuinely inapplicable (e.g., no RBAC changes in the feature), state that explicitly rather than omitting silently.

## Always load

- [rubric.md](rubric.md) — required documentation topics for Kubernetes artifacts: RBAC decision rationale, rollback runbook, resource-baseline reasoning, cluster-compat matrix, and NetworkPolicy/egress posture narrative.
