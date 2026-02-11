# Security and Reliability Checklist

## Input/Output Safety

- **XSS**: Unsafe HTML injection, unescaped output in JSP/Thymeleaf templates, raw string interpolation in HTTP responses
- **Injection**: SQL injection via string concatenation instead of `PreparedStatement`; command injection via `Runtime.exec` or `ProcessBuilder` with user input; JNDI injection via unsanitized lookup names
- **SSRF**: User-controlled URLs reaching internal services without allowlist validation
- **Path traversal**: User input in file paths without sanitization (`../` attacks), `Paths.get` with user input not normalized
- **Unsafe deserialization**: `ObjectInputStream.readObject` on untrusted data, XXE in XML parsers with external entities enabled

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

- Unpinned dependencies allowing malicious updates (version ranges in `pom.xml`/`build.gradle`)
- Dependency confusion (private package name collision in Maven Central/JCenter)
- Importing from untrusted repositories without integrity checks
- Outdated dependencies with known CVEs

## CORS & Headers

- Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials)
- Missing security headers (CSP, X-Frame-Options, X-Content-Type-Options)
- Exposed internal headers or stack traces

## Runtime Risks

- Unbounded loops, recursive calls, or large in-memory buffers
- Missing timeouts, retries, or rate limiting on external calls
- Blocking operations on request-handling threads (sync I/O in reactive/async context)
- Resource exhaustion (file handles, connections, thread pools, memory)
- **Log injection**: User-controlled input written directly to log messages without sanitization (enables log forging, CRLF injection)
- **`assert` disabled by default**: Java `assert` statements are off unless `-ea` flag is passed — never use for security/input validation
- ReDoS (Regular Expression Denial of Service)

## Cryptography

- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded IVs or salts
- Using encryption without authentication (ECB mode, no HMAC)
- Insufficient key length
- Using `java.util.Random` for security-sensitive values (tokens, nonces, salts) instead of `java.security.SecureRandom` (predictable output)
- Using `==` or `.equals()` for secret/token comparison instead of `MessageDigest.isEqual` (leaks timing information)

## Race Conditions

Race conditions are subtle bugs that cause intermittent failures and security vulnerabilities. Pay special attention to:

### Shared State Access
- Multiple threads accessing shared variables without `synchronized`, `Lock`, or `volatile`
- Global state or singletons modified concurrently
- Lazy initialization without proper locking (double-checked locking issues)
- Non-thread-safe collections (`HashMap`, `ArrayList`) used in concurrent context instead of `ConcurrentHashMap`, `CopyOnWriteArrayList`

### Check-Then-Act (TOCTOU)
- `if (exists) then use` patterns without atomic operations
- `if (authorized) then perform` where authorization can change
- File existence check followed by file operation
- Balance check followed by deduction (financial operations)
- Inventory check followed by order placement

### Database Concurrency
- Missing optimistic locking (`@Version` column, `updated_at` checks)
- Missing pessimistic locking (`SELECT FOR UPDATE`, `@Lock(LockModeType.PESSIMISTIC_WRITE)`)
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
```java
// Dangerous patterns:

// TOCTOU
File file = new File(path);
if (!file.exists()) {
    file.createNewFile();
}

// Read-modify-write
int value = cache.get(key);
value++;
cache.put(key, value);

// Check-then-act
if (user.getBalance() >= amount) {
    user.setBalance(user.getBalance() - amount);
}
```

### Questions to Ask
- "What happens if two requests hit this code simultaneously?"
- "Is this operation atomic or can it be interrupted?"
- "What shared state does this code access?"
- "How does this behave under high concurrency?"

## Data Integrity

- Missing transactions, partial writes, or inconsistent state updates
- Weak validation before persistence (unsafe type casting)
- Missing idempotency for retryable operations
- Lost updates due to concurrent modifications
