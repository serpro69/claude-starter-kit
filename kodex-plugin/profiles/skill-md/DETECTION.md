# Agent Skills — detection

Declares when the `skill-md` profile activates on a given set of files. Consumed by `klaude-plugin/skills/_shared/profile-detection.md`. Detection is additive: multiple profiles may activate on the same diff (e.g., `go` + `skill-md` when editing a Go skill).

## Path signals

_None._ Skill detection uses filename signals exclusively; path heuristics would over-trigger on any directory named `skills/`.

## Filename signals

Authoritative: any match activates the profile. Filename matches short-circuit content inspection for the matched file.

- `SKILL.md` (exact) — the canonical skill entry point. Any file literally named `SKILL.md` activates the profile.
- **Skill-root adjacency rule:** any file whose nearest ancestor directory contains a `SKILL.md`. Walk upward from the file's parent directory toward the repo root; stop at the first directory containing a `SKILL.md`. If found, the file is part of that skill and the profile activates. This covers:
  - Direct siblings (e.g., `skills/review-code/plan-mode.md` where `skills/review-code/SKILL.md` exists)
  - Resource subdirectories (e.g., `skills/my-skill/references/guide.md`, `skills/my-skill/scripts/helper.py`)
  - Eval fixtures (e.g., `skills/my-skill/evals/test-1/eval.json`)

The binding constraint is nearest-ancestor `SKILL.md`, following the same ancestor-walk pattern as the Helm template rule in the k8s profile (files under `templates/` activate when the parent contains `Chart.yaml`).

**Scoping:** the walk stops at the *first* directory containing `SKILL.md`. A `SKILL.md` at the repo root does NOT claim every file in the repository — files in subdirectories that have their own `SKILL.md` are scoped to that nearer ancestor. Files outside any `SKILL.md`-containing ancestor do not activate.

**Edge cases and non-triggers:**
- Test-fixture `SKILL.md` files inside `evals/test-files/` are legitimate detection targets — they *are* skill files. The ancestor walk scopes them correctly.
- Generic markdown outside a skill root (`docs/design.md`, `README.md`, `CONTRIBUTING.md`) does NOT activate, regardless of content or frontmatter.
- Agent definitions (`agents/*.md`) with skill-like `name:` / `description:` frontmatter do NOT activate unless they sit under a `SKILL.md`-rooted ancestor.

## Content signals

_None._ Skill detection is entirely file-location-based. Content inspection cannot reliably distinguish skill instructions from other markdown.

## Design signals

display_name: Agent Skills
tokens:
  - skill
  - SKILL.md
  - agent skill
  - slash command
  - skill description
  - skill trigger
