# Go — review checklists

Consumed by the `review-code` skill. When the `go` profile is active, every checklist in **Always load** is applied to the diff. Conditional entries are loaded when their trigger matches.

## Always load

- [solid-checklist.md](solid-checklist.md) — SOLID design-principle smells expressed in Go terms: package cohesion, interface segregation, dependency inversion, composition over inheritance.
- [removal-plan.md](removal-plan.md) — staged-removal template for Go code being retired (exports, packages, modules).

<!-- BEGIN VENDORED -->
## Always load

- [security.md](security.md) — Security in Go follows the principle of **defense in depth**: protect at multiple layers, validate all inputs, use secur
- [code-style.md](code-style.md) — Style rules that require human judgment — linters handle formatting, this skill handles clarity. For naming see `sambe
- [error-handling.md](error-handling.md) — This skill guides the creation of robust, idiomatic error handling in Go applications. Follow these principles to write 

## Conditional

- [security-injection-ref.md](security-injection-ref.md) — Injection vulnerabilities allow attackers to execute arbitrary code, queries, or commands. **Load if:** Diff handles user input, SQL queries, command execution, or template rendering
- [naming.md](naming.md) — Go favors short, readable names. Capitalization controls visibility — uppercase is exported, lowercase is unexported.  **Load if:** Diff introduces new exported types, functions, or packages
- [performance.md](performance.md) — 1. **Profile before optimizing** — intuition about bottlenecks is wrong ~80% of the time. Use pprof to find actual hot **Load if:** Diff involves hot paths, allocations, caching, or performance-sensitive code
- [database.md](database.md) — Go's `database/sql` provides a solid foundation for database access. Use `sqlx` or `pgx` on top of it for ergonomics — **Load if:** Diff imports database/sql, sqlx, gorm, ent, or pgx
- [concurrency.md](concurrency.md) — Go's concurrency model is built on goroutines and channels. Goroutines are cheap but not free — every goroutine you sp **Load if:** Diff uses goroutines, channels, or sync package
- [grpc.md](grpc.md) — Treat gRPC as a pure transport layer — keep it separate from business logic. The official Go implementation is `google **Load if:** Diff imports google.golang.org/grpc
<!-- END VENDORED -->
