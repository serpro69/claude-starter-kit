# Agent Skills profile

## What this profile covers

Authoring agent skills: the markdown-based extension format used by Claude Code, Codex, and other AI coding assistants. Covers skill structure (progressive disclosure, workflow ordering), description effectiveness, resource organization, evaluation design, and provider-specific integration (hooks, commands, plugin-root substitution).

Agent skills are a [provider-agnostic concept](https://agentskills.io/home); each provider adds its own conventions on top. This profile encodes universal skill-authoring knowledge in always-load content and provider-specific knowledge in conditional content.

## When it activates

Any file named `SKILL.md`, or any file whose nearest ancestor directory contains a `SKILL.md`. See [DETECTION.md](DETECTION.md) for the authoritative rule including the ancestor-walk algorithm and edge cases.

Activation is additive with other profiles on the same diff — a Go skill activates both `go` and `skill-md`.

## Populated phases

- `implement/` — pre-write gotchas for scaffolding skills correctly (workflow ordering, progressive disclosure, description quality, resource separation, provider-specific pitfalls).
- `review-code/` — quality checklists for skill files (universal checks, Claude Code checks, kk-plugin checks).

Deferred phases: `design/`, `test/`, `document/`, `review-spec/`.

## Looking up skill-authoring dependencies

When authoring skills that integrate with a provider's SDK or plugin system, follow the `/kk:dependency-handling` skill's cascade:

1. **capy-first** — query indexed `kk:project-conventions` and `kk:arch-decisions` for prior skill-authoring patterns and decisions.
2. **context7** — fetch current provider documentation. For Claude Code skills, resolve `claude-code` or `anthropic` as the context7 library. For Codex, resolve `openai-codex`.
3. **web** — fall back to [agentskills.io](https://agentskills.io/home) and provider-specific skill documentation only if the first two yield nothing.

Project-specific skill conventions live in `CLAUDE.md` (§Skill & Command Naming Conventions, §Skill description budget, §Skill workflow ordering, §Skill evaluations, §Profile Conventions). Always check the current CLAUDE.md — it is the source of truth for this repository's conventions.
