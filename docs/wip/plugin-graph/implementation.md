# plugin-graph — Implementation Plan

> Design: [design.md](design.md) | Tasks: [tasks.md](tasks.md)

## Project Structure

```
cmd/plugin-graph/
  main.go              — CLI entry point, flag parsing, subcommand dispatch
  graph.go             — Graph/Node/Edge types, graph builder
  parse.go             — File walker + six extractors
  parse_test.go        — Extractor unit tests (table-driven, one section per extractor)
  metrics.go           — Metric computation over the graph
  metrics_test.go      — Metric calculation tests
  output.go            — JSON/text/DOT/Mermaid formatters
  output_test.go       — Output format tests (golden file comparisons)
  worktree.go          — Git worktree create/cleanup for --ref
  worktree_test.go     — Worktree lifecycle tests
  main_test.go         — Integration test: full pipeline against fixture directory
  testdata/
    minimal-plugin/    — Fixture mimicking minimal klaude-plugin/ structure
```

Follows the flat `package main` pattern used by `cmd/generate-kodex/` and `cmd/vendor-profiles/`.

## Dependencies

- **`gopkg.in/yaml.v3`** — already in `go.mod`.
- **Goldmark** (`github.com/yuin/goldmark`) — markdown parser for reliable link extraction. Needs validation in Task 0 that it can extract inline link targets (`[text](path.md)`) from AST nodes. Fallback: regex-based extraction if goldmark's AST is awkward for this use case.
- No other new dependencies expected. Symlinks, file walking, regex, JSON encoding, and text formatting are all stdlib.

## Implementation Details

### Core Types (`graph.go`)

**`NodeType`** — string enum: `skill`, `shared`, `agent`, `profile`, `profile-phase`, `content`, `command`.

**`EdgeType`** — string enum: `markdown-link`, `symlink`, `template-ref`, `parameterized-nav`, `agent-delegation`, `skill-invocation`.

**`Node`** — `Path` (relative to plugin root, unique ID), `Type`, `Name` (human label derived from path).

**`Edge`** — `Source` (path), `Target` (path), `Type`, `Line` (source line number for diagnostics).

**`Graph`** — `Nodes` map (path → Node), `Edges` slice. Methods: `AddNode`, `AddEdge`, `NodeByPath`, `OutEdges(path)`, `InEdges(path)`, `Reachable(path, direction)`, `NormalizePath(path)`.

The graph builder walks the plugin root, classifies each file/directory into a node type based on its location in the tree, then runs the extractors on each `.md` file to discover edges. Edge endpoints are normalized to their owning artifact node via `NormalizePath`.

#### Node identity and normalization

Two node levels: **artifact nodes** (directory-level: skill, profile, profile-phase, command) and **file nodes** (individual `.md`: shared, agent, content). Edges are discovered from file paths but normalized:

- Files inside an artifact directory → normalized to the artifact node (e.g., `skills/review-code/SKILL.md` → `skills/review-code/`)
- Files not inside an artifact directory → kept as file-level nodes (e.g., `skills/_shared/profile-detection.md`)

`NormalizePath(path string) string` walks up from the given path, checking if any ancestor is a known artifact node. Returns the artifact's path if found, otherwise the original path. Targeted mode also uses this: `plugin-graph metrics skills/review-code/SKILL.md` resolves to the `skills/review-code/` skill node.

#### Node Classification Rules

| Path pattern | Node type | Level |
|-------------|-----------|-------|
| `skills/<name>/SKILL.md` present → directory is a `skill` | `skill` | artifact |
| `skills/_shared/*.md` | `shared` | file |
| `agents/*.md` | `agent` | file |
| `profiles/<name>/` (directory with `DETECTION.md`) | `profile` | artifact |
| `profiles/<name>/<phase>/` (directory with `index.md`) | `profile-phase` | artifact |
| `commands/<name>/` | `command` | artifact |
| Everything else `.md` | `content` | file |

### Extractors (`parse.go`)

Each extractor is a standalone function: `func(filePath string, content []byte, ctx *ParseContext) []Edge`.

`ParseContext` carries shared state the extractors need:
- `PluginRoot` — absolute path to the plugin directory being analyzed
- `KnownProfiles` — list of profile names (parsed from `skills/_shared/profile-detection.md` §Known profiles at startup)
- `KnownPhases` — `[]string{"review-code", "review-spec", "design", "implement", "test", "document"}`
- `KnownAgents` — list of agent names (derived from `agents/` directory listing at startup)
- `KnownSkills` — list of skill names (derived from `skills/` directory listing at startup)
- `KnownCommands` — map of skill name → command names (derived from `commands/` directory listing)

#### Code-block stripping

