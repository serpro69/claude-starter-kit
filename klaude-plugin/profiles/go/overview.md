# Go profile

## What this profile covers

Idiomatic Go source code: error handling, concurrency (goroutines, channels, context), interfaces and composition, package cohesion, the standard library, and SOLID principles expressed in Go terms (package responsibility, interface segregation, dependency inversion via interfaces).

## When it activates

Any file with a `.go` extension in scope. See [DETECTION.md](DETECTION.md) for the authoritative rule. Activation is additive with other profiles on the same diff (e.g., a repo containing both `.go` files and Kubernetes manifests activates both `go` and `k8s`).

## Populated phases

- `review/` — checklists consumed by `review-code` (security, SOLID, code-quality, removal-plan).

Other phase subdirectories (`design/`, `test/`, `implement/`, `document/`, `review-spec/`) are not populated for this profile: the generic per-phase behavior is sufficient.

## Looking up Go dependencies

When adding or upgrading a dependency (module, SDK, framework, API), follow the `dependency-handling` skill's cascade:

1. **capy-first** — query the project's indexed `kk:lang-idioms` / `kk:project-conventions` / prior context7 fetches.
2. **context7** — fetch current docs for the Go module (`github.com/<org>/<repo>` resolves to a context7 library). Covers standard-library and common third-party packages.
3. **web** — fall back to [pkg.go.dev](https://pkg.go.dev) and the module's own repository README only if the first two yield nothing.

Module metadata for the project lives in `go.mod` / `go.sum`. Version-specific behaviors should always be verified against the module version the project actually resolves to, not the latest available version.
