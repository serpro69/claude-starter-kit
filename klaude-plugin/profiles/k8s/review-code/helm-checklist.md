# Kubernetes — Helm Checklist

Applied conditionally when the diff contains Helm-shaped files: `Chart.yaml`, `values*.yaml` adjacent to a `Chart.yaml`, or files under a `templates/` directory whose ancestor contains `Chart.yaml`. (See `index.md` for the full `Load if:` predicate.)

## Contents

- `Chart.yaml` metadata
- `values.yaml` schema
- Template correctness
- Chart dependencies
- Linting and validation
- `NOTES.txt` and release UX

## `Chart.yaml` metadata

- `apiVersion: v2` — `v1` is deprecated. `v2` is required for `dependencies` to live in `Chart.yaml` (rather than `requirements.yaml`).
- `name` matches the chart directory name; `version` follows semver and is bumped whenever `templates/` or `values.yaml` changes meaningfully.
- `appVersion` set and tracks the packaged application's version independently of the chart version.
- `kubeVersion` constraint when the chart uses version-specific features (PDBs, PSS labels, `seccompProfile`). Use semver ranges (`>=1.25.0-0`) to document support.
- `type: application` or `type: library` — libraries don't install resources; applications do. Applications have `templates/`; libraries should not.
- `description` present and informative (one-line summary; longer prose goes in `README.md`).
- `maintainers` and `sources` populated so installers know who to contact and where the canonical source is.
- `icon` optional but useful for UI surfaces.
- `deprecated: true` when sunsetting — triggers warnings in Helm clients.
- `annotations` for chart-level metadata (ArtifactHub keys, OCI references).

## `values.yaml` schema

- Every value referenced in `templates/` has a sensible default in `values.yaml`, OR is gated by `required` in the template with a clear error message.
- Structure mirrors consumer expectations: group by concern (`image`, `resources`, `ingress`, `serviceAccount`), not flat.
- Boolean-flag vs object-nesting consistency: `ingress.enabled: true` + `ingress.hosts: [...]` is the common pattern; avoid `ingressEnabled` alongside `ingress: {...}`.
- `values.schema.json` (JSON Schema draft 7 or later) optional but recommended for non-trivial charts — catches type errors at `helm install`/`upgrade` time.
- `image.repository`, `image.tag`, `image.pullPolicy` as separate values — consumers override tags for CI image promotion.
- Secret material is NOT a default in `values.yaml`; mark such values as required without a default, and document at the README level how to supply them (via `--set`, `-f`, Sealed Secrets, External Secrets).
- Backwards-compat concerns: renaming a values key without a deprecation cycle breaks installers. `Chart.yaml` version bump to major when rename is unavoidable.

## Template correctness

- `{{ include "chart.fullname" . }}` (or equivalent helpers in `_helpers.tpl`) used for resource names — avoids two charts in the same release colliding.
- `{{ .Values.foo | quote }}` on any user-supplied string interpolated into YAML values — prevents YAML injection and unquoted-number bugs (`"123abc"` interpreted as a number).
- `nil` handling: `{{ .Values.optional | default "x" }}` or `{{- if .Values.optional }}...{{- end }}`. Templates that produce `key: <no value>` on nil are malformed.
- `toYaml` with `nindent`: `{{ toYaml .Values.x | nindent 4 }}` — get the indent right; empty maps output `{}`, empty lists output `[]`, neither renders well if indentation is wrong.
- `lookup` function used sparingly — it makes templates non-deterministic (cluster state at render time affects output). Document any usage.
- `{{- }}` whitespace trimming applied consistently; stray blank lines in rendered output cause diffs to look noisier than they are.
- Range iteration names the index explicitly (`{{- range $index, $item := .Values.list }}`) when the index is used, not just `{{- range .Values.list }}`.
- Named template definitions (`{{- define "..." }}...{{- end }}`) live in `_helpers.tpl` files; file names starting with `_` are NOT rendered.

## Chart dependencies

- `dependencies[]` in `Chart.yaml` pin versions strictly (`1.2.3`), not with floating ranges (`~1.2` or `>=1.2.0`). Floating ranges make a chart un-reproducible.
- Each dependency has a `repository` (URL or `@alias` of a `helm repo add` entry) and a `condition` when optional.
- `alias` used when the same chart is included multiple times or when naming conflicts arise.
- `helm dependency update` has been run; `Chart.lock` is present and committed.
- Subchart values exposed via the dependency's top-level key in `values.yaml` with documented overrides.

## Linting and validation

- `helm lint` runs clean on the chart. Warnings are addressed or explicitly suppressed with rationale.
- `helm template .` produces valid YAML that a `kubectl apply --dry-run=client -f -` would accept.
- `kubeconform` (or `kubeval`) run on the template output against the target K8s version.
- If CRDs are used, they are listed in `crds/` (installed before templates, not templated themselves — Helm's `crds/` lifecycle is intentional).
- Tests live in `templates/tests/` with `"helm.sh/hook": test-success` / `test-failure` annotations for `helm test` to pick up.

## `NOTES.txt` and release UX

- `templates/NOTES.txt` gives the installer actionable post-install info: how to reach the service, what to set next, URLs and credentials retrieval commands.
- Notes render cleanly (no leaked template syntax, no `<no value>` placeholders).
- Upgrade notes flag breaking changes in the release.

## Questions to ask

- "Can I upgrade this chart without losing data or breaking existing deployments?" — surfaces dependency pinning, PVC handling, schema compat.
- "If I override nothing, does the chart still install successfully in a fresh cluster?" — surfaces missing defaults and required-but-undocumented values.
- "What does `helm diff` show for a no-op upgrade?" — surfaces non-deterministic templating (`lookup`, `randAlphaNum`, timestamps).