Before running regex-based extractors (3–5), content is pre-processed to replace fenced code blocks (`` ``` `` and `~~~`` delimited) with blank lines of equal length (preserving line numbers for edge diagnostics). Extractor 1 (goldmark AST) is inherently code-block-safe. Extractor 2 (symlinks) operates on the filesystem.

**Extractor 1 — Markdown links:** Parse with goldmark, walk AST for `ast.Link` nodes, extract `Destination`. Resolve relative paths against the file's directory. Filter: skip external URLs (`://`), anchor-only (`#...`), non-`.md` targets. Each surviving link → `markdown-link` edge with line number from AST position. Code-block-safe via AST.

**Extractor 2 — Symlinks:** Called before content extraction. `os.Lstat(path)` → if `ModeSymlink`, `os.Readlink(path)` → resolve target relative to symlink's directory → `symlink` edge. Note: the resolved file's content is still processed by other extractors (the walker follows symlinks for content but records the symlink edge separately).

**Extractor 3 — Plugin-root references (merged template + parameterized):** A single extractor handles both concrete and parameterized `${CLAUDE_PLUGIN_ROOT}/...` paths. Regex: `` `\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)` ``. Strip the prefix, then branch:
- **No angle-bracket variables** in remainder → `template-ref` edge to the concrete relative path.
- **Contains `<name>`, `<profile>`, `<phase>`, or `<checklist>`** → `parameterized-nav` edge. Expansion logic:
  1. Expand `<name>` and `<profile>` over `KnownProfiles`.
  2. Expand `<phase>` over `KnownPhases`.
  3. Expand `<checklist>` by globbing `profiles/<profile>/<phase>/*.md` (excluding `index.md`). The bidirectional invariant guarantees this matches what `index.md` references, avoiding the need to parse index files during extraction.
  4. Each concrete expansion that exists on disk → edge.

Runs on code-block-stripped content.

**Extractor 4 — Agent delegation:** Matches `subagent_type` in **structured contexts only**: markdown table rows where one cell contains `subagent_type` and another cell on the same line contains `kk:(<agent-name>)`. Regex: a line matching `\|\s*` + `subagent_type` + `\s*\|` + `.*kk:([a-z-]+)`. Maps capture to `agents/<name>.md`. Does NOT scan for agent names as whole words in free prose — this avoids false positives from prose descriptions that mention agents without implying delegation.

Runs on code-block-stripped content.

**Extractor 5 — Skill and command invocation:** Regex: `/kk:([a-z-]+)(?::([a-z-]+))?`. The first capture group maps to `skills/<skill>/` directories (matched against `KnownSkills`). If a second capture group is present (command name), an additional edge is created to `commands/<skill>/<command>.md` if it exists on disk. Self-references (skill referencing itself) are skipped.

Runs on code-block-stripped content.

### Metrics (`metrics.go`)

**`NodeMetrics`** struct: `FanOut`, `FanIn`, `Depth`, `TransitiveClosureSize` (all `int`).

**`GraphMetrics`** struct: `PerNode` map (path → NodeMetrics), `Orphans` ([]path), `BrokenEdges` ([]Edge), `Hotspots` ([]path sorted by fan-in desc), `Coupling` ([]SkillPair with shared dep count).

Computation:
- Fan-in/fan-out: single pass over edges, count per node.
- Depth: DFS from each node, memoized. Cycle detection → report cycle as a diagnostic, depth = -1 for nodes in a cycle.
- Transitive closure: BFS from each node, count reachable set size.
- Coupling: for each pair of `skill` nodes, intersect their forward-reachable sets. Only report pairs with intersection > threshold (default 3).
- Orphans: nodes where fan-in = 0, excluding **entry-point nodes** that legitimately have no incoming edges. Entry points: `skill` nodes (invoked by users), `profile` nodes (activated by detection), `command` nodes (invoked via `/kk:<skill>:<command>` — but may also have edges from skill-invocation extractor), `agent` nodes (spawned by skills, but delegation edges may exist), `README.md` at plugin root, and files under `evals/` directories (test fixtures). Only `content` and `shared` nodes with zero fan-in are flagged as orphans.
- Broken edges: edges whose target path doesn't resolve to a file on disk.

### Output (`output.go`)

Four formatter functions, each taking `*Graph` and `*GraphMetrics` and returning `[]byte`. Structured output goes to **stdout**; diagnostics (cycles, parse warnings, skipped files) go to **stderr**.

**JSON:** Marshal a `Report` struct containing `nodes`, `edges`, `metrics`, and `diagnostics` arrays. Pretty-printed with `json.MarshalIndent`. The `diagnostics` array captures cycle reports, parse warnings, etc. so programmatic consumers get the full picture.

