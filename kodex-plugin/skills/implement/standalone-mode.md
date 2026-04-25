# Standalone Mode

Applies for bug fixes, GitHub issues, one-off tasks, and any work without docs/wip infrastructure.

## Entry Procedure

1. Parse the user's request — what is the problem or requirement?
2. If the user references a GitHub issue, fetch it (`gh issue view`)
3. **Capy search:** Search `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, `kk:review-findings`, and `kk:debug-context` for relevant prior context
4. Identify questions or ambiguities — ask before assuming
5. Investigate the relevant code — read files, trace call paths, reproduce the bug if applicable
6. Identify the set of files that will need changes
7. State the approach briefly if the fix is non-trivial (more than a few lines across 1–2 files). For trivial fixes, proceed directly.

After completing the entry procedure, return to SKILL.md Step 2 (Execute).
