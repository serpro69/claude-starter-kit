# Code Quality Checklist

## Error Handling

### Anti-patterns to Flag

- **Swallowed exceptions**: Empty `except` blocks or catch with only logging. Example:
  ```python
  try: ...
  except Exception: pass              # Silent failure
  try: ...
  except Exception as e: print(e)     # Log and forget, no re-raise
  ```
- **Overly broad except**: Catching bare `Exception` or `BaseException` instead of specific types
- **Error information leakage**: Stack traces or internal details exposed to users
- **Missing error handling**: No try-except around fallible operations (I/O, network, parsing)
- **Async error handling**: Unhandled exceptions in `asyncio` tasks, missing `try/except` in coroutines, fire-and-forget tasks without error callbacks

### Best Practices to Check

- [ ] Errors are caught at appropriate boundaries
- [ ] Error messages are user-friendly (no internal details exposed)
- [ ] Errors are logged with sufficient context for debugging
- [ ] Async task exceptions are retrieved or handled (not silently dropped)
- [ ] Fallback behavior is defined for recoverable errors
- [ ] Critical errors trigger alerts/monitoring

### Questions to Ask
- "What happens when this operation fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this error?"

---

## Performance & Caching

### CPU-Intensive Operations

- **Expensive operations in hot paths**: `re.compile` in loops, JSON parsing in hot paths, crypto in loops
- **Blocking the event loop**: Sync I/O or heavy computation in `async` functions without `run_in_executor`
- **Unnecessary recomputation**: Same calculation done multiple times
- **Missing caching**: Pure functions called repeatedly with same inputs, no `@functools.lru_cache` or `@functools.cache`
- **GIL limitation for CPU-bound work**: `threading` does not parallelize CPU-bound tasks due to the GIL — use `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`

### Database & I/O

- **N+1 queries**: Loop that makes a query per item instead of batch
  ```python
  # Bad: N+1
  for id in ids:
      user = db.execute("SELECT * FROM users WHERE id = %s", (id,)).fetchone()

  # Good: Batch
  users = db.execute("SELECT * FROM users WHERE id IN %s", (tuple(ids),)).fetchall()
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

- **Unbounded collections**: Lists/dicts that grow without limit
- **Large object retention**: Holding references preventing GC, circular references
- **String concatenation in loops**: Use `"".join(parts)` instead
- **Loading large files entirely**: Use streaming/iterator patterns instead
- **Mutable default arguments**: `def foo(items=[])` — default list is shared across all calls, mutating it causes cross-call contamination
- **Generator exhaustion**: Iterating a generator/iterator twice silently produces no results on the second pass
- **Missing context managers**: Not using `with` for files, DB connections, locks — resources leak on exceptions
- **Late binding closures**: Lambdas/closures in loops capture the variable by reference, not by value — all closures see the final loop value
- **`__del__` unreliability**: `__del__` is not guaranteed to run — never rely on it for cleanup; use context managers or `atexit`

### Questions to Ask
- "What's the time complexity of this operation?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable? Should it be?"
- "Can this be batched instead of one-by-one?"

---

## Boundary Conditions

### None Handling

- **Missing None checks**: Accessing attributes on potentially `None` objects (causes `AttributeError`)
- **Truthiness confusion**: `if value:` when `0`, `""`, `[]`, `{}` are valid values
- **Excessive None checks**: Deep chains of `if x is not None and x.y is not None` hiding structural issues
- **`is` vs `==` confusion**: Using `is` to compare values instead of `==` — works unreliably due to interning (e.g., `x is "hello"` may pass for small strings but fail for others)
- **None vs missing inconsistency**: Mixed usage of `None` and sentinel values without clear convention

### Empty Collections

- **Empty list not handled**: Code assumes list has items
- **Empty dict edge case**: Iteration or key access on empty dict
- **First/last element access**: `items[0]` or `items[-1]` without length check

### Numeric Boundaries

- **Division by zero**: Missing check before division (raises `ZeroDivisionError`)
- **Integer overflow**: Python handles big ints natively, but watch for C-extension or struct boundaries
- **Floating point comparison**: Using `==` instead of `math.isclose`
- **Negative values**: Index or count that shouldn't be negative
- **Off-by-one errors**: Loop bounds, slicing, pagination

### String Boundaries

- **Empty string**: Not handled as edge case
- **Whitespace-only string**: Passes truthiness check but is effectively empty
- **Very long strings**: No length limits causing memory/display issues
- **Unicode edge cases**: Emoji, RTL text, combining characters

### Common Patterns to Flag

```python
# Dangerous: no None check (AttributeError if user or profile is None)
name = user.profile.name

# Dangerous: list access without check (IndexError if items is empty)
first = items[0]

# Dangerous: division without check (ZeroDivisionError if count is 0)
avg = total / count

# Dangerous: truthiness check excludes valid values
if value:  ...   # fails for 0, "", [], {}, False
```

### Questions to Ask
- "What if this is None?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at the boundaries (0, -1, sys.maxsize)?"
