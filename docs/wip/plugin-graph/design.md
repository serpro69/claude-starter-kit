# plugin-graph — Design

## Problem Statement

How might we give plugin maintainers, contributors, and AI assistants visibility into the dependency web between skills, shared instructions, profiles, and agents — so they can assess impact before making changes, catch broken links before they ship, and objectively measure skill complexity?

The klaude-plugin has a rich link taxonomy (markdown links, symlinks, `${CLAUDE_PLUGIN_ROOT}` template references, parameterized navigation instructions, implicit agent delegations, skill invocations) but no unified view of it. Impact analysis is manual, and complexity is felt but not measured.

## Target Users

1. **Plugin maintainer** — needs impact analysis, validation, and complexity visibility across the skill web.
2. **Contributors** — need to understand the dependency structure before making changes.
3. **AI assistants** — skills like `/kk:review-code` and `/kk:review-design` need programmatic access to complexity data to flag "this skill has unusually high coupling" with evidence.

## Success Metric

Quantified complexity metrics (fan-in/out, depth, coupling, transitive closure) are available to review skills and humans, with data-backed findings. Validation and impact analysis are supporting capabilities.

## Design

### Graph Model

A directed graph where nodes represent plugin artifacts and edges represent dependency relationships.

#### Node Types

Each node has a `type` discriminator and a `path` (relative to `klaude-plugin/`) as its unique identifier.

#### Node identity

Two levels exist: **artifact nodes** (directory-level groupings: skills, profiles, profile-phases, commands) and **file nodes** (individual `.md` files: shared, agent, content). Edges always reference file-level paths. When a file belongs to an artifact node (e.g., `skills/review-code/SKILL.md` belongs to the `skills/review-code/` skill), the builder normalizes the edge endpoint to the artifact node. This means:

- Edge source `skills/review-code/SKILL.md` → normalized to `skills/review-code/`
- Edge source `skills/review-code/review-process.md` → normalized to `skills/review-code/`
- Edge source `skills/_shared/profile-detection.md` → stays as-is (file node, not inside an artifact)
- Targeted mode: both `plugin-graph metrics skills/review-code/` and `plugin-graph metrics skills/review-code/SKILL.md` resolve to the same skill node

| Type | Level | Description | Example |
|------|-------|-------------|---------|
| `skill` | artifact | Skill directory containing `SKILL.md` | `skills/review-code/` |
| `shared` | file | File under `skills/_shared/` | `skills/_shared/profile-detection.md` |
| `agent` | file | Agent definition under `agents/` | `agents/code-reviewer.md` |
| `profile` | artifact | Profile directory under `profiles/` | `profiles/go/` |
| `profile-phase` | artifact | Phase subdirectory within a profile | `profiles/go/review-code/` |
| `content` | file | Any other `.md` file (process files, checklists, indexes, evals) | `skills/review-code/review-process.md` |
| `command` | artifact | Command directory under `commands/` | `commands/chain-of-verification/` |

#### Edge Types

Edges fall into three categories based on how they're discovered.

**Static edges** — directly parseable from the filesystem:

| Type | Source | Discovery |
|------|--------|-----------|
| `markdown-link` | `[text](target.md)` in file content | Markdown parser or regex |
| `symlink` | Filesystem symlink | `os.Readlink` |

**Template and parameterized edges** — require variable substitution and/or expansion. A single extractor handles both: it matches backtick-delimited `${CLAUDE_PLUGIN_ROOT}/...` paths, strips the prefix, then either resolves the remainder as a concrete path (template-ref) or expands angle-bracket variables over known sets (parameterized-nav). Paths containing `<name>`, `<profile>`, `<phase>`, or `<checklist>` are always parameterized; paths without angle-bracket variables are always template-refs.

| Type | Source | Discovery |
|------|--------|-----------|
| `template-ref` | `` `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/overview.md` `` | Regex, strip prefix, resolve concrete path |
| `parameterized-nav` | `` `${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md` `` | Regex, strip prefix, expand variables over known sets |

