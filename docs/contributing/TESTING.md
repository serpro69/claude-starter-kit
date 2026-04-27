# Testing

## Running Tests

Run all test suites:

```bash
for test in test/test-*.sh; do $test; done
```

Run a single suite:

```bash
./test/test-plugin-structure.sh
```

## Test Suites

| Suite | What it covers |
|-------|----------------|
| `test-plugin-structure.sh` | Plugin/marketplace manifests, skills, commands, hooks, profiles, cross-references, kodex-plugin generated output validation |
| `test-codex-structure.sh` | Codex marketplace, config.toml, hooks.json, agent TOMLs, Starlark rules, scripts, AGENTS.md |
| `test-template-sync.sh` | CLI parsing, manifest validation, variable substitution, settings merge, plugin migration, sync exclusions |
| `test-template-cleanup.sh` | Manifest generation, variable capture, git tag/SHA detection |
| `test-claude-extra.sh` | CLAUDE.extra.md existence, compare_files detection, auto-import |
| `test-manifest-jq.sh` | JSON generation patterns, special character handling, schema validation, round-trip |
| `test-semver-compare.sh` | Semver comparison logic used by release workflows |
| `test-hooks.sh` | Hook script validation (Bash denylist patterns, capy HTTP interception) |

## Test Infrastructure

Tests use shared utilities from `test/helpers.sh`:

- `log_section`, `log_test` — structured output
- `assert_equals`, `assert_contains`, `assert_file_exists` — assertion helpers
- `log_pass`, `log_fail`, `log_skip` — result reporting
- `print_summary` — final pass/fail count

Test fixtures live in `test/fixtures/`.

## Writing Tests

- Add tests to the appropriate existing suite when possible
- New suites follow the same pattern: source `helpers.sh`, use `log_section`/`log_test`/`assert_*`, end with `print_summary`
- Structure tests check file existence and content invariants, not runtime behavior
- The bidirectional index invariant (every link in `index.md` resolves, every `.md` in a phase dir is referenced) is enforced in `test-plugin-structure.sh` — adding profile content automatically gets tested

## Go Tests

The generation tool (`cmd/generate-kodex/`) has Go unit tests:

```bash
go test ./cmd/generate-kodex/...
```

These are also run as part of `make generate-kodex`.

## Validation Before Release

- All 8 shell test suites must pass
- `make generate-kodex` must leave `kodex-plugin/` and `.codex/agents/` clean (`git diff --exit-code`)
- Go tests must pass (`go test ./...`)
