# Helm-specific spec verification

Verification patterns for comparing Helm chart implementations against design specifications. Load alongside `type-mapping.md` when Helm signals are present in the diff.

## Chart.yaml metadata

| Design constraint | Chart.yaml field | Finding type if mismatch |
|---|---|---|
| Target app version | `appVersion` | `SPEC_DEV` |
| K8s compat range from cluster-compat matrix | `kubeVersion` | `SPEC_DEV` (wrong range) or `MISSING_IMPL` (absent) — only if design specifies cluster-compat matrix |
| Chart API version | `apiVersion` (should be `v2`) | `SPEC_DEV` |
| Chart dependencies | `dependencies[]` entries | `MISSING_IMPL` (dep missing) or `SPEC_DEV` (version/repo wrong) |

If the design includes a cluster-compat matrix specifying supported Kubernetes versions, `kubeVersion` must express a constraint consistent with that matrix. Absent `kubeVersion` when the design specifies version bounds is `MISSING_IMPL`.

## values.yaml defaults

Each design decision that maps to a configurable value should have a corresponding entry in `values.yaml` with a matching default:

- **Replica count.** Design says "3 replicas in production" — `replicaCount` default should match (or the design should state the default is an override).
- **Image tag.** Design pins a specific version — the default `image.tag` should match.
- **Feature flags.** Design describes optional features — each should have a `.enabled` key in values with the design's stated default.
- **Resource requests/limits.** Design's resource budget section — defaults should match.

A values default that contradicts the design is `SPEC_DEV`. A design-specified configurable that has no values entry is `MISSING_IMPL`.

## values.schema.json

If the design specifies required inputs (values the installer must provide, with no safe default), check:

- A `values.schema.json` exists with those fields marked `required`.
- Required fields have correct types and constraints matching the design.
- If no schema exists but the design specifies required inputs → `MISSING_IMPL` at P2 (schema is a quality guardrail, not a hard requirement).

## Template correctness vs design

- **Conditional features.** If the design says "feature X is optional, controlled by a flag" — the template should gate the resource with `{{ if .Values.x.enabled }}`. Missing gate on a design-described optional feature → `SPEC_DEV`.
- **Environment-specific behavior.** If the design describes different behavior per environment and the chart uses value overrides to achieve this, verify the template conditionals and value structures support the described variations.
- **Default rendering.** The chart rendered with default values (`helm dependency build && helm template .` — dependencies must be resolved first) should produce manifests consistent with the design's "default deployment" description. Resources present in the rendered output but absent from the design's default → `EXTRA_IMPL`; resources described in the design's default but absent from the rendered output → `MISSING_IMPL`.

## Dependency pinning

If the design lists external chart dependencies:

- Each dependency in `Chart.yaml` `dependencies[]` must match.
- Version constraints should use strict semver (not floating ranges) unless the design explicitly allows floating.
- Repository URLs should match the design's stated chart sources.
- `Chart.lock` should exist with resolved versions consistent with `Chart.yaml` constraints.

Missing `Chart.lock` when `dependencies[]` is non-empty is `MISSING_IMPL` at P3 (reproducibility concern — the file should exist but doesn't).
