# Kubernetes — Kustomize Checklist

Applied conditionally when the diff contains Kustomize-shaped files: `kustomization.yaml` / `kustomization.yml` / `Kustomization` (exact), files under `bases/` or `overlays/`, or a patch file referenced by a nearby `kustomization.*`. (See `index.md` for the full `Load if:` predicate.)

## Contents

- Base / overlay separation
- Patch targets and precision
- Generators (ConfigMap, Secret)
- Common labels, annotations, and selectors
- Images, name prefixes/suffixes, namespace transforms
- Patch type clarity

## Base / overlay separation

- **Bases** contain environment-agnostic resources and no environment-specific values. A base that hardcodes `prod-us-east` hostnames is a finding — that belongs in an overlay.
- **Overlays** contain the per-environment deltas: patches, image overrides, replica counts, labels. Overlays should NOT contain whole-resource definitions that could have lived in the base (unless they truly exist only in one environment).
- `resources` in `kustomization.yaml` references OTHER kustomization directories or raw manifests — keep the tree shallow; deeply nested bases-of-bases become hard to reason about.
- Reuse via overlay composition > reuse via YAML anchors. Kustomize provides the overlay model precisely to avoid ad-hoc YAML tricks.
- Each environment has its own overlay directory (`overlays/dev/`, `overlays/staging/`, `overlays/prod/`). Shared overlay material (e.g., "all non-prod") is a separate base.

## Patch targets and precision

- Strategic merge patches target a specific resource by `apiVersion` + `kind` + `metadata.name` + (optional) `metadata.namespace`. Patches without an explicit target rely on Kustomize's default matching, which can become ambiguous.
- JSON 6902 patches specify both `target` and `patch` precisely; the target selector must identify exactly one resource.
- Avoid over-broad selectors (e.g., patching "every Deployment in the project" with one patch) unless that is the intent; broad patches make subsequent reviews harder.
- Patches modifying a field that doesn't exist in the base are often bugs — Kustomize may silently add or may error depending on the patch type. Verify with `kustomize build`.
- Patches should be minimal: include only the fields being changed, not a full resource spec. Full-resource patches are overlays in disguise and belong in `resources` with a different name.

## Generators

`configMapGenerator` and `secretGenerator` behavior is different from authoring resources directly:

- Generators append a **content-based suffix** to the resource name (`my-config-abc1234`). References to generated resources auto-update via name references — do NOT hardcode the suffixed name in Pods manually.
- `generatorOptions.disableNameSuffixHash: true` removes the suffix but also defeats the immutability guarantee. Use only when consumers cannot handle name changes.
- `behavior: create|replace|merge` controls overlay interaction. Default is `create`; `merge` adds keys to a base-generated resource; `replace` overrides the base entirely.
- Generator inputs come from `files:`, `literals:`, or `envs:` — avoid mixing sources into one generator without a clear reason.
- `secretGenerator` outputs `Secret` resources with the same supply-chain concerns as hand-authored secrets (see security-checklist.md). Don't commit secret values; wire generators to external sources.

## Common labels, annotations, and selectors

- `commonLabels` is superseded (still functional in v5.x, but discouraged for new work) by the `labels:` stanza. The critical semantic difference: `commonLabels` applies to metadata AND selectors AND Pod template labels (per official Kustomize docs, `commonLabels` is equivalent to `labels: [{includeSelectors: true}]`). The `labels:` stanza is safer by default because `includeSelectors` defaults to `false` — it applies to metadata only unless you explicitly opt in. **Only set `includeSelectors: true` when you are writing the initial selector-defining base; never add `true` to an overlay that patches an existing Deployment** — adding labels to `matchLabels` retroactively violates selector immutability and forces manual intervention.
- `commonAnnotations` applies annotations to every resource but NOT to Pod templates — usually harmless.
- Align with the recommended label set (see quality-checklist.md):
  - `commonLabels.app.kubernetes.io/managed-by: kustomize`
  - environment / version labels in overlays, not bases.
- Watch for label collisions: a base applying `app: foo` + an overlay applying `app: foo-prod` would break the Deployment's selector.

## Images, name prefixes/suffixes, namespace transforms

- `images:` transformer overrides image tags/digests per overlay — the idiomatic way to pin prod to a digest while dev uses `:latest`.
- Use digests (`newTag: "@sha256:..."` or the `digest:` field) in prod overlays for reproducibility.
- `namePrefix` / `nameSuffix` per overlay to distinguish environments in the same cluster (`prod-my-app`, `my-app-dev`). Consistent across the overlay.
- `namespace:` transform applies a namespace to every resource — prefer setting namespace on each resource in its manifest if the namespace is stable across environments, and use the transform only when overlays differ.
- `replicas:` transformer vs patching `.spec.replicas` — both work; pick one convention per project and stick with it.

## Patch type clarity

Kustomize supports three patch styles; choose per case and document the choice:

- **Strategic merge patch** — the default; readable for most cases. Fails on lists where the list-merge key isn't known to Kustomize.
- **JSON 6902 patch** — explicit ops (`add`, `replace`, `remove`, `move`). Unambiguous but verbose; best for list surgery and deletions.
- **JSON merge patch** — RFC 7396; useful for wholesale replacement of a field. Cannot express list-item edits.

Avoid alternating styles within a single overlay for the same concern — pick one and be consistent. JSON 6902 is the right choice when strategic merge silently does the wrong thing (common with `hostAliases`, `tolerations`, container args).

## `kustomization.yaml` hygiene

- `apiVersion: kustomize.config.k8s.io/v1` explicit at top of file (GA since Kustomize v4.x; preferred for new work). `v1beta1` is still accepted but has subtle behavioral differences in `resources:` resolution — flag as a migration target in existing files.
- `resources:` listed with relative paths, sorted for reviewability.
- Avoid remote bases (`resources: - github.com/...?ref=...`) in production overlays — pin by commit SHA or vendor the base locally.
- `components:` used for cross-cutting, reusable pieces (e.g., "enable metrics sidecar on any overlay that includes this component").

## Questions to ask

- "What does `kustomize build overlays/prod` produce?" — always check, review the rendered output, not just the source files.
- "If I rename a resource in the base, what overlays break?" — surfaces tight coupling.
- "Does this patch still apply cleanly after the next base change?" — surfaces patches that rely on fragile field presence.
