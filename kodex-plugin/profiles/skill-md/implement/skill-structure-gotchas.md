# Universal skill-structure gotchas

Applies to any agent skill regardless of provider. Consult before writing or modifying skill files.

## Workflow ordering

Every skill MUST fully load its instructions before taking any action on its subject matter. This is the single most critical rule for skill authoring — violating it produces skills that shortcut their own methodology.

**Why it matters:** once an LLM has subject-matter content loaded (a diff, code, idea prose), its efficiency bias favors pattern-matching findings without methodology. The methodology becomes ceremony the agent optimizes away. This is a workflow-ordering bug, not an agent-discipline bug — telling the model to "follow the process exactly" does not fix it.

**What to do:**

- Place a mandatory-order directive at the top of the Workflow section, named by intent (e.g., "instructions before action"), not by step numbers — step numbers drift across edits.
- Structure the workflow so all instruction files (SKILL.md, referenced process files, shared protocols, resolved profile content) load before any content-level reading of subject matter.
- A narrow early scope is permitted for profile detection (e.g., `git diff --stat` for filenames), but content-level reading is blocked until instructions are fully loaded.
- Content-level read instructions appear exactly once in the workflow, after instruction loading. Restating them earlier — even as a "Preflight" — re-creates the failure mode.

**Self-check after drafting:** grep the skill directory for repeated content-read instructions. If the same `git diff` / `Read` step appears twice, collapse to one instance at the post-instruction position.

## Progressive disclosure

Skills use a three-tier model. Respect the budgets:

| Tier | What | Budget |
|------|------|--------|
| 1 — Metadata | YAML frontmatter (`name`, `description`) | ~100 words |
| 2 — SKILL.md body | Main instruction file | <500 lines |
| 3 — Bundled resources | References, scripts, examples, data | Unlimited (on-demand) |

If SKILL.md exceeds 500 lines, split content into bundled reference files. The agent loads the entire SKILL.md body on trigger — a 2,000-line file wastes context on content irrelevant to most tasks.

Delegate detailed content to Tier 3 files with clear pointers: "See `[FORMS.md](FORMS.md)` for the complete guide." Claude reads each file only when the user's task requires it.

## Description effectiveness

The description is the primary selection signal — Claude uses it to choose the right skill from potentially 100+ available skills. Get it wrong and the skill never triggers; get it right and it triggers precisely.

**Rules:**

- **Lead with trigger keywords.** Truncation happens at the tail (1,536 char cap in Claude Code, 1,024 in OpenCode). Put the decisive "when to invoke" words first.
- **Write in third person.** The description is injected into the system prompt; first/second person causes discovery problems.
- **Be specific and pushy.** Include both what the skill does and concrete triggers: "Use when working with PDF files or when the user mentions PDFs."
- **One description field only.** Detailed rules, cascades, and examples belong in the SKILL.md body, not the description.
- **Portable ceiling: 1,024 chars.** If the skill must work on both Claude Code (1,536 cap) and OpenCode (1,024 cap), treat 1,024 as the hard ceiling.

**Bad pattern:** "A helpful tool for various document processing tasks including but not limited to..." — hedging wastes the truncation budget.

## Resource organization

Organize skill directories by purpose:

| Directory | Purpose | How Claude uses it |
|-----------|---------|-------------------|
| `scripts/` | Utility scripts | **Execute** via bash — only output enters context |
| `references/` | On-demand context | **Read** when the workflow needs deeper information |
| `assets/` | Static resources | Templates, data files, configs |
| `evals/` | Evaluation scenarios | Test fixtures and assertions |

Use descriptive filenames (`form_validation_rules.md`, not `doc2.md`). Make the execute-vs-read distinction explicit in instructions: "Run `analyze_form.py`" vs. "See `analyze_form.py` for the algorithm."

## Instruction clarity

**Explain the why over rigid MUSTs.** An LLM that understands *why* a rule exists applies it correctly in edge cases; one that only knows "MUST do X" either follows it blindly where it doesn't apply, or skips it when it seems like ceremony.

- Good: "Filter test accounts because they skew regional metrics by 15-20%."
- Bad: "You MUST always filter test accounts."

**Keep instructions lean.** If a step doesn't contribute to output quality, remove it. Skill instructions are a protocol for an LLM, not documentation for a human — brevity improves compliance.

**Use checklists for multi-step workflows.** Copy-paste checklists help both Claude and the user track progress through complex procedures.

## Eval structure

Skills with non-trivial decision logic (routing, detection, conditional loading) should ship evaluation scenarios. One directory per eval with real filesystem fixtures:

```
evals/<eval-name>/
  eval.json        # scenario definition
  test-files/      # real fixtures (YAML, code, configs)
```

`eval.json` includes `trap` (the failure hypothesis — what the model is likely to get wrong) and numbered `assertions` for traceable grading. Include at least one regression eval proving the skill does NOT activate when it shouldn't.

Use real filesystem fixtures, not inline-in-prompt descriptions. Inline fixtures test pattern-matching on prose, not the actual detection logic.
