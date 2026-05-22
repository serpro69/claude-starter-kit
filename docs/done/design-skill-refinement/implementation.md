# Design Skill Refinement — Implementation Plan

## Prerequisites

- Familiarity with the kk plugin's skill system: `klaude-plugin/skills/<name>/SKILL.md` entry points, process files, shared instructions via symlinks. See [CLAUDE.md — Skill & Command Naming Conventions](../../../CLAUDE.md).
- Understanding of the design skill's current workflow: `klaude-plugin/skills/design/idea-process.md` Steps 1-6, `example-tasks.md` task format, `SKILL.md` mandatory ordering.
- Understanding of the review-design skill: `klaude-plugin/skills/review-design/review-process.md` Steps 1-6.
- Understanding of the `/kk:chain-of-verification:isolated` skill: how it spawns sub-agents, its verification workflow, and how other skills invoke it.
- The source material from addyosmani/agent-skills' idea-refine skill (frameworks.md, refinement-criteria.md) is available in capy under source labels `idea-refine-frameworks` and `idea-refine-criteria`, or can be re-fetched from GitHub.

## Phases

1. **Reference files** — Create frameworks.md and refinement-criteria.md with upstream pinning and license attribution.
2. **Step 3 restructuring** — Rewrite idea-process.md Step 3 into five sub-phases.
3. **Steps 5 and 6 updates** — Add new required sections and task creation guidance to idea-process.md.
4. **Example update** — Rework example-tasks.md with new fields and vertical slice examples.
5. **SKILL.md update** — Update mandatory-order directive, instruction-load step, and conventions.
6. **Review-design update** — Add checks to standard mode, isolated mode, design-reviewer agent, and SKILL.md scope guidance.
7. **Evals** — Spec-style eval scenarios for hard gate, diverge routing, and review-design checks.
8. **Validation** — Run full test suite and verify the flow.

---

## Phase 1: Reference Files

### Task 1.1: Create frameworks.md

**Location:** `klaude-plugin/skills/design/frameworks.md`

**Actions:**

- Identify the current HEAD commit SHA of addyosmani/agent-skills `main` branch (`git ls-remote https://github.com/addyosmani/agent-skills.git HEAD`). Pin this SHA — all fetches use it instead of `main`.
- Fetch the original from GitHub at the pinned SHA: `https://raw.githubusercontent.com/addyosmani/agent-skills/<SHA>/skills/idea-refine/frameworks.md`.
- Add a license/attribution header at the top of the produced file:
  ```
  <!-- Adapted from addyosmani/agent-skills (MIT License, Copyright Addy Osmani)
       Source: https://github.com/addyosmani/agent-skills/blob/<SHA>/skills/idea-refine/frameworks.md
       Pinned at: <SHA> -->
  ```
- Preserve the full structure: one H2 per framework (SCAMPER, HMW, First Principles, JTBD, Constraint Mapping, Pre-mortem, Analogous Inspiration), each with a description, usage guidance, and "Best for" line.
- Light adaptation:
  - Add a brief framing paragraph at the top: these frameworks apply to software engineering features — APIs, infrastructure, developer tools, internal systems, library design — not just consumer products. The goal is to unlock thinking, not follow a checklist.
  - Remove product-specific examples that reference restaurants, startups, delivery platforms, or consumer apps. Replace with brief SE-flavored equivalents where the framework's meaning would be unclear without an example (e.g., for SCAMPER's "Substitute": "What if you swapped the synchronous RPC for an event-driven approach?").
  - Keep the structural definitions, quality criteria, and "Best for" guidance verbatim.
- The file has no frontmatter — it is a reference file loaded by the agent, not a skill entry point.

**Step → verify:** Read the produced file and confirm: all seven frameworks present, no consumer-product examples, "Best for" guidance on each, framing note at top.

### Task 1.2: Create refinement-criteria.md

**Location:** `klaude-plugin/skills/design/refinement-criteria.md`

**Actions:**

- Fetch the original from GitHub at the same pinned SHA used in Task 1.1: `https://raw.githubusercontent.com/addyosmani/agent-skills/<SHA>/skills/idea-refine/refinement-criteria.md`.
- Add the same license/attribution header as Task 1.1 (adjusted source path).
- Preserve the full structure: three evaluation dimensions (User Value, Feasibility, Differentiation) each with questions, red flags, and sub-categories. Plus the MVP Scoping section with its five rules.
- Light adaptation:
  - Same framing approach as frameworks.md — brief SE-context note.
  - Remove consumer examples. Keep the painkiller-vs-vitamin framing (it applies universally). Keep the differentiation ranking (new capability > 10x improvement > ... > cheaper).
  - Keep the value/feasibility matrix table.
  - Keep the "if it's not embarrassing you waited too long" MVP guidance — it applies to internal features too.
