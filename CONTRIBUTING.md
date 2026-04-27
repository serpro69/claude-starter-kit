# Contributing

Thanks for your interest in contributing to claude-toolbox!

## Getting Started

1. Fork and clone the repo
2. Run the test suite to make sure everything works: `for test in test/test-*.sh; do $test; done`
3. Create a feature branch from `master`

## Development

See [Architecture](docs/contributing/ARCHITECTURE.md) for how the components fit together and [Testing](docs/contributing/TESTING.md) for test conventions.

### Key workflows

- **Editing skills:** Edit in `klaude-plugin/skills/`, then run `make generate-kodex` to regenerate the Codex variant.
- **Editing profiles:** Edit in `klaude-plugin/profiles/`, then run `make generate-kodex`. Vendored profiles (e.g., Go) use `make vendor-go` instead.
- **Adding a profile:** Follow the "Adding a new profile" checklist in `CLAUDE.md`.
- **Editing codex config:** Hand-authored files live in `.codex/` (config.toml, hooks.json, rules, scripts). Generated files (agents, kodex-plugin) should not be edited directly.

### Commit conventions

- Use imperative mood in commit messages ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Include a blank line + body for non-trivial changes explaining the "why"

## Pull Requests

- One logical change per PR
- All test suites must pass: `for test in test/test-*.sh; do $test; done`
- If you edited `klaude-plugin/`, verify `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/` shows no drift
- Update documentation if your change affects user-facing behavior

## Architecture Decisions

Non-trivial design decisions are recorded as ADRs in `docs/adr/`. If your change involves choosing between multiple approaches, document the decision using the template in that directory.

## License

By contributing, you agree that your contributions will be licensed under the ELv2 License.
