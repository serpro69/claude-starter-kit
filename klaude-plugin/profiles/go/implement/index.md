# Go — implement checklists

<!-- BEGIN VENDORED -->
## Always load

- [design-patterns.md](design-patterns.md) — Idiomatic Go patterns for production-ready code. For error handling details see the `samber/cc-skills-golang@golang-erro
- [structs-interfaces.md](structs-interfaces.md) — > "The bigger the interface, the weaker the abstraction." — Go Proverbs
- [error-handling.md](error-handling.md) — This skill guides the creation of robust, idiomatic error handling in Go applications. Follow these principles to write 
- [security.md](security.md) — Security in Go follows the principle of **defense in depth**: protect at multiple layers, validate all inputs, use secur

## Conditional

- [concurrency.md](concurrency.md) — Go's concurrency model is built on goroutines and channels. Goroutines are cheap but not free — every goroutine you sp **Load if:** Task involves goroutines, channels, or sync primitives
- [context.md](context.md) — `context.Context` is Go's mechanism for propagating cancellation signals, deadlines, and request-scoped values across AP **Load if:** Task involves context propagation or cancellation
- [data-structures.md](data-structures.md) — Built-in and standard library data structures: internals, correct usage, and selection guidance. For safety pitfalls (ni **Load if:** Task involves custom data structures, generics, or collection types
- [database.md](database.md) — Go's `database/sql` provides a solid foundation for database access. Use `sqlx` or `pgx` on top of it for ergonomics — **Load if:** Task involves database access or SQL
- [grpc.md](grpc.md) — Treat gRPC as a pure transport layer — keep it separate from business logic. The official Go implementation is `google **Load if:** Task involves gRPC services or protobuf
- [dependency-injection.md](dependency-injection.md) — Dependency injection (DI) means passing dependencies to a component rather than having it create or find them. In Go, th **Load if:** Task involves dependency injection or wire
<!-- END VENDORED -->