- No frontmatter.

**Step → verify:** Read the produced file and confirm: three dimensions present with questions and red flags, MVP scoping section present with five rules, no consumer examples, value/feasibility matrix intact.

---

## Phase 2: Step 3 Restructuring

### Task 2.1: Rewrite idea-process.md Step 3

**Location:** `klaude-plugin/skills/design/idea-process.md`, section headed `**Step 3: Help refine the idea/feature**`

**Actions:**

Replace the current Step 3 body with the five sub-phases. The profile detection block stays in its current position (before questions begin). Structure:

**Step 3: Refine the idea**

Open with the profile detection paragraph (preserved from current Step 3, starting with "Detect active profiles before refining"). Note: frameworks.md and refinement-criteria.md are already loaded during the mandatory instruction-load phase (SKILL.md step 2) — do NOT add a redundant load instruction here.

Then the five sub-phases:

**3a. Frame the problem.** Restate the idea as a "How Might We" problem statement (format defined in frameworks.md §HMW). Present to the user for confirmation before proceeding. This anchors all subsequent questions on the problem, not a solution.

**3b. Establish foundations.** Three things must be explicitly answered before advancing to alternatives. Ask one at a time, multiple choice preferred:
1. Who is this for — specific user, persona, or role. "Everyone" is not an answer.
2. What does success look like — a measurable outcome, not a feature name. "Users can log in" → "Login p99 latency under 500ms with zero-downtime deployment."
3. Technical/system constraints — what existing systems, APIs, data stores, infrastructure, or conventions must be respected. What is off-limits to change.

Do not advance to 3c until all three are confirmed.

**3c. Explore alternatives.** Select frameworks from the already-loaded frameworks.md that fit the idea — pick by "Best for" guidance, never run every framework. Before generating alternatives, state which path the agent is taking and why: "This looks like a straightforward single-path problem — I'll propose the direct approach plus one alternative. Want me to explore more broadly instead?" Two paths:
- **Non-trivial ideas** (multiple valid approaches, significant unknowns, architectural choices): generate 2-3 alternative directions using selected lenses. Present each with a one-sentence trade-off summary.
- **Simple ideas** (single-concern, low-uncertainty, obvious path): propose the direct implementation path plus briefly mention one alternative optimized for a different constraint (e.g., "We could also do X if extensibility matters more than simplicity"). Ask which to proceed with.

Never skip this step silently — the user always sees at least two options. If the user rejects all alternatives, ask what constraint or dimension was missed, then loop back with that input as an additional lens.

**3d. Converge.** Default: evaluate each direction against the already-loaded refinement-criteria.md (User Value, Feasibility, Differentiation) via manual criteria-based analysis. Present a pros/cons matrix and recommend one direction with a one-line rationale per rejected alternative.

CoVe as user-initiated option: when alternatives make specific factual claims about APIs, libraries, or existing code, offer the user an explicit choice — run `/kk:chain-of-verification:isolated` to fact-check, or proceed with criteria-based analysis. The agent does not auto-invoke or auto-skip CoVe; the user decides.

**3e. Surface assumptions and scope.** Before moving to Step 4, produce and present to the user:
- **Assumptions** — what is baked into the chosen direction but has not been validated. Each should be specific enough to be testable or falsifiable.
- **Not Doing** — explicit scope exclusions with a one-line reason each.

Both become first-class artifacts in the design document (Step 5) and tasks.md header (Step 6).

**Interaction style throughout:** one question per message, multiple choice preferred — same as current. The sub-phases add structure to what is asked, not how.

**Step → verify:** Read the rewritten Step 3 and confirm: all five sub-phases present in order, profile detection block preserved in its original position, frameworks.md and refinement-criteria.md referenced by relative link, CoVe invocation instruction present with user confirmation gate, no content-level engagement before instructions are loaded (the mandatory ordering from SKILL.md is respected).

---

## Phase 3: Steps 5 and 6 Updates

### Task 3.1: Update Step 5 in idea-process.md

**Location:** `klaude-plugin/skills/design/idea-process.md`, section headed `**Step 5: Document the design**`

**Actions:**

Add to the "When documenting design and implementation plan" bullet list:

