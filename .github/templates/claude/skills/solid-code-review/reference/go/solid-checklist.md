# SOLID Smell Prompts

## SRP (Single Responsibility)

- Package owns unrelated concerns (e.g., HTTP + DB + domain rules in one package)
- Large struct with low cohesion or multiple reasons to change
- Functions that orchestrate many unrelated steps
- God structs that know too much about the system
- Circular import between packages (Go enforces this at compile time — signals tangled responsibilities)
- **Ask**: "What is the single reason this package/struct would change?"

## OCP (Open/Closed)

- Adding a new behavior requires editing many switch/if blocks
- Feature growth requires modifying core logic rather than extending
- No plugin/strategy/hook points for variation
- **Ask**: "Can I add a new variant without touching existing code?"

## LSP (Liskov Substitution)

- Type switches/assertions on interface values instead of relying on the interface contract
- Interface implementations that violate expected behavior or documented contracts
- Embedded type methods overridden with incompatible semantics
- **Ask**: "Can I substitute any implementation without the caller knowing?"

## ISP (Interface Segregation)

- Interfaces with many methods, most unused by implementers (Go idiom: keep interfaces small — `io.Reader`, `io.Writer`)
- Callers depend on broad interfaces for narrow needs
- Interfaces defined at the implementation site instead of the consumer site
- Missing compile-time interface checks: `var _ Interface = (*Type)(nil)` ensures types satisfy interfaces at build time
- **Ask**: "Do all implementers use all methods?"

## DIP (Dependency Inversion)

- High-level logic depends on concrete IO, storage, or network types
- Hard-coded implementations instead of abstractions or injection
- Import chains that couple business logic to infrastructure
- Returning interfaces instead of concrete types — Go idiom: accept interfaces, return structs
- **Ask**: "Can I swap the implementation without changing business logic?"

---

## Common Code Smells (Beyond SOLID)

| Smell | Signs |
|-------|-------|
| **Long method** | Function > 30 lines, multiple levels of nesting |
| **Feature envy** | Method uses more data from another struct/package than its own |
| **Data clumps** | Same group of parameters passed together repeatedly |
| **Primitive obsession** | Using strings/numbers instead of domain types |
| **Shotgun surgery** | One change requires edits across many files |
| **Divergent change** | One package changes for many unrelated reasons |
| **Dead code** | Unreachable or never-called code |
| **Speculative generality** | Abstractions for hypothetical future needs |
| **Magic numbers/strings** | Hardcoded values without named constants |

---

## Refactor Heuristics

1. **Split by responsibility, not by size** - A small file can still violate SRP
2. **Introduce abstraction only when needed** - Wait for the second use case
3. **Keep refactors incremental** - Isolate behavior before moving
4. **Preserve behavior first** - Add tests before restructuring
5. **Name things by intent** - If naming is hard, the abstraction might be wrong
6. **Beware tight coupling via embedding** - Embedding exposes all methods, creating implicit interface satisfaction and coupling
7. **Make illegal states unrepresentable** - Use types to enforce invariants
