# Kustomize-specific spec verification

Verification patterns for comparing Kustomize implementations against design specifications. Load alongside `type-mapping.md` when Kustomize signals are present in the diff.

## Base/overlay structure

The design's environment strategy dictates the expected directory layout:

- **Environments match overlays.** If the design names environments (dev, staging, production), each should have a corresponding overlay directory. A design-described environment with no overlay → `MISSING_IMPL`.
- **Base completeness.** Resources shared across all environments (per the design) should live in the base, not duplicated per overlay. A resource the design describes as common that only exists in one overlay → `SPEC_DEV` (wrong location, even if the resource exists).
- **Overlay minimality.** Overlays should contain only environment-specific deltas. A resource fully duplicated in an overlay (not patched, just copied) when the design describes it as shared → `SPEC_DEV`.

## Patch targets

For each per-environment override the design describes, verify a corresponding patch exists:

| Design override | Expected patch | Finding type if mismatch |
|---|---|---|
| Env-specific replica count | Strategic merge or JSON patch on Deployment `spec.replicas` | `MISSING_IMPL` |
| Env-specific resource limits | Patch on container `resources` | `MISSING_IMPL` |
| Env-specific image tag | Patch or `images` transformer in `kustomization.yaml` | `MISSING_IMPL` |
| Env-specific config values | ConfigMapGenerator with env-specific data or patch on ConfigMap | `MISSING_IMPL` |

A patch that targets a resource or field the design doesn't describe as environment-variable → `EXTRA_IMPL` (may be legitimate infrastructure plumbing — assess conservatively).

**Patch precision.** The design may specify that only certain fields differ per environment. A strategic merge patch that replaces an entire spec block when the design only calls for a replica count change → `SPEC_DEV` (over-broad patch risks unintended overrides).

## Generator usage

If the design describes configuration injection via ConfigMap or Secret:

- **ConfigMapGenerator / SecretGenerator.** The `kustomization.yaml` should use generators matching the design's config-injection strategy. A design that says "config injected via ConfigMap" but the implementation uses inline env vars → `SPEC_DEV`.
- **Generator options.** `generatorOptions.disableNameSuffixHash` should match the design's stability expectations. If the design assumes stable ConfigMap names (e.g., for external references), the hash suffix must be disabled. Mismatch → `SPEC_DEV`.
- **Literal vs file sources.** Check that the generator's source type matches the design's data model. A design that describes a config file mounted as a volume needs a `files` source, not `literals`.

## Common labels and annotations

If the design specifies a labeling standard:

- Verify selector immutability constraints (Deployment `spec.selector.matchLabels` are immutable after creation). The `commonLabels` field inherently injects labels into selectors — it cannot be configured otherwise. If the design's labels are metadata-only, the Kustomization must use the `labels:` field instead with `includeSelectors: false` (Kustomize ≥4.1). A Kustomization using `commonLabels` for metadata-only labels is `SPEC_DEV` (wrong mechanism, even if the labels are correct).
- `commonAnnotations` should match any design-specified annotation standard.

Mismatch between the design's label set and the Kustomize configuration → `SPEC_DEV`.

## Components usage

If the design specifies modular, optional, or cross-cutting features (e.g., "optional monitoring sidecar", "database connection add-on"):

- Verify these are implemented using the `components:` field (Kustomize ≥4.1) rather than duplicating resources across overlays or hardcoding them into the base.
- A design-specified modular feature that is instead duplicated across overlays → `SPEC_DEV` (wrong structural pattern).
- The presence of a `components:` directory or `components:` entries in `kustomization.yaml` is not `EXTRA_IMPL` when the design describes optional/cross-cutting features — it is the correct Kustomize mechanism for that design pattern.
