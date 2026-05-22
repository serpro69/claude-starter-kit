### Workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Phase 1: Parse invocation
- [ ] Phase 2: Validate
- [ ] Phase 3: Build reachable file sets
- [ ] Phase 4: Judgment
- [ ] Phase 5: Write report
- [ ] Phase 6: Present inline summary
- [ ] Phase 7: Index to capy
```

**Input:** A skill name or skill directory path, optionally with comparison refs.

**Output:** A report file at `docs/reviews/diff-skill/<slug>-<sha-a>-<sha-b>.md` and an inline summary.

---

**Phase 1: Parse invocation**

Extract `<skill-name>` from the user's prompt.

Locate SKILL.md:
- Try `klaude-plugin/skills/<skill-name>/SKILL.md` as a convenience shortcut
- If not found, ask the user for the path to the skill directory
- Normalize any user-provided path to repo-relative: strip the leading absolute prefix up to the repo root. Reject paths outside the repo — `git show` and `git cat-file` require repo-relative paths

Determine the **report slug**: read SKILL.md's YAML frontmatter `name` field if present, otherwise use the parent directory basename of the SKILL.md path.

Determine **comparison refs**: default is `HEAD` (before) → working tree (after). "Before" is the baseline; "after" is what's being judged. If the user specifies different refs, use those.

**Verify:** SKILL.md path is resolved and both refs are determined.

---

**Phase 2: Validate**

For each git ref (not the working tree):
- Run `git rev-parse <ref>` to confirm the ref resolves

Confirm SKILL.md exists at both sides:
- For git refs: `git cat-file -e <ref>:<repo-relative-path>`
- For the working tree: check the file exists on disk

If either side is missing, stop with a clear error message naming which ref and path failed.

**Verify:** Both refs resolve and SKILL.md exists at both.

---

**Phase 3: Build reachable file sets**

For each ref, build the set of all files transitively reachable via markdown links from SKILL.md.

**Algorithm:**

1. Initialize `frontier = [SKILL.md path]`, `visited = {}`, `missing_links = []`
2. Pop a file from frontier, add to visited
3. Retrieve content:
   - For git refs: check `git ls-tree <ref> <path>` first
     - Mode `120000` (symlink): read the target path with `git cat-file -p <ref>:<path>`, resolve it relative to the symlink's directory, then retrieve the resolved target at the same ref (recurse if the target is also a symlink)
     - Otherwise: `git show <ref>:<path>` returns content directly
   - For working tree: use the `Read` tool (follows symlinks transparently)
4. Extract markdown links from the content:
   - Match `[text](relative/path.md)` and `[text](relative/path.md#anchor)` patterns
   - Strip fragment identifiers (`#anchor`) before resolution — `[text](file.md#section)` resolves to `file.md`
   - Skip external URLs (`http://`, `https://`)
   - Skip anchor-only refs (`#section`)
   - Skip links inside fenced code blocks (triple-backtick or triple-tilde, with or without info strings) — use best-effort fence detection; don't build an elaborate parser
5. Resolve each extracted path relative to the containing file's directory
6. For each resolved path:
   - If it exists at the ref and is not in visited → add to frontier
   - If it does NOT exist at the ref → add to `missing_links` as `{source_file, raw_href, resolved_path}`
7. Repeat until frontier is empty

After building both sets, estimate total combined content size (both sides together). If it exceeds ~100KB, warn the user with the size and file count, and offer to proceed or narrow scope (e.g., compare only changed files). This fails loud about context-window risk without refusing to run.

**Verify:** Two file sets produced, one per ref. Each set maps `{path → content}`. A `missing_links` list per ref tracks `{source_file, raw_href, resolved_path}` for broken references.

---

**Phase 4: Judgment**

Present yourself with the full content from both sides and judge across three axes. The judgment is **asymmetric** — additions, clarifications, and strengthenings are NOT degradations.

**Input to judgment:**
1. Full content of all reachable files at ref-a ("before" state)
2. Full content of all reachable files at ref-b ("after" state)
3. Files present on only one side
4. Missing links per ref (broken references are a core degradation signal)

**Degradation axis** (affects verdict):

Only these count as degradations:
- Load-bearing instruction dropped
- Constraint weakened (`MUST` → `SHOULD`, `NEVER` → `AVOID`)
- Verification step removed
- Scope narrowed (fewer cases covered)
- Required output dropped
- Reference broken — a link whose target does not exist in the after-state. This covers two cases: a previously-resolving link whose target was removed, and a newly-added link whose target never existed. Missing links present in both states are pre-existing advisories, not degradations

Content that was **relocated** (moved between files, inlined elsewhere, extracted to a new file) is neutral — check whether the substance survived. If yes, neutral. If substance was lost in the move, degradation.

**Complexity regression axis** (affects verdict):

Compare both states. Flag complexity that was *introduced or worsened* by the edit:
- Instruction density — too many rules crammed into one section
- Cross-turn state burden — gates and sub-phase state the LLM must track across multiple messages
- Inline multi-path logic — branching workflows that could be extracted into dedicated files
- Contradictory or tension-creating instructions — rules pulling in opposite directions without clear precedence
- Deep reference chains — files linking to files linking to files, inflating the working set
- Ambiguous conditional logic — gates without clear evaluation criteria

**Pre-existing complexity advisory** (does NOT affect verdict):

Separately, flag structural issues in the after-state that exist regardless of whether the edit caused them. These are improvement opportunities — surfaced for the author's benefit but kept in a distinct report section.

For each finding: state what was found, where (file and section), and why it matters. Classify each as degradation, complexity regression, or pre-existing advisory.

**Verdict** (combining both axes):
- **No issues** — no degradation, no complexity regressions
- **Degraded** — content was lost or weakened
- **Complexity regressed** — no content lost, but the edit made the skill harder to follow
- **Both** — degradation and complexity regression

Pre-existing complexity advisories appear in the report regardless of the verdict but do not influence it.

**Verify:** Each finding has a clear what/where/why description and is classified. A verdict is determined.

---

**Phase 5: Write report**

Create the report directory if absent:
```bash
mkdir -p docs/reviews/diff-skill
```

Compute the filename: `<report-slug>-<short-sha-a>-<short-sha-b>.md`
- Short SHA = 7 characters from `git rev-parse --short=7 <ref>`
- Working-tree side → `WORKTREE`

Write the report using the `Write` tool, following this structure:

```markdown
# diff-skill: <name> (<ref-a> → <ref-b>)

## Summary
<one-paragraph verdict combining both axes>

## Degradations
<each finding: what was lost/weakened, where, and why it matters>

## Complexity Regressions
<each finding: what became harder to follow due to this edit, and how it could be simplified>

## Pre-existing Complexity
<improvement opportunities that exist in the after-state regardless of this edit>

## Neutral Changes
<brief list of changes that are neither degradations nor complexity issues>
```

Omit sections that have no findings (except Summary, which is always present).

**Verify:** Report file exists at the expected path and follows the template structure.

---

**Phase 6: Present inline summary**

Print a short block in the conversation — under 10 lines. Include:
- The verdict
- Finding counts per axis (e.g., "2 degradations, 1 complexity regression, 3 pre-existing advisories")
- The path to the full report file

**Verify:** Summary is under 10 lines and contains the report file path.

---

**Phase 7: Index to capy**

If any degradation or complexity regression findings exist, index a concise summary under source label `kk:review-findings`. Follow the protocol in [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

Skip indexing on clean results — nothing durable to record.

**Verify:** Capy index call made if findings exist, skipped if clean.
