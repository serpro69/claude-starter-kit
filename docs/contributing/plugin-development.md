# Plugin Development

The kk plugin lives at `klaude-plugin/`. This section covers the practical rules for authoring each component. For the full specification, see [`CLAUDE.md`](https://github.com/serpro69/claude-toolbox/blob/master/CLAUDE.md).

## Skills

Each skill is a directory under `klaude-plugin/skills/<name>/` containing at minimum a `SKILL.md` entry point.

### SKILL.md structure

```yaml
---
name: skill-name
description: |
  Trigger-first description. Front-load the key use case.
---

# Skill Title

## Conventions
## Workflow
```

### Naming rules

- Imperative verbs over noun phrases: `/kk:design` not `/kk:analysis-process`.
- Family prefixes for grouped skills: `/kk:review-code`, `/kk:review-design`, `/kk:review-spec`.
- Always use `/kk:` prefix when referencing skills: write `/kk:review-code` not `review-code`. The codex generation tool rewrites `/kk:` → `$kk:` for Codex output.

### Description budget

Claude Code truncates skill descriptions at **1,536 characters** per entry. OpenCode's limit is **1,024**. Lead with trigger keywords — truncation happens at the tail. Detailed rules, cascades, and examples belong in the SKILL.md body, not the description.

### Workflow ordering ([ADR 0004](../adr/0004-skill-workflow-ordering.md))

Every skill MUST fully load its instructions before taking any action on its subject matter. This is the single most critical rule for skill authoring.

- "Instructions" = SKILL.md + referenced process files + shared protocols + resolved profile content.
- "Action on subject matter" = reading diff content, editing code, engaging with idea prose, running tests, producing findings.
- A narrow early scope is permitted (e.g., `git diff --stat` for filenames) to drive profile detection.
- Content-level read instructions appear exactly once in the workflow, after instruction loading.

Every skill's Workflow section must carry a mandatory-order directive at the top naming this rule by intent. The failure mode: once an LLM has diff content loaded, it has enough to pattern-match findings without methodology, and its efficiency bias favors the shortcut. The methodology becomes ceremony the agent optimizes away.

## Shared Instructions

Instructions consumed by multiple skills live at `klaude-plugin/skills/_shared/<name>.md`. Each consuming skill gets a symlink:

```bash
# In the consuming skill directory:
ln -s ../_shared/<name>.md shared-<name>.md
```

Reference in skill prose as `[shared-<name>.md](shared-<name>.md)`. The `shared-` prefix makes it obvious which files are shared vs. skill-specific. Only symlink into skills that actually reference the file.

Symlinks must stay inside the `skills/` tree — cross-boundary symlinks break under some plugin installers (see [ADR 0003](../adr/0003-plugin-root-referenced-content.md)).

## Commands

Commands live under `klaude-plugin/commands/<name>/`. For skills with standard + isolated modes:

- `default.md` — standard variant, invoked as `/kk:<name>:default`
- `isolated.md` — isolated sub-agent variant, invoked as `/kk:<name>:isolated`

## Agents

Agent definitions live at `klaude-plugin/agents/<name>.md` with frontmatter specifying `name`, `description`, and `tools` (an allowlist of tools the agent can use):

```yaml
---
name: code-reviewer
description: |
  Independent code reviewer with no authorship attachment.
tools:
  - Read
  - Grep
  - Glob
  - mcp__capy__capy_search
---
```

Agent names describe the **role** (`code-reviewer`, `design-reviewer`), not the skill that invokes them. Don't rename agent files when renaming skills.

Agents inherit the instruction-before-action rule — they must read provided checklists before analyzing subject matter, regardless of payload delivery order from the spawning skill.

## Hooks

Hook definitions in `klaude-plugin/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/set-plugin-root.sh ${CLAUDE_PLUGIN_ROOT}"
      }]
    }],
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate-bash.sh"
      }]
    }]
  }
}
```

**SessionStart hook:** Exports `TOOLBOX_PLUGIN_ROOT` into the session via `$CLAUDE_ENV_FILE`. The harness-substituted `${CLAUDE_PLUGIN_ROOT}` is passed as an argument; a standalone resolver (`cpr.py`) serves as fallback. Once set, every Bash tool call in the session has `$TOOLBOX_PLUGIN_ROOT` available — this gives LLMs a reliable path to the plugin root without guessing.

**PreToolUse hooks:** Read JSON from stdin (the `tool_input` object), return structured JSON for deny decisions. Always exit 0 — use `permissionDecision: "deny"` in the JSON output to block a tool call. See `klaude-plugin/scripts/validate-bash.sh` for the pattern.

## Profiles

Profiles at `klaude-plugin/profiles/<name>/` provide domain-specific content to every workflow phase. See the [Profile Conventions](https://github.com/serpro69/claude-toolbox/blob/master/CLAUDE.md#profile-conventions) section of CLAUDE.md for the full specification.

**Required files:**

- `DETECTION.md` — three mandatory section headings: `## Path signals`, `## Filename signals`, `## Content signals`. All three must be present even if the body is empty. Optional: `## Design signals` for pre-code detection.
- `overview.md` — human-readable summary and dependency-lookup targets.

**Phase subdirectories:** `review-code/`, `design/`, `implement/`, `test/`, `document/`, `review-spec/`. Not every profile populates every phase. Each populated phase must have an `index.md` with always-load and conditional entries. Conditional entries need explicit `Load if:` clauses naming concrete diff properties — two agents evaluating the same diff must reach the same conclusion.

**Bidirectional index invariant** (enforced by `test/test-plugin-structure.sh`):

- Forward: every markdown link in `index.md` resolves to a file on disk.
- Reverse: every `.md` in the phase directory (except `index.md`) is referenced by the index.

An unreferenced `.md` inside a phase subdirectory is always a bug. Authoring notes belong in `overview.md` at the profile root, not inside phase subdirectories.

**Adding a new profile checklist:**

1. Create the profile directory by copying an existing one as a template.
2. Write `DETECTION.md` and `overview.md`.
3. Populate the phase subdirectories the profile needs (each with `index.md`).
4. Append the profile name to `EXPECTED_PROFILES` in `test/test-plugin-structure.sh`.
5. Append the profile name to the Known Profiles list in `klaude-plugin/skills/_shared/profile-detection.md`.
6. Run `bash test/test-plugin-structure.sh` and confirm green.

## Evaluations

Skills with non-trivial decision logic should ship evaluation scenarios under `klaude-plugin/skills/<skill>/evals/`. One directory per eval:

```
evals/<eval-name>/
  eval.json        # scenario definition
  test-files/      # real filesystem fixtures
```

`eval.json` schema:

```json
{
  "id": 1,
  "name": "eval-name-kebab-case",
  "description": "What this eval tests.",
  "skills": ["skill-name"],
  "prompt": "The user prompt that triggers the skill.",
  "trap": "The failure hypothesis — what a model is likely to get wrong.",
  "files": ["test-files/foo.yaml"],
  "assertions": [
    { "id": "1.1", "text": "Specific, gradable behavior." }
  ]
}
```

Use real filesystem fixtures in `test-files/`, not inline JSON strings. Include at least one regression eval proving the skill does NOT activate when it shouldn't.

## `${CLAUDE_PLUGIN_ROOT}` — Substitution Rules

The harness provides `${CLAUDE_PLUGIN_ROOT}` resolving to the installed plugin's root. Understanding its substitution boundary is critical ([ADR 0003](../adr/0003-plugin-root-referenced-content.md)):

**Substituted at plugin-load time** (safe to use freely):

- `SKILL.md` files
- `agents/*.md` files
- `hooks/*.json` command strings
- MCP config files

**NOT substituted by the `Read` tool** (the literal token reaches the agent):

- Everything in `skills/_shared/`
- Everything in `profiles/`
- Any file an agent reads at runtime

For runtime-read files, prefer explicit content (e.g., hard-coded profile name lists) over the token. If the file must describe a plugin-root path, instruct the agent to construct it using the resolved prefix it already knows from SKILL.md.

**`TOOLBOX_PLUGIN_ROOT` — runtime alternative.** The SessionStart hook exports this env var into every Bash call. Unlike `${CLAUDE_PLUGIN_ROOT}` (which is only substituted at plugin-load time), `$TOOLBOX_PLUGIN_ROOT` is available in the shell environment throughout the session. Use it in Bash commands when you need the plugin root at runtime — e.g., `ls $TOOLBOX_PLUGIN_ROOT/profiles/`.

**Other rules:**

- Brace form required: `${CLAUDE_PLUGIN_ROOT}` works, bare `$CLAUDE_PLUGIN_ROOT` does NOT get substituted.
- `Glob` won't work against these paths — it's cwd-scoped and returns 0 matches for outside-cwd absolute paths. Use `Read` with the resolved path instead.
- To reference the variable name literally in prose, use bare `$CLAUDE_PLUGIN_ROOT` or `&#36;{CLAUDE_PLUGIN_ROOT}`.

## Capy Knowledge Protocol

Skills that interact with capy MCP tools use `kk:` namespaced source labels:

| Label | Contents |
|-------|----------|
| `kk:arch-decisions` | Architecture decisions, design rationale |
| `kk:review-findings` | Code review patterns, recurring issues |
| `kk:lang-idioms` | Language best practices from external sources |
| `kk:project-conventions` | Discovered project patterns |
| `kk:test-patterns` | Testing approaches, edge cases |
| `kk:debug-context` | Root causes, tricky bugs |

Only index non-obvious learnings not derivable from reading the code or git history. Empty results are normal for new projects — proceed with standard guidelines.

## Common Pitfalls

1. **Workflow ordering is the #1 failure mode.** If the agent sees subject matter before methodology, it shortcuts the methodology. Structure every workflow so instructions load first. See [ADR 0004](../adr/0004-skill-workflow-ordering.md).

2. **Forgetting `make generate-kodex`.** After editing anything in `klaude-plugin/`, the Codex variant drifts. CI checks this with `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/`.

3. **Orphan files in profile phase directories.** Every `.md` file (except `index.md`) must be referenced by the phase's `index.md`. The bidirectional invariant test catches this.

4. **Symlinks outside `skills/`.** Per-skill symlinks must point within the `skills/` tree (`../_shared/<name>.md`). Cross-boundary symlinks break under some installers. Profile content uses `${CLAUDE_PLUGIN_ROOT}` references instead.

5. **Skill description truncation.** Descriptions are truncated from the tail. If your trigger keywords are at the end, the skill won't be matched. Lead with the use case.

6. **Stale Known Profiles list.** When adding a profile, you must update both `EXPECTED_PROFILES` in the test file and the Known Profiles list in `klaude-plugin/skills/_shared/profile-detection.md`. The list is the runtime enumeration — consumers iterate it rather than walking the filesystem.

7. **Renaming skills.** Update `EXPECTED_SKILLS` / `EXPECTED_COMMANDS` in tests. Don't rename agent files. Don't touch `run_plugin_migration`'s `dirs_to_remove` in `.claude/toolbox/scripts/template-sync.sh` (historical cleanup paths). Don't touch `docs/done/` (frozen history). Watch for substring collisions in sed operations.

8. **Vague `Load if:` clauses.** Conditional entries in profile `index.md` must name concrete diff properties (field values, filenames, directory names) — not vague category labels. Two agents evaluating the same diff must reach the same conclusion.
