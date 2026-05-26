# Try It

After setup, try the core workflow:

1. **Start with an idea.** Type `/kk:design` and describe a feature you want to build. Claude will ask you refinement questions one at a time, then produce design docs and a task list in `docs/wip/`.

2. **Review the design.** Run `/kk:review-design your-feature` to catch gaps before writing code.

3. **Build it.** Type `/kk:implement` — Claude executes the task list with code review checkpoints between batches.

4. **Review the code.** `/kk:review-code` checks for SOLID violations, security risks, and quality issues. Use `/kk:review-code:isolated` for independent sub-agent reviewers with zero authorship bias.

This is the core loop. See the [kk plugin README](https://github.com/serpro69/claude-toolbox/tree/master/klaude-plugin) for all available skills and the full workflow pipeline.

## What Just Happened?

Each skill produced artifacts the next one consumed:

| Skill | Input | Output |
|-------|-------|--------|
| `/kk:design` | Your idea | `design.md`, `tasks.md` |
| `/kk:review-design` | Design docs | Review findings, gap analysis |
| `/kk:implement` | Task list | Code changes, review checkpoints |
| `/kk:review-code` | Git diff | Findings, fix suggestions |
| `/kk:test` | Code changes | Test files, coverage report |
| `/kk:document` | All of the above | Updated `architecture.md`, ADRs |

## Next Steps

- [Skills](../user-guide/skills.md) — learn what each skill does in detail
- [Profiles](../user-guide/profiles.md) — understand language-specific behavior
- [Configuration](../user-guide/configuration.md) — customize for your workflow