**Implicit edges** — inferred from structured references in prose:

| Type | Source | Discovery |
|------|--------|-----------|
| `agent-delegation` | `subagent_type` parameter in Agent tool-call tables | Structured-context regex in markdown tables |
| `skill-invocation` | `/kk:<skill>` or `/kk:<skill>:<command>` in prose | Regex + match against `skills/` and `commands/` |

Each edge records: `source` (path), `target` (path), `type`, and `line` number.

### Link Parsing Pipeline

Files are processed in a single pass. Five extractors run in sequence, each independent and composable. A **pre-processing step** strips fenced code blocks (`` ``` `` and `~~~` delimiters) from content before running regex-based extractors 3–5. Extractor 1 (goldmark AST) is inherently code-block-safe. Extractor 2 (symlinks) operates on the filesystem, not content.

**Extractor 1 — Markdown links:** Uses goldmark (or regex fallback) to find `[text](target.md)`. Resolves relative targets against the file's directory. Ignores external URLs, anchor-only refs, and non-`.md` targets. Code-block-safe via goldmark AST (links inside code blocks are not `ast.Link` nodes).

**Extractor 2 — Symlinks:** `os.Lstat` before reading content. If symlink, `os.Readlink` captures target. Creates `symlink` edge. The resolved file is also processed for its own outgoing links.

**Extractor 3 — Plugin-root references (merged template + parameterized):** A single extractor handles both concrete and parameterized `${CLAUDE_PLUGIN_ROOT}/...` paths. Regex matches backtick-delimited brace-form paths, strips the `${CLAUDE_PLUGIN_ROOT}/` prefix, then branches:
- **No angle-bracket variables** → `template-ref` edge to the concrete relative path.
- **Contains `<name>`, `<profile>`, `<phase>`, or `<checklist>`** → `parameterized-nav` edge. Expands `<name>`/`<profile>` over Known Profiles, `<phase>` over the six known phase names. For `<checklist>`, globs `profiles/<profile>/<phase>/*.md` (the bidirectional invariant guarantees this matches what `index.md` references). Each concrete expansion that exists on disk becomes an edge.

Runs on code-block-stripped content.

**Extractor 4 — Agent delegation:** Matches `subagent_type` in **structured contexts only**: markdown table rows where a cell contains `subagent_type` and another cell on the same row contains `kk:<agent-name>`. Does NOT scan for agent names as whole words in free prose. Runs on code-block-stripped content.

**Extractor 5 — Skill and command invocation:** Regex for `/kk:([a-z-]+)(?::([a-z-]+))?` patterns. The first capture group maps to `skills/<name>/`. If a second capture group is present (command name), an additional edge is created to `commands/<skill>/<command>.md` if it exists on disk. Runs on code-block-stripped content.

### Metrics

#### Per-Node Metrics

| Metric | Definition | Signal |
|--------|-----------|--------|
| Fan-out | Out-degree (direct dependencies) | High = pulls in many files |
| Fan-in | In-degree (direct dependents) | High = high-impact change target |
| Depth | Longest dependency chain to a leaf | Deep = many instruction layers |
| Transitive closure | Total reachable nodes | "True weight" of a skill |

#### Global Metrics

| Metric | Definition | Signal |
|--------|-----------|--------|
| Orphans | Nodes with zero fan-in, excluding entry points (see below) | Potential dead content |
| Broken edges | Edges whose target doesn't exist on disk | Build-breaking errors |
| Hotspots | Nodes ranked by fan-in | Highest-impact change targets |
| Coupling | Shared dependency count between skill pairs | Over-sharing between unrelated skills |

### CLI Interface

Lives at `cmd/plugin-graph/`. Single binary, subcommand-based.

```
plugin-graph <subcommand> [flags] [target...]
```

Subcommand comes first, flags follow. Each subcommand uses its own `flag.FlagSet` so flags are parsed after the subcommand argument.

#### Subcommands

- `graph` — emit the dependency graph in the chosen format (default when no subcommand given)
- `metrics` — compute and emit complexity metrics
- `validate` — check for broken edges and orphans; exit code 1 if any found

#### Flags

Global flags (parsed before subcommand): `--root <path>` (default: `klaude-plugin/`), `--ref <git-ref>` (default: working tree).

Per-subcommand flags: `--format json|text|dot|mermaid` (default: `text`), `--direction forward|reverse|both` (default: `forward`, targeted mode only).

#### Targeted Mode

When positional arguments are provided after flags, the tool builds the full graph internally but filters output to the subgraph reachable from those starting nodes. Multiple targets are unioned. Target paths resolve to the owning artifact node (e.g., `skills/review-code/SKILL.md` resolves to the `skills/review-code/` skill node).

```
plugin-graph metrics --format json skills/review-code/
plugin-graph graph --direction both skills/_shared/profile-detection.md
```

#### Git Ref Support

When `--ref` is provided:
1. `git worktree add --detach <tempdir> <ref>`
2. Effective root becomes `<tempdir>/klaude-plugin/`
3. Run normally
4. `git worktree remove <tempdir>` on cleanup (deferred)

### Output Formats

Structured output (graph data, metrics, validation results) goes to **stdout**. Diagnostics (cycle warnings, parse errors, skipped files) go to **stderr**.

- **`json`** — full graph + metrics as structured JSON. Contains `nodes`, `edges`, `metrics`, and `diagnostics` arrays. The `diagnostics` array includes cycle reports, parse warnings, etc. The canonical programmatic output.
- **`text`** — human-readable summary table. Per-skill metrics sorted by transitive closure size. Warnings for orphans/broken edges. Diagnostics appended at the end.
- **`dot`** — GraphViz DOT format. Nodes colored by type, edges styled by type. Diagnostics only on stderr.
- **`mermaid`** — Mermaid flowchart syntax. Same visual semantics as DOT. Diagnostics only on stderr.

The `validate` subcommand respects `--format`: `json` emits structured validation findings, `text` (default) emits human-readable findings. Exit code 1 when broken edges or orphans are found.

## Assumptions

1. **Goldmark (or equivalent) can reliably extract markdown link targets.** Will be validated as a prerequisite task before implementation.
2. **Three link categories cover all dependency edges.** Static (markdown links, symlinks), template paths (`${CLAUDE_PLUGIN_ROOT}/...` with concrete suffixes), and parameterized navigation instructions (backtick-quoted paths with variables expanding over known sets). The variable vocabulary is small and the expansion sets are finite (8 profiles, 6 phases).
3. **`git worktree` is available** in environments where the tool runs (CI, local dev).
4. **The graph fits in memory.** ~10 skills, 5 agents, 8 profiles, ~4 shared instructions — dozens of nodes, not thousands.
5. **JSON output is sufficient for programmatic consumers.**

## Not Doing

- **Review skill integration** — Teaching `/kk:review-code` or `/kk:review-design` to invoke the tool and interpret results. The CLI needs to exist first; integration is follow-up work.
- **Committed JSON artifact / CI freshness checks** — A `make plugin-graph` target that generates and checks in a JSON artifact. Easy to layer later, orthogonal to the CLI.
- **Interactive visualization** — No web UI, no `--serve` mode. DOT/Mermaid output can be rendered by external tools.
- **Diff/comparison subcommand** — Users can diff JSON output from two `--ref` runs themselves. A dedicated `diff` subcommand is future work.
- **Cross-plugin analysis** — Only `klaude-plugin/` is in scope. Analyzing `kodex-plugin/` or downstream consumer plugins is out of scope.
- **Semantic analysis of prose** — The tool parses backtick-quoted path patterns, not free-text descriptions of what files to read.
