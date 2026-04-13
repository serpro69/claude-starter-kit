---
name: development-guidelines
description: |
  Use when writing code to ensure you follow development best practices during development and implementation.
---

# Development Guidelines

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Assumptions & Fail-Loud

1. **State assumptions explicitly.** If uncertain, ask. Don't guess silently.
2. **Surface ambiguity.** If the request has multiple reasonable interpretations, present them and let the user choose — don't pick one silently.
3. **Fail loud.** Flag errors explicitly. No softening, no silent corrections, no swallowed exceptions, no assertions you quietly relax to make a test pass.
4. **Pre-existing dead code is not yours to delete.** If you notice unrelated dead code, mention it — don't remove it. Only remove orphans (imports, variables, helpers) that *your* changes made unused.

## Working with Dependencies

1. Always try to use latest versions for dependencies.
2. If you are not sure, **do not make assumptions about how external dependencies work**. Always consult documentation.
3. **Capy search:** Before consulting external docs, search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency in question.
4. Before trying alternative methods, always try to **use context7 MCP to lookup documentation for external dependencies** like libraries, SDKs, APIs and other external frameworks, tools, etc.
   - **IMPORTANT! Always make sure that documentation version is the same as declared dependency version itself.**
   - Only revert to web-search or other alternative methods if you can't find documentation in context7.
5. **Capy index:** If context7 or web search yields a valuable best-practice nugget not obvious from the docs themselves, index it as `kk:lang-idioms`.
