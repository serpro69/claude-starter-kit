# Security and Reliability Checklist

## Input/Output Safety

- **XSS**: Unsafe HTML injection, using `text/template` instead of `html/template`, bypassing auto-escaping via `template.HTML()`, raw string interpolation in HTTP responses
- **Injection**: SQL/NoSQL/command injection via string concatenation or `fmt.Sprintf` instead of parameterized queries
- **SSRF**: User-controlled URLs reaching internal services without allowlist validation
- **Path traversal**: User input in file paths without sanitization (`../` attacks), `filepath.Clean` not used
- **Unsafe reflection**: Using `reflect` or `unsafe` packages to bypass type safety with user-controlled input
- **cgo risks**: Importing C code via `cgo` bypasses Go's memory safety — review C bindings for buffer overflows and memory leaks

## AuthN/AuthZ

- Missing tenant or ownership checks for read/write operations
- New endpoints without auth guards or RBAC enforcement
- Trusting client-provided roles/flags/IDs
- Broken access control (IDOR - Insecure Direct Object Reference)
- Session fixation or weak session management

## JWT & Token Security

- Algorithm confusion attacks (accepting `none` or `HS256` when expecting `RS256`)
- Weak or hardcoded secrets
- Missing expiration (`exp`) or not validating it
- Sensitive data in JWT payload (tokens are base64, not encrypted)
- Not validating `iss` (issuer) or `aud` (audience)

## Secrets and PII

- API keys, tokens, or credentials in code/config/logs
- Secrets in git history or environment variables exposed to client
- Excessive logging of PII or sensitive payloads
- Missing data masking in error messages

## Supply Chain & Dependencies

- Missing or tampered `go.sum` entries bypassing integrity verification
- Dependency confusion (private module path collision on public proxies)
- Using `replace` directives pointing to untrusted sources
- Outdated dependencies with known CVEs (`govulncheck` not run)

## CORS & Headers

- Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials)
- Missing security headers (CSP, X-Frame-Options, X-Content-Type-Options)
- Exposed internal headers or stack traces

## Runtime Risks

- Unbounded loops, recursive calls, or large in-memory buffers
- Missing timeouts, retries, or rate limiting on external calls
- Blocking operations on request path (long-running operations without goroutines or context cancellation)
- **Goroutine leaks**: goroutines that never terminate due to missing context cancellation, blocked channel operations, or forgotten `done` signals
- Resource exhaustion (file handles, connections, memory)
- ReDoS (Regular Expression Denial of Service)

## Cryptography

- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded IVs or salts
- Using encryption without authentication (ECB mode, no HMAC)
- Insufficient key length
- Using `==` for secret/token comparison instead of `crypto/subtle.ConstantTimeCompare` (leaks timing information)

## Race Conditions

Race conditions are subtle bugs that cause intermittent failures and security vulnerabilities. Pay special attention to:

### Shared State Access
- Multiple goroutines accessing shared variables without `sync.Mutex`, `sync.RWMutex`, `sync/atomic`, or channels
- Global state or singletons modified concurrently
- Lazy initialization without `sync.Once`
- Concurrent map read/write causes a **fatal runtime crash** (not just data corruption) — use `sync.Map` or mutex-guarded maps
- Run with `-race` flag (`go test -race`) to detect data races

### Check-Then-Act (TOCTOU)
- `if (exists) then use` patterns without atomic operations
- `if (authorized) then perform` where authorization can change
- File existence check followed by file operation
- Balance check followed by deduction (financial operations)
- Inventory check followed by order placement

### Database Concurrency
- Missing optimistic locking (`version` column, `updated_at` checks)
- Missing pessimistic locking (`SELECT FOR UPDATE`)
- Read-modify-write without transaction isolation
- Counter increments without atomic operations (`UPDATE SET count = count + 1`)
- Unique constraint violations in concurrent inserts

### Distributed Systems
- Missing distributed locks for shared resources
- Leader election race conditions
- Cache invalidation races (stale reads after writes)
- Event ordering dependencies without proper sequencing
- Split-brain scenarios in cluster operations

### Common Patterns to Flag
```go
// Dangerous patterns:

// TOCTOU
if _, err := os.Stat(path); os.IsNotExist(err) {
    os.Create(path)
}

// Read-modify-write
value := get(key)
value++
set(key, value)

// Check-then-act
if user.Balance >= amount {
    user.Balance -= amount
}
```

### Questions to Ask
- "What happens if two requests hit this code simultaneously?"
- "Is this operation atomic or can it be interrupted?"
- "What shared state does this code access?"
- "How does this behave under high concurrency?"

## Data Integrity

- Missing transactions, partial writes, or inconsistent state updates
- Weak validation before persistence (type assertion issues)
- Missing idempotency for retryable operations
- Lost updates due to concurrent modifications
