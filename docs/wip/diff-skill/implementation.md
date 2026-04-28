# Implementation: diff-skill

> Design: [./design.md](./design.md)
> Tasks: [./tasks.md](./tasks.md)

## Reader orientation

This skill is pure markdown. There is no compiled code, no new language runtime, no library dependency. The "implementation" is a set of instructions that an LLM follows at invocation time, using `Bash` (for `git show`, `git rev-parse`) and `Read` to gather content. Tasks below are therefore **authoring tasks** (writing/editing markdown files) plus small amounts of shell for tests.

Familiarity needed:

- How the repo lays out skills — see `CLAUDE.md` § "Skill & Command Naming Conventions".
- How existing skills structure `SKILL.md` + a process file + `_shared` symlinks — read `klaude-plugin/skills/merge-docs/` and `klaude-plugin/skills/review-code/` for the two closest shapes.
- The `docs/wip/` ↔ `docs/done/` lifecycle for feature docs.

Treat the design document as the source of truth. If a task description disagrees with the design, the design wins and the task needs updating.

## Files to be created

```
klaude-plugin/skills/diff-skill/
├── SKILL.md                                       (new)
├── diff-process.md                                (new)
└── shared-capy-knowledge-protocol.md              (symlink → ../_shared/capy-knowledge-protocol.md)

docs/reviews/diff-skill/                           (directory created on first skill run, not at implementation time)

test/test-plugin-structure.sh                      (update EXPECTED_SKILLS array)
klaude-plugin/README.md                            (update skill table + workflow description)
```

No new commands directory for v1 (single mode; the skill is invoked directly as `/kk:diff-skill …`).

## Task 1 — Skill directory scaffold

**What:** Create the directory and the `_shared` symlink.

**Steps:**

1. `mkdir -p klaude-plugin/skills/diff-skill`
2. `cd klaude-plugin/skills/diff-skill && ln -s ../_shared/capy-knowledge-protocol.md shared-capy-knowledge-protocol.md`

   Rationale: `diff-skill` indexes findings into capy; it consumes the same protocol as other indexing skills. The symlink pattern is the project's convention for shared instructions (see `CLAUDE.md` § "Shared instructions").

**Verify:**

- `ls -la klaude-plugin/skills/diff-skill/` shows the symlink with correct target.
- `readlink klaude-plugin/skills/diff-skill/shared-capy-knowledge-protocol.md` prints `../_shared/capy-knowledge-protocol.md`.
- `cat klaude-plugin/skills/diff-skill/shared-capy-knowledge-protocol.md` prints the actual `_shared` file content (confirms symlink resolves).

## Task 2 — Author `SKILL.md`

**What:** Write the entry-point file with YAML frontmatter, overview, invocation, and pointer to `diff-process.md`.

**Required frontmatter fields:** `name`, `description`. Model after `merge-docs/SKILL.md`.

**Required sections:**

- Overview (goal + asymmetric framing — two-three paragraphs, lift from design.md § Goal)
- Conventions (references `shared-capy-knowledge-protocol.md` exactly as `review-code/SKILL.md` does)
- Required Outputs checklist (report written to file, inline summary presented, capy indexing done unless `no-degradation`)
- Invocation table (copy from design.md § Invocation)
- Rename handling (brief — one paragraph pointing at the `@ref..` syntax)
- Workflow phases (short list; the details live in `diff-process.md`)
- Pointer to `diff-process.md`

**Reference shared file in prose as:** `` [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md) `` (see `CLAUDE.md` § "Reference bare in prose").

**Verify:**

- `head -5 klaude-plugin/skills/diff-skill/SKILL.md` shows `---`, `name: diff-skill`, `description: |`, multi-line description, `---`.
- All internal links resolve — for each `[text](./foo.md)` or `[text](foo.md)`, the target file exists in the skill dir.
- `grep -E 'MUST|NEVER|ALWAYS' klaude-plugin/skills/diff-skill/SKILL.md` returns the normative rules mentioned in design (asymmetric framing, file-backed report, capy indexing rule).

## Task 3 — Author `diff-process.md`

**What:** The detailed workflow document. This is the load-bearing instruction set — the LLM follows this step-by-step when the skill is invoked.

**Structure:** Follow the pattern in `klaude-plugin/skills/review-code/review-process.md` — numbered phases, each phase having concrete steps.

**Phases (map 1:1 to design.md):**

1. **Parse invocation** — extract `<skill-name>`, `<ref-a>`, `<ref-b>`, handle `@ref..` rename syntax, apply defaults (working-tree + HEAD).
2. **Validate** — `git rev-parse` each ref, confirm `klaude-plugin/skills/<name>/SKILL.md` exists at the ref via `git cat-file -e <ref>:<path>` (existence-only, avoids reading content). Error messages per design.md § Validation.
3. **Traverse** — build the reachable-file set for each side. For each file, follow the symlink-aware read protocol from design.md § "Symlink handling at historical refs": (a) `git ls-tree --full-tree <ref> <path>` to check mode; (b) if mode `120000`, resolve target via `git cat-file -p` and recurse; (c) otherwise `git show <ref>:<path>` for content. Working-tree reads use filesystem `readlink` + normal file reads. Extract links using a described regex, resolve relative/absolute paths, respect safety rails (50 files, depth 20).
4. **Pass 1 — structural extraction** — enumerate normative rules, headings, required outputs, verification steps, tool/agent/command references, file references per design.md. Produce a candidate findings list with categories: `lost-rule`, `weakened-constraint`, `dropped-section`, `dropped-verification`, `dropped-output`, `broken-reference`, `addition`, `prose-only-neutral`, `file-only-on-one-side`.
5. **Pass 2 — LLM judgment** — reclassify candidates using the asymmetric framing; attach confidence; record reclassification rationales.
6. **Write report** — create `docs/reviews/diff-skill/` if absent, compute filename per design convention, write the report with the exact structure from design.md § Report.
7. **Present inline summary** — first line is `Verdict: <value>`, then ≤10 lines summarizing findings + report path.
8. **Index to capy** — only if verdict != `no-degradation`. Use source label `kk:skill-diff-findings`.

