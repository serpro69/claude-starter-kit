# kk-plugin gotchas

Applies when authoring skills within the `klaude-plugin/` directory structure of this project. Consult before writing or modifying skill files within the kk plugin.

## Shared instruction symlinks

Instructions consumed by multiple skills live at `klaude-plugin/skills/_shared/<name>.md`. Each consuming skill gets a per-skill symlink:

```bash
# Run from inside the consuming skill's directory:
ln -s ../_shared/<name>.md shared-<name>.md
```

**Constraints:**

- The `shared-` prefix in the skill directory makes it obvious which files are shared vs. skill-specific.
- Reference in skill prose as `[shared-<name>.md](shared-<name>.md)` — local links resolve without `../` path traversal.
- Only symlink into skills that actually reference the file — don't blanket-symlink.
- Symlinks must stay inside the `skills/` tree. Cross-boundary symlinks break under some plugin installers.
- Profile content uses `${CLAUDE_PLUGIN_ROOT}` references instead of symlinks (profiles are outside the `skills/` tree).

## Bidirectional index invariant

Every profile phase subdirectory's `index.md` must satisfy two invariants (enforced by `test/test-plugin-structure.sh`):

- **Forward:** every markdown link in `index.md` resolves to a file on disk.
- **Reverse:** every `.md` file in the phase directory (except `index.md` itself) is referenced by at least one link in `index.md`.

An unreferenced `.md` inside a phase subdirectory is always a bug — an orphan checklist or a stray README. Authoring notes belong in `overview.md` at the profile root, not inside phase subdirectories.

## Test registration

When adding a new skill, command, or profile, update the corresponding array in `test/test-plugin-structure.sh`:

- `EXPECTED_SKILLS` — for new skills
- `EXPECTED_COMMANDS` — for new commands
- `EXPECTED_PROFILES` — for new profiles

Add the entry *after* the files exist, not before. For new profiles, also append the profile name to the **Known Profiles** list in `klaude-plugin/skills/_shared/profile-detection.md` — the detection procedure iterates this list, not the filesystem.

Run `bash test/test-plugin-structure.sh` and confirm green.

## Codex generation

After editing anything in `klaude-plugin/`, the Codex variant may drift. Run:

```bash
make generate-kodex
```

CI checks freshness via `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/`.

## Agent naming convention

Agent names describe the **role** (`code-reviewer`, `design-reviewer`, `spec-reviewer`), not the skill that invokes them. Don't rename agent files when renaming skills — agent names persist across skill renames.

Agents inherit the instruction-before-action rule: they must read provided checklists before analyzing subject matter, regardless of payload delivery order from the spawning skill.
