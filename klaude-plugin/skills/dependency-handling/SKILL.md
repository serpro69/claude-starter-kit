---
name: dependency-handling
description: |
  TRIGGER when: adding or upgrading a dependency; calling a library, SDK, framework, or external API; unsure how a third-party function behaves; about to guess a signature, config key, or version-specific behavior.
  Use BEFORE writing the call — not after it fails. Forces a context7/capy lookup instead of guessing.
---

# Dependency & External API Handling

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Rules

1. **Prefer the latest stable version** when introducing a new dependency. Pin deliberately; don't inherit a stale version by copy-paste.
2. **Never assume how an external dependency behaves.** If you are not 100% sure of the signature, config, or semantics, look it up. Guessing is the failure mode this skill exists to prevent.
3. **Capy search first.** Before hitting external docs, search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency.
4. **Context7 second.** Use the context7 MCP to fetch documentation for libraries, SDKs, APIs, and frameworks.
   - **IMPORTANT:** the doc version MUST match the declared dependency version. A right answer against the wrong version is a wrong answer.
   - Only fall back to web search if context7 has no coverage.
5. **Index what you learn.** If context7 or web search yields a best-practice nugget that isn't obvious from the docs themselves, index it as `kk:lang-idioms` so the next agent doesn't pay the lookup cost again.
