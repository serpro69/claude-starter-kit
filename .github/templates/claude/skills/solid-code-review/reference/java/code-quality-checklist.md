# Code Quality Checklist

## Error Handling

### Anti-patterns to Flag

- **Swallowed exceptions**: Empty catch blocks or catch with only logging. Example:
  ```java
  try { ... } catch (Exception e) { }                    // Silent failure
  try { ... } catch (Exception e) { e.printStackTrace(); } // Log and forget, no re-throw
  ```
- **Overly broad catch**: Catching `Exception` or `Throwable` instead of specific types
- **Error information leakage**: Stack traces or internal details exposed to users
- **Missing error handling**: Unchecked exceptions from I/O, network, or parsing operations not anticipated
- **Checked exception abuse**: Declaring `throws Exception` instead of specific types, wrapping checked exceptions in `RuntimeException` without cause chaining
- **CompletableFuture error handling**: Missing `.exceptionally()` or `.handle()`, unobserved exceptions in async chains

### Best Practices to Check

- [ ] Errors are caught at appropriate boundaries
- [ ] Error messages are user-friendly (no internal details exposed)
- [ ] Errors are logged with sufficient context for debugging
- [ ] Async/CompletableFuture exceptions are handled, not silently dropped
- [ ] Fallback behavior is defined for recoverable errors
- [ ] Critical errors trigger alerts/monitoring

### Questions to Ask
- "What happens when this operation fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this error?"

---

## Performance & Caching

### CPU-Intensive Operations

- **Expensive operations in hot paths**: `Pattern.compile` in loops, JSON parsing in hot paths, crypto in loops
- **Blocking request threads**: Blocking I/O on reactor/virtual threads, heavy computation without offloading
- **Unnecessary recomputation**: Same calculation done multiple times
- **Autoboxing in hot paths**: Repeated `int`/`Integer` boxing in tight loops
- **Stream API pitfalls**: Parallel streams on shared mutable state, stateful lambdas in `map`/`filter` chains, side effects in `forEach`

### Database & I/O

- **N+1 queries**: Loop that makes a query per item instead of batch
  ```java
  // Bad: N+1
  for (Long id : ids) {
      User user = em.find(User.class, id);
  }
  // Good: Batch
  List<User> users = em.createQuery(
      "SELECT u FROM User u WHERE u.id IN :ids", User.class)
      .setParameter("ids", ids).getResultList();
  ```
- **Missing indexes**: Queries on unindexed columns
- **Over-fetching**: SELECT * when only few columns needed; eager fetching entire object graphs
- **No pagination**: Loading entire dataset into memory

### Caching Issues

- **Missing cache for expensive operations**: Repeated API calls, DB queries, computations
- **Cache without TTL**: Stale data served indefinitely
- **Cache without invalidation strategy**: Data updated but cache not cleared
- **Cache key collisions**: Insufficient key uniqueness
- **Caching user-specific data globally**: Security/privacy issue

### Memory

- **Unbounded collections**: `ArrayList`/`HashMap` that grow without limit
- **Large object retention**: Holding references preventing GC
- **String concatenation in loops**: Use `StringBuilder` instead
- **Loading large files entirely**: Use `InputStream`/`BufferedReader` streaming instead
- **Resource leaks**: Missing `try-with-resources` for `Closeable`/`AutoCloseable` resources
- **`equals`/`hashCode` contract**: Overriding `equals` without `hashCode` (or vice versa) — breaks `HashMap`/`HashSet` behavior
- **`==` vs `.equals()` for strings**: Reference comparison instead of value comparison for `String` and boxed types (`Integer`, `Long`)
- **`ConcurrentModificationException`**: Modifying a collection during `for-each` iteration — use `Iterator.remove()` or concurrent collections

### Questions to Ask
- "What's the time complexity of this operation?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable? Should it be?"
- "Can this be batched instead of one-by-one?"

---

## Boundary Conditions

### Null Handling

- **Missing null checks**: Accessing methods on potentially null references (causes `NullPointerException`)
- **Optional misuse**: `Optional.get()` without `isPresent()`, using `Optional` as field type
- **Nullable annotations ignored**: `@Nullable` return values used without checks
- **Null vs empty inconsistency**: Mixed usage of `null` and empty collections/strings without clear convention

### Empty Collections

- **Empty list not handled**: Code assumes list has items
- **Empty map edge case**: Key access or iteration on empty map
- **First/last element access**: `list.get(0)` or `list.get(list.size()-1)` without size check

### Numeric Boundaries

- **Division by zero**: Missing check before division (throws `ArithmeticException`)
- **Integer overflow**: `int` wrapping at `Integer.MAX_VALUE`, unchecked cast from `long` to `int`
- **Floating point comparison**: Using `==` instead of epsilon comparison or `BigDecimal`
- **Negative values**: Index or count that shouldn't be negative
- **Off-by-one errors**: Loop bounds, `subList`, pagination

### String Boundaries

- **Empty string**: Not handled as edge case
- **Whitespace-only string**: Passes non-null check but is effectively empty
- **Very long strings**: No length limits causing memory/display issues
- **Unicode edge cases**: Emoji, RTL text, surrogate pairs

### Common Patterns to Flag

```java
// Dangerous: no null check (NullPointerException if user or getProfile() is null)
String name = user.getProfile().getName();

// Dangerous: list access without check (IndexOutOfBoundsException if items is empty)
Item first = items.get(0);

// Dangerous: division without check (ArithmeticException if count is 0)
int avg = total / count;

// Dangerous: Optional.get without check
String value = optional.get();  // NoSuchElementException if empty
```

### Questions to Ask
- "What if this is null?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at the boundaries (0, -1, Integer.MAX_VALUE)?"
