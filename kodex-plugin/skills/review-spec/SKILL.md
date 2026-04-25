---
name: review-spec
description: |
  Use after implementing tasks or mid-feature to verify code matches design docs and ensure they are in sync.
  Detects spec deviations, missing implementations, doc inconsistencies, and outdated docs in design and implementation documentation.
---
<!-- codex: tool-name mapping applied. See .codex/scripts/session-start.sh -->

# Implementation Review

## Conventions

Read capy knowledge base conventions at [shared-capy-knowledge-protocol.md](shared-capy-knowledge-protocol.md).

**Profile detection.** See [shared-profile-detection.md](shared-profile-detection.md) for the shared detection procedure. When an active profile populates a `review-spec/` phase slot, its `index.md` content is loaded before per-task verification begins.

## Overview

Systematically compare implemented code against a feature's `design.md`, `implementation.md`, and `tasks.md` in `/docs/wip/[feature]/`. Works both mid-implementation (reviewing completed tasks only) and post-implementation (full feature review).

Findings go in **both directions** — code that deviates from spec AND spec that is wrong or outdated given the code.

## Required Outputs

Before declaring the review complete, verify all outputs are delivered:

- [ ] Review report presented to user
- [ ] User-confirmed intentional `SPEC_DEV`/`EXTRA_IMPL` findings indexed as `kk:arch-decisions` (skip if none confirmed)
- [ ] Next steps confirmation from user

Indexing is owned by this skill — callers (e.g., `implement`) do NOT duplicate it.

## Review Modes

### Standard Mode (`/kk:review-spec`)

Reviews spec conformance in the main conversation context. Single-pass review using the workflow below.

### Isolated Mode (`/kk:review-spec:isolated`)

Delegates detection to an independent `spec-reviewer` sub-agent that did not write the code, then annotates its findings with type-specific author context. Low-relevance types (MISSING_IMPL, DOC_INCON, OUTDATED_DOC, AMBIGUOUS) get brief annotations; high-relevance types (SPEC_DEV, EXTRA_IMPL) get detailed annotations with spec update suggestions.

- **Cost**: Higher (sub-agent + annotation)
- **Isolation**: True — reviewer has zero authorship bias or session context
- **Degradation**: If sub-agent fails, suggests standard mode fallback
- **Best for**: When extra rigor is worth the cost (post-implementation, pre-merge)

See [review-isolated.md](./review-isolated.md) for the isolated workflow.

## Finding Types

Each finding is classified by type (what kind of mismatch) and severity (how urgent).

| Type                   | Code           | Description                                                      | Example                                                                      |
| ---------------------- | -------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Missing Implementation | `MISSING_IMPL` | Spec describes something that was not implemented                | Design says "rate limiting on /api/auth" but no rate limiter exists          |
| Extra Implementation   | `EXTRA_IMPL`   | Code implements something not in the spec                        | A caching layer was added that design docs don't mention                     |
| Spec Deviation         | `SPEC_DEV`     | Code implements the feature but differently than specified       | Design says "bcrypt cost 12" but code uses cost 10                           |
| Doc Inconsistency      | `DOC_INCON`    | Documentation contradicts itself or is internally inconsistent   | design.md says JWT tokens, implementation.md says session cookies            |
| Outdated Doc           | `OUTDATED_DOC` | Code is correct but docs haven't been updated to reflect reality | Endpoint was renamed during implementation but docs still reference old name |
| Ambiguous Spec         | `AMBIGUOUS`    | Spec is unclear enough that multiple interpretations are valid   | "Support pagination" without specifying cursor vs offset                     |

### IaC Profile Semantics

When profile detection identifies an Infrastructure-as-Code profile (e.g., Kubernetes, Terraform), the declarative artifacts ARE the implementation — there is no separate runtime code to trace. Apply these adjusted type-mappings:

- A design-specified resource whose manifest is absent → `MISSING_IMPL` (absence in declarative systems is a gap, not a pending item or inconsistency)
- A field value in a manifest that disagrees with the design → `SPEC_DEV`
- A manifest resource the design does not mention → `EXTRA_IMPL`

`DOC_INCON` and `OUTDATED_DOC` apply unchanged — their semantics are doc-vs-doc or code-vs-doc, which declarative IaC does not alter.

For each active IaC profile that populates a `review-spec/` slot, load `../klaude-plugin/profiles/<name>/review-spec/index.md` for domain-specific verification patterns.

## Severity Levels

Same P0–P3 scale as `review-code`, adapted for spec conformance:

| Level  | Name     | Description                                                                           | Action                  |
| ------ | -------- | ------------------------------------------------------------------------------------- | ----------------------- |
| **P0** | Critical | Missing core functionality, security spec violated, data model mismatch               | Must fix before merge   |
| **P1** | High     | Significant behavioral deviation from spec, missing error handling that spec requires | Should fix before merge |
| **P2** | Medium   | Minor deviation, doc inconsistency, partial implementation of a spec requirement      | Fix or create follow-up |
| **P3** | Low      | Naming mismatch, doc typo, cosmetic deviation from spec                               | Optional                |

## Confidence Levels

Each finding gets a confidence score (1–10) with **mandatory reasoning** explaining what was checked, what evidence supports the finding, and what uncertainty remains.

| Score | Meaning                                                                                      |
| ----- | -------------------------------------------------------------------------------------------- |
| 9–10  | Certain — direct, unambiguous contradiction between spec and code                            |
| 7–8   | Strong — clear evidence but minor room for interpretation                                    |
| 5–6   | Moderate — likely issue but spec is somewhat vague or code has plausible alternative reading |
| 3–4   | Uncertain — possible issue, needs human judgment                                             |
| 1–2   | Speculative — gut feeling, very ambiguous spec or indirect evidence                          |

## Workflow

**Mandatory order — spec before code.** The flow below is strictly sequential. Do not read implementation code, run `grep`/`serena` against the codebase, or form spec-deviation findings until you have loaded the feature's design/implementation docs AND completed profile detection and loaded all resolved `review-spec/` profile content. The only early contact with the implementation is a feature-directory listing (filenames only) — enough to drive profile detection, not enough to pattern-match deviations. See [ADR 0004](../../../docs/adr/0004-skill-workflow-ordering.md) for the rationale.

See [review-process.md](./review-process.md) for the detailed step-by-step process.

**Phases:**

1. Load feature documents — read `tasks.md`, `design.md`, `implementation.md` (the spec, not the subject matter)
2. **Capy search:** Search `kk:arch-decisions` for design rationale that may explain intentional spec deviations. Search `kk:review-findings` for known patterns from prior reviews.
3. Detect active profiles and load `review-spec/` content from matching profiles
4. Determine review scope (mid-implementation vs post-implementation)
5. Per-task verification against spec — only now read implementation code (apply IaC type-mapping when an IaC profile is active)
6. Cross-cutting concern check
7. Self-check and confidence assessment
8. Present findings
9. Index confirmed deviations — index user-confirmed intentional `SPEC_DEV`/`EXTRA_IMPL` as `kk:arch-decisions`

## Invocation

Use the `/review-spec [feature-name]` command, or invoke naturally when a user asks to verify implementation against docs.

For isolated mode with an independent sub-agent:

```
/kk:review-spec:isolated [feature-name]
```
