# Tasks: JWT Authentication System

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: in-progress
> Created: 2026-03-11

## Task 1: Token generation and validation library
- **Status:** done
- **Depends on:** —
- **Docs:** [implementation.md#token-library](./implementation.md#token-library)

### Subtasks
- [x] 1.1 Create `internal/auth/token.go` with `GenerateToken(userID, role)` and `ValidateToken(tokenString)` functions
- [x] 1.2 Add token expiry configuration via `internal/config/auth.go` — read from env vars with sensible defaults
- [x] 1.3 Write table-driven tests covering: valid token, expired token, malformed token, wrong signing key

## Task 2: Auth middleware
- **Status:** in-progress
- **Depends on:** Task 1
- **Docs:** [implementation.md#middleware](./implementation.md#middleware)

### Subtasks
- [x] 2.1 Create `internal/middleware/auth.go` — extract token from `Authorization: Bearer <token>` header, validate via token library, inject user claims into request context
- [ ] 2.2 Add middleware to router in `cmd/server/routes.go` for all `/api/v1/*` routes except `/api/v1/auth/login`
- [ ] 2.3 Integration tests: request without token → 401, expired token → 401, valid token → passes through with claims in context

## Task 3: Login and refresh endpoints
- **Status:** pending
- **Depends on:** Task 1, Task 2
- **Docs:** [implementation.md#endpoints](./implementation.md#endpoints)

### Subtasks
- [ ] 3.1 `POST /api/v1/auth/login` — accept email/password, verify against user store, return access + refresh tokens
- [ ] 3.2 `POST /api/v1/auth/refresh` — accept refresh token, validate, return new access token
- [ ] 3.3 Tests: valid credentials → tokens returned, invalid credentials → 401, expired refresh token → 401

## Task 4: Password hashing migration
- **Status:** blocked
- **Depends on:** —
- **Docs:** [design.md#password-storage](./design.md#password-storage)
- **Blocked:** Waiting on DB migration tooling decision (see design.md#open-questions)

### Subtasks
- [ ] 4.1 Add bcrypt hashing to `internal/auth/password.go` with cost factor from config
- [ ] 4.2 Create migration to add `password_hash` column to users table
- [ ] 4.3 Update user registration flow to hash passwords on create

## Task 5: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4

### Subtasks
- [ ] 5.1 Run `testing-process` skill to verify all tasks — full test suite, integration tests, edge cases
- [ ] 5.2 Run `documentation-process` skill to update any relevant docs
