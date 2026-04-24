# Go Vendor Integration — Implementation Plan

## Prerequisites

- Familiarity with the kk plugin's profile system: `klaude-plugin/profiles/<name>/<phase>/index.md` contract, bidirectional index invariant, DETECTION.md schema. See [ADR 0002](../../adr/0002-profile-content-organization.md) and [CLAUDE.md — Profile Conventions](../../../CLAUDE.md).
- Understanding of the Go profile's current state: `klaude-plugin/profiles/go/` with only `review-code/` populated.
- Go toolchain (`go 1.22+`) for building and testing the vendor tool.
- Access to GitHub raw content URLs for fetching upstream files.

## Phases

1. **Manifest and vendor tool** — Create the manifest schema, implement the Go CLI tool, and write unit tests.
2. **Populate Go profile** — Run the vendor tool against the real manifest to populate all 6 phase directories. Delete replaced hand-written files. Update `overview.md`.
3. **Validation and cleanup** — Run plugin structure tests, verify index.md invariants, update DETECTION.md if needed.

---

## Phase 1: Manifest and Vendor Tool

### Task 1.1: Initialize the Go module and CLI skeleton

**Location:** `cmd/vendor-profiles/`

**Actions:**
- Initialize Go module if not already present (check if `go.mod` exists at repo root). If creating, use a module path matching the repo.
- Create `cmd/vendor-profiles/main.go` with CLI argument parsing: `-manifest <path>` (required), `-target <path>` (optional, defaults to `klaude-plugin/profiles/go`, the profile root for the target profile), `-dry-run` (optional, prints actions without writing).
- The tool reads the manifest, iterates upstreams and files, and delegates to the pipeline stages (fetch → transform → write → index update).
- Define exit codes: 0 = success, 1 = fatal error (fetch failure, missing H1, invalid manifest).

**Verify:** `go build ./cmd/vendor-profiles` succeeds. `go run ./cmd/vendor-profiles -help` prints usage.

### Task 1.2: Manifest parsing

**Location:** `cmd/vendor-profiles/manifest.go`

**Actions:**
- Define Go types:
  ```go
  type Manifest []Upstream

  type Upstream struct {
      Repo        string `yaml:"repo"`
      Ref         string `yaml:"ref"`
      KeepDefault string `yaml:"keep_default,omitempty"`
      Files       []File `yaml:"files"`
  }

  type File struct {
      Source    string `yaml:"source"`
      Phase     string `yaml:"phase"`
      As        string `yaml:"as"`
      Keep      any    `yaml:"keep,omitempty"` // string or KeepHeadings
      Condition string `yaml:"condition,omitempty"`
  }

  type KeepHeadings struct {
      Headings []string `yaml:"headings"`
  }
  ```
- Parse the manifest file using `gopkg.in/yaml.v3`.
- Validate: `repo`, `ref`, `source`, `phase`, `as` are required. `phase` must be one of the known phase names. `as` must be a plain filename (no path separators or `..` — prevents directory traversal via manifest). `keep` must be `"all"`, `"from_first_h1"`, or a `headings` object.
- Resolve effective keep: if a file entry has no `keep`, use the upstream's `keep_default`. If neither is set, default to `"all"`.

**Verify:** `manifest_test.go` — parse valid manifests (single upstream, multi-upstream), reject missing required fields, resolve keep defaults correctly.

### Task 1.3: Fetch from GitHub raw URLs

**Location:** `cmd/vendor-profiles/fetch.go`

**Actions:**
- Construct the raw content URL: `https://raw.githubusercontent.com/<repo>/<ref>/<source>`.
- Fetch via `net/http`. Fail with a clear error on non-200 status (include URL, status code, upstream repo, ref).
- Return the raw content as `[]byte`.
- The fetcher is an interface to allow local file fixtures in tests:
  ```go
  type Fetcher interface {
      Fetch(repo, ref, source string) ([]byte, error)
  }
  ```
  Production implementation uses HTTP; test implementation reads from a local `testdata/` directory.

**Verify:** Unit test with the interface — production fetcher tested in integration test only (no network calls in unit tests).

### Task 1.4: Keep transforms

**Location:** `cmd/vendor-profiles/transform.go`

**Actions:**
- `TransformAll(content []byte) []byte` — return as-is.
- `TransformFromFirstH1(content []byte) ([]byte, error)` — scan for the first line matching `^# ` (H1 heading). Return everything from that line onward. Return error if no H1 found.
- `TransformHeadings(content []byte, headings []string) ([]byte, error)` — for each named heading (e.g., `"## Injection Prevention"`), find the heading line, capture everything until the next heading of equal or higher level (or EOF). Concatenate extracted sections with a blank line separator. Return error if any named heading is not found.
- Dispatch function that takes the resolved keep mode and delegates.

