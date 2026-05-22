---
name: review-tool
description: Reviews tool configurations for correctness.
---

# Review Tool

**Goal: Validate tool configuration files against the project schema.**

## Conventions

Follow standard review conventions.

## Validation Rules

You MUST check every configuration file for:
- Required fields present (`name`, `version`, `entrypoint`)
- No deprecated fields (`legacy_mode`, `compat_shim`)
- Version string matches semver format

## Error Handling

When a validation error is found:
1. Record the file path, field name, and violation type
2. Continue checking remaining files — do not stop on first error
3. Group errors by severity: blocking vs. warning

## Required Outputs

- [ ] Validation report written to `docs/reports/`
- [ ] Inline summary with pass/fail counts
- [ ] Blocking errors indexed under `kk:review-findings`

## Workflow

**Mandatory order — load rules before validating.** Read all configuration schemas before examining any target files.

Phases: load schemas → scan files → classify errors → write report → present summary.
