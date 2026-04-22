---
name: test
description: |
  Guidelines describing how to test the code.
  Use whenever writing new or updating existing code, for example after implementing a new feature or fixing a bug.
---

# Testing & Quality Assurance Process

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Profile detection is delegated to [shared-profile-detection.md](shared-profile-detection.md). When an active profile contributes a `test/` subdirectory (e.g., `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/test/`), its `index.md` lists validators, check categories, and any binary-presence or auto-detection protocols the skill must apply. Load profile content BEFORE running validators — a missing pre-check step can crash on a tool that isn't installed.

## Guidelines

1. Always try to add tests for any new functionality, and make sure to cover all cases and code branches, according to requirements.
2. Always try to add tests for any bug-fixes, if the discovered bug is not already covered by tests. If the bug was already covered by tests, fix the existing tests as needed.
3. Always run all existing tests after you are done with a given implementation or bug-fix.
4. **Profile-aware validator planning (load before running).** After language-specific test patterns, run the shared profile-detection procedure against the changed files. For each active profile that contributes a `test/` subdirectory, load `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/test/index.md` and read the always-load + any matching conditional content BEFORE executing any validator named there. Apply the validators and check categories the profile specifies; honor binary-presence protocols the profile documents (missing binaries should surface install hints, not shell errors).

**Capy search:** Before applying test guidelines, search `kk:test-patterns` for project-specific testing approaches and known edge cases.

Use the following guidelines when working with tests:

- Ensure comprehensive testing
- Use table-/data-driven tests and test generation
- Benchmark tests and performance regression detection
- Integration testing with test containers
- Mock generation with %LANGUAGE% best practices and well-establised %LANGUAGE% mocking tools
- Property-based testing with %LANGUAGE% best practices and well-establised %LANGUAGE% testing tools
- Propose end-to-end testing strategies if automated e2e testing is not feasible
- Code coverage analysis and reporting

**Capy index:** If a novel testing approach or tricky edge case was discovered during this session, index it as `kk:test-patterns`.