**Tools referenced in the process doc:**

- `Bash` — `git rev-parse`, `git cat-file -e` (existence), `git ls-tree --full-tree` (mode check), `git cat-file -p` (symlink target read), `git show` (regular-file content), `mkdir`, `readlink`.
- `Read` — for working-tree file reads.
- `Write` — the report.
- The MCP capy index tool — indexing findings.

**Do NOT write full code samples for link extraction or path resolution.** Describe the algorithm in prose with enough precision that an experienced implementer couldn't go wrong (regex for markdown links, frontmatter link fields, symlink deref via `readlink` or `git cat-file -p`).

**Verify:**

- All eight phases present with clear step-by-step content.
- Error messages match design.md § Validation word-for-word (user-facing strings are part of the spec).
- Every instruction the LLM would take action on is prescriptive (`Do X`, `MUST X`, `Never X`) rather than descriptive.
- Links to `design.md` use repo-root-absolute paths (`/docs/wip/diff-skill/design.md`) so they work when the skill is copied out into a plugin cache.

## Task 4 — Wire the skill into the plugin manifest and tests

**What:** Register `diff-skill` so the plugin structure tests pass and the README reflects reality.

**Steps:**

1. Edit `test/test-plugin-structure.sh`:
   - Add `diff-skill` to the `EXPECTED_SKILLS` array (line ~68).
   - Update the `log_test "All 10 skill directories exist"` message from `10` to `11` (line ~81).
2. Edit `klaude-plugin/README.md`:
   - Add a row for `diff-skill` to the Skills table (line ~19).
   - One-sentence description matching the tone of surrounding rows: what it does + its single most important constraint.
   - Do NOT add a row to the Commands table — v1 has no sub-mode commands.
   - Mention `diff-skill` briefly in the "Utilities" paragraph (line ~49) alongside `merge-docs` and `chain-of-verification`.

**Verify:**

- `bash test/test-plugin-structure.sh` passes all assertions (in particular Section 3: Skills).
- The Skills table in `klaude-plugin/README.md` contains exactly 11 rows: one per skill in `EXPECTED_SKILLS`. Verify by either (a) listing each skill name with `grep -c "| \*\*<name>\*\*" klaude-plugin/README.md` returning 1, or (b) using `awk` to extract only the Skills section between its heading and the next `## ` heading, then counting `| **` rows there — do NOT use a raw repo-wide `grep -c '^| \*\*'` as future tables may use the same pattern.

## Task 5 — Smoke test the skill end-to-end

**What:** Run the skill against a known-degraded example to confirm the pipeline works. This is an exercise in running the skill, not an automated test.

**Steps:**

1. Create a local branch off `master`.
2. Pick an existing skill (e.g., `merge-docs`) and intentionally degrade it in a commit on the branch: weaken a `MUST` to a `SHOULD`, drop one required-output bullet, remove one link.
3. From a fresh Claude Code session in the repo, invoke `/kk:diff-skill merge-docs master HEAD`.
4. Observe: inline summary printed, report file created at the expected path, verdict = `degraded`, all three deliberate regressions flagged.
5. Invoke again on the same skill without any degradation (`/kk:diff-skill merge-docs master master`) — verdict = `no-degradation`, no capy indexing.
6. Roll back the test branch — this is ephemeral validation, not something to merge.

**Verify:**

- Each deliberate degradation appears as a distinct finding with correct `Kind` classification.
- Report path exactly matches `docs/reviews/diff-skill/merge-docs-<short-sha-a>-<short-sha-b>.md`.
- Inline summary's first line is `Verdict: degraded`.
- The `no-degradation` run produces a report with empty Degradations section and skips capy indexing.

## Task 6 — Final verification

**What:** Run the standard end-of-feature verification gates. Depends on all prior tasks.

**Steps:**

1. Run `test` skill — executes the full test suite (`bash test/test-plugin-structure.sh` and any sibling tests).
2. Run `document` skill — update any docs that now need to reference `diff-skill` (main repo README if applicable, any workflow docs that list available skills).
3. Run `review-code` skill (language: markdown/shell) — review the new skill's markdown for clarity, normativity, and absence of prose rot.
4. Run `review-spec` skill — verify `SKILL.md` + `diff-process.md` actually match `design.md` and `implementation.md`; flag any drift.

**Verify:**

- `test` → all plugin-structure assertions pass; no regressions in sibling test files.
- `document` → README reflects the skill; no stale references to the 10-skill count anywhere.
- `review-code` → no P0/P1 findings on the new skill files.
- `review-spec` → no divergence between docs and implementation.

## Risks and open concerns

- **Link extraction accuracy.** The traversal depends on extracting markdown links with a regex. Edge cases (links inside code fences, links split across lines, HTML `<a href>` tags) may need explicit handling in `diff-process.md`. Task 3 should name these cases.
- **LLM judgment drift between runs.** Pass 2 is stochastic. Identical inputs may produce slightly different reclassifications. Acceptable for v1 (report is advisory, not gating). Revisit if the skill gets used in CI — at that point either the LLM call needs deterministic sampling or evals need to happen behind `--with-evals`.
- **Rename detection blind spot.** v1 requires the user to explicitly specify `old@ref..new@ref` for renames. Auto-detection via git's rename-tracking is out of scope but would be a useful v2 feature.
