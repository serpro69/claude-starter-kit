# Go — detection

Declares when the `go` profile activates on a given set of files. Consumed by `klaude-plugin/skills/_shared/profile-detection.md`. Multiple profiles may activate additively on the same diff.

## Path signals

_None._ Go detection does not use path heuristics; file extension alone is authoritative (see Content signals).

## Filename signals

_None._ Go detection is extension-based, not filename-based.

## Content signals

A file activates the Go profile if its extension is `.go`. The extension match is authoritative; no byte-level content inspection is required.

## Design signals

display_name: Go
tokens:
  - Go
  - Golang
  - goroutine
  - go module
  - go.mod
