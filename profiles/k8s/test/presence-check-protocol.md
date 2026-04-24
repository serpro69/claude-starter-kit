# Binary-presence protocol

Before invoking any Kubernetes validator or policy tool, verify the binary is reachable on `PATH`. Blind execution that fails with a shell `command not found` error is a bad user experience and obscures what the skill was trying to do — the skill must either run the tool, surface a structured install hint, or mark the check as skipped in the report.

This protocol applies uniformly to **floor**, **menu**, and **policy** tools named in [validators.md](validators.md) and [policy-hook.md](policy-hook.md).

## The check

Before running `<tool>`:

```
command -v <tool> >/dev/null 2>&1
```

`command -v` is portable (POSIX), exits non-zero when the binary is missing, and does not emit output on stdout when quiet-redirected. `which` is acceptable on macOS/Linux but varies across shells; prefer `command -v`.

For tools invoked as a subcommand of another binary (e.g., `helm lint`, `kubectl --dry-run=server`, `trivy config`), check the parent binary — `helm`, `kubectl`, `trivy` — not the subcommand string.

## When the binary is present

Proceed with the tool as described in `validators.md` / `policy-hook.md`.

## When the binary is missing

1. **Do NOT attempt execution.** A missing-binary path never becomes a shell error in the final report.
2. **Surface a per-tool install hint.** The hint must name the tool, the recommended install path, and an alternative where one exists. Install hints for every tool named in this profile live next to the tool's description — in [validators.md](validators.md) for floor/menu/cluster-dependent tools and [policy-hook.md](policy-hook.md) for policy engines. Use the hint from the tool's own entry rather than re-deriving it here; if an entry lacks a hint, fall back to the tool's README as the authoritative install source.
3. **Fall back to descriptive guidance OR mark skipped.** Two acceptable reports — pick whichever fits the check's importance:
   - **Descriptive guidance**: name the category of problems the validator would have caught (e.g., "kubeconform would have schema-validated the 12 matched YAML docs against the Kubernetes API; install it to enable this check"). Useful for floor tools, because the user should understand what coverage they are missing.
   - **Skipped**: a one-line entry in the report (e.g., `[SKIP] kube-score — binary not installed`). Useful for menu tools the user did not opt into.

## Floor-binary absence is NOT a blocker

A missing floor binary (`kubeconform`, `helm`, `kustomize`) surfaces the install hint and continues the run. The remaining floor checks still execute. The test skill does not abort the overall test plan because one tool is missing — the user is informed and the other validators produce their usual output.

Policy-hook tools that are gated by project markers follow the same rule: if the marker exists but the binary is missing, surface the install hint and continue; do not let a missing `conftest` silence the rest of the validator run.

## When to re-check

The skill re-checks binary presence at the start of each test run. Caching a "found" / "not found" result across runs is not necessary — `command -v` is cheap, and the user may install a tool mid-session (the friendly flow is: skill reports missing binary, user installs it, next run picks it up without requiring a skill restart).
