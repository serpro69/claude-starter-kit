# Design: diff-skill

> Status: design
> Created: 2026-04-18
> Related: [implementation.md](./implementation.md), [tasks.md](./tasks.md)

## Goal

`diff-skill` answers one question about a skill maintained in `klaude-plugin/skills/`:

> **Did commit B degrade this skill compared to commit A?**

The check is deliberately **asymmetric**. Additions, clarifications, and strengthenings are not degradations. Only the following count:

- Load-bearing instruction dropped
- Constraint weakened (`MUST` → `SHOULD`, `NEVER` → `AVOID`, etc.)
- Verification step removed
- Scope narrowed (fewer cases covered)
- Required output dropped
- Reference broken (link/symlink/agent/tool no longer resolvable or no longer present)

This is a refactor-safety tool for skill authors: edit a skill, run `diff-skill`, and get a high-signal answer about whether the edit made the skill worse.

## Scope of comparison

The "skill" being compared is defined as **every file transitively reachable via links from `SKILL.md`**. The definition is closed — what a reader of `SKILL.md` could land on by following links is exactly what the skill is. The rule is simple on purpose: no heuristics about what "counts," just a fixed-point link walk.

### Traversal rule

```
frontier = {SKILL.md}
visited  = {}
while frontier non-empty:
    file = frontier.pop()
    visited.add(file)
    for link in extract_links(file):
        resolved = resolve_relative_to(file.dir, link)
        if resolved not in visited and resolved exists at <ref>:
            frontier.add(resolved)
return visited
```

### What counts as a link

- Markdown relative links: `[text](./foo.md)`, `[text](../foo.md)`, `[text](/abs/path.md)` (absolute = repo-root-relative).
- YAML frontmatter fields that name a file.
- Symlinks are dereferenced transparently. The dereferenced path is the comparison key across both sides (so relocations like `shared-foo.md → _shared/foo.md` are tracked as location changes, not content loss).

**Symlink handling at historical refs.** `git show <ref>:<path>` on a symlink returns the symlink *target string*, not the content at the target. The traversal therefore does a two-step dance at refs:

1. `git ls-tree --full-tree <ref> <path>` — check mode. Mode `120000` = symlink.
2. If symlink: `git cat-file -p <ref>:<path>` returns the target path text; resolve relative to the symlink's directory, then fetch the resolved path (recursively if the target is itself a symlink).
3. If regular file: `git show <ref>:<path>` returns content directly.

Working-tree reads use filesystem `readlink` + normal file reads — same end result.

### What is excluded from traversal

- External URLs (`http://`, `https://`)
- Anchor-only references (`#section`)
- Binary attachments (images, PDFs)
- Files that don't exist at the ref being walked (treated as "absent at this ref" — fed into add/remove judgment, not an error)

### Safety rails

- Max file count per side: 50. A skill pulling in more than 50 files is almost certainly a bug. Fail loudly.
- Max traversal depth: 20. Defensive — `visited` set already prevents cycles; depth cap handles malformed ref content.

## Invocation

```
/kk:diff-skill <skill-name> [<ref-a>] [<ref-b>]
```

`git diff`-style ergonomics:

| Form                                                   | Compares                  |
| ------------------------------------------------------ | ------------------------- |
| `/kk:diff-skill review-code`                           | working tree vs. `HEAD`   |
| `/kk:diff-skill review-code HEAD~5`                    | working tree vs. `HEAD~5` |
| `/kk:diff-skill review-code v0.8.0 v0.9.0`             | two refs                  |
| `/kk:diff-skill design@v0.4.0..review-design@HEAD`     | cross-rename syntax       |

### Rename handling

Skill renames happen (e.g., `design-review → review-design`). Syntax for cross-name diff:

```
<old-name>@<ref-a>..<new-name>@<ref-b>
```

Bare `skill-name@ref` is allowed on either side; the other side defaults to the same name and the default ref (working tree for side B, `HEAD` for side A).

### Validation at invocation

- Ref resolves → else pass through git error.
- `klaude-plugin/skills/<name>/SKILL.md` exists at the resolved ref → else: `error: skill "foo" not found at <ref>. If this is a new skill, there's nothing to diff. If it was renamed, use old@ref..new@ref syntax.`
- Working directory is inside a git repo → else error.

### Add/remove of referenced files

A referenced file existing only on one side is *not* automatically classified. It flows into the judgment pipeline for case-by-case evaluation:

