# Tasks: JWT Authentication System

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: in-progress
> Created: 2026-03-11
> Not Doing: OAuth/social login, API rate limiting, token revocation list

## Task 1: User login end-to-end
- **Status:** done
- **Depends on:** —
- **Size:** M
- **Can run in parallel with:** Task 2
- **Docs:** [implementation.md#user-login](./implementation.md#user-login)

### Subtasks
- [x] 1.1 Create `internal/auth/token.go` with `GenerateToken(userID, role)` and `ValidateToken(tokenString)` — access token generation with configurable expiry via `internal/config/auth.go`
- [x] 1.2 Create `POST /api/v1/auth/login` endpoint — accept email/password, verify against user store, return access + refresh tokens
- [x] 1.3 Create `internal/middleware/auth.go` — extract token from `Authorization: Bearer <token>` header, validate via token library, inject user claims into request context. Wire to `/api/v1/auth/login` route in `cmd/server/routes.go`
- [x] 1.4 Integration tests for the login flow: valid credentials → tokens returned, invalid credentials → 401, malformed token → 401, expired token → 401

## Task 2: Token refresh end-to-end
- **Status:** in-progress
- **Depends on:** —
- **Size:** S
- **Can run in parallel with:** Task 1
- **Docs:** [implementation.md#token-refresh](./implementation.md#token-refresh)

### Subtasks
- [x] 2.1 Create `POST /api/v1/auth/refresh` endpoint — accept refresh token, validate, return new access token with rotation
- [ ] 2.2 Integration tests: valid refresh → new access token, expired refresh → 401, reused refresh token → 401

## Task 3: Protected routes end-to-end
- **Status:** pending
- **Depends on:** Task 1
- **Size:** M
- **Can run in parallel with:** —
- **Docs:** [implementation.md#protected-routes](./implementation.md#protected-routes)

### Subtasks
- [ ] 3.1 Apply auth middleware to all `/api/v1/*` routes except `/api/v1/auth/login` and `/api/v1/auth/refresh` in `cmd/server/routes.go`
- [ ] 3.2 Rejection tests: request without token → 401, expired token → 401, valid token → passes through with claims in context
- [ ] 3.3 Verify existing endpoint tests still pass with auth middleware applied

## Task 4: Password hashing migration
- **Status:** blocked
- **Depends on:** —
- **Size:** M
- **Can run in parallel with:** Task 1, Task 2
- **Docs:** [design.md#password-storage](./design.md#password-storage)
- **Blocked:** Waiting on DB migration tooling decision (see design.md#open-questions)

### Subtasks
- [ ] 4.1 Add bcrypt hashing to `internal/auth/password.go` with cost factor from config
- [ ] 4.2 Create migration to add `password_hash` column to users table
- [ ] 4.3 Update user registration flow to hash passwords on create
- [ ] 4.4 Tests: registration stores hashed password, login verifies against hash

## Task 5: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4
- **Size:** S
- **Can run in parallel with:** —

### Subtasks
- [ ] 5.1 Run `$kk:test` skill to verify all tasks — full test suite, integration tests, edge cases
- [ ] 5.2 Run `$kk:document` skill to update any relevant docs
- [ ] 5.3 Run `$kk:review-code` skill with the project language input to review the implementation
- [ ] 5.4 Run `$kk:review-spec` skill to verify implementation matches design and implementation docs

## Dependency Graph

```
Task 1 ─→ Task 3 ─→ Task 5
Task 2 ─────────────→ Task 5
Task 4 (blocked) ────→ Task 5
```
