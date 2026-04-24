# Kubernetes — document artifacts

Consumed by the `document` skill when the `k8s` profile is active. The rubric below enumerates topics that documentation for Kubernetes artifacts must cover. Declarative infrastructure has no runtime self-documentation — an operator looking at a broken cluster at 03:00 needs the documentation to tell them what was intended, why it was intended, and how to roll back. How to satisfy each rubric section (write / N/A / inherit) is governed by `document/SKILL.md` guideline #3.

## Always load

- [rubric.md](rubric.md) — required documentation topics for Kubernetes artifacts: RBAC decision rationale (incl. Pod Security Standards posture), rollback runbook, resource-baseline reasoning, cluster-compat matrix, and NetworkPolicy/egress posture narrative.
