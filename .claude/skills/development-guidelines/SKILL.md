---
name: development-guidelines
description: Use this task to ensure you follow development best practices during development and implementation.
---

# Development Guidelines

## Working with code

**ALWAYS**:

- Ensure minimal and atomic code changes: any code change should only be related to current task at hand

**DO NOT**:

- Never rename things just for the sake of renaming
- Never optimize the code unless you're working specifically on code optimization

## Working with Dependencies

1. Always try to use latest versions for dependencies.
2. If you are not sure, **do not make assumptions about how external dependencies work**. Always consult documentation.
3. Before trying alternative methods, always try to **use context7 MCP to lookup documentation for external dependencies** like libraries, SDKs, APIs and other external frameworks, tools, etc.
    - **IMPORTANT! Always make sure that documentation version is the same as declared dependency version itself.**
    - Only revert to web-search or other alternative methods if you can't find documentation in context7.
