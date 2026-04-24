# Plan Mode

Applies when the user references a docs/wip feature or task number.

## Entry Procedure

1. Read the feature's `tasks.md` file to get the task list and current progress
2. Read the linked `design.md` and `implementation.md` for full context
3. Identify the next pending task (one whose dependencies are all done)
4. **Capy search:** Search `kk:arch-decisions`, `kk:project-conventions`, `kk:lang-idioms`, and `kk:review-findings` for context relevant to the identified task
5. Review critically — identify any questions or concerns about the plan
6. If concerns: Raise them with your human partner before starting

After completing the entry procedure, return to SKILL.md Step 2 (Execute).

## Iteration

After each execution + review cycle (SKILL.md Steps 2–3):

- Verify the completed task's **Required Outputs** are all checked
- Move to the next pending task in `tasks.md`
- Return to the Entry Procedure above to load context for the new task
- Repeat until all tasks are completed

## Completion

After all tasks are complete and verified:

- Use `test` skill to verify and validate functionality
- Use `document` skill to create or update any relevant docs
- **Reflect:** briefly note where the implementation diverged from the plan, what turned out harder or simpler than expected, and any surprises that future work in this area should know about. Keep it short — a paragraph, not an essay. Index non-obvious learnings as `kk:project-conventions` or `kk:arch-decisions` if they weren't already captured during per-task cycles.
- Update the feature status in `tasks.md` header to `done`
