# Java profile

## What this profile covers

Idiomatic Java source code: OOP discipline and composition, immutability (records, `final`, defensive copies), exception hygiene (checked vs. unchecked), concurrency primitives (`java.util.concurrent`), Collections API usage, Streams, and SOLID principles expressed in Java terms.

## When it activates

Any file with a `.java` extension in scope. See [DETECTION.md](DETECTION.md) for the authoritative rule. Activation is additive with other profiles on the same diff.

## Populated phases

- `review-code/` — checklists consumed by `review-code` (security, SOLID, code-quality, removal-plan).

Other phase subdirectories are not populated for this profile: generic per-phase behavior is sufficient.

## Looking up Java dependencies

When adding or upgrading a dependency, follow the `dependency-handling` skill's cascade:

1. **capy-first** — query the project's indexed `kk:lang-idioms` / `kk:project-conventions` / prior context7 fetches.
2. **context7** — fetch current docs for the library or framework (Spring, Jackson, JUnit, etc.).
3. **web** — fall back to [Maven Central](https://search.maven.org) (`mvnrepository.com`), Javadoc hosted by the project, or the project's repository README only if the first two yield nothing.

Project dependency metadata lives in `pom.xml`, `build.gradle`, or `build.gradle.kts`. Version-specific behaviors must be verified against the version the build resolves to, not the latest available.