- **Include an Assumptions section** — carried from Step 3e. List assumptions baked into the design, each specific enough to be validated or invalidated during implementation. Assumptions are not caveats — they are testable bets the design depends on.
- **Include a Not Doing section** — carried from Step 3e. Explicit scope exclusions with a one-line rationale each. These are genuine scope decisions, not deferred work items. If something is deferred (will be done later), say so in the implementation plan, not in Not Doing.

These go after the existing documentation guidelines and before the "DO NOT" list.

**Step → verify:** Read Step 5 and confirm: Assumptions and Not Doing requirements present, positioned before the DO NOT list, wording distinguishes scope exclusions from deferrals.

### Task 3.2: Update Step 6 in idea-process.md

**Location:** `klaude-plugin/skills/design/idea-process.md`, section headed `**Step 6: Create the task list**`

**Actions:**

Add to the "Key points" bullet list after the existing bullets:

- **Not Doing in header:** The tasks.md header metadata block includes a `> Not Doing:` line listing the concise scope exclusions from design.md (names only, no extended rationale). The implement skill reads tasks.md first; this puts scope boundaries front and center.
- **Vertical slicing:** Each task delivers one complete, testable user-facing path — not a horizontal layer. Anti-pattern: "Do not create tasks that complete an entire layer (all database work, then all API work, then all UI work) — this defers integration risk to the end." A task like "create all DB models" is wrong; "create user registration end-to-end (model + endpoint + validation + test)" is right.
- **Size tags:** Each task gets a `**Size:** S/M/L` field. S = 1-2 files, M = 3-5 files, L = 5+ files. Size measures complexity, not raw file count — exclude boilerplate registrations, test fixtures, and config entries that are mechanical consequences of the main change. Hard rule: any task tagged L is forbidden as a single task. Break it into smaller vertical slices.
- **Slicing strategies:** Three strategies, noted per-task only when deviating from default:
  - **Vertical** (default): each task delivers one complete path from input to output, testable in isolation.
  - **Contract-First**: define the interface/API boundary first, then implement each side independently. Use when introducing a new external boundary (API, SDK, message queue).
  - **Risk-First**: tackle the most uncertain piece first to surface unknowns early. Use when one task carries significantly more uncertainty than others.
- **Parallel markers:** Each task gets a `**Can run in parallel with:**` field listing task numbers with no blocking dependency, or `—`.
- **Dependency graph:** After all tasks, add a `## Dependency Graph` section with an ASCII diagram showing task relationships. Written once, never updated during implementation.
- **Review scope recommendation:** At the end of Step 6, recommend invoking `/kk:review-design <feature>` as the post-design gate. The default scope already reviews all documents (`design.md + implementation.md + tasks.md`), including the task-format checks.

**Step → verify:** Read Step 6 and confirm: all seven additions present (Not Doing header, vertical slicing with anti-pattern, Size tags with L-forbidden rule, slicing strategies with definitions, parallel markers, dependency graph), existing bullet points preserved.

---

## Phase 4: Example Update

### Task 4.1: Rework example-tasks.md

**Location:** `klaude-plugin/skills/design/example-tasks.md`

**Actions:**

Update the JWT Authentication System example to demonstrate all new fields:

