# Kotlin profile

## What this profile covers

Idiomatic Kotlin source code: null safety, coroutines and structured concurrency, data classes and sealed hierarchies, extension functions, scope functions, interop boundaries with Java, build scripts (`.kts`), and SOLID principles expressed in Kotlin terms.

## When it activates

Any file with a `.kt` or `.kts` extension in scope. See [DETECTION.md](DETECTION.md) for the authoritative rule. Activation is additive with other profiles on the same diff.

## Populated phases

- `review/` — checklists consumed by `review-code` (security, SOLID, code-quality, removal-plan).

Other phase subdirectories are not populated for this profile: generic per-phase behavior is sufficient.

## Looking up Kotlin dependencies

When adding or upgrading a dependency, follow the `dependency-handling` skill's cascade:

1. **capy-first** — query the project's indexed `kk:lang-idioms` / `kk:project-conventions` / prior context7 fetches.
2. **context7** — fetch current docs for the library or framework (Ktor, kotlinx.coroutines, Exposed, Arrow, etc.).
3. **web** — fall back to [Maven Central](https://search.maven.org), [Kotlin docs](https://kotlinlang.org/docs), or the project's own repository README only if the first two yield nothing.

Project dependency metadata lives in `build.gradle.kts` (preferred), `build.gradle`, or `pom.xml` with a lockfile for resolved versions. Version-specific behaviors must be verified against the version the build resolves to, not the latest available.
