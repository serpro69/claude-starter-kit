---
name: development-guidelines
description: |
  Use when writing code to ensure you follow development best practices during development and implementation.
---

# Development Guidelines

For capy knowledge base conventions, see [capy-knowledge-protocol.md](../_shared/capy-knowledge-protocol.md).

## Working with Dependencies

1. Always try to use latest versions for dependencies.
2. If you are not sure, **do not make assumptions about how external dependencies work**. Always consult documentation.
3. **Capy search:** Before consulting external docs, search `kk:lang-idioms` and `kk:project-conventions` for previously indexed knowledge about the dependency in question.
4. Before trying alternative methods, always try to **use context7 MCP to lookup documentation for external dependencies** like libraries, SDKs, APIs and other external frameworks, tools, etc.
   - **IMPORTANT! Always make sure that documentation version is the same as declared dependency version itself.**
   - Only revert to web-search or other alternative methods if you can't find documentation in context7.
5. **Capy index:** If context7 or web search yields a valuable best-practice nugget not obvious from the docs themselves, index it as `kk:lang-idioms`.