**Verify:** `transform_test.go` —
- `from_first_h1`: content with frontmatter + persona + H1 → output starts at H1. Content with no H1 → error. Empty content → error.
- `headings`: extract single H2, multiple H2s, H2 not found → error. Nested H3s inside extracted H2 are included.
- `all`: passthrough.

### Task 1.5: Link rewriting

**Location:** `cmd/vendor-profiles/linkrewrite.go`

**Actions:**
- Parse markdown links using regex: `\[([^\]]+)\]\(([^)]+)\)`.
- For each link, classify the target:
  1. **External URL** (starts with `http://` or `https://`) → leave untouched.
  2. **Co-vendored file** — resolve the link target relative to the source file's directory in the upstream repo. Check if any file entry in the same upstream has that resolved path as its `source` AND the same `phase`. If yes, rewrite the URL to the `as` filename.
  3. **Cross-skill reference** — matches pattern `samber/cc-skills-golang@<skill-name>` or references a file outside the current skill directory. Strip the link: keep display text, remove `[` `]` `(` `)`.
  4. **Non-vendored within-skill file** — strip the link: keep display text, remove URL.
- The rewriter needs the full file manifest for the current upstream to resolve co-vendored targets.

**Verify:** `linkrewrite_test.go` —
- External URL preserved.
- Co-vendored `references/injection.md` rewritten to `security-injection-ref.md`.
- Cross-skill ref `samber/cc-skills-golang@golang-naming` → plain text "golang-naming".
- Non-vendored `references/crypto.md` → plain text "crypto".

### Task 1.6: index.md injection

**Location:** `cmd/vendor-profiles/index.go`

**Actions:**
- Read the existing `index.md` if present.
- Find `<!-- BEGIN VENDORED -->` and `<!-- END VENDORED -->` markers.
- If markers exist: replace everything between them (exclusive of the markers themselves).
- If markers don't exist and the file exists: append markers + vendored content at the end.
- If the file doesn't exist: generate a new `index.md` with a heading (`# Go — <phase> checklists`), the markers, and all vendored entries.
- Vendored entries between the markers:
  - Files without `condition` go under an `## Always load` sub-heading, formatted as: `- [filename](filename) — description.`
  - Files with `condition` go under a `## Conditional` sub-heading, formatted as: `- [filename](filename) — description. **Load if:** condition.`
  - The one-line description is extracted from the transformed file content: first non-empty, non-heading line, truncated to 120 characters. Fallback: the `as` filename without extension.
- Heading structure: if only always-load entries exist, omit the Conditional heading. If only conditional entries exist, omit the Always load heading.

**Verify:** `index_test.go` —
- New file: generates correct structure with heading, markers, entries.
- Existing file with markers: replaces between markers, preserves outside content.
- Existing file without markers: appends markers and content.
- Always-load and conditional entries formatted correctly.
- Description extraction from file content (happy path, fallback).

### Task 1.7: Integration test

**Location:** `cmd/vendor-profiles/main_test.go` and `cmd/vendor-profiles/testdata/`

**Actions:**
- Create `testdata/` with:
  - A fixture manifest pointing at local files.
  - Sample upstream files: a SKILL.md with frontmatter + persona + H1 + content, a `references/` file, a file with internal links.
  - Expected output files for comparison.
- The integration test:
  1. Creates a temp directory as the target profile root.
  2. Runs the full pipeline against the fixture manifest.
  3. Asserts output files exist with expected content.
  4. Asserts `index.md` files have correct structure and entries.
  5. Re-runs the pipeline to verify idempotency (same output on second run).

**Verify:** `go test ./cmd/vendor-profiles/...` passes.

### Task 1.8: Makefile target

**Location:** `Makefile` (create if not present)

**Actions:**
- Add targets:
  ```makefile
  .PHONY: vendor-go test-structure

  vendor-go:
  	go run ./cmd/vendor-profiles -manifest scripts/go-vendor-manifest.yml
  	bash test/test-plugin-structure.sh

  test-structure:
  	bash test/test-plugin-structure.sh
  ```

**Verify:** `make vendor-go` runs the tool and validation. `make test-structure` runs the structure test alone.

---

## Phase 2: Populate Go Profile

### Task 2.1: Create the manifest

