# Java — detection

Declares when the `java` profile activates on a given set of files. Consumed by `klaude-plugin/skills/_shared/profile-detection.md`. Multiple profiles may activate additively on the same diff.

## Path signals

_None._ Java detection does not use path heuristics; file extension alone is authoritative (see Content signals).

## Filename signals

_None._ Java detection is extension-based, not filename-based.

## Content signals

A file activates the Java profile if its extension is `.java`. The extension match is authoritative; no byte-level content inspection is required.
