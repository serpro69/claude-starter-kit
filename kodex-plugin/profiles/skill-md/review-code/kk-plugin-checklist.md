# kk-plugin review checklist

Review checks specific to skills within the `klaude-plugin/` directory structure.

## Shared symlinks

- [ ] Do per-skill symlinks follow the pattern `shared-<name>.md` → `../_shared/<name>.md`?
- [ ] Are symlinks created from inside the consuming skill's directory?
- [ ] Do symlinks stay inside the `skills/` tree? (Cross-boundary symlinks break under some installers.)
- [ ] Are only skills that actually reference the shared file symlinked? (No blanket-symlinking.)
- [ ] Does profile content use `${CLAUDE_PLUGIN_ROOT}` references instead of symlinks?

## Bidirectional index invariant

- [ ] Does every markdown link in a phase `index.md` resolve to a file on disk? (Forward invariant.)
- [ ] Is every `.md` file in the phase directory (except `index.md`) referenced by at least one link in `index.md`? (Reverse invariant.)
- [ ] Are there no orphan `.md` files (authoring notes, READMEs) inside phase subdirectories? (These belong in `overview.md` at the profile root.)

## Naming conventions

- [ ] Do skill names use imperative verbs (`design`, not `analysis-process`)?
- [ ] Do grouped skills share a family prefix (`review-code`, `review-design`, `review-spec`)?
- [ ] Do agent names describe roles (`code-reviewer`), not invoking skills?
- [ ] Are other skills referenced without the `kk:` prefix in prose?

## Test registration and Codex generation

- [ ] Is `EXPECTED_SKILLS` in `test/test-plugin-structure.sh` updated for new skills?
- [ ] Is `EXPECTED_COMMANDS` updated for new commands?
- [ ] Is `EXPECTED_PROFILES` updated for new profiles?
- [ ] Is the **Known Profiles** list in `klaude-plugin/skills/_shared/profile-detection.md` updated for new profiles?
- [ ] Does `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/` show no drift?
