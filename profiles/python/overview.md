# Python profile

## What this profile covers

Idiomatic Python source code: type hints and `typing` usage, mutability and aliasing, context managers, exception hygiene, packaging boundaries, async idioms, testing/mocking pitfalls, and SOLID principles adapted to Python's duck-typed model.

## When it activates

Any file with a `.py` or `.pyi` extension in scope. See [DETECTION.md](DETECTION.md) for the authoritative rule. Activation is additive with other profiles on the same diff.

## Populated phases

- `review-code/` — checklists consumed by `review-code` (security, SOLID, code-quality, removal-plan).

Other phase subdirectories are not populated for this profile: generic per-phase behavior is sufficient.

## Looking up Python dependencies

When adding or upgrading a dependency, follow the `dependency-handling` skill's cascade:

1. **capy-first** — query the project's indexed `kk:lang-idioms` / `kk:project-conventions` / prior context7 fetches.
2. **context7** — fetch current docs for the package; most mainstream PyPI packages are indexed there.
3. **web** — fall back to [pypi.org](https://pypi.org), the project's own repository README, or [readthedocs.io](https://readthedocs.io) mirrors only if the first two yield nothing.

Project dependency metadata lives in `pyproject.toml`, `requirements.txt`, or `poetry.lock` / `pdm.lock`. Version-specific behaviors must be verified against the version the project resolves to, not the latest available.
