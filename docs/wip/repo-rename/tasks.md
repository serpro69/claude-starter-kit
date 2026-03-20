# Tasks: Repo Rename (claude-starter-kit -> claude-sak)

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-03-20

## Task 1: Find-and-replace across the repository
- **Status:** pending
- **Depends on:** —
- **Docs:** [implementation.md#1-find-and-replace-across-the-repo](./implementation.md#1-find-and-replace-across-the-repo)

### Subtasks
- [ ] 1.1 Run a global replacement of `claude-starter-kit` → `claude-sak` across all files listed in the implementation plan (scripts, workflows, config, tests, fixtures, docs, commands)
- [ ] 1.2 Verify workflow guards: confirm `template-sync.yml:28` and `template-cleanup.yml:43` now read `!= 'claude-sak'`
- [ ] 1.3 Verify Serena config: confirm `.github/templates/serena/project.yml` `project_name` is `claude-sak`
- [ ] 1.4 Run `grep -r 'claude-starter-kit' . --include='*.sh' --include='*.yml' --include='*.yaml' --include='*.json' --include='*.md'` and confirm zero matches (excluding `.git/`)
- [ ] 1.5 Run existing test suite (`for test in test/test-*.sh; do $test; done`) to verify nothing is broken by the rename

## Task 2: Add manifest migration to template-sync.sh
- **Status:** pending
- **Depends on:** Task 1
- **Docs:** [implementation.md#manifest-migration](./implementation.md#manifest-migration)

### Subtasks
- [ ] 2.1 Create a `migrate_manifest()` function in `.github/scripts/template-sync.sh` near `validate_manifest()` — reads `upstream_repo` from the loaded manifest, checks if it equals `serpro69/claude-starter-kit`, and if so rewrites the manifest file using `jq` and reloads it via `read_manifest()`
- [ ] 2.2 Call `migrate_manifest` in `main()` after `validate_manifest()` and before `resolve_version()`
- [ ] 2.3 Add tests in `test/test-template-sync.sh`: (a) manifest with old `upstream_repo` gets rewritten to new value, (b) manifest already using new value is not modified, (c) migration emits a log message when triggered

## Task 3: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2

### Subtasks
- [ ] 3.1 Run `testing-process` skill to verify all tasks — full test suite, migration tests, edge cases
- [ ] 3.2 Run `documentation-process` skill to update any relevant docs
- [ ] 3.3 Run `solid-code-review` skill with `bash` language input to review the implementation
- [ ] 3.4 Run `implementation-review` skill to verify implementation matches design and implementation docs
