# Policy-toolchain auto-detection

Kubernetes projects commonly adopt one of three policy engines: **Conftest/OPA**, **Kyverno**, or **Gatekeeper** (Gatekeeper's CLI is `gator`). Each has its own project-local markers (directories, file patterns, resource kinds) that signal the project uses it. The `test` skill's policy hook activates a policy engine's tests when BOTH its project marker is present AND its binary is on `PATH` (per [presence-check-protocol.md](presence-check-protocol.md)).

**Both gates are required.** Marker alone → skill emits an install hint for the corresponding binary, does not execute. Binary alone → skill does nothing (the project has not adopted the engine; running the binary against random YAML produces spurious findings). No markers → the policy hook is skipped silently; no install hints are surfaced.

## Conftest / OPA

- **Project markers** — any one of:
  - A `.conftest/` directory at the repo root or in the feature's scope.
  - `policies/` directory containing `*.rego` files.
  - A `conftest.toml` file at the repo root.
- **Binary check** — `command -v conftest`.
- **Command when both gates pass**: `conftest test <matched-manifests>` from the repo root (or the policy directory the project uses). Defaults to `./policy/` for rule location; pass `-p <dir>` if the project uses a non-default path.
- **What it catches**: rule violations the project has authored in Rego — RBAC over-permission, required labels, banned `hostPath`, enforcement of `imagePullPolicy: IfNotPresent`, custom invariants.
- **Install hint (binary missing)**: `conftest: install via 'brew install conftest' or from https://github.com/open-policy-agent/conftest/releases`.

## Kyverno

- **Project markers** — any one of:
  - A `kyverno-policies/` directory.
  - Kubernetes resources of `kind: ClusterPolicy` or `kind: Policy` under API group `kyverno.io` (inspect `apiVersion: kyverno.io/v1` etc.) present in the project.
  - A `kyverno.yaml` or `kyverno-test.yaml` scaffold file.
- **Binary check** — `command -v kyverno`.
- **Command when both gates pass**: `kyverno test <policies-dir>` — Kyverno's `test` subcommand validates policies against test cases defined in `kyverno-test.yaml` files alongside the policies. Point it at the directory that contains the test scaffolds, not at the manifest tree.
- **What it catches**: policy rule errors, failing test cases the project authored for its own policies (e.g., "this manifest should be denied", "this label must be injected").
- **Install hint (binary missing)**: `kyverno: install via 'brew install kyverno' or from https://github.com/kyverno/kyverno/releases`.

## Gatekeeper (`gator`)

- **Project markers** — any one of:
  - A `.gator/` directory.
  - Kubernetes resources of `kind: ConstraintTemplate` (API group `templates.gatekeeper.sh`) or concrete `Constraint` resources (API group `constraints.gatekeeper.sh`) present in the project.
  - A `gator-test.yaml` or `suite.yaml` Gatekeeper test scaffold.
- **Binary check** — `command -v gator`.
- **Command when both gates pass**: `gator test --filename=<constraints-and-templates-dir>` or `gator verify --filename=<suite.yaml>` depending on which scaffold the project uses. `gator test` validates admission against the constraint set; `gator verify` runs the suite of test expectations.
- **What it catches**: constraint-template compilation errors, failing unit tests for the project's admission rules, gaps between design intent and admission behavior.
- **Install hint (binary missing)**: `gator: install via 'go install github.com/open-policy-agent/gatekeeper/v3/cmd/gator@latest' or from https://github.com/open-policy-agent/gatekeeper/releases`.

## No markers present

The project has not adopted a policy toolchain. The policy hook is **skipped silently** — do NOT list it in the report, do NOT emit install hints for Conftest/Kyverno/gator. Surfacing install hints for tools the project has no stated use for is noise.

This is the "skip silently" default. It is different from the "binary missing" report path documented in [presence-check-protocol.md](presence-check-protocol.md) — that path applies only when a project marker HAS been detected and the binary turns out to be absent.

## Multiple policy engines

Rare but valid — a repo may adopt Conftest for CI-time checks and Gatekeeper for admission-time enforcement. If multiple engine markers are detected, run each one whose binary is present. Each engine's output is reported separately; do not merge findings.

## What to report

For each detected engine:

- Marker that fired (e.g., "`.conftest/` present" or "`ClusterPolicy` resources found in `policies/kyverno/`").
- Binary status (`[OK]` or `[SKIP — binary not installed: <install hint>]`).
- Command executed when both gates passed, plus its own output on failure.

When no markers are present, the policy hook section is omitted from the report entirely.
