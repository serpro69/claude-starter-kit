# plugin-graph — Tasks

> **Feature:** plugin-graph
> **Design:** [design.md](design.md) | **Implementation:** [implementation.md](implementation.md)
> **Status:** pending
> **Not Doing:** Review skill integration, committed JSON artifact, interactive visualization, diff subcommand, cross-plugin analysis, semantic prose analysis.

---

## Task 0: Validate goldmark dependency

**Status:** done
**Size:** S
**Dependencies:** —
**Can run in parallel with:** —
**Slicing strategy:** Risk-First (validates the riskiest assumption before building on it)

> Ref: [implementation.md §Dependencies](implementation.md#dependencies)

Validate that goldmark (`github.com/yuin/goldmark`) can extract inline markdown link targets from AST nodes before committing to it as a dependency.

- [x] Create `cmd/plugin-graph/` directory and `go` file with a spike test: parse a markdown snippet containing inline links (`[text](path.md)`), reference-style links, and non-link backtick content; walk the AST for `ast.Link` nodes; assert `Destination` fields are correct
- [x] Verify goldmark preserves source position info (line numbers) on link nodes — needed for edge diagnostics
- [x] If goldmark's AST is awkward for this use case, document findings and switch to regex-based extraction before proceeding
- [x] Add `github.com/yuin/goldmark` to `go.mod` / `go.sum`

**Verify:** `go test ./cmd/plugin-graph/... -run TestGoldmarkSpike` passes and link targets + line numbers are correctly extracted.

---

## Task 1: Core graph types and builder

**Status:** done
**Size:** S
**Dependencies:** Task 0
**Can run in parallel with:** —

> Ref: [implementation.md §Core Types](implementation.md#core-types-graphgo)

Implement the graph data model and builder in `cmd/plugin-graph/graph.go`.

- [x] Define `NodeType` and `EdgeType` string enums with all values from design
- [x] Define `Node` struct: `Path`, `Type`, `Name`
- [x] Define `Edge` struct with dual-layer endpoints: `RawSource`, `RawTarget` (concrete file paths), `Source`, `Target` (normalized), `Type`, `Line`
- [x] Define `Graph` struct with `Nodes` map and `Edges` slice
- [x] Implement `AddNode`, `AddEdge` (auto-normalizes raw endpoints), `NodeByPath` methods
- [x] Implement `OutEdges(path)` and `InEdges(path)` query methods (on normalized endpoints)
- [x] Implement `MetricEdges()` — returns edges excluding intra-artifact self-loops (where `Source == Target` after normalization)
- [x] Implement `Reachable(path, direction)` — BFS on metric edges following out-edges, in-edges, or both; returns set of reachable node paths
- [x] Implement `NormalizePath(path)` — walks up from a file path, returns the **nearest (most specific)** ancestor artifact node. For `profiles/go/review-code/index.md` returns `profiles/go/review-code/` (profile-phase), not `profiles/go/` (profile). Returns original path if no ancestor is an artifact
- [x] Implement node classification: given a file path relative to plugin root, return the correct `NodeType` based on the path pattern rules (skill directory with SKILL.md, `_shared/*.md`, `agents/*.md`, etc.)
- [x] Write table-driven tests for node classification covering all 7 node types plus edge cases (files outside known directories → `content`)
- [x] Write tests for `NormalizePath`: file inside skill dir → skill node (nearest), file in `_shared/` → stays as file, file in profile phase → profile-phase node (not profile), nested artifact specificity
- [x] Write tests for `MetricEdges`: intra-artifact edges suppressed, cross-artifact edges preserved

**Verify:** `go test ./cmd/plugin-graph/... -run TestGraph` passes. Node classification correctly maps all path patterns. Reachable returns correct sets for a small hand-built graph.

---

## Task 2: File walker and extractors

**Status:** done
**Size:** M
**Dependencies:** Task 1
**Can run in parallel with:** —

> Ref: [implementation.md §Extractors](implementation.md#extractors-parsego)

Implement the file walker and all five extractors in `cmd/plugin-graph/parse.go`.

- [x] Define `ParseContext` struct: `PluginRoot`, `KnownProfiles`, `KnownPhases`, `KnownAgents`, `KnownSkills`, `KnownCommands`
- [x] Implement `ParseContext` initialization: derive `KnownProfiles` by parsing §Known profiles from `skills/_shared/profile-detection.md`, derive `KnownAgents`, `KnownSkills`, and `KnownCommands` from directory listings, hardcode `KnownPhases`
- [x] Implement code-block stripping: replace fenced code blocks (`` ``` `` and `~~~`) with blank lines preserving line count. Used as pre-processing for regex extractors 3–5
- [x] Implement Extractor 1 (markdown links): goldmark AST walk for `ast.Link` nodes, resolve relative paths, filter external/anchor/non-md. Inherently code-block-safe
- [x] Implement Extractor 2 (symlinks): `os.Lstat` + `os.Readlink`, resolve relative target, create `symlink` edge. Skip content extraction for symlink files — target's outgoing links are attributed to the canonical path only (prevents double-counting shared dependencies)
- [x] Implement Extractor 3 (plugin-root refs, merged template + parameterized): regex for `` `\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)` ``, strip prefix, branch on angle-bracket variable presence → concrete paths become `template-ref`, parameterized paths expand `<name>`/`<profile>` × `<phase>` × `<checklist>` (via glob). Runs on stripped content
- [x] Implement Extractor 4 (agent delegation): match `subagent_type` in markdown table rows only (structured context), extract `kk:<agent-name>` from same row → `agents/<name>.md`. No free-prose scanning. Runs on stripped content
- [x] Implement Extractor 5 (skill + command invocation): regex `/kk:([a-z-]+)(?::([a-z-]+))?`, first group → skill edge, second group (if present) → command edge to `commands/<skill>/<command>.md`. Runs on stripped content
- [x] Implement file walker: `filepath.WalkDir` over plugin root, skip non-`.md` files (except for symlink detection), classify each file into a node (normalizing to artifact nodes where applicable), run extractors, accumulate into `Graph`
- [x] Write table-driven unit tests for each extractor in `parse_test.go` covering: valid cases, skip cases (external URLs, anchors, non-md for extractor 1; bare `$CLAUDE_PLUGIN_ROOT` for extractor 3; non-existent expansion targets for extractor 3; agent name in prose NOT producing edge for extractor 4; self-references for extractor 5; command syntax for extractor 5), and code-block-stripping cases

**Verify:** `go test ./cmd/plugin-graph/... -run TestExtract` passes. Each extractor produces correct edges for its test cases.

**Implementation notes (deviations from plan):**

- **`NormalizePath` self-check (touches Task 1's `graph.go`).** Directory-form edge targets — skill-invocation targets `skills/<x>/` and concrete template-refs to phase dirs like `profiles/k8s/design/` — were collapsing to a *parent* artifact (e.g. a profile-phase into its profile) because `NormalizePath` only inspected ancestors. Added a self-check: a directory path that is itself an artifact node resolves to itself before the ancestor walk. Also fixes a latent Task 5 (targeted mode) bug where `skills/review-code/` would not resolve to its node. Regression cases added to `graph_test.go`.
- **Edge dedup (`dedupEdges`).** Not in the original plan. A skill that mentions `/kk:review-code` N times must not produce N edges, or fan-in/out is distorted. `BuildGraph` collapses to one edge per `(RawSource, RawTarget, Type)`, first-line-wins, before normalization.
- **Doc-placeholder skipping in Extractor 3.** Real plugin files contain non-path `${CLAUDE_PLUGIN_ROOT}/**` (glob) and `${CLAUDE_PLUGIN_ROOT}/…` / `.../...` (ellipsis) in prose. Concrete template-refs containing `*`, `…`, or `...` are skipped to avoid false broken edges. Parameterized refs with literal `...` naturally yield no edges (expansions don't exist on disk).
- **Pre-existing gofmt gap:** `metrics.go` (Task 3) has un-gofmt'd struct-tag alignment. Left untouched to keep this task's diff focused — should be cleaned up alongside Task 3 follow-up.

**Code-review fixes applied (isolated review, corroborated by code-reviewer + pal/gemini-3.1-pro):**

- **Path confinement (`escapesRoot`).** All four path resolvers (`resolveMarkdownTarget`, `symlinkEdge`, `concreteTarget`, `expandParameterized`) now reject results that escape the plugin root (`..` / `../`-prefixed after `path.Clean`). Prevents misleading broken-edge stats outside the tree — defense-in-depth ahead of Task 6 (untrusted worktree roots). Covered by `TestExtractRejectsRootEscape`. Indexed as `kk:review-findings`.
- **goldmark parser localized.** `extractMarkdownLinks` now builds `goldmark.New()` per call instead of a shared package global (goldmark's parser is stateful per `Parse`, not goroutine-safe).
- **Irregular-file guard.** The walker skips non-regular `.md` entries (`d.Type().IsRegular()`) so a named pipe/device named `*.md` can't block `os.ReadFile`.
- **`KnownCommands` made live.** Command-edge resolution now checks `ctx.KnownCommands[skill]` instead of a per-match `os.Stat`, removing dead state and honoring the spec field's purpose.
- Dismissed: `strings.SplitSeq` "needs Go 1.24+" — `go.mod` is `go 1.25.2`.

---

## Task 3: Metrics computation

**Status:** done
**Size:** S
**Dependencies:** Task 1
**Can run in parallel with:** Task 2

> Ref: [implementation.md §Metrics](implementation.md#metrics-metricsgo)

Implement metric computation in `cmd/plugin-graph/metrics.go`.

- [x] Define `NodeMetrics` struct: `FanOut`, `FanIn`, `Depth`, `TransitiveClosureSize`
- [x] Define `GraphMetrics` struct: `PerNode` map, `Orphans`, `BrokenEdges`, `Hotspots`, `Coupling`
- [x] Define `SkillPair` struct for coupling output
- [x] Implement fan-in/fan-out: single pass over edges, count per node
- [x] Implement depth: DFS from each node with memoization; detect cycles → depth = -1 for cyclic nodes, report cycle as diagnostic
- [x] Implement transitive closure: BFS from each node, count reachable set
- [x] Implement coupling: for each skill-node pair, intersect forward-reachable sets; report pairs above threshold (default 3)
- [x] Implement orphan detection: fan-in = 0, excluding entry-point nodes (skills, profiles, commands, agents, `README.md`, `evals/` fixtures). Only `content` and `shared` nodes flagged
- [x] Implement broken edge detection: uses `RawTarget` — checks concrete file path existence on disk. Does NOT normalize first (a missing `skills/foo/missing.md` is broken even if `skills/foo/` exists)
- [x] Implement hotspot ranking: nodes sorted by fan-in descending
- [x] Write tests in `metrics_test.go`: linear chain (depth = N), diamond (fan-in 2), star (fan-out N), isolated node (orphan), missing target via RawTarget (broken edge), cycle (depth -1), intra-artifact self-loop (suppressed from MetricEdges, not counted as cycle)

**Verify:** `go test ./cmd/plugin-graph/... -run TestMetrics` passes. All metric cases produce expected values.

---

## Task 4: Output formatters

**Status:** done
**Size:** M
**Dependencies:** Task 1, Task 3
**Can run in parallel with:** Task 2

> Ref: [implementation.md §Output](implementation.md#output-outputgo)

Implement the four output formatters in `cmd/plugin-graph/output.go`.

- [x] Implement JSON formatter: `Report` struct containing nodes, edges, per-node metrics, global metrics. `json.MarshalIndent` for pretty output
- [x] Implement text formatter: `text/tabwriter` table with columns Name, Fan-out, Fan-in, Depth, Transitive. Sort by transitive closure desc. Sections for orphans, broken edges, hotspots
- [x] Implement DOT formatter: template-based. Nodes get `shape`/`fillcolor` by type. Edges get `style` by type (solid=static, dashed=template/parameterized, dotted=implicit). Subgraph clusters for skills, profiles, agents
- [x] Implement Mermaid formatter: flowchart LR syntax. Sanitized node IDs from paths. Edge labels with type
- [x] Create `testdata/` golden files for a small fixture graph (manually constructed in test setup) × 4 formats
- [x] Write golden file comparison tests in `output_test.go` with `-update` flag support via `go test -update`

**Verify:** `go test ./cmd/plugin-graph/... -run TestOutput` passes. Golden files match expected output. Manual inspection: render a DOT golden file with `dot -Tpng` or paste Mermaid golden into mermaid.live.

**Implementation notes (deviations from plan):**

- **`Render(format, …)` dispatcher added.** A single entry point (`output.go`) returning `([]byte, error)`; unknown format → error (fail-loud), not a silent default. Gives Task 5's CLI a clean call site. `renderJSON`/`renderDOT` return `([]byte, error)` (marshal/template error propagated rather than panicking); `renderText`/`renderMermaid` cannot fail and return `[]byte`.
- **Coupling section added to text output.** The plan's text spec listed only orphans/broken/hotspots, but coupling is a primary design metric (success metric calls out "flag high coupling"). Omitting it from the only human-readable format was a spec gap; added a Coupling section. JSON already carries it via `metrics`.
- **Mermaid `classDef` node coloring added.** Honors design's "same visual semantics as DOT" for nodes; node IDs are sanitized-path with collision disambiguation (`uniqueMermaidID`); edge type carried as the `|label|`.
- **Visual vs programmatic edge split.** JSON dumps all raw edges (full fidelity, incl. intra-artifact self-loops). DOT/Mermaid use `graphEdges()` — normalized endpoints, self-loops removed (`MetricEdges`), deduped by `(Source,Target,Type)`, filtered to declared-node endpoints. All map iteration funneled through sorted slices for deterministic golden output.
- **gofmt cleanup of `metrics.go`.** The Task-2-deferred struct-tag-alignment gap was resolved here (`gofmt -w`); whitespace-only.

**Code-review fixes applied (isolated review: code-reviewer + pal/gemini-3.1-pro, all findings corroborated):**

- **Output-side escaping (P1, corroborated).** Formatters embedding path-derived strings must escape per the target grammar. `dq()` now uses `strconv.Quote` (valid DOT, escapes `"`/`\`). Mermaid node + edge labels routed through `mermaidLabel()`, which escapes `#`→`#35;` (first), `"`→`#quot;`, `|`→`#124;` via Mermaid's verified HTML-entity syntax (context7-confirmed; `strconv.Quote`'s `\"` is NOT valid Mermaid). No-op for the current clean corpus (goldens unchanged); defense-in-depth ahead of Task 6's untrusted roots. Output-side counterpart to the Task-2 input-side `escapesRoot` finding. Covered by `TestEscapingAdversarialPaths`. Indexed as `kk:review-findings`.
- **panic→error (P2, corroborated).** `renderJSON`/`renderDOT` return errors via `Render` instead of panicking on the (unreachable) marshal/template-execute failures.
- **nil-metrics guard (P2, corroborated).** `metricsOrZero()` guards `m.PerNode[path]` lookups in `renderText` + `skillNodesByTransitive` — robust when Task 5 targeted mode renders a graph against metrics computed for a different node set.
- **`styleFor()` fallback (P3, corroborated).** Unknown `NodeType` → neutral box instead of invalid `shape=, fillcolor=""`.
- **Not done (deferred, P3):** graphEdges' inline sort comparator structurally duplicates `edgeLess` (deliberate raw-vs-normalized split). Left as-is — extracting a shared comparator risks coupling the two intentionally-different orderings; revisit only if a third edge-sort site appears.

---

## Task 5: CLI entry point and targeted mode

**Status:** done
**Size:** S
**Dependencies:** Task 2, Task 3, Task 4
**Can run in parallel with:** —

> Ref: [implementation.md §CLI Interface](implementation.md) and [implementation.md §Targeted Mode](implementation.md#targeted-mode)

Wire everything together in `cmd/plugin-graph/main.go`.

- [x] Implement CLI parsing: scan `os.Args[1:]` for global flags (`--root`, `--ref`) before the subcommand, extract them, treat first non-flag arg as subcommand, pass remainder to per-subcommand `flag.FlagSet` for `--format`/`--direction`
- [x] Implement subcommand dispatch: `graph` (default), `metrics`, `validate`
- [x] Implement targeted mode: when positional args provided, normalize paths via `NormalizePath`, build full graph, compute reachable set per `--direction`, filter graph to subgraph, then run the selected subcommand on the filtered result
- [x] Implement `validate` exit code: exit 1 if broken edges or orphans found. Respect `--format` for output
- [x] Add basic integration test in `main_test.go`: run `graph`, `metrics`, `validate` subcommands against a fixture and assert non-empty output / correct exit codes. Test that global flags before subcommand work, per-subcommand flags after work

**Verify:** `go run ./cmd/plugin-graph --root klaude-plugin/ validate` exits cleanly against the real plugin. `go run ./cmd/plugin-graph --root klaude-plugin/ metrics --format json` produces valid JSON with all skills present.

**Implementation notes (deviations from plan):**

- **`validate` rejects target arguments (clarifies targeted-mode scope).** Targeted mode applies to `graph`/`metrics` only. `validate`'s findings (broken edges, orphans) are *global* health signals: on a reachable slice, boundary nodes lose their in-edges (false orphans) and filtered-out broken edges vanish, making the gate misleading. `run` rejects `validate` + targets with a loud error rather than silently slicing. Design updated ([design.md §Targeted Mode](design.md)). Surfaced during the isolated code review.

**Code-review fixes applied (isolated review: code-reviewer + pal/gemini-3.1-pro):**

- **`flag.ErrHelp` → exit 0 (pal).** `-h`/`--help` under `flag.ContinueOnError` returns `ErrHelp`; both flag-set parse blocks now treat it as a clean exit, not a usage error. Covered by `TestMainHelpExitsZero`.
- **Slice-aliasing hygiene (corroborated).** `diags := append(buildDiags, metricDiags...)` → `slices.Concat(...)` — appending onto `buildDiags` could alias and mutate its backing array under a future reader. No live corruption today; forward-looking fix.
- **`--direction` no-op warning (corroborated).** A non-default `--direction` with no targets is inert; now warns on stderr instead of silently ignoring. Covered by `TestMainDirectionWithoutTargetsWarns`.
- **Test gap closed.** Added `TestMainValidateUnsupportedFormat` (`validate --format dot` → loud error), exercising the only previously-untested branch in `renderValidate`.
- **Dismissed:** validate's format-error wording "divergence" from `Render` (correct as-is — `validate` genuinely supports only json/text); `renderValidate`'s nil-guards (kept — defensive `[]`-not-`null` at the JSON serializer boundary, decoupled from `ComputeMetrics`); a "single-line if" style finding (false positive — artifact of diff compression in the reviewer prompt; the real file is gofmt-clean).

---

## Task 6: Git worktree support

**Status:** done
**Size:** S
**Dependencies:** Task 5
**Can run in parallel with:** —

> Ref: [implementation.md §Git Worktree](implementation.md#git-worktree-worktreego)

Implement `--ref` flag support via git worktrees in `cmd/plugin-graph/worktree.go`.

- [x] Implement `WithWorktree(ref string, fn func(root string) error) error`: create temp dir, `git worktree add --detach`, call fn, deferred cleanup via `git worktree remove --force` + `os.RemoveAll`
- [x] Wire into `main.go`: when `--ref` is set, wrap the build step in `WithWorktree`
- [x] Handle error cases: invalid ref, not a git repo, worktree add failure → clear error message
- [x] Write test in `worktree_test.go`: skip if git not available (`exec.LookPath`), create a test repo with two commits, verify worktree at older ref sees the older state, verify cleanup removes worktree

**Verify:** `go run ./cmd/plugin-graph --root klaude-plugin/ --ref HEAD~1 metrics --format text` produces output reflecting the state at the previous commit. `git worktree list` shows no leftover worktrees after the command completes.

**Implementation notes (deviations from plan):**

- **`--ref` requires a repo-relative `--root` (new guard).** The effective root inside the worktree is `filepath.Join(worktreeRoot, cfg.root)`. An absolute `--root` cannot be located inside the worktree, so `run` rejects `--ref` + absolute `--root` with a loud error rather than joining into a nonsense path. The documented/default usage (`--root klaude-plugin/`) is unaffected. Covered by `TestMainRefAbsoluteRootRejected`.
- **`git` resolves from the process cwd (not a new param).** Kept the design's 2-arg `WithWorktree(ref, fn)` signature; `exec.Command` inherits cwd, so the tool must run from inside the repo being analyzed (the design's stated assumption). Tests point git at a synthetic two-commit repo via `t.Chdir` (Go 1.24+; `go.mod` is `go 1.25.2`).
- **Argument-injection guard.** Beyond passing `ref` as a separate argv entry (no shell), a leading-dash guard rejects refs git would otherwise parse as an option. Empty/`-x`/`--detach` refs are rejected before any git call.
- **Exit-code precedence on cleanup failure.** A worktree setup/teardown failure is an environment problem (exit 2) but must not erase a more specific analysis result: `validate`'s findings (exit 1) take precedence once `execute` has run. `execute`'s code is captured by closure side-effect; the closure returns `nil` intentionally.

**Code-review fixes applied (isolated review: code-reviewer + pal/gemini-3.1-pro, CORROBORATED):**

- **Cleanup error-swallowing (P1/HIGH, corroborated).** The original defer gated all teardown-error reporting on `os.RemoveAll` succeeding; a `git worktree remove` failure was silently swallowed whenever `RemoveAll` succeeded, leaking a dangling worktree registration in the parent repo's `.git/worktrees/` (directly contradicting this task's "no leftover worktrees" verify criterion). Fixed: each teardown step's error is evaluated independently and combined with `errors.Join`, surfaced only when `err == nil` (don't mask fn's error). A `registered bool` (set after a successful `add`) skips `git worktree remove` on the add-failed path, removing a spurious discarded git error (folds in the related single-reviewer P2). Indexed as `kk:review-findings`.
- **`main.go` readability (P3).** Added an inline comment clarifying that the `WithWorktree` callback captures `execute`'s exit code by side-effect and returns `nil` intentionally.
- **Kept as-is:** multi-line git-stderr-in-error normalization (P2) — `git worktree add/remove` errors are single-line, `TrimSpace` covers the common case, and raw git text is more useful on CLI stderr. The sub-agent's reraise of the Task 4 output-escaping finding is a non-issue — that was already fixed in Task 4 (`escapesRoot` + `mermaidLabel`/`dq`, `TestEscapingAdversarialPaths`).

---

## Task 7: Integration test fixture and Makefile

**Status:** done
**Size:** S
**Dependencies:** Task 5, Task 6
**Can run in parallel with:** —

> Ref: [implementation.md §Integration Test](implementation.md#integration-test) and [implementation.md §Makefile Integration](implementation.md#makefile-integration)

Create the integration test fixture and wire up Makefile/CI.

- [x] Create `cmd/plugin-graph/testdata/minimal-plugin/` with: 2 skills (one with symlink to shared, one referencing an agent via `${CLAUDE_PLUGIN_ROOT}`), 1 shared instruction, 1 agent, 1 profile with 1 phase and index.md, 1 intentional broken markdown link, 1 orphan `.md` file
- [x] Write full-pipeline integration test in `main_test.go`: walk → parse → build → metrics → validate. Assert expected node count/types, edge count/types, broken edge detected, orphan detected, non-zero metrics for connected nodes
- [x] Add `plugin-graph` target to `Makefile`: `go test ./cmd/plugin-graph/...` then `go run ./cmd/plugin-graph --root klaude-plugin/ validate`
- [x] Run `make plugin-graph` against the real `klaude-plugin/` and fix any validation findings (broken links, orphans) that surface — these are real bugs in the plugin, not test failures

**Verify:** `make plugin-graph` passes. Integration test passes. `go run ./cmd/plugin-graph --root klaude-plugin/ metrics --format text` produces a readable table with all skills.

**Implementation notes (deviations from plan):**

- **The 6 `validate` findings were false positives, not "real bugs in the plugin" as the checkbox assumed.** All 6 broken edges originated from *non-operative content*: eval-fixture internal links under `evals/test-files/` (3 — several deliberately omit their targets because the eval tests missing-target/degradation detection, so "fixing" them by creating targets would break those evals) and illustrative/example links (3 — `example-tasks.md`'s template links ×2, and a `[FORMS.md](FORMS.md)` syntax example in `skill-structure-gotchas.md`).
- **Resolution (Option B, user-approved):** Broadened broken-edge detection to exempt non-operative sources via `nonOperativeSource(RawSource)` in `metrics.go` (Task 3's file) — skips edges sourced under `evals/` (mirrors the existing orphan exemption) or from `example-*.md` artifacts. Source-fixed only the one operative-file illustration: backticked the `[FORMS.md](FORMS.md)` example in `skill-structure-gotchas.md` so it renders as a code span (goldmark no longer parses it as a live link). `design.md` / `implementation.md` updated to document the exemption. `validate` against the real plugin now exits 0.
- **Integration fixture exercises all 6 edge types + both defects.** `testdata/minimal-plugin/` (9 nodes) drives markdown-link, symlink, template-ref, parameterized-nav, agent-delegation, and skill-invocation edges, plus one intentional broken edge (`beta → does-not-exist.md`) and one orphan (`orphan.md`), with `README.md` pinning the entry-point orphan exclusion.
- **Expected, not fixed:** `metrics`/`validate` on the real plugin emit a `cycle detected` stderr diagnostic and `DEPTH = -1` for most skills — the documented strongly-connected-component behavior from Task 3, not a `validate` failure.

**Code-review fixes applied (isolated review: code-reviewer + pal/gemini-3.1-pro-preview):**

- **Integration-test robustness (code-reviewer P2 ×2 + P3).** `TestIntegrationFixturePipeline` now (a) asserts `ComputeMetrics` emits no diagnostics — symmetric with the existing `BuildGraph` diagnostics check; (b) pins the agent-delegation edge to its source (`skills/alpha/SKILL.md → agents/example-reviewer.md`) so a misfiring extractor producing the right *type* from the wrong file is caught; (c) pins total `len(g.Nodes) == 9` alongside the per-type counts.
- **Windows symlink portability (corroborated, Medium).** The symlink-edge assertion is now guarded by `os.Lstat`/`ModeSymlink`: on a checkout where `shared-common-helper.md` didn't materialize as a real symlink (Git on Windows without symlink support), the assertion `t.Logf`-skips instead of hard-failing. Node count and diagnostics still hold on that path (the file is absorbed into the skill artifact, produces no edges).
- **`nonOperativeSource` doc note (code-reviewer P1 → downgraded to P3; pal: "correctly scoped").** Comment now states the `example-*.md` basename match is plugin-wide *by design* (repo convention for example artifacts) and that `path.Base` (not `filepath.Base`) is correct for slash-normalized `RawSource`. Empirically the only non-eval `example-*.md` today is `example-tasks.md` — the intended target; no operative `example-*.md` exists.
- **Dismissed:** pal re-raised the Task 6 `WithWorktree` cleanup error-swallowing as P1/HIGH — verified already fixed (`worktree.go` has the `registered` gate + `errors.Join` + `err == nil` guard) and out-of-scope for this diff; pal's continuation had resumed stale Task 6 review context. Kept the Makefile `plugin-graph` target as-is (the test+validate coupling is the intended CI gate per implementation.md §Makefile Integration). No P0/P1 systemic findings to index as `kk:review-findings`.

**Heads-up (observed during Task 5 review):** `metrics`/`validate` against the real `klaude-plugin/` already emits a large `cycle detected affecting: …` diagnostic spanning most skills/profiles/agents. This is **expected, not a bug** — the plugin's cross-references (skills ↔ shared ↔ profiles) form a strongly-connected component, and depth = −1 for cyclic nodes is the Task 3 design. Cycles are stderr diagnostics, not `validate` failures (`validate` exits 1 only on broken edges/orphans). Don't try to "fix" the cycle; the Task 7 finding-triage checkbox is about broken links and orphans only.

---

## Task 8: Gate — Post-implementation verification

**Status:** pending
**Size:** S
**Dependencies:** Task 7
**Can run in parallel with:** —

Post-implementation gate (not an implementation task — workflow verification steps).

- [ ] Run `/kk:test` — full test suite including `make plugin-graph` and `test/test-plugin-structure.sh`
- [ ] Run `/kk:document` — update any relevant docs (README mention of the new tool, CLAUDE.md if conventions change)
- [ ] Run `/kk:review-code` — review all changes for the feature
- [ ] Run `/kk:review-spec` — verify implementation matches design.md and implementation.md

**Verify:** All four skills pass without blocking findings.

---

## Dependency Graph

```
Task 0 (goldmark validation)
  │
  v
Task 1 (graph types) ──────────────────┐
  │                                     │
  ├──> Task 2 (walker + extractors)     ├──> Task 4 (output formatters)
  │                                     │
  └──> Task 3 (metrics) ───────────────┘
                                        │
         Task 2 ────────────────────────┤
                                        v
                                  Task 5 (CLI + targeted mode)
                                        │
                                        v
                                  Task 6 (worktree)
                                        │
                                        v
                                  Task 7 (integration fixture + Makefile)
                                        │
                                        v
                                  Task 8 (final verification)
```
