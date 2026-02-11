# Code Quality Checklist

## Error Handling

### Anti-patterns to Flag

- **Discarded errors**: Ignoring returned errors with `_`. Example:
  ```go
  result, _ := someOperation()           // Silent failure
  if err != nil { log.Println(err) }     // Log and forget, no return
  ```
- **Missing error context**: Returning raw errors without wrapping via `fmt.Errorf("context: %w", err)` — breaks `errors.Is`/`errors.As` unwrapping chains
- **Overly broad error handling**: Not using `errors.Is`/`errors.As` to check specific error types
- **Error information leakage**: Stack traces or internal details exposed to users
- **Missing error handling**: Unchecked error returns from I/O, network, or parsing operations
- **Goroutine error handling**: Unrecovered panics in goroutines, unchecked error returns, missing `defer recover()`

### Best Practices to Check

- [ ] Errors are caught at appropriate boundaries
- [ ] Error messages are user-friendly (no internal details exposed)
- [ ] Errors are logged with sufficient context for debugging
- [ ] Goroutine panics are recovered or errors are propagated via channels
- [ ] Fallback behavior is defined for recoverable errors
- [ ] Critical errors trigger alerts/monitoring

### Questions to Ask
- "What happens when this operation fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this error?"

---

## Performance & Caching

### CPU-Intensive Operations

- **Expensive operations in hot paths**: `regexp.MustCompile` in loops, `json.Unmarshal` in hot paths, crypto in loops
- **Blocking the caller**: Long-running operations without spawning goroutines for concurrency
- **Missing context propagation**: Not passing `context.Context` through call chains, not checking `ctx.Done()` or `ctx.Err()`
- **Unnecessary recomputation**: Same calculation done multiple times
- **Missing caching**: Pure functions called repeatedly with same inputs, no `sync.Once` for one-time init
- **`http.DefaultClient` has no timeout**: Always create a custom `http.Client` with explicit `Timeout` — the default waits forever

### Database & I/O

- **N+1 queries**: Loop that makes a query per item instead of batch
  ```go
  // Bad: N+1
  for _, id := range ids {
      var user User
      db.QueryRow("SELECT * FROM users WHERE id = ?", id).Scan(&user)
  }
  // Good: Batch
  rows, err := db.Query("SELECT * FROM users WHERE id IN (?)", ids)
  ```
- **Missing indexes**: Queries on unindexed columns
- **Over-fetching**: SELECT * when only few columns needed
- **No pagination**: Loading entire dataset into memory

### Caching Issues

- **Missing cache for expensive operations**: Repeated API calls, DB queries, computations
- **Cache without TTL**: Stale data served indefinitely
- **Cache without invalidation strategy**: Data updated but cache not cleared
- **Cache key collisions**: Insufficient key uniqueness
- **Caching user-specific data globally**: Security/privacy issue

### Memory

- **Unbounded collections**: Slices/maps that grow without limit
- **Large object retention**: Holding references preventing GC
- **String concatenation in loops**: Use `strings.Builder` instead
- **Loading large files entirely**: Use `io.Reader` streaming instead
- **Slice append gotcha**: `append` may return a new backing array or mutate the existing one; sub-slices share backing arrays and can leak data
- **Defer in loops**: `defer` runs at function exit, not loop iteration — resources accumulate until function returns
- **Channel deadlocks**: Unbuffered channels without receivers, goroutines blocked on full/empty channels
- **`init()` function abuse**: Package-level `init()` functions with side effects (I/O, network calls) — makes testing and initialization ordering difficult

### Questions to Ask
- "What's the time complexity of this operation?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable? Should it be?"
- "Can this be batched instead of one-by-one?"

---

## Boundary Conditions

### Nil Handling

- **Missing nil checks**: Accessing fields on potentially nil pointers (causes panic)
- **Zero value confusion**: `if value != 0` when `0` is a valid value; not distinguishing zero value from "not set"
- **Excessive nil checks**: Deep chains of `if x != nil && x.Y != nil && x.Y.Z != nil` hiding structural issues
- **Pointer vs value inconsistency**: Mixed usage of pointer and value receivers without clear convention

### Empty Collections

- **Empty slice not handled**: Code assumes slice has items
- **Nil map write**: Assigning to a nil map causes a panic — always initialize with `make(map[K]V)` before writing
- **Map iteration order**: Go randomizes map iteration order — never depend on consistent ordering
- **First/last element access**: `slice[0]` or `slice[len(slice)-1]` without length check

### Numeric Boundaries

- **Division by zero**: Missing check before division
- **Integer overflow**: Large numbers exceeding type bounds (e.g., `int32` wrapping)
- **Floating point comparison**: Using `==` instead of epsilon comparison
- **Negative values**: Index or count that shouldn't be negative
- **Off-by-one errors**: Loop bounds, array slicing, pagination

### String Boundaries

- **Empty string**: Not handled as edge case
- **Whitespace-only string**: Passes `!= ""` check but is effectively empty
- **Very long strings**: No length limits causing memory/display issues
- **Unicode edge cases**: Emoji, RTL text, combining characters

### Common Patterns to Flag

```go
// Dangerous: no nil check (panic if user or Profile is nil)
name := user.Profile.Name

// Dangerous: slice access without check (panic if items is empty)
first := items[0]

// Dangerous: division without check (panic if count is 0)
avg := total / count

// Dangerous: zero value check excludes valid values
if value != 0 { ... }  // may exclude legitimate zero values (e.g., temperature, offset)
if name != "" { ... }   // cannot distinguish "not set" from "intentionally empty" — consider *string if the distinction matters
```

### Questions to Ask
- "What if this is nil?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at the boundaries (0, -1, MAX_INT)?"
