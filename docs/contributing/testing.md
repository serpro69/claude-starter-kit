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
| `test-cpr.sh` | Claude Plugin Root resolver — exact/fuzzy matching, scope priority, env var precedence, error handling |
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

The Go tools under `cmd/` ship unit and integration tests:

```bash
go test ./cmd/generate-kodex/...   # Codex generation tool
go test ./cmd/plugin-graph/...     # plugin dependency-graph analyzer
```

`cmd/generate-kodex` tests also run as part of `make generate-kodex`.

`cmd/plugin-graph` tests run via `make plugin-graph`, which additionally runs
`go run ./cmd/plugin-graph --root klaude-plugin/ validate` against the real
plugin — a structural-health gate that exits non-zero on broken markdown/template
links or orphaned content. It complements `test-plugin-structure.sh`'s
bidirectional index invariant: the structure test enforces profile `index.md`
completeness, while `plugin-graph validate` catches broken links and orphans
across the whole plugin. See [Architecture › Plugin Graph Analysis](architecture.md).

## Validation Before Release

- All 8 shell test suites must pass
- `make generate-kodex` must leave `kodex-plugin/` and `.codex/agents/` clean (`git diff --exit-code`)
- `make plugin-graph` must pass (Go tests + `validate` exits 0 against `klaude-plugin/`)
- Go tests must pass (`go test ./...`)