**Location:** `scripts/go-vendor-manifest.yml`

**Actions:**
- Write the full manifest with all file entries from the [Phase-by-Phase Content Plan](design.md#phase-by-phase-content-plan) in the design doc.
- Pin to the latest samber/cc-skills-golang tag.
- Use `from_first_h1` as `keep_default` for the samber upstream.
- Use `keep: all` for `references/` files.
- Include `condition` for all conditional entries.

**Verify:** The manifest parses correctly: `go run ./cmd/vendor-profiles -manifest scripts/go-vendor-manifest.yml -dry-run` prints the planned actions without writing.

### Task 2.2: Run the vendor tool

**Actions:**
- Run `make vendor-go`.
- Verify all phase directories are created and populated.
- Verify `index.md` files have correct injection markers and entries.
- Verify transformed files have no frontmatter, persona, or mode preamble.
- Verify relative links are rewritten or stripped correctly.

**Verify:** `test/test-plugin-structure.sh` passes (bidirectional index invariant for all new phase directories).

### Task 2.3: Delete replaced hand-written files

**Location:** `klaude-plugin/profiles/go/review-code/`

**Actions:**
- Delete `security-checklist.md` (replaced by vendored `security.md`).
- Delete `code-quality-checklist.md` (replaced by vendored `code-style.md` + `error-handling.md`).
- Update the hand-written section of `review-code/index.md` to remove references to deleted files.
- Verify `solid-checklist.md` and `removal-plan.md` are still referenced in the hand-written section.

**Verify:** `test/test-plugin-structure.sh` passes. No orphan files, no broken links.

### Task 2.4: Update overview.md

**Location:** `klaude-plugin/profiles/go/overview.md`

**Actions:**
- Update the "Populated phases" section to list all 6 phases (was: only `review-code/`).
- Note which phases contain vendored content and which have hand-written files.
- Remove the statement "Other phase subdirectories are not populated for this profile."

**Verify:** `overview.md` accurately reflects the current state of the profile.

### Task 2.5: Add Design signals to DETECTION.md

**Location:** `klaude-plugin/profiles/go/DETECTION.md`

**Actions:**
- Add a `## Design signals` section to enable design-phase detection for Go projects. Without this, the `design/` phase content would never be loaded (the design skill uses token matching, not file detection).
- Content:
  ```markdown
  ## Design signals

  display_name: Go
  tokens:
    - Go
    - Golang
    - goroutine
    - go module
    - go.mod
  ```
- Be careful with the `Go` token — it's short and could false-positive on common words. The design interaction pattern uses case-insensitive whole-word matching, so "go" in "going" would not match, but standalone "go" in "I want to build a Go service" would. This is acceptable — the design skill always confirms with the user before activating.

**Verify:** The design skill's token matching can detect Go features in idea prose. Manually test with a sample idea.

---

## Phase 3: Validation and Cleanup

### Task 3.1: Full test suite

**Actions:**
- Run `go test ./cmd/vendor-profiles/...` — all unit and integration tests pass.
- Run `make vendor-go` — full pipeline succeeds, structure test passes.
- Run `bash test/test-plugin-structure.sh` independently — all profile assertions green.

**Verify:** All three commands exit 0.

### Task 3.2: Verify token budget

**Actions:**
- Count the total tokens loaded for each phase when the Go profile is active with all always-load entries.
- The always-load budget for each phase should be reasonable (target: under ~8k tokens per phase for always-load content, with conditional content adding more when triggered).
- If any phase exceeds the budget, consider moving some always-load entries to conditional.

**Verify:** Token counts are within budget. Document the counts in a comment in the manifest for future reference.

### Task 3.3: Update Known profiles list

**Location:** `klaude-plugin/skills/_shared/profile-detection.md`

**Actions:**
- The Go profile is already in the Known profiles list. No changes needed to the list itself.
- However, verify that the design interaction pattern works with the new `## Design signals` section added in Task 2.5.

**Verify:** Read `profile-detection.md` and confirm `go` is listed. Test the design interaction pattern manually.

### Task 3.4: Final review

**Actions:**
- Invoke `review-code` with a Go diff to verify vendored checklists are loaded and applied.
- Invoke `implement` on a Go task to verify pre-write gotchas are loaded.
- Invoke `design` with a Go-related idea to verify design signals and conditional content.
- Invoke `test` with a Go project to verify testing guidance loads.

**Verify:** Each skill loads the expected profile content. Vendored content reads cleanly (no leftover frontmatter, no broken links, no persona declarations).
