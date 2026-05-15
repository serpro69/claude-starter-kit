# Universal skill quality checklist

Review questions for any agent skill regardless of provider. Each question maps to a common failure mode.

## Workflow ordering

- [ ] Is there a mandatory-order directive at the top of the Workflow section?
- [ ] Is the directive named by intent (e.g., "instructions before action"), not by step numbers?
- [ ] Does the actual workflow comply — are all instruction files (SKILL.md, process files, shared protocols, profile content) loaded before any content-level reading of subject matter?
- [ ] Do content-level read instructions appear exactly once, after instruction loading? (Check for duplicate `git diff` / `Read` steps — a "Preflight" step that reads content re-creates the failure mode.)

## Progressive disclosure

- [ ] Is SKILL.md under 500 lines? If over, is content properly delegated to bundled reference files with clear pointers?
- [ ] Does Tier 3 content (references, scripts, examples) use descriptive filenames and organize by domain/feature?
- [ ] Are bundled files loaded on-demand (not eagerly) — does the workflow only read them when the task requires it?

## Description quality

- [ ] Does the description lead with trigger keywords? (Truncation happens at the tail.)
- [ ] Is the description written in third person? (First/second person causes discovery problems.)
- [ ] Is it specific enough for selection from 100+ skills? Does it name concrete triggers ("Use when...")?
- [ ] Is the combined `description` + `when_to_use` text under 1,536 characters? Under 1,024 if the skill must be portable across harnesses?
- [ ] Does the description avoid hedging and filler ("A helpful tool for various tasks...")?

## Resource separation

- [ ] Are scripts in `scripts/` intended to be executed, not read? Does the instruction text make the distinction explicit?
- [ ] Are reference files in `references/` loaded on-demand, not eagerly?
- [ ] Are filenames descriptive (`form_validation_rules.md`, not `doc2.md`)?

## Instruction clarity

- [ ] Do instructions explain *why* rules exist, not just state rigid MUSTs?
- [ ] Are instructions lean — no steps that don't contribute to output quality?
- [ ] For multi-step workflows, is there a copy-paste checklist for progress tracking?
- [ ] Are conditional workflows in separate files rather than deeply nested in SKILL.md?

## Eval coverage

- [ ] For skills with non-trivial decision logic (routing, detection, conditional loading): are there eval scenarios under `evals/`?
- [ ] Do evals use real filesystem fixtures in `test-files/`, not inline-in-prompt descriptions?
- [ ] Is there at least one regression eval proving the skill does NOT activate when it shouldn't?
- [ ] Does each `eval.json` include a `trap` field naming the failure hypothesis?
