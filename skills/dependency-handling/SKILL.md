---
name: dependency-handling
description: |
  TRIGGER when: adding or upgrading any dependency — library, SDK, framework, API, IaC API version (K8s/Terraform/Helm), CRD, or container image. Use BEFORE writing the call. Forces context7/capy lookup instead of guessing.
---

# Dependency & External API Handling

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Workflow

**Mandatory order — lookup before usage.** Do not write, modify, or recommend any call, import, config key, or version specifier involving the dependency until you have completed the lookup cascade below. Guessing a signature or API version and fixing it after the fact is the failure mode this skill exists to prevent. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

1. **Extract the dependency identity.** From the calling context, identify the dependency name, the version constraint (declared or inferred), and the specific API surface being used (function, config key, API version, image tag). This is the minimal scope — enough to drive the lookup, not enough to guess the answer.
2. **Capy search.** Search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about this dependency.
3. **Context7 lookup.** Use the context7 MCP to fetch documentation. The doc version MUST match the declared dependency version.
4. **Web fallback.** Only if context7 has no coverage.
5. **Apply.** With verified knowledge now loaded, write or recommend the call, import, or config.

## Rules

1. **Prefer the latest stable version** when introducing a new dependency. Pin deliberately; don't inherit a stale version by copy-paste.
2. **Never assume how an external dependency behaves.** If you are not 100% sure of the signature, config, or semantics, look it up. Guessing is the failure mode this skill exists to prevent.
3. **Capy search first.** Before hitting external docs, search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency.
4. **Context7 second.** Use the context7 MCP to fetch documentation for libraries, SDKs, APIs, and frameworks.
   - **IMPORTANT:** the doc version MUST match the declared dependency version. A right answer against the wrong version is a wrong answer.
   - Only fall back to web search if context7 has no coverage.
5. **Index what you learn.** If context7 or web search yields a best-practice nugget that isn't obvious from the docs themselves, index it as `kk:lang-idioms` so the next agent doesn't pay the lookup cost again.

## IaC and config artifacts

The cascade rule (capy-first, context7-second, web-last) applies uniformly to all dependency categories — libraries, SDKs, frameworks, APIs, IaC API versions, CRDs, Helm charts, and container images. Per-domain lookup targets (which context7 library to query, which local command to run, which registry to consult) live in each profile's `overview.md` under a "Looking up dependencies" heading. When the `k8s` profile is active, consult `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/overview.md` under the `## Looking up Kubernetes dependencies` heading for Kubernetes API versions, third-party CRDs, Helm chart versions, and container image targets.
