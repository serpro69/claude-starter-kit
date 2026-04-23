# Tasks: Go Vendor Integration

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-04-23

## Task 1: Go module and CLI skeleton
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md — Task 1.1](./implementation.md#task-11-initialize-the-go-module-and-cli-skeleton)

### Subtasks
- [ ] 1.1 Initialize Go module at repo root if `go.mod` does not exist (or extend existing one)
- [ ] 1.2 Create `cmd/vendor-profiles/main.go` with `-manifest`, `-target`, and `-dry-run` flags using `flag` package
- [ ] 1.3 Wire up the top-level pipeline: parse manifest → iterate upstreams → iterate files → fetch → transform → write → update index
- [ ] 1.4 Define exit codes: 0 success, 1 fatal error
- [ ] 1.5 Verify: `go build ./cmd/vendor-profiles` succeeds, `-help` prints usage

## Task 2: Manifest parsing and validation
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md — Task 1.2](./implementation.md#task-12-manifest-parsing)

### Subtasks
- [ ] 2.1 Define Go types: `Manifest` (alias for `[]Upstream`), `Upstream`, `File`, `KeepHeadings` in `cmd/vendor-profiles/manifest.go`
- [ ] 2.2 Implement `ParseManifest(path string) (Manifest, error)` — read YAML, unmarshal, validate required fields
- [ ] 2.3 Validate `phase` against known phase names (`review-code`, `implement`, `design`, `test`, `document`, `review-spec`)
- [ ] 2.4 Resolve effective keep: file-level `keep` overrides upstream `keep_default`, fallback to `"all"`
- [ ] 2.5 Write `manifest_test.go`: valid single-upstream, valid multi-upstream, missing required fields error, keep resolution

## Task 3: Fetch from upstream
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md — Task 1.3](./implementation.md#task-13-fetch-from-github-raw-urls)

### Subtasks
- [ ] 3.1 Define `Fetcher` interface in `cmd/vendor-profiles/fetch.go`: `Fetch(repo, ref, source string) ([]byte, error)`
- [ ] 3.2 Implement `HTTPFetcher` — construct raw URL `https://raw.githubusercontent.com/<repo>/<ref>/<source>`, GET, fail on non-200 with descriptive error
- [ ] 3.3 Implement `LocalFetcher` for tests — reads from a base directory, resolving `repo/ref/source` to a local path
- [ ] 3.4 Verify: HTTPFetcher tested in integration test only; LocalFetcher used in all unit tests

## Task 4: Keep transforms
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md — Task 1.4](./implementation.md#task-14-keep-transforms)

### Subtasks
- [ ] 4.1 Implement `TransformAll(content []byte) []byte` — passthrough
- [ ] 4.2 Implement `TransformFromFirstH1(content []byte) ([]byte, error)` — scan for `^# `, return from that line onward, error if not found
- [ ] 4.3 Implement `TransformHeadings(content []byte, headings []string) ([]byte, error)` — extract named H2 sections, error if any heading not found
- [ ] 4.4 Implement dispatch function `ApplyTransform(content []byte, keep any) ([]byte, error)`
- [ ] 4.5 Write `transform_test.go`: from_first_h1 with frontmatter+persona, no-H1 error, empty file error, headings extraction, nested H3 inclusion, all passthrough

## Task 5: Link rewriting
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md — Task 1.5](./implementation.md#task-15-link-rewriting)

### Subtasks
- [ ] 5.1 Implement markdown link regex parser in `cmd/vendor-profiles/linkrewrite.go`
- [ ] 5.2 Implement link classifier: external URL → preserve, co-vendored → rewrite to `as` filename, cross-skill ref → strip to text, non-vendored internal → strip to text
- [ ] 5.3 The rewriter takes the full file list for the current upstream + the source file's directory to resolve relative paths
- [ ] 5.4 Write `linkrewrite_test.go`: external URL preserved, co-vendored rewrite, cross-skill stripping, non-vendored stripping

## Task 6: index.md injection
- **Status:** pending
- **Depends on:** Task 2
- **Docs:** [implementation.md — Task 1.6](./implementation.md#task-16-indexmd-injection)

### Subtasks
- [ ] 6.1 Implement marker detection and content replacement in `cmd/vendor-profiles/index.go`
- [ ] 6.2 Handle three cases: new file (create with heading + markers), existing with markers (replace between), existing without markers (append markers)
- [ ] 6.3 Generate always-load entries (no condition) under `## Always load`, conditional entries under `## Conditional` with `**Load if:**` clause
- [ ] 6.4 Extract one-line description from transformed file content (first non-empty non-heading line, truncated to 120 chars, fallback to filename)
- [ ] 6.5 Write `index_test.go`: new file generation, marker replacement preserving outside content, always-load vs conditional formatting, description extraction

## Task 7: Integration test and Makefile
- **Status:** pending
- **Depends on:** Task 3, Task 4, Task 5, Task 6
- **Docs:** [implementation.md — Task 1.7, Task 1.8](./implementation.md#task-17-integration-test)

### Subtasks
- [ ] 7.1 Create `cmd/vendor-profiles/testdata/` with fixture manifest, sample SKILL.md (frontmatter + persona + H1 + content), sample references file, sample file with internal links
- [ ] 7.2 Write `main_test.go` integration test: run full pipeline against fixtures, assert output files, assert index.md structure, assert idempotency (second run produces same output)
- [ ] 7.3 Create `Makefile` with `vendor-go` and `test-structure` targets
- [ ] 7.4 Verify: `go test ./cmd/vendor-profiles/...` all green, `make vendor-go` runs end-to-end

## Task 8: Create manifest and populate Go profile
- **Status:** pending
- **Depends on:** Task 7
- **Docs:** [implementation.md — Task 2.1, Task 2.2](./implementation.md#task-21-create-the-manifest)

### Subtasks
- [ ] 8.1 Write `scripts/go-vendor-manifest.yml` with all file entries from the design doc's Phase-by-Phase Content Plan
- [ ] 8.2 Pin to latest samber/cc-skills-golang tag
- [ ] 8.3 Verify with dry run: `go run ./cmd/vendor-profiles -manifest scripts/go-vendor-manifest.yml -dry-run`
- [ ] 8.4 Run `make vendor-go` — all phase directories created and populated
- [ ] 8.5 Spot-check vendored files: no frontmatter, no persona, links rewritten, content starts at H1

## Task 9: Delete replaced files and update profile docs
- **Status:** pending
- **Depends on:** Task 8
- **Docs:** [implementation.md — Task 2.3, Task 2.4, Task 2.5](./implementation.md#task-23-delete-replaced-hand-written-files)

### Subtasks
- [ ] 9.1 Delete `klaude-plugin/profiles/go/review-code/security-checklist.md` and `code-quality-checklist.md`
- [ ] 9.2 Update the hand-written section of `review-code/index.md` — remove references to deleted files, keep `solid-checklist.md` and `removal-plan.md`
- [ ] 9.3 Update `klaude-plugin/profiles/go/overview.md` — list all populated phases, remove "not populated" statement
- [ ] 9.4 Add `## Design signals` section to `klaude-plugin/profiles/go/DETECTION.md` with tokens: Go, Golang, goroutine, go module, go.mod
- [ ] 9.5 Verify: `test/test-plugin-structure.sh` passes — no orphans, no broken links, all invariants green

## Task 10: Final verification
- **Status:** pending
- **Depends on:** Task 8, Task 9

### Subtasks
- [ ] 10.1 Run `go test ./cmd/vendor-profiles/...` — all unit and integration tests pass
- [ ] 10.2 Run `make vendor-go` — full pipeline succeeds, structure test passes
- [ ] 10.3 Run `bash test/test-plugin-structure.sh` independently — all profile assertions green
- [ ] 10.4 Verify token budget: count approximate tokens loaded per phase for always-load entries, flag if any phase exceeds ~8k tokens
- [ ] 10.5 Run `test` skill to verify all tasks
- [ ] 10.6 Run `document` skill to update any relevant docs
- [ ] 10.7 Run `review-code` skill with Go input to review the implementation
- [ ] 10.8 Run `review-spec` skill to verify implementation matches design and implementation docs
