# Tasks: Auth Refactor

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: in progress
> Created: 2026-05-15
> Not Doing: OAuth/social login, API rate limiting, token revocation list, multi-device session management

## Task 1: User login end-to-end
- **Status:** done
- **Depends on:** —
- **Size:** M
- **Can run in parallel with:** Task 2

### Subtasks
- [x] 1.1 Create JWT token generation and validation module
- [x] 1.2 Create login endpoint with credential validation and token issuance
- [x] 1.3 Create auth middleware that validates access tokens
- [x] 1.4 Integration test for the login flow

## Task 2: Token refresh end-to-end
- **Status:** in progress
- **Depends on:** —
- **Size:** S
- **Can run in parallel with:** Task 1

### Subtasks
- [x] 2.1 Create refresh endpoint with token rotation
- [ ] 2.2 Integration test for refresh flow (happy path + expired + reuse detection)

## Task 3: Protected routes migration
- **Status:** not started
- **Depends on:** Task 1
- **Size:** M
- **Can run in parallel with:** —

### Subtasks
- [ ] 3.1 Apply JWT middleware to all /api/v1/* routes alongside existing session middleware
- [ ] 3.2 Rejection tests (no token, expired, malformed)
- [ ] 3.3 Remove session middleware after migration window

## Task 4: Final verification
- **Status:** not started
- **Depends on:** Task 2, Task 3
- **Size:** S
- **Can run in parallel with:** —

### Subtasks
- [ ] 4.1 End-to-end test: login → access → refresh → access → logout
- [ ] 4.2 Verify zero-downtime: both auth methods work simultaneously

## Dependency Graph

```
Task 1 ──→ Task 3 ──→ Task 4
Task 2 ─────────────→ Task 4
```
