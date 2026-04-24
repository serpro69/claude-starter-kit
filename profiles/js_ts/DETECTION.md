# JS/TS — detection

Declares when the `js_ts` profile activates on a given set of files. Consumed by `skills/_shared/profile-detection.md`. Multiple profiles may activate additively on the same diff.

The profile covers JavaScript and TypeScript jointly: review concerns (typing, async, modules, React patterns) overlap substantially, and the ecosystem tools (npm, bundlers, Node/browser runtimes) are shared.

## Path signals

_None._ JS/TS detection does not use path heuristics; file extension alone is authoritative (see Content signals).

## Filename signals

_None._ JS/TS detection is extension-based, not filename-based.

## Content signals

A file activates the JS/TS profile if its extension is one of: `.js`, `.jsx`, `.mjs`, `.cjs`, `.ts`, `.tsx`, `.mts`, `.cts`. The extension match is authoritative; no byte-level content inspection is required.