**Text:** Table formatted with `text/tabwriter`. Header row, one row per skill node sorted by transitive closure size descending. Columns: Name, Fan-out, Fan-in, Depth, Transitive. Followed by sections for orphans, broken edges, hotspots. Diagnostics appended at the end.

**DOT:** Template-based. Nodes get `shape` and `fillcolor` by type. Edges get `style` by type (solid for static, dashed for template/parameterized, dotted for implicit). Subgraph clusters for skills, profiles, agents. Diagnostics only on stderr.

**Mermaid:** Same visual semantics as DOT, rendered as Mermaid flowchart LR syntax. Node IDs are sanitized paths. Edge labels show type. Diagnostics only on stderr.

The `validate` subcommand respects `--format`: `json` emits structured validation findings (broken edges, orphans), `text` (default) emits human-readable findings. Exit code 1 when findings exist.

### Targeted Mode

When positional args are provided:
1. Build the full graph normally.
2. Parse each arg as a path relative to plugin root. Normalize via `NormalizePath` to resolve file paths to their owning artifact node.
3. Based on `--direction`: compute forward-reachable set (BFS following out-edges), reverse-reachable set (BFS following in-edges), or union of both.
4. Filter graph to only include nodes in the reachable set and edges between them.
5. Compute metrics on the filtered subgraph.

### Git Worktree (`worktree.go`)

```go
func WithWorktree(ref string, fn func(root string) error) error
```

1. Create temp directory via `os.MkdirTemp`.
2. Run `git worktree add --detach <tempdir> <ref>`.
3. Call `fn(tempdir)`.
4. Deferred: `git worktree remove --force <tempdir>` then `os.RemoveAll(tempdir)`.

Error handling: if `git worktree add` fails (invalid ref, not a git repo), return a clear error message. The `--force` on remove handles the case where the worktree has uncommitted changes (shouldn't happen since we're read-only, but defensive).

### Makefile Integration

```makefile
plugin-graph:
	go test ./cmd/plugin-graph/...
	go run ./cmd/plugin-graph --root klaude-plugin/ validate
```

The `validate` subcommand provides a natural CI hook — broken links and orphans fail the build.

### CLI Flag Parsing

The binary uses per-subcommand `flag.FlagSet`s. `main()` extracts global flags (`--root`, `--ref`) from `os.Args[1:]` before the subcommand, then passes remaining args to the subcommand's own FlagSet. This matches the usage pattern `plugin-graph <subcommand> [flags] [targets...]`.

## Testing Strategy

### Unit Tests

**Extractor tests (`parse_test.go`):** Table-driven. Each extractor gets its own test function with cases like:

- Markdown links: inline link, reference link, external URL (skipped), anchor-only (skipped), non-md target (skipped), link inside code block (skipped — goldmark AST)
- Symlinks: valid symlink, broken symlink
- Plugin-root refs (merged extractor): concrete `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/overview.md` → template-ref; parameterized `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md` → parameterized-nav expanded over profiles; bare `$CLAUDE_PLUGIN_ROOT` (skipped — no braces); path inside fenced code block (skipped); `<checklist>` expansion via glob
- Agent delegation: `subagent_type` in markdown table row → edge; `subagent_type` in fenced code block (skipped); agent name in free prose (skipped — structured context only)
- Skill/command invocation: `/kk:review-code` → skill edge; `/kk:review-code:isolated` → skill edge + command edge; `/kk:name` inside code block (skipped); self-reference (skipped)
- Code-block stripping: verify fenced blocks are removed while preserving line numbers

**Metrics tests (`metrics_test.go`):** Construct small graphs programmatically, assert computed metrics. Cases: linear chain (depth), diamond (fan-in/out), isolated node (orphan), missing target (broken edge), cycle (cycle detection).

**Output tests (`output_test.go`):** Golden file comparisons. A fixture graph → each format → compare against `testdata/*.golden`. Update with `-update` flag.

### Integration Test

**`main_test.go`:** Uses `testdata/minimal-plugin/` — a stripped-down plugin structure with:
- 2 skills (one with symlink to shared, one referencing an agent)
- 1 shared instruction
- 1 agent
- 1 profile with 1 phase
- 1 intentional broken link
- 1 orphan file

Runs the full pipeline: walk → parse → build graph → compute metrics → validate. Asserts:
- Expected node count and types
- Expected edge count and types
- Broken edge detected
- Orphan detected
- Metrics are non-zero for connected nodes

### Worktree Test

**`worktree_test.go`:** Tests `WithWorktree` lifecycle. Skipped in environments without git (`testing.Short()` or git-not-found check). Asserts temp directory is created, callback receives valid path, cleanup removes worktree.

## Assumptions

See [design.md §Assumptions](design.md#assumptions).

## Not Doing

See [design.md §Not Doing](design.md#not-doing).
