# Profiles

The kk plugin ships per-domain profiles that make every workflow skill language-aware. Profiles provide:

- **Review checklists** — language-specific code review items
- **Implementation gotchas** — common pitfalls and idioms
- **Design prompts** — architecture patterns relevant to the language
- **Test validators** — testing conventions and frameworks
- **Documentation rubrics** — what to document and how

## Supported Profiles

| Profile | Covers | Detection |
|---------|--------|-----------|
| **Go** | Go modules, packages, concurrency patterns | `*.go`, `go.mod`, `go.sum` |
| **Java** | Maven/Gradle projects, Spring, JVM patterns | `*.java`, `pom.xml`, `build.gradle` |
| **JS/TS** | Node.js, TypeScript, React, frontend tooling | `*.ts`, `*.tsx`, `*.js`, `package.json` |
| **Kotlin** | Kotlin/JVM, Android, Gradle | `*.kt`, `*.kts`, `build.gradle.kts` |
| **Kubernetes** | Helm charts, Kustomize, YAML manifests | `Chart.yaml`, `kustomization.yaml`, K8s resource kinds |
| **K8s Operator** | kubebuilder, operator-sdk, controller-runtime | `PROJECT`, `config/crd/`, `controller-gen` in Makefile |
| **Python** | pip, poetry, pytest, Django, FastAPI | `*.py`, `pyproject.toml`, `requirements.txt` |
| **Skill MD** | Agent skill authoring (Claude Code, Codex) | `SKILL.md`, files under a `SKILL.md`-rooted ancestor |

## How Detection Works

Profiles activate automatically based on the files in your diff or working directory. Detection uses three signal types in cost order:

1. **Path signals** — file extension globs (fast pre-filter, not authoritative alone)
2. **Filename signals** — literal filenames like `go.mod`, `Chart.yaml` (authoritative)
3. **Content signals** — anchors and patterns inside files (authoritative)

Multiple profiles can activate simultaneously — a Helm chart that generates Python scripts would trigger both `k8s` and `python`.

## What Profiles Provide

Each profile populates phase-specific content for the skills that consume it:

| Phase | Consuming Skill | Content |
|-------|----------------|---------|
| `review-code/` | /kk:review-code | Language-specific review checklists, gotchas |
| `design/` | /kk:design | Architecture patterns, design considerations |
| `implement/` | /kk:implement | Implementation gotchas, idioms |
| `test/` | /kk:test | Testing frameworks, conventions, validators |
| `document/` | /kk:document | Documentation rubrics |
| `review-spec/` | /kk:review-spec | Spec conformance rules |

## Vendored Content

Some profiles vendor content from external upstream repositories. The Go profile, for example, vendors from [samber/cc-skills-golang](https://github.com/samber/cc-skills-golang) via a manifest-driven pipeline. See the [Contributing Guide](../contributing/plugin-development.md) for details on the vendoring workflow.
