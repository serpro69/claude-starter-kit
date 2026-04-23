# Go Vendor Integration — Design

## Overview

Integrate external Go knowledge from [samber/cc-skills-golang](https://github.com/samber/cc-skills-golang) into the kk plugin's Go profile via an automated vendor pipeline. A YAML manifest maps upstream skill files to profile phase directories; a Go CLI tool fetches, transforms, and places the content; and injection markers in `index.md` files separate vendored entries from hand-written ones.

## Problem Statement

The Go profile currently only populates `review-code/` with 4 hand-written checklists. samber/cc-skills-golang provides ~16 high-quality, actively maintained Go skills covering security, code style, concurrency, testing, design patterns, and more. We want this knowledge flowing through the structured profile pipeline (review-code applies it against the diff, implement loads it before writing code, etc.) without copy-pasting or maintaining a fork.

## Goals

1. Vendor samber's Go knowledge into all 6 profile phases (review-code, implement, design, test, document, review-spec)
2. Automated pipeline: manifest-driven fetch, transform, place, and index update
3. Zero maintenance burden beyond bumping a version tag and reviewing the diff
4. Support multiple upstreams for future extensibility
5. Clean separation between vendored and hand-written content via injection markers

## Non-Goals

1. CI automation for upstream change detection (deferred to follow-up)
2. Vendoring for other language profiles (the tool supports it, but only Go is populated now)
3. Installing samber's plugin as a side-by-side standalone plugin
4. Merging vendored content with hand-written files (replace, not merge)

## Architecture

### Component overview

```
scripts/
  go-vendor-manifest.yml          # manifest: maps upstream files to profile phases
  vendor-profiles.sh              # (future) CI wrapper, currently just make target

cmd/vendor-profiles/
  main.go                         # CLI entry point
  manifest.go                     # YAML parsing into typed structs
  fetch.go                        # HTTP fetch from GitHub raw URLs
  transform.go                    # keep transforms (from_first_h1, headings, all)
  linkrewrite.go                  # markdown link rewriting for vendored files
  index.go                        # index.md injection marker management
  main_test.go                    # integration test
  manifest_test.go
  transform_test.go
  linkrewrite_test.go
  index_test.go
  testdata/                       # fixtures for tests

klaude-plugin/profiles/go/
  review-code/
    index.md                      # hand-written + <!-- BEGIN/END VENDORED --> sections
    solid-checklist.md            # hand-written (survives)
    removal-plan.md               # hand-written (survives)
    security.md                   # vendored (replaces security-checklist.md)
    code-style.md                 # vendored (replaces code-quality-checklist.md)
    naming.md                     # vendored
    error-handling.md             # vendored
    performance.md                # vendored
    database.md                   # vendored (conditional)
    concurrency.md                # vendored (conditional)
    grpc.md                       # vendored (conditional)
    http.md                       # vendored (conditional)
    security-injection-ref.md     # vendored (references/ content)
  implement/                      # new — all vendored
  design/                         # new — all vendored
  test/                           # new — all vendored
  document/                       # new — all vendored
```

### Data flow

```
manifest.yml
  → parse into []Upstream
  → for each upstream:
      → resolve GitHub raw base URL from repo + ref
      → for each file entry:
          → fetch source file from raw URL
          → apply keep transform (from_first_h1 / headings / all)
          → rewrite relative markdown links
          → write to klaude-plugin/profiles/go/<phase>/<as>
      → for each phase directory touched:
          → update index.md between injection markers
```

## Manifest Schema

The manifest is a YAML file containing a top-level array of upstream entries.

```yaml
# scripts/go-vendor-manifest.yml

- repo: samber/cc-skills-golang
  ref: v1.1.3
  keep_default: from_first_h1
  files:
    - source: skills/golang-security/SKILL.md
      phase: review-code
      as: security.md

    - source: skills/golang-security/references/injection.md
      phase: review-code
      as: security-injection-ref.md
      keep: all

    - source: skills/golang-database/SKILL.md
      phase: review-code
      as: database.md
      condition: "Diff imports database/sql, sqlx, gorm, ent, or pgx"
```

### Field definitions

| Field | Scope | Required | Description |
|---|---|---|---|
| `repo` | upstream | yes | GitHub `owner/repo` |
| `ref` | upstream | yes | Git ref — tag (preferred) or branch |
| `keep_default` | upstream | no | Default keep transform for this upstream's files. One of: `from_first_h1`, `all`, or a `headings` object. Defaults to `all` if absent. |
| `source` | file | yes | Repo-relative path to the source file |
| `phase` | file | yes | Target phase subdirectory name (`review-code`, `implement`, `design`, `test`, `document`, `review-spec`) |
| `as` | file | yes | Target filename in the phase directory |
| `keep` | file | no | Per-file override of `keep_default` |
| `condition` | file | no | `Load if:` predicate for conditional loading. Absent = always-load. |

### Keep transforms

- **`all`** — verbatim copy. Used for `references/` files that are already clean.
- **`from_first_h1`** — strip everything before the first line matching `^# ` (regex: `^# .+`). This removes YAML frontmatter, persona declarations, mode descriptions, cross-skill references, and community-default notes — all of which live above the first H1 in samber's SKILL.md files. The tool exits non-zero if no H1 is found.
- **`headings`** — extract only named H2 sections. Specified as a list:
  ```yaml
  keep:
    headings:
      - "## Injection Prevention"
      - "## Cryptography"
  ```
  Each named heading is extracted with all content until the next H2 or end of file. Escape hatch for cherry-picking — not expected in initial use.

## index.md Integration

### Injection markers

Each phase's `index.md` uses HTML comment markers to separate vendored from hand-written content:

```markdown
# Go — review checklists

## Always load

- [solid-checklist.md](solid-checklist.md) — SOLID design principles in Go terms.
- [removal-plan.md](removal-plan.md) — staged-removal template for retiring Go code.

<!-- BEGIN VENDORED -->
- [security.md](security.md) — Go security: injection, crypto, secrets, auth.
- [code-style.md](code-style.md) — Code style, formatting, conventions.
- [naming.md](naming.md) — Naming conventions and identifier clarity.
- [error-handling.md](error-handling.md) — Error wrapping, sentinel errors, handling.
- [performance.md](performance.md) — Performance anti-patterns and optimization.

## Conditional

- [database.md](database.md) — Database patterns and SQL safety. **Load if:** Diff imports database/sql, sqlx, gorm, ent, or pgx.
- [concurrency.md](concurrency.md) — Goroutine lifecycle, channels, sync primitives. **Load if:** Diff uses goroutines, channels, or sync package.
- [grpc.md](grpc.md) — gRPC service patterns. **Load if:** Diff imports google.golang.org/grpc.
- [http.md](http.md) — HTTP handler patterns. **Load if:** Diff imports net/http or an HTTP framework.
<!-- END VENDORED -->
```

### Generation rules

- The vendor tool only writes between `<!-- BEGIN VENDORED -->` and `<!-- END VENDORED -->`. Content outside the markers is preserved verbatim.
- If no markers exist (new phase directory), the tool creates the full `index.md` with an `# Go — <phase> checklists` heading, the markers, and all vendored entries inside. Hand-written entries can be added outside the markers later.
- Entries without a `condition` go under `## Always load` inside the markers.
- Entries with a `condition` go under `## Conditional` inside the markers, formatted as: `- [filename](filename) — description. **Load if:** condition.`
- The one-line description for each entry is derived from the first paragraph or heading of the vendored file content (after transformation). If extraction fails, the `as` filename is used as a fallback.

### Bidirectional invariant

The existing `test/test-plugin-structure.sh` enforces:
- **Forward**: every markdown link in `index.md` resolves to a file on disk.
- **Reverse**: every `.md` in the phase directory (except `index.md`) is referenced in `index.md`.

Both hold naturally: vendored files are placed in the phase directory AND referenced between the markers. Hand-written files live outside the markers and are referenced there. The test requires no changes.

## Phase-by-Phase Content Plan

### review-code/ (enrich existing)

**Existing file disposition:**

| File | Action | Reason |
|---|---|---|
| `security-checklist.md` | **Delete** — replaced by `security.md` | samber's golang-security is more comprehensive |
| `code-quality-checklist.md` | **Delete** — replaced by `code-style.md` + `error-handling.md` | Split into two more focused vendored files |
| `solid-checklist.md` | **Keep** | No samber equivalent for SOLID-in-Go framing |
| `removal-plan.md` | **Keep** | Staged-removal template, not Go knowledge |

**Vendored content:**

| Target file | Source | Load |
|---|---|---|
| `security.md` | `golang-security/SKILL.md` | always |
| `security-injection-ref.md` | `golang-security/references/injection.md` | always |
| `code-style.md` | `golang-code-style/SKILL.md` | always |
| `naming.md` | `golang-naming/SKILL.md` | always |
| `error-handling.md` | `golang-error-handling/SKILL.md` | always |
| `performance.md` | `golang-performance/SKILL.md` | always |
| `database.md` | `golang-database/SKILL.md` | conditional |
| `concurrency.md` | `golang-concurrency/SKILL.md` | conditional |
| `grpc.md` | `golang-grpc/SKILL.md` | conditional |
| `http.md` | `golang-http/SKILL.md` | conditional |

### implement/ (new)

All vendored. Pre-write gotchas loaded before the agent writes code.

| Target file | Source | Load |
|---|---|---|
| `design-patterns.md` | `golang-design-patterns/SKILL.md` | always |
| `structs-interfaces.md` | `golang-structs-interfaces/SKILL.md` | always |
| `error-handling.md` | `golang-error-handling/SKILL.md` | always |
| `security.md` | `golang-security/SKILL.md` | always |
| `concurrency.md` | `golang-concurrency/SKILL.md` | conditional |
| `context.md` | `golang-context/SKILL.md` | conditional |
| `data-structures.md` | `golang-data-structures/SKILL.md` | conditional |
| `database.md` | `golang-database/SKILL.md` | conditional |
| `grpc.md` | `golang-grpc/SKILL.md` | conditional |
| `http.md` | `golang-http/SKILL.md` | conditional |
| `dependency-injection.md` | `golang-dependency-injection/SKILL.md` | conditional |

### design/ (new)

All vendored, all conditional. Feeds the refinement question pool when Go + the relevant technology is in scope.

| Target file | Source | Load |
|---|---|---|
| `database.md` | `golang-database/SKILL.md` | conditional |
| `grpc.md` | `golang-grpc/SKILL.md` | conditional |
| `http.md` | `golang-http/SKILL.md` | conditional |
| `observability.md` | `golang-observability/SKILL.md` | conditional |

### test/ (new)

| Target file | Source | Load |
|---|---|---|
| `testing.md` | `golang-testing/SKILL.md` | always |
| `benchmark.md` | `golang-benchmark/SKILL.md` | conditional |

### document/ (new)

| Target file | Source | Load |
|---|---|---|
| `cli.md` | `golang-cli/SKILL.md` | conditional |
| `continuous-integration.md` | `golang-continuous-integration/SKILL.md` | conditional |

### review-spec/

No vendored content. This phase checks implementation against design docs, not Go-specific rules.

## Link Rewriting

samber's SKILL.md files contain relative markdown links to other files in their skill directory and cross-references to other skills.

### Within-skill links

Links like `[see injection details](references/injection.md)` are rewritten:
- If the target is another vendored file (matched by resolving the relative path against the source skill directory and checking if it appears in the manifest's file list), rewrite to the `as` filename.
- If the target is not vendored, strip the link — keep the display text, remove the URL. This prevents broken links without losing the readable reference.

### Cross-skill references

Links like `samber/cc-skills-golang@golang-naming` are stripped entirely — these reference standalone skills that don't exist in the profile context. The display text is preserved.

### External URLs

Links to external sites (pkg.go.dev, Go docs, etc.) are left untouched.

## Testing Strategy

### Unit tests (`cmd/vendor-profiles/`)

| Test file | Coverage |
|---|---|
| `manifest_test.go` | YAML parsing, validation, multi-upstream, missing required fields |
| `transform_test.go` | `from_first_h1` (happy path, no-H1 error, empty file), `headings` extraction, `all` passthrough |
| `linkrewrite_test.go` | Co-vendored link rewrite, non-vendored link stripping, cross-skill ref stripping, external URL preservation |
| `index_test.go` | Marker injection (new file, existing file with markers, existing file without markers), always-load vs conditional formatting, content outside markers preserved |

### Integration test (`cmd/vendor-profiles/`)

End-to-end test using local fixture files (no network). A small test manifest points at `testdata/` containing sample SKILL.md and references files. Verifies the full pipeline: parse, fetch (from local path), transform, write, index update. Asserts output file contents and index.md structure.

### Plugin structure test (`test/test-plugin-structure.sh`)

Existing test covers the bidirectional index invariant automatically once new phase directories are populated. No changes to test logic needed. `make vendor-go` runs the vendor tool and then `test/test-plugin-structure.sh` to validate.

## Developer Workflow

### First-time setup

```bash
make vendor-go    # fetches, transforms, places, validates
```

### Updating upstream version

1. Edit `scripts/go-vendor-manifest.yml` — bump `ref`
2. `make vendor-go`
3. Review diff, commit

### Adding a skill to the profile

1. Add a `files` entry to the manifest
2. `make vendor-go`
3. Commit

### Adding a second upstream

Append a new entry to the manifest array. No code changes.

### Adding vendor support for another profile

Create `scripts/<profile>-vendor-manifest.yml`, add a `make vendor-<profile>` target. The vendor tool is profile-agnostic.

## Future Considerations

1. **CI automation** — A GitHub Action that periodically fetches the latest samber tag, diffs against the pinned `ref`, and opens a PR if content changed. Deferred to a follow-up feature.
2. **Other language profiles** — The same manifest + tool pattern applies to Python (with a different upstream), Java, etc. The tool needs no changes.
3. **Structured conditions** — Currently `condition` is freeform text. A future enhancement could parse structured conditions (regex, import detection) for automated evaluation. The freeform text is sufficient for now — the consuming skill's LLM evaluates it.
4. **Description extraction** — Currently the one-line description in index.md is derived heuristically from the vendored file. A future manifest field (`description`) could make this explicit.
