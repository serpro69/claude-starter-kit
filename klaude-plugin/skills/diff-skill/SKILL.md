---
name: diff-skill
description: |
  Compare two versions of a skill's instructions to detect degradations and complexity increases.
  TRIGGER when: user asks to diff, compare, or review changes to a skill's markdown instructions.
  Asymmetric check — only regressions count. Additions, clarifications, and strengthenings are not degradations.
  Compares HEAD → working tree by default. Walks the full reachable file set from SKILL.md via markdown links.
  Produces a report file under docs/reviews/diff-skill/ and an inline summary.
---

# Diff Skill Instructions

**Goal: Detect whether an edit to a skill's markdown instructions introduced degradations or made the skill harder for an LLM to follow.**

Two judgment axes:

1. **Degradation (asymmetric)** — load-bearing instruction dropped, constraint weakened, verification step removed, scope narrowed, required output dropped, or reference broken. Content relocated but preserved is neutral.
2. **Complexity** — split into *regressions* (introduced or worsened by the edit, affects verdict) and *pre-existing advisories* (exist regardless of the edit, surfaced as improvement opportunities, does NOT affect verdict).

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

## Required Outputs

- [ ] Report written to `docs/reviews/diff-skill/<slug>-<sha-a>-<sha-b>.md`
- [ ] Inline summary presented (under 10 lines: verdict, finding counts, report path)
- [ ] Capy indexed under `kk:review-findings` if any findings exist (skip on clean results)

## Invocation

```
/kk:diff-skill <skill-name>
```

Convenience shortcut: resolves `klaude-plugin/skills/<skill-name>/SKILL.md`. If not found, asks the user for the skill directory path.

Defaults: `HEAD` (before) → working tree (after). User can specify different refs in the prompt.

## Workflow

**Mandatory order — load instructions before acting on subject matter.** The phases below are strictly sequential. Do not read skill content, build file sets, or produce judgments until you have loaded and internalized the full process file. The only early contact with the target skill is its name and SKILL.md path — enough to validate, not enough to judge.

See [diff-process.md](diff-process.md) for the detailed step-by-step process.