- **Header:** Add `> Not Doing:` line with realistic exclusions (e.g., "OAuth/social login, API rate limiting, token revocation list").
- **Task metadata:** Add `**Size:**` and `**Can run in parallel with:**` fields to each task.
- **Vertical slicing:** Rework the tasks to demonstrate vertical slices. The current Task 1 ("Token generation and validation library") is a pure horizontal layer. Reslice so each task is an end-to-end path. For example:
  - Task 1: "User login end-to-end" — token generation + login endpoint + auth middleware for login route + integration test for the login flow. Size: M.
  - Task 2: "Token refresh end-to-end" — refresh endpoint + token rotation logic + integration test. Size: S. Can run in parallel with Task 1.
  - Task 3: "Protected routes end-to-end" — apply middleware to remaining /api/v1/* routes + rejection tests (no token, expired, malformed). Size: M. Depends on Task 1.
  - Task 4: "Password hashing migration" — unchanged (already vertical: schema + hashing + registration update + test). Blocked status preserved for demonstration. Size: M.
  - Task 5: Final verification — unchanged.
- **Dependency graph:** Add `## Dependency Graph` section at the bottom:
  ```
  Task 1 ─→ Task 3 ─→ Task 5
  Task 2 ─────────────→ Task 5
  Task 4 (blocked) ────→ Task 5
  ```

The example stays a recognizable JWT auth scenario, just resliced to model the vertical approach.

**Step → verify:** Read the produced file and confirm: Not Doing in header, Size and Can run in parallel with on every task, no task larger than M (no L tasks that should be broken down), tasks are vertical slices not horizontal layers, dependency graph at end.

---

## Phase 5: SKILL.md Touch

### Task 5.1: Reference new files in SKILL.md

**Location:** `klaude-plugin/skills/design/SKILL.md`

**Actions:**

Three changes to SKILL.md:

1. **Mandatory-order directive** (the bold paragraph at the top of §Workflow): Update the instruction enumeration from "this SKILL.md, the relevant process file, the shared profile-detection procedure, and every resolved profile's `design/` content" to also include "and (for fresh ideas) the reference files frameworks.md and refinement-criteria.md." The directive defines what counts as "all instructions" — if the new files are not named here, agents may treat them as optional.

2. **Workflow step 2 ("Load instructions"):** Add frameworks.md and refinement-criteria.md to the list of files that must be loaded for the fresh-idea flow. Current text says to read "the relevant process file and the shared profile-detection procedure." Update to: "Read the relevant process file, the shared profile-detection procedure, and (for fresh ideas) the reference files [frameworks.md](./frameworks.md) (ideation lenses) and [refinement-criteria.md](./refinement-criteria.md) (evaluation rubric)."

3. **Conventions section:** Add a sentence noting the reference files' existence and purpose, similar to how it mentions profile `questions.md` and `sections.md`.

**Step → verify:** Read SKILL.md and confirm: mandatory-order directive names the new files, step 2 lists them for the fresh-idea flow, Conventions mentions them.

---

## Phase 6: Review-Design Update

### Task 6.1: Update review-process.md Steps 3 and 4 (standard mode)

**Location:** `klaude-plugin/skills/review-design/review-process.md`

**Actions:**

**Step 3 (Document Quality Review)** — add to the existing checks:

Under the Completeness/Convention adherence bullets, add:

When design.md is in scope:
- Check for an **Assumptions** section. Present? Are assumptions specific and testable (not vague hedges like "the API is fast enough")? Missing section → `STRUCTURE` finding.
- Check for a **Not Doing** section. Present? Are exclusions justified with rationale? Missing section → `STRUCTURE` finding.

When tasks.md is in scope:
- Check for **Not Doing** in header metadata. Missing → `STRUCTURE`.
- Check for **Size tags** on every task. Missing → `STRUCTURE`. Any task tagged L that has not been broken down → `STRUCTURE`.
- Check for **vertical slicing**. Flag tasks that look like horizontal layers — tasks named or scoped as "all models", "all endpoints", "all tests", or that complete an entire architectural layer without delivering a testable user-facing path → `TECH_RISK` (deferred integration risk).
- Check for **parallel markers** (`Can run in parallel with:`) on every task. Missing → `STRUCTURE`.
- Check for **dependency graph** section. Missing → `STRUCTURE`.

**Step 4 (Technical Soundness Review)** — add to the Trade-offs checks:

When design.md Assumptions section is in scope:
- Verify assumptions are specific enough to be testable or falsifiable. "We assume the API is fast enough" → `AMBIGUOUS`. "We assume the external API responds within 200ms at p99 under expected load" → pass.

When design.md Not Doing section is in scope:
- Verify exclusions are genuine scope decisions, not deferred critical requirements disguised as non-goals. If a Not Doing item would block the feature from being usable or shippable, it is not a scope exclusion — it is a deferred critical requirement → `TECH_RISK`.

**Step → verify:** Read review-process.md and confirm: Step 3 has checks for Assumptions, Not Doing, Size, vertical slicing, parallel markers, and dependency graph with correct finding types. Step 4 has testability check for assumptions and validity check for Not Doing exclusions.

### Task 6.2: Update design-reviewer agent

**Location:** `klaude-plugin/agents/design-reviewer.md`

**Actions:**

The design-reviewer agent (used by isolated mode) has its own quality and soundness pass steps (§3 Document Quality Pass, §4 Technical Soundness Pass). These are generic and do not know about the new required sections. Add the same checks from Task 6.1:

- In §3 (Document Quality Pass), under Completeness and Convention adherence: add checks for Assumptions and Not Doing sections in design.md, and task-format checks (Size, vertical slicing, parallel markers, dependency graph, Not Doing header) when tasks.md is in scope.
- In §4 (Technical Soundness Pass), under Trade-offs: add assumptions testability check and Not Doing validity check.

The agent must produce these checks independently — it does not inherit standard mode's review-process.md.

**Step → verify:** Read design-reviewer.md and confirm: §3 has the new quality checks, §4 has the new soundness checks.

### Task 6.3: Update review-design SKILL.md description

**Location:** `klaude-plugin/skills/review-design/SKILL.md`

**Actions:**

Add a note in the invocation section that review-design is the recommended post-design gate after `/kk:design` completes. The default scope already reviews all documents (`design.md + implementation.md + tasks.md`), including task-format checks — no special scope argument is needed.

**Step → verify:** Read review-design SKILL.md and confirm the post-design gate note is present in the invocation section.

---

## Phase 7: Evals

### Task 7.1: Create spec-style evals for design skill

**Location:** `klaude-plugin/skills/design/evals/`

**Actions:**

Per CLAUDE.md §Skill evaluations, create spec-style eval scenarios for the highest-risk new behaviors. Each eval gets its own directory with `eval.json` and `test-files/` as needed:

**Eval 1: hard-gate-enforcement** — Verify the agent does not advance to diverge without all three foundations answered (who, success, constraints).
- Prompt: an idea that naturally invites jumping to solution ("add Redis caching for the API")
- Trap: agent skips the hard gate and proposes a design immediately
- Assertions: HMW framing presented, who/success/constraints each asked before alternatives appear

**Eval 2: proportional-diverge-routing** — Verify the agent classifies complexity correctly and confirms with user.
- Prompt: a simple, single-concern idea ("add a health check endpoint")
- Trap: agent generates full 2-3 alternatives for a trivially simple idea
- Assertions: agent states it's taking the simple path, proposes direct + one alternative, asks if user wants broader exploration

**Eval 3: review-design-catches-missing-sections** — Verify review-design flags missing Assumptions and Not Doing sections.
- Test files: a design.md with no Assumptions section and no Not Doing section, a tasks.md with no Size tags and horizontal-layer tasks
- Prompt: invoke review-design on the test files (default scope covers all documents)
- Assertions: STRUCTURE findings for missing Assumptions and Not Doing, TECH_RISK for horizontal tasks, STRUCTURE for missing Size tags

**Step → verify:** Each eval directory contains eval.json with id, name, description, skills, prompt, trap, files, and assertions fields per the CLAUDE.md schema.

---

## Phase 8: Validation

### Task 8.1: Structure tests and Codex freshness

**Actions:**

- Run `bash test/test-plugin-structure.sh` to validate plugin structure. The new files (frameworks.md, refinement-criteria.md) are not skill entry points and have no frontmatter, so they should not trigger skill-specific assertions. Verify they do not cause test failures.
- If the structure test has assertions about files in skill directories (e.g., every .md must be referenced somewhere), check whether the new reference files need to be accounted for.
- Run `make generate-kodex` to regenerate the Codex plugin from the canonical klaude-plugin source. Then run `git diff --exit-code kodex-plugin/ .codex/agents/` to verify the generated output is fresh. This is required per CLAUDE.md: "After editing skills in `klaude-plugin/`, run `make generate-kodex` to regenerate."

- Run the full test suite per CLAUDE.md: `for test in test/test-*.sh; do $test; done`. This covers test-plugin-structure.sh, test-codex-structure.sh, test-template-sync.sh, and any other test scripts.

**Step → verify:** All test scripts exit 0. `make generate-kodex && git diff --exit-code kodex-plugin/ .codex/agents/` exits 0.

### Task 8.2: Manual flow verification

**Actions:**

- Invoke `/kk:design` with a non-trivial test idea. Verify:
  - Agent loads frameworks.md and refinement-criteria.md during instruction-load phase (before Step 1)
  - HMW framing presented before questions
  - Hard gate enforced (who, success, constraints)
  - Alternatives generated using framework lenses
  - CoVe invocation with user confirmation
  - Assumptions and Not Doing produced before Step 4
  - design.md contains Assumptions and Not Doing sections
  - tasks.md has Not Doing in header, Size tags, parallel markers, vertical slices, dependency graph

- Invoke `/kk:review-design` against the produced design. Verify:
  - Checks for Assumptions and Not Doing sections
  - Checks task format fields (Size, parallel, slicing, graph)
  - Produces appropriate findings for any missing or weak elements

**Step → verify:** Both skills execute the updated flows without errors. review-design catches intentionally omitted sections when tested.
