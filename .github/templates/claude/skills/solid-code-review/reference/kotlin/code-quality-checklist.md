# Code Quality Checklist

## Error Handling

### Anti-patterns to Flag

- **Swallowed exceptions**: Empty catch blocks or catch with only logging. Example:
  ```kotlin
  try { ... } catch (e: Exception) { }                 // Silent failure
  try { ... } catch (e: Exception) { e.printStackTrace() } // Log and forget, no re-throw
  ```
- **Overly broad catch**: Catching `Exception` or `Throwable` instead of specific types
- **Error information leakage**: Stack traces or internal details exposed to users
- **Missing error handling**: Unchecked exceptions from I/O, network, or parsing operations not anticipated
- **Coroutine error handling**: Unhandled exceptions in `launch` blocks, missing `CoroutineExceptionHandler`, `runCatching` catching `CancellationException` (breaks structured concurrency — use a wrapper that rethrows `CancellationException`)

### Best Practices to Check

- [ ] Errors are caught at appropriate boundaries
- [ ] Error messages are user-friendly (no internal details exposed)
- [ ] Errors are logged with sufficient context for debugging
- [ ] Coroutine exceptions use structured concurrency and `SupervisorJob` where appropriate
- [ ] Fallback behavior is defined for recoverable errors
- [ ] Critical errors trigger alerts/monitoring

### Questions to Ask
- "What happens when this operation fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this error?"

---

## Performance & Caching

### CPU-Intensive Operations

- **Expensive operations in hot paths**: `Regex` construction in loops, JSON parsing in hot paths, crypto in loops
- **Blocking in coroutines**: Blocking I/O on `Dispatchers.Main`/`Default` instead of `Dispatchers.IO`
- **Unnecessary recomputation**: Same calculation done multiple times
- **Unnecessary object allocation**: Excessive `data class` copies in hot paths, autoboxing with nullable primitives (`Int?`)

### Database & I/O

- **N+1 queries**: Loop that makes a query per item instead of batch
  ```kotlin
  // Bad: N+1
  for (id in ids) {
      val user = em.find(User::class.java, id)
  }
  // Good: Batch
  val users = em.createQuery(
      "SELECT u FROM User u WHERE u.id IN :ids", User::class.java)
      .setParameter("ids", ids).resultList
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

- **Unbounded collections**: `MutableList`/`MutableMap` that grow without limit
- **Large object retention**: Holding references preventing GC
- **String concatenation in loops**: Use `StringBuilder` or `buildString` instead
- **Loading large files entirely**: Use `useLines`/`bufferedReader` streaming instead
- **Missing `.use {}` for resources**: Not using `.use {}` on `Closeable`/`AutoCloseable` — resources leak on exceptions (Kotlin's equivalent of try-with-resources)
- **Sequence vs list**: Using `map`/`filter` chains on large lists instead of `asSequence()`
- **Scope function abuse**: Deeply nested `.let { .also { .run { } } }` chains reducing readability
- **`data class copy()` with mutable fields**: `copy()` creates a shallow copy — mutable reference fields are shared between original and copy
- **Mutable state in `object` declarations**: `object` singletons with mutable `var` properties are effectively global mutable state — concurrency hazard without synchronization

### Questions to Ask
- "What's the time complexity of this operation?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable? Should it be?"
- "Can this be batched instead of one-by-one?"

---

## Boundary Conditions

### Null Safety

- **Force-unwrap abuse**: Using `!!` without justification (causes `KotlinNullPointerException`)
- **Platform type blindness**: Ignoring nullability of Java interop return values (platform types `T!`)
- **`lateinit` not initialized**: Accessing `lateinit var` before assignment (causes `UninitializedPropertyAccessException`)
- **Null vs default confusion**: Mixed usage of nullable types and default values without clear convention

### Empty Collections

- **Empty list not handled**: Code assumes list has items
- **Empty map edge case**: Key access or iteration on empty map
- **First/last element access**: `list.first()` or `list.last()` without empty check (use `firstOrNull()`)

### Numeric Boundaries

- **Division by zero**: Missing check before division (throws `ArithmeticException`)
- **Integer overflow**: `Int` wrapping at `Int.MAX_VALUE`, unchecked `Long` to `Int` conversion
- **Floating point comparison**: Using `==` instead of epsilon comparison or `BigDecimal`
- **Negative values**: Index or count that shouldn't be negative
- **Off-by-one errors**: Loop bounds, `subList`, pagination

### String Boundaries

- **Empty string**: Not handled as edge case
- **Blank string**: Passes `isNotEmpty()` but is whitespace-only (use `isNotBlank()`)
- **Very long strings**: No length limits causing memory/display issues
- **Unicode edge cases**: Emoji, RTL text, surrogate pairs

### Common Patterns to Flag

```kotlin
// Dangerous: force-unwrap (KotlinNullPointerException if user or profile is null)
val name = user!!.profile!!.name

// Dangerous: list access without check (NoSuchElementException if items is empty)
val first = items.first()

// Dangerous: division without check (ArithmeticException if count is 0)
val avg = total / count

// Dangerous: lateinit access before init
lateinit var config: Config
fun process() = config.value  // UninitializedPropertyAccessException
```

### Questions to Ask
- "What if this is null?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at the boundaries (0, -1, Int.MAX_VALUE)?"