- Content removed and not inlined elsewhere → likely degradation
- Content removed because it was inlined into `SKILL.md` → neutral (relocation)
- New file added with new content → likely improvement or neutral
- New file added that replaces inline content now removed → neutral (relocation)
- In-tree rename (file at path X in A, path Y in B, both sides link to the respective path) → Pass 2 pairs the removal with the addition when content is ≥70% similar (by line-overlap); treat as neutral when paired. Below the threshold, treat as removal + unrelated addition.

## Judgment pipeline

Two passes. Pass 1 is mechanical; Pass 2 is LLM judgment.

### Pass 1 — Structural/prescriptive extraction

For each file in each side's content map, extract and enumerate:

| Element              | Examples                                                             |
| -------------------- | -------------------------------------------------------------------- |
| Normative rules      | Lines containing all-caps markers: `MUST`, `MUST NOT`, `NEVER`, `ALWAYS`, `DO NOT`, `SHOULD`, `DON'T`. Lowercase forms (`always`, `never`) are deliberately excluded to avoid false positives on prose; Pass 2 still catches load-bearing lowercase prose via LLM judgment. |
| Section headings     | All `#`, `##`, `###` headings with their full path                   |
| Required outputs     | Checkbox items under "Required Outputs" / "Outputs" / "Deliverables" headings. This binds extraction to a heading convention — skills that want required-output coverage MUST use one of those heading names. Checkbox lists under other headings are not extracted by this rule (they may still be picked up as prose by Pass 2). |
| Verification steps   | Lines matching `Step → verify: <check>` or similar patterns          |
| Tool/agent/command references | Named tools, agents (`code-reviewer`, `pal`), commands invoked |
| File references      | All links discovered in the traversal                                |

Diff the extracted sets. Produce a candidate findings list with categories:

- Rule present in A, absent in B → candidate degradation (`lost-rule`)
- Same rule, weakened (`MUST` → `SHOULD`) → candidate degradation (`weakened-constraint`)
- Heading dropped → candidate degradation (`dropped-section`)
- Required output dropped → candidate degradation (`dropped-output`)
- Verification step dropped → candidate degradation (`dropped-verification`)
- Tool/agent reference dropped → candidate degradation (`broken-reference`)
- Added rule / added section / added output → candidate improvement
- Prose-only diff (no structural deltas) → candidate neutral
- File present on one side only → candidate pending LLM classification

### Pass 2 — LLM degradation judgment

The LLM running the skill receives:

1. The candidate findings list from Pass 1
2. Full content of changed files on both sides (for context)
3. Explicit asymmetric framing:

   > "Your job is to decide whether version B degrades version A. Additions, clarifications, and strengthenings are NOT degradations. A degradation is: load-bearing instruction lost, weakened constraint, dropped verification, narrowed scope, broken reference, or required output lost. For each candidate, classify as `degradation`, `neutral`, or `improvement`, and justify."

The LLM **can reclassify**:

- Candidate degradation → neutral when content was inlined/moved.
- Candidate neutral → degradation when load-bearing prose was silently lost.
- Candidate improvement → neutral or degradation when an "addition" is actually a constraint loosener.

### Confidence

Each finding carries `high` / `medium` / `low` confidence. Low-confidence findings surface under "Unclear — needs user review" rather than being forced into a decisive bucket.

### Why two passes

- **Pass 1 guarantees coverage.** Mechanical extraction ensures no load-bearing rule slips past because of prose fatigue.
- **Pass 2 guarantees precision.** LLM reclassification prevents false positives on cosmetic changes and catches semantic degradations buried in prose.

## Report

### File location

```
docs/reviews/diff-skill/<skill-name>-<short-sha-a>-<short-sha-b>.md
```

- Short SHA = 7 chars.
- Working-tree side → `WORKTREE`.
- Renames → `<old-name>-to-<new-name>-<sha-a>-<sha-b>.md`.
- Directory is created on first run.

### Structure

```markdown
# diff-skill: <name> (<ref-a> → <ref-b>)

> Generated: <date>
> Files compared: N reachable files (rooted at SKILL.md)
> Verdict: no-degradation | degraded | unclear

## Summary
<one-sentence verdict>
<counts per bucket>
<notable reclassification decisions>

## Degradations
### <short title>
- **File:** `<path>` (and `<alt path>` if relocated)
- **Kind:** lost-rule | weakened-constraint | dropped-verification | narrowed-scope | broken-reference | dropped-output
- **Confidence:** high | medium | low
- **Before (<ref-a>):**
  > <quote>
- **After (<ref-b>):**
  > <quote or "removed">
- **Why it matters:** <one paragraph>

## Neutral Changes
- `<file>`: <one-line description>

## Improvements
- `<file>`: <one-line description>

## Unclear — Needs User Review
- `<file>`: <one-line description + what's ambiguous>

## Traversal Summary
<tree of reachable files, both sides, with add/remove annotations>
```

