### Validation Rules

You MUST check every configuration file for:
- Required fields present (`name`, `version`, `entrypoint`)
- No deprecated fields (`legacy_mode`, `compat_shim`)
- Version string matches semver format

### Error Handling

When a validation error is found:
1. Record the file path, field name, and violation type
2. Continue checking remaining files — do not stop on first error
3. Group errors by severity: blocking vs. warning

### Phases

1. **Load schemas** — read all configuration schemas
2. **Scan files** — validate each target file against the rules above
3. **Classify errors** — group by severity (blocking vs. warning)
4. **Write report** — output to `docs/reports/`
5. **Present summary** — inline pass/fail counts
