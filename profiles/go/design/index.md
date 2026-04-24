# Go — design checklists

<!-- BEGIN VENDORED -->
## Conditional

- [database.md](database.md) — Go's `database/sql` provides a solid foundation for database access. Use `sqlx` or `pgx` on top of it for ergonomics — **Load if:** Design involves database access or SQL
- [grpc.md](grpc.md) — Treat gRPC as a pure transport layer — keep it separate from business logic. The official Go implementation is `google **Load if:** Design involves gRPC services or protobuf
- [observability.md](observability.md) — Observability is the ability to understand a system's internal state from its external outputs. In Go services, this mea **Load if:** Design involves logging, metrics, or tracing
<!-- END VENDORED -->
