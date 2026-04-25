### Workflow: Continue WIP Feature

1. **Find the feature** — Locate the feature directory in `/docs/wip/`. If multiple WIP features exist, ask the user which one to work on.

2. **Review progress** — Read `tasks.md` to understand:
   - Which tasks are done, in-progress, or pending
   - What dependencies exist between remaining tasks
   - Any notes logged on previous subtasks

3. **Review context** — Read the linked `design.md` and `implementation.md` to understand the full picture. Also check any relevant contributing guidelines and documentation. **Capy search:** Search `kk:arch-decisions` and `kk:project-conventions` for context relevant to the feature being resumed.

4. **Detect active profiles** — Apply [shared-profile-detection.md](shared-profile-detection.md). Unlike the fresh-idea flow, the feature directory's files ARE available: feed the full feature-directory file list (and any in-tree artifacts the feature has produced so far) to the shared procedure's file-based input model. If the file list yields no profile — common when the design is for future work that has not emitted profile-bearing artifacts yet — fall back to the [design interaction pattern](shared-profile-detection.md#the-design-interaction-pattern) against the `design.md` prose; it iterates all profiles with `## Design signals` and handles token matching + confirmation. For each active profile, use the `Read` tool on `<plugin_root>/profiles/<name>/design/index.md` — where `<plugin_root>` is the absolute plugin-root path you already know from SKILL.md context; skip silently if absent. Load every always-load entry; the profile's `questions.md` guides any further refinement and its `sections.md` lists required sections the design document must cover. A design authored before the profile rubric existed should be audited against `sections.md` on resumption.

5. **Assess readiness:**
   - **If tasks are well-documented and clear** → proceed to implement using the `implement` skill.
   - **If tasks need refinement** (missing details, unclear subtasks, gaps in the plan) → update `tasks.md` and/or the design/implementation docs before proceeding. Follow the documentation guidelines from the [Ideas and Prototypes](#ideas-and-prototypes) section.
