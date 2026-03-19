### Workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Explore the feature
- [ ] Step 2: Merge design docs
- [ ] Step 3: Merge implementation docs
- [ ] Step 4: Generate task list
- [ ] Step 5: Final review
```

**Inputs:** Two feature directories under `/docs/wip/` (e.g., `auth-system-v1/` and `auth-system-v2/`).

**Output:** A new directory `/docs/wip/[feature-title]-merged/` containing the unified `design.md`, `implementation.md`, and `tasks.md`.

---

**Step 1: Explore the feature**

Before you can judge which doc is more correct, you need to understand what we're actually building.

- Read both feature directories fully — design, implementation, and tasks from each
- Explore the codebase: relevant source files, existing architecture, patterns in use
- Check contributing guidelines, relevant documentation, and any prior art
- Build a mental model of the feature's purpose, constraints, and integration points

You cannot make good merge decisions without this grounding. Don't skip it. Make sure you have a very thorough understanding of both the existing state and the new feature.

**Step 2: Merge design docs**

Read both design docs and categorize every section/decision into one of four buckets:

| Category | What it means | Action |
|---|---|---|
| **Agreement** | Both docs say the same thing | Keep as-is — use whichever framing is clearer |
| **Gap** | One doc covers something the other doesn't | Verify against codebase reality (re-read the codebase if needed). If correct, merge in. If wrong, drop with explanation |
| **Contradiction** | Both docs cover the same topic but disagree | Surface to user for resolution — one question at a time |
| **Error** | A doc claims something that conflicts with codebase reality | Verify against codebase reality (re-read the codebase if needed). Assign confidence percentage. Flag to user, recommend keeping/dropping, explain why |

**How to surface decisions to the user:**

- Resolve agreements and straightforward gaps silently
- For each contradiction or judgment call, present it as a single question with:
  - What Doc A says
  - What Doc B says
  - Your recommendation (grounded in what you learned in Step 1) and why
  - Ask the user to pick or provide an alternative
- One question per message. Wait for a response before moving on.

After all decisions are made, write the merged `design.md` to `/docs/wip/[feature-title]-merged/`.

**Step 3: Merge implementation docs**

This step is informed by two things:
1. Your understanding of the codebase (from Step 1)
2. The decisions already made in the merged design (from Step 2)

Do NOT treat this as a blind semantic comparison of the two original implementation docs. If the merged design changed direction on something, the implementation merge must reflect that — even if both original implementation docs agreed on the old direction.

Apply the same four-bucket categorization (agreement, gap, contradiction, error), but also check each section against the merged design:

- Does this implementation section still align with the merged design? If not, flag it.
- Did the design merge introduce new decisions that need implementation coverage? If so, add them.
- Did the design merge drop something? Remove the corresponding implementation sections.

Surface contradictions and judgment calls to the user the same way as in Step 2.

Write the merged `implementation.md` to `/docs/wip/[feature-title]-merged/`.

**Step 4: Generate task list**

The task list is a **derived artifact** — generate it from the merged implementation plan, don't merge the two original task lists directly.

1. Read the merged `implementation.md` and break it into tasks following the same structure and conventions as the [analysis-process example tasks](../analysis-process/example-tasks.md)
2. For each new task, check if a corresponding task exists in either original `tasks.md`:
   - If a matching task exists and is `done` or `in-progress`, carry forward its status and subtask completion — but update the subtask descriptions if the merged implementation changed the details
   - If a matching task exists but the implementation changed significantly, reset to `pending` with updated subtasks
   - If no matching task exists (new section from the merge), create a fresh `pending` task
3. Preserve dependency ordering based on the merged implementation plan
4. Include a final verification task (same pattern as analysis-process)

Write `tasks.md` to `/docs/wip/[feature-title]-merged/`.

**Step 5: Final review**

Present the user with a summary of the merged output:

- List of key decisions made (both silent resolutions and user-guided ones)
- Sections where the merge significantly diverged from either original
- Any open concerns or areas that may need further refinement
- Links to the three output files

Ask the user to review and confirm, or flag anything that needs adjustment.
