# Skill-Building Reference Guide

Distilled from Anthropic's skill-building documentation and accumulated project learnings. Organized by topic for on-demand consultation during skill authoring.

## Table of contents

- [How skill triggering works](#how-skill-triggering-works)
- [Writing effective descriptions](#writing-effective-descriptions)
- [Progressive disclosure](#progressive-disclosure)
- [Workflow ordering](#workflow-ordering)
- [Resource organization](#resource-organization)
- [Bundling executable scripts](#bundling-executable-scripts)
- [Writing clear instructions](#writing-clear-instructions)
- [Evaluation-driven development](#evaluation-driven-development)
- [The develop-with-Claude pattern](#the-develop-with-claude-pattern)
- [Anti-patterns](#anti-patterns)

---

## How skill triggering works

At startup, Claude loads every skill's YAML frontmatter (`name` and `description`) into the system prompt. The full SKILL.md body and bundled files are NOT loaded until the skill is selected. This means:

1. **Metadata is pre-loaded** — name and description are always in context.
2. **Files are read on-demand** — SKILL.md body, references, scripts are read from disk only when triggered.
3. **Scripts execute without loading** — utility scripts run via bash; only their output enters context.
4. **No context penalty for large bundles** — reference files, data, and docs cost zero tokens until actually read.

The description is the primary selection signal. Claude uses it to choose the right skill from potentially 100+ available skills. Everything else — SKILL.md body, bundled files — is implementation detail that only matters after selection.

## Writing effective descriptions

The description field is critical for skill discovery. It must answer two questions: *what does this skill do?* and *when should it be used?*

**Rules:**

- **Write in third person.** The description is injected into the system prompt; inconsistent point-of-view causes discovery problems.
  - Good: "Processes Excel files and generates reports"
  - Bad: "I can help you process Excel files"
  - Bad: "You can use this to process Excel files"
- **Lead with trigger keywords.** Truncation happens at the tail (1,536 char cap in Claude Code, 1,024 in OpenCode). Put the decisive "when to invoke" words first.
- **Be specific and pushy.** Include both what the skill does and concrete triggers. "Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."
- **One description field only.** No aliases, no secondary descriptions. Make it count.

**Good examples:**

```
description: Extract text and tables from PDF files, fill forms, merge documents.
  Use when working with PDF files or when the user mentions PDFs, forms, or
  document extraction.
```

```
description: Generate descriptive commit messages by analyzing git diffs.
  Use when the user asks for help writing commit messages or reviewing staged changes.
```

**Bad example:**

```
description: A helpful tool for various document processing tasks including
  but not limited to reading, writing, and transforming documents in multiple
  formats such as PDF, DOCX, and others.
```

The bad example wastes its budget on hedging. By the time it reaches useful trigger words, truncation may have already cut them.

## Progressive disclosure

Skills use a three-tier model to manage context efficiently:

**Tier 1 — Metadata (~100 words).** The YAML frontmatter: `name`, `description`. Always loaded. This is the selection surface.

**Tier 2 — SKILL.md body (<500 lines).** The main instruction file. Loaded when the skill is triggered. Contains workflow, conventions, and pointers to deeper content. Keep it lean — if it exceeds 500 lines, split content into bundled files.

**Tier 3 — Bundled resources (unlimited).** Reference files, scripts, examples, data. Loaded on-demand when the workflow needs them. No context penalty until accessed.

**Patterns for Tier 3 delegation:**

*High-level guide with references:*
```markdown
## Advanced features
**Form filling**: See [FORMS.md](FORMS.md) for complete guide
**API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
```

*Domain-specific organization:*
```
references/
  finance.md    (revenue, billing metrics)
  sales.md      (opportunities, pipeline)
  product.md    (API usage, features)
```

*Conditional details:*
```markdown
**For tracked changes**: See [REDLINING.md](REDLINING.md)
**For OOXML details**: See [OOXML.md](OOXML.md)
```

Claude reads each file only when the user's task requires it, keeping token usage proportional to task complexity.

## Workflow ordering

**The single most critical rule for skill authoring.** Every skill MUST fully load its instructions before taking any action on its subject matter.

This is a workflow-ordering bug, not an agent-discipline bug. Telling the model to "follow the process exactly" does not fix it, because once an LLM has subject-matter content loaded, its efficiency bias favors pattern-matching findings without methodology. The methodology becomes ceremony the agent optimizes away.

**The correct order:**

1. SKILL.md is already in context (loaded by the harness).
2. Read every referenced process/rubric/protocol file.
3. For profile-driven skills: run profile detection (filename-level scope only), then read all resolved profile content.
4. **Only then** read subject matter (diff, code, idea prose) and take action.

**Authoring requirements:**

- Place a mandatory-order directive at the top of the Workflow section, named by intent (not by step numbers — step numbers drift).
- Content-level read instructions appear exactly once, after instruction loading. Restating them earlier — even as a "Preflight" — re-creates the failure mode.
- After drafting, grep for repeated content-read instructions. If the same `git diff` / `Read` step appears twice, collapse to one instance at the post-instruction position.

## Resource organization

Use descriptive filenames that indicate content. Organize directories by domain or feature.

| Directory | Purpose | How Claude uses it |
|-----------|---------|-------------------|
| `scripts/` | Utility scripts | **Execute** (most common) — run via bash, only output enters context |
| `references/` | On-demand context | **Read** when the workflow needs deeper information |
| `assets/` | Static resources | Templates, data files, configs |
| `evals/` | Evaluation scenarios | Test fixtures and assertions |

**Naming:**

- Good: `form_validation_rules.md`, `references/finance.md`
- Bad: `doc2.md`, `docs/file1.md`

**Execute vs. read distinction:** Make it explicit in your instructions whether Claude should run a script or read it as reference. "Run `analyze_form.py` to extract fields" vs. "See `analyze_form.py` for the field extraction algorithm." For most utility scripts, execution is preferred — more reliable and more token-efficient.

## Bundling executable scripts

Pre-made scripts bundled with a skill offer advantages over generated code:

- **More reliable** — tested, deterministic behavior
- **Save tokens** — no need to include code in context or generate it
- **Save time** — no code generation step
- **Ensure consistency** — same script runs every time

The instruction file references the script; Claude executes it without loading its contents into context. Only the script's output consumes tokens.

```markdown
## Utility scripts

**analyze_form.py**: Extract all form fields from PDF
\`\`\`bash
python scripts/analyze_form.py input.pdf > fields.json
\`\`\`
```

## Writing clear instructions

**Explain the why over rigid MUSTs.** Instructions that explain reasoning produce better results than inflexible commands. An LLM that understands *why* a rule exists can apply it correctly in edge cases; one that only knows "MUST do X" either follows the rule blindly in contexts where it doesn't apply, or ignores it when it seems inconvenient.

- Good: "Filter test accounts because they skew regional metrics by 15-20%."
- Bad: "You MUST always filter test accounts."

**Keep instructions lean.** Cut unproductive steps. If a step doesn't contribute to the output quality, remove it. Skill instructions are a protocol for an LLM, not documentation for a human — brevity improves compliance.

**Use checklists for multi-step workflows.** Copy-paste checklists help both Claude and the user track progress:

```markdown
Copy this checklist and check off items as you complete them:
- [ ] Step 1: Analyze the input
- [ ] Step 2: Validate mapping
- [ ] Step 3: Generate output
- [ ] Step 4: Verify results
```

**Test across models.** What works for Opus might need more detail for Haiku. If your skill targets multiple models, aim for instructions that work with all of them.

## Evaluation-driven development

**Create evaluations BEFORE writing extensive documentation.** This ensures your skill solves real problems rather than documenting imagined ones.

**Process:**

1. **Identify gaps** — run Claude on representative tasks without a skill. Document specific failures or missing context.
2. **Create evaluations** — build 3+ scenarios that test these gaps.
3. **Establish baseline** — measure performance without the skill.
4. **Write minimal instructions** — just enough to address the gaps and pass evaluations.
5. **Iterate** — execute evaluations, compare against baseline, refine.

**Eval structure (this project's conventions):**

One directory per eval with real filesystem fixtures:
```
evals/<eval-name>/
  eval.json        # scenario definition
  test-files/      # real fixtures (YAML, code, configs)
```

`eval.json` includes `trap` (the failure hypothesis — what a model is likely to get wrong) and numbered `assertions` for traceable grading. Include at least one regression eval proving the skill does NOT activate when it shouldn't.

Inline-in-prompt fixtures test pattern-matching on prose, not the actual detection logic. Real files are syntax-highlightable, validatable, and trivial to edit.

## The develop-with-Claude pattern

The most effective skill development involves Claude itself:

1. **Claude A writes** — work through a problem with Claude using normal prompting. Notice what context you repeatedly provide. Then ask Claude to capture that pattern as a skill.
2. **Claude B tests** — use the skill in a fresh session on real tasks. Observe where it fails.
3. **Claude A refines** — share what you observed. Ask Claude A to improve the skill based on Claude B's failures.

This works because Claude understands both how to write effective agent instructions and what information agents need. You don't need special prompts or a meta-skill to get Claude to help create skills.

## Anti-patterns

**Monolithic skills.** A single SKILL.md that tries to cover everything. Exceeding 500 lines signals that content should be delegated to reference files. The agent loads the entire SKILL.md body on trigger — a 2,000-line file wastes context on content irrelevant to most tasks.

**Vague instructions.** "Handle the document appropriately" gives the agent no useful guidance. Be specific: name the tool, the format, the expected output. Vagueness produces inconsistent behavior across invocations.

**Too many choices.** Listing five alternative libraries without a default forces the agent to make an arbitrary selection. Provide a default with an escape hatch: "Use pdfplumber for text extraction. For scanned PDFs requiring OCR, use pdf2image with pytesseract instead."

**Rigid MUSTs without reasoning.** "You MUST always validate input" tells the agent what but not when or why. The agent either applies it blindly (validating internal data that's already trusted) or skips it (because it seems like ceremony). Explain the reasoning so the agent can judge edge cases.

**Subject-matter-first workflows.** Putting "read the diff" or "read the code" as Step 1 because that's what a human does. The skill author is writing a protocol for an LLM, not a human — once the agent has subject matter, it shortcuts methodology. Instructions must load first.

**Description budget waste.** Spending the description on hedging ("A helpful tool for various tasks including but not limited to...") instead of trigger keywords. By the time useful terms appear, truncation has already cut them.