### Inline summary

The conversation receives a ≤10-line summary following capy routing rules. The summary MUST contain exactly one line matching the regex `^Verdict: (no-degradation|degraded|unclear)\b` — this is the machine-parseable contract (CI integration depends on it). Position of the line within the summary is not specified; parsers use the regex.

```
diff-skill: review-code (HEAD~5 → WORKTREE)
Verdict: degraded (2 findings)

Degradations:
  1. Dropped `MUST re-read changed files` rule in review-process.md
  2. Security-checklist reference removed from SKILL.md

Full report: docs/reviews/diff-skill/review-code-a1b2c3d-WORKTREE.md
```

### Capy indexing

On completion, index the verdict + finding summaries under `kk:diff-skill-findings`. Skip if verdict is `no-degradation` — nothing durable to record. Follows `review-code`'s `kk:review-findings` pattern.

## Extension points

v1 is deliberately small. The following extension points are designed in so later features plug in without restructuring:

### 1. Behavioral evals seam

The judgment pipeline has two named phases (Pass 1, Pass 2). A future `--with-evals` flag inserts a Pass 1.5:

- Run eval fixtures against both versions of the skill
- Parse agent traces / outputs
- Fold behavioral findings into the candidate list fed to Pass 2

*If v2 goes this route:* if `skill-creator`'s eval infrastructure is present and produces parseable output, `diff-skill` invokes it. Otherwise, `--with-evals` errors with a pointer. `skill-creator` is Anthropic-maintained (not owned by this repo) — its output contract isn't guaranteed stable, so this seam is speculative.

### 2. Isolated mode seam

`SKILL.md` references `diff-process.md` for standard-mode workflow. When isolated mode is added:

- New file `diff-isolated.md` alongside `diff-process.md`
- `SKILL.md` gains a mode-selection section (mirrors `review-code`'s pattern)
- Commands directory grows from empty to `commands/diff-skill/{default,isolated}.md` per the symmetric-naming convention

### 3. Output format seam

Report generation is a discrete phase with a templated structure. Additional formats (JSON, GitHub comment body, plain-text CI output) attach as formatters without touching the judgment pipeline.

### 4. Scope-override seam

The traversal algorithm takes a root file as input. Default is `SKILL.md`, but any file works. Future flags:

- `--root <path>` — diff starting from any file (e.g., a single process file or agent)
- `--include-external-refs` — include commands/agents that reference the skill but aren't reachable from `SKILL.md`

### 5. Helper-script seam

v1 runs the traversal inside the LLM (via `Bash` for `git show` + `Read` for content). If this proves slow or error-prone in practice, the traversal can be extracted into `klaude-plugin/scripts/diff-skill-walk.sh` that emits a JSON manifest consumed by Pass 1. The skill instructions stay the same; only the data-gathering mechanism changes.

### 6. CI integration seam

The skill produces a deterministic file artifact (the report) and a single machine-parseable line in the inline summary matching `^Verdict: (no-degradation|degraded|unclear)\b`. A future GitHub Action / pre-commit hook greps for this line to gate merges without needing changes to the skill itself.

## Non-negotiables

Whatever v2+ adds, these stay:

- Asymmetric framing (degradation, not symmetric difference)
- File-backed report + inline summary (per capy routing rules)
- Transitive link-tree traversal as the scope definition
- Pass 1 (mechanical extraction) → Pass 2 (LLM judgment) separation

## Explicitly out of scope for v1

- Behavioral evals
- Isolated mode
- Auto-fix / auto-apply of findings
- Cross-skill diffing
- CI integration
- Reports for multiple skills in one invocation

### Accepted v1 limitations

These are deliberate trade-offs, not oversights. An implementer should not "fix" them without revisiting the design.

- **Prose mentions of agents, tools, and commands are not traversed.** Only markdown relative links and YAML frontmatter file fields count as edges in the reachable-file graph. A skill that names `` `code-reviewer` `` in prose without a markdown link to `klaude-plugin/agents/code-reviewer.md` will not have that agent file included in the diff scope, even when the agent's instructions materially affect the skill's behavior. Trade-off: simple, predictable traversal vs. coverage of textual cross-references. Users who want agent coverage can add a markdown link from `SKILL.md` to the agent file.
- **Rename auto-detection is not performed.** Users must use the `old@ref..new@ref` syntax when a skill was renamed between refs; git's native rename-tracking is not consulted.
- **Pass 2 is stochastic.** Identical inputs may produce slightly different reclassifications across runs. The report is advisory, not gating.
