# ADR 0001 — Profile/language detection remains a single additive axis

- **Status:** Accepted
- **Date:** 2026-04-17
- **Originated in:** [docs/wip/kubernetes-support/design.md](../wip/kubernetes-support/design.md)
- **Related:** [ADR 0002](0002-profile-content-organization.md), [ADR 0003](0003-plugin-root-referenced-content.md)

## Context

The `review-code` skill has historically detected a single "primary language" from file extensions and loaded per-language reference checklists from `reference/<lang>/`. Extensions mapped to reference sets: `.go` → `reference/go/`, `.py` → `reference/python/`, etc. Other skills (`test`, `document`, `design`) use a `%LANGUAGE%` placeholder in their prose.

Adding Kubernetes support surfaces a question the existing model did not address: K8s is not a programming language in the classical sense — it is a schema overlay on YAML (plus Helm templating and Kustomize composition). Whether to model K8s as another "language" row or as a parallel concept materially affects every skill touched by this and all future non-programming-language profiles (Terraform, Dockerfile, Ansible collections, …).

The question is foundational because it dictates:
- whether existing skills need a new dimension in their frontmatter/prose, or just new rows in an existing table,
- whether a Go service with Kubernetes manifests loads one reference set or two,
- how much refactor cost falls on this feature versus a future one.

## Decision

**Detection remains a single axis. All detectable artifact types — programming languages, IaC DSLs (Terraform/HCL), config schemas (K8s, Helm, Kustomize), and future additions — are equal rows in one detection table. Matching a file contributes that row's reference directory to the set loaded for the current task. Multiple matches are additive — the skill loads every matching set.**

The term "language" is retained. Editor tooling (LSP, VS Code) already uses "language" as an umbrella term for YAML, Dockerfile, HCL, JSON, Markdown, and other non-programming-language file formats. Adopting the LSP-aligned framing keeps the existing prose honest rather than forcing a terminology rewrite.

## Alternatives considered

### A. Mutually exclusive: K8s *replaces* the detected language

Adding `kubernetes` to the detection table as yet another language, with the existing "one wins" rule preserved. Simplest possible change.

**Rejected.** Breaks cloud-native repositories where application code and Kubernetes manifests coexist in the same diff. A Go service with a Deployment manifest would load *either* `reference/go/` *or* `reference/kubernetes/`, never both. The reviewer would miss half the findings.

### C. Orthogonal axis: language × profiles

Introduce a `profiles: []` dimension parallel to `language`. A project has at most one programming language but zero or more profiles (k8s, terraform, ansible). Each skill's frontmatter, prose, and reference-loading logic gains a parallel axis.

**Rejected for now.** Larger refactor: every consuming skill grows a parallel concept in its frontmatter and body. The justification for paying that cost would be behavioral divergence between the axes — e.g., different severity weighting, different reviewer agents, different `%LANGUAGE%` prose treatment. No such divergence is required today; introducing the axis speculatively is premature architecture.

This ADR records C as the forward-compatible migration target rather than a dead end. B is a proper subset of C — if C is ever adopted, the detection rows simply gain a `kind:` discriminator (`programming-language` | `iac` | `config-schema`) and prose begins to branch on it. Reference directories themselves do not move.

## Consequences

**Positive**
- Minimal architectural churn. One detection step, one load rule, one placeholder.
- Loading is naturally additive — a Go + K8s diff loads both reference sets; `%LANGUAGE%` retains its "programming language" meaning; profile content is consulted additively.
- Matches LSP mental model already familiar to contributors.
- Forward-compatible with C: no content moves if we later migrate.

**Negative**
- The word "language" is a mild stretch for some entries (K8s is a schema overlay on YAML, not a language proper). The LSP framing mitigates this but does not eliminate the ambiguity for a reader encountering the term fresh.
- Homogeneous severity/handling across programming languages and IaC profiles. If the plugin ever needs to treat (say) a deprecated Helm chart differently from a deprecated Go package, a migration to C is required.

**Neutral**
- Reference directories keep their role as checklist bundles, regardless of whether the matching row is a programming language or an IaC DSL.

## Forward-compatibility: migration path to C

If behavioral divergence between programming-language profiles and non-language profiles ever becomes necessary, the migration from B to C is mechanical and does not rewrite content:

1. **Add a `kind:` field** to each profile's top-level metadata (`DETECTION.md` or `overview.md` frontmatter): `programming-language`, `iac`, `config-schema`, etc.
2. **Add a `profiles:` array** to skill frontmatter where it needs to distinguish the axes — separate from any `language:` field if one exists. Consumers opt in per skill.
3. **Fork prose** in the skills whose treatment should diverge. For most skills, prose will remain unchanged: the `%LANGUAGE%` placeholder keeps its current semantics.
4. **No file moves.** Reference directories stay at their chosen locations (see [ADR 0002](0002-profile-content-organization.md)).

Trigger conditions that would warrant starting this migration (non-exhaustive):
- Severity weighting needs to differ between programming-language and IaC findings.
- A skill's reviewer agent needs to be chosen by kind (e.g., a dedicated IaC reviewer).
- Prose in `test`/`document`/`design` needs to say something meaningfully different for IaC — where the additive "plus, consult profile-specific guidance" clause no longer suffices.

Until at least one such trigger fires, B remains the decision.

## References

- [design.md — Detection mechanics](../wip/kubernetes-support/design.md#detection-mechanics)
- [design.md — Profile content organization](../wip/kubernetes-support/design.md#file-structure)
- LSP language-ID registry (for the umbrella-term precedent): https://microsoft.github.io/language-server-protocol/
