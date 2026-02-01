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

### Task 6: Create Isolated Mode Workflow

**Objective:** Create the isolated verification workflow that uses sub-agents for true factored verification.

**Location:** `.claude/skills/cove/cove-isolated.md`

**Content sections:**

1. **Workflow Checklist**
   - Same 4-step structure as standard mode
   - Note that Step 3 uses sub-agents

2. **Step 1-2: Same as Standard Mode**
   - Generate initial answer
   - Generate verification questions

3. **Step 3: Isolated Verification with Sub-Agents**
   - Instructions for parsing flags from arguments (`--explore`, `--haiku`, `--agent=<name>`)
   - Sub-agent prompt template (question only, no initial answer context)
   - Instructions to spawn sub-agents in parallel using Task tool
   - Each Task call must include:
     - `subagent_type`: from flags or default `general-purpose`
     - `model`: from flags if `--haiku` specified
     - `prompt`: Sub-agent prompt with verification question
     - `description`: Short description for tracking
   - Instructions for collecting and formatting sub-agent responses

4. **Step 4: Reconciliation**
   - Same as standard mode but with sub-agent metadata
   - Include agent type and status in output

5. **Output Format Template**
   - Extended template showing agent info and sources
   - Reconciliation table format
   - Verification notes with isolation method

6. **Error Handling**
   - Sub-agent timeout: Mark as "Inconclusive"
   - Sub-agent failure: Fall back to standard mode for that question
   - All failures: Suggest using `/cove` instead

**Key difference from cove-process.md:** Step 3 spawns isolated sub-agents instead of using prompt-based isolation.

---

### Task 7: Create Isolated Mode Command

**Objective:** Create the `/cove-isolated` slash command.

**Location:** `.claude/commands/cove/cove-isolated.md`

**Content requirements:**

1. **Description**
   - Explain this is the isolated verification mode
   - Mention sub-agents and true context isolation

2. **Flag Parsing Instructions**
   - Check for flags at start of `$ARGUMENTS`
   - Supported flags: `--explore`, `--haiku`, `--agent=<name>`
   - Extract flags and remaining question
   - Document flag combinations

3. **Invocation**
   - Invoke the `cove` skill with `cove-isolated.md` workflow
   - Pass parsed flags to workflow

4. **Examples**
   ```
   /cove-isolated What is the default port for PostgreSQL?
   /cove-isolated --explore How does the auth middleware work?
   /cove-isolated --haiku What is TCP?
   /cove-isolated --agent=my-verifier What is X?
   /cove-isolated --haiku --explore What pattern does this codebase use?
   ```

---

### Task 8: Update SKILL.md for Dual Modes

**Objective:** Update the skill entry point to document both verification modes.

**Location:** `.claude/skills/cove/SKILL.md`

**Changes:**
- Add section explaining the two modes
- Document when to use each mode
- Reference both `cove-process.md` and `cove-isolated.md`
- Update "When to Use" section to include isolated mode recommendations

---

### Task 9: Isolated Mode Testing

**Objective:** Verify isolated mode works correctly.

**Test scenarios:**

1. **Basic isolated verification:**
   ```
   /cove-isolated What is the default port for PostgreSQL?
   ```
   Expected: Sub-agents spawned, output shows agent metadata, true isolation achieved

2. **With --explore flag:**
   ```
   /cove-isolated --explore How does error handling work in this codebase?
   ```
   Expected: Uses Explore sub-agents for codebase verification

3. **With --haiku flag:**
   ```
   /cove-isolated --haiku What is the speed of light?
   ```
   Expected: Uses haiku model for faster/cheaper verification

4. **With custom agent:**
   ```
   /cove-isolated --agent=general-purpose What is X?
   ```
   Expected: Uses specified agent type

5. **Combined flags:**
   ```
   /cove-isolated --haiku --explore How does auth work?
   ```
   Expected: Uses Explore agent with haiku model

6. **Error handling:**
   - Test sub-agent timeout behavior
   - Test graceful degradation to standard mode

**Validation criteria:**
- Sub-agents receive only the verification question (no initial answer context)
- Sub-agents run in parallel
- Output includes agent metadata and sources
- Reconciliation table present
- Errors handled gracefully

---

## File Contents Summary

### .claude/skills/cove/SKILL.md

Key elements:
- YAML frontmatter: `name: cove`, `description: ...`
- One paragraph explaining purpose
- Section explaining both verification modes
- Links to both `cove-process.md` and `cove-isolated.md`
- When to use each mode

### .claude/skills/cove/cove-process.md (Standard Mode)

Key elements:
- Workflow checklist (4 steps)
- Detailed instructions for each step
- Emphasis on independent verification (Step 3) using prompt-based isolation
- Output format template
- Tool usage guidance table

### .claude/skills/cove/cove-isolated.md (Isolated Mode)

Key elements:
- Workflow checklist (4 steps)
- Same Steps 1-2 as standard mode
- Step 3: Sub-agent spawning with Task tool
- Flag parsing instructions (`--explore`, `--haiku`, `--agent=<name>`)
- Sub-agent prompt template
- Parallel execution instructions
- Extended output format with agent metadata
- Error handling guidance

### .claude/commands/cove/cove.md (Standard Mode)

Key elements:
- Command description
- Skill invocation instruction
- Argument handling (with/without question)
- Brief usage examples

### .claude/commands/cove/cove-isolated.md (Isolated Mode)

Key elements:
- Command description (emphasizes sub-agent isolation)
- Flag parsing instructions
- Supported flags: `--explore`, `--haiku`, `--agent=<name>`
- Examples with various flag combinations
- Reference to `cove-isolated.md` workflow

---

## Implementation Notes

### Critical Implementation Details

1. **Independence in Step 3 is crucial**
   - Standard mode: The process file must strongly emphasize answering verification questions without referencing the initial answer
   - Isolated mode: Sub-agents physically cannot see the initial answer (true isolation)
   - This prevents confirmation bias and is the key mechanism for catching errors

2. **Output format consistency**
   - Use the exact markdown format specified in the design
   - Users should be able to easily identify each phase of verification
   - Isolated mode output includes additional agent metadata

3. **Tool encouragement**
   - Explicitly encourage using WebSearch, context7, etc. during verification
   - External verification sources strengthen the process
   - Sub-agents in isolated mode should prioritize tool use

### Isolated Mode Implementation Details

1. **Sub-agent prompt must be minimal**
   - Only include the verification question
   - Do NOT include: initial answer, other verification questions, conversation context
   - Include instructions to use tools and cite sources

2. **Parallel execution is essential**
   - All sub-agent Task calls must be in a single message
   - This minimizes latency from sequential spawning
   - Collect all results before proceeding to reconciliation

3. **Flag parsing must be robust**
   - Flags appear before the question: `--flag1 --flag2 question text`
   - Support `--agent=value` format for custom agents
   - Unknown flags should be ignored (passed as part of question)

4. **Error handling must be graceful**
   - Individual sub-agent failures shouldn't abort the entire verification
   - Mark failed verifications as "Inconclusive"
   - If all sub-agents fail, suggest using standard mode

### What NOT to Include

- No code examples in the skill files (this is a prompting technique, not code)
- No modifications to existing skills or CLAUDE.md
- No auto-trigger implementation (that's optional user configuration)
- No commit message templates

### Conventions to Follow

- Match the formatting style of existing skills in `.claude/skills/`
- Use imperative mood in instructions ("Generate verification questions" not "You should generate")
- Keep SKILL.md brief, put details in the process files
- Use markdown formatting consistently (headers, lists, code blocks, tables)
- Isolated mode workflow mirrors standard mode structure where possible
