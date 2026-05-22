---
name: review-tool
description: Reviews tool configurations for correctness.
---

# Review Tool

**Goal: Validate tool configuration files against the project schema.**

## Conventions

Follow standard review conventions.

## Required Outputs

- [ ] Validation report written to `docs/reports/`
- [ ] Inline summary with pass/fail counts
- [ ] Blocking errors indexed under `kk:review-findings`

## Workflow

**Mandatory order — load rules before validating.** Read all configuration schemas before examining any target files.

See [review-process.md](review-process.md) for validation rules, error handling, and the detailed phase-by-phase workflow.
