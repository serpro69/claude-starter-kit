# Chain-of-Verification (CoVe) Skill Implementation Plan

## Prerequisites

- Familiarity with Claude Code skill structure (see existing skills in `.claude/skills/`)
- Understanding of slash command format (see `.claude/commands/tm/` for examples)
- No external dependencies required

## Implementation Tasks

### Task 1: Create Skill Directory Structure

**Objective:** Set up the directory structure for the CoVe skill.

**Location:** `.claude/skills/cove/`

**Actions:**
1. Create directory `.claude/skills/cove/`
2. Create empty files: `SKILL.md`, `cove-process.md`

**Reference:** Examine existing skill structure at `.claude/skills/analysis-process/` for conventions.

---

### Task 2: Implement SKILL.md Entry Point

**Objective:** Create the skill definition file with metadata and overview.

**Location:** `.claude/skills/cove/SKILL.md`

**Structure:**
```yaml
---
name: cove
description: [description text]
---
```

**Content requirements:**
- YAML frontmatter with `name` and `description` fields
- Description should mention: improved accuracy, fact-checking, complex questions
- Brief explanation of when to use the skill
- Reference to `cove-process.md` for the detailed workflow
- Keep concise - detailed instructions go in the process file

**Reference:** See `.claude/skills/development-guidelines/SKILL.md` for format example.

---

### Task 3: Implement cove-process.md Workflow

**Objective:** Create the detailed verification workflow instructions.

**Location:** `.claude/skills/cove/cove-process.md`

**Content sections:**

1. **Workflow Checklist**
   - Copyable checklist for tracking progress through verification steps
   - Format: `- [ ] Step N: Description`

2. **Step 1: Initial Response**
   - Instructions for providing the initial answer
   - Requirement to mark clearly as "Initial Answer"
   - Note areas of uncertainty

3. **Step 2: Generate Verification Questions**
   - Instructions for creating 3-5 verification questions
   - Categories to cover: factual, logical, edge cases, assumptions, technical
   - Guidelines for effective question formulation
   - Emphasis on targeting critical/uncertain claims

4. **Step 3: Independent Verification**
   - Critical instruction: answer each question independently
   - Explicit instruction to NOT reference the initial answer
   - Guidance on using tools (WebSearch, context7, Read, Grep)
   - Treat each question as a fresh standalone query

5. **Step 4: Reconciliation & Final Answer**
   - Instructions for comparing verification vs initial answer
   - Process for identifying and correcting discrepancies
   - Output format for the final verified answer
   - Handling when no errors are found

6. **Output Format Template**
   - Complete markdown template showing expected output structure
   - Sections: Initial Answer, Verification (Q&A pairs), Final Verified Answer
   - Verification notes section for listing corrections

7. **Tool Usage During Verification**
   - Table mapping tools to verification use cases
   - Encourage tool use for authoritative verification

**Reference:** See `.claude/skills/analysis-process/idea-process.md` for workflow formatting conventions.

---

### Task 4: Create Slash Command

**Objective:** Create the `/cove` slash command for invoking the skill.

**Location:** `.claude/commands/cove/cove.md`

**Actions:**
1. Create directory `.claude/commands/cove/`
2. Create `cove.md` command file

**Content requirements:**
- Brief description of the command purpose
- Instruction to invoke the CoVe skill
- Handle `$ARGUMENTS`:
  - If arguments provided: apply CoVe to the given question
  - If no arguments: apply CoVe to verify the previous response
- Reference to the skill for the actual workflow

**Reference:** See `.claude/commands/tm/show/show-task.md` for argument handling example.

---

### Task 5: Verification and Testing

**Objective:** Verify the skill works correctly.

**Test scenarios:**

1. **Slash command with question:**
   ```
   /cove What is the default port for PostgreSQL?
   ```
   Expected: Full CoVe workflow with verification of the port number

2. **Slash command for previous response:**
   ```
   User: How does JavaScript's event loop work?
   Claude: [response]
   User: /cove
   ```
   Expected: CoVe applied to the previous response about event loops

3. **Natural language invocation:**
   ```
   Use chain of verification to answer: What's the memory limit for AWS Lambda?
   ```
   Expected: Skill recognized and invoked

4. **Code verification scenario:**
   ```
   /cove Is this implementation of binary search correct? [code]
   ```
   Expected: Verification questions about edge cases, off-by-one errors, etc.

**Validation criteria:**
- All four steps appear in output
- Verification questions are relevant and targeted
- Independent answers don't simply repeat initial claims
- Final answer acknowledges any corrections made

---

## File Contents Summary

### .claude/skills/cove/SKILL.md

Key elements:
- YAML frontmatter: `name: cove`, `description: ...`
- One paragraph explaining purpose
- Link to cove-process.md
- Brief list of when to use

### .claude/skills/cove/cove-process.md

Key elements:
- Workflow checklist (4 steps)
- Detailed instructions for each step
- Emphasis on independent verification (Step 3)
- Output format template
- Tool usage guidance table

### .claude/commands/cove/cove.md

Key elements:
- Command description
- Skill invocation instruction
- Argument handling (with/without question)
- Brief usage examples

---

## Implementation Notes

### Critical Implementation Details

1. **Independence in Step 3 is crucial**
   - The process file must strongly emphasize answering verification questions without referencing the initial answer
   - This prevents confirmation bias and is the key mechanism for catching errors

2. **Output format consistency**
   - Use the exact markdown format specified in the design
   - Users should be able to easily identify each phase of verification

3. **Tool encouragement**
   - Explicitly encourage using WebSearch, context7, etc. during verification
   - External verification sources strengthen the process

### What NOT to Include

- No code examples in the skill files (this is a prompting technique, not code)
- No modifications to existing skills or CLAUDE.md
- No auto-trigger implementation (that's optional user configuration)
- No commit message templates

### Conventions to Follow

- Match the formatting style of existing skills in `.claude/skills/`
- Use imperative mood in instructions ("Generate verification questions" not "You should generate")
- Keep SKILL.md brief, put details in the process file
- Use markdown formatting consistently (headers, lists, code blocks, tables)
