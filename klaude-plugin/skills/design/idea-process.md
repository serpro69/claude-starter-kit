### Workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Understand the current state of the project
- [ ] Step 2: Check the documentation
- [ ] Step 3: Refine the idea
- [ ] Step 4: Describe the design
- [ ] Step 5: Document the design
- [ ] Step 6: Create the task list
```

**Step 1: Understand the current state of the project**

To properly refine the idea into a fully-formed design you need to **understand the existing code** in our working directory to know where we're starting off.

**Step 2: Check the documentation**

In order to gain a better understanding of the project, **check the contributing guidelines and any relevant documentation**. For example, take a look at `CONTRIBUTING.md` and `docs` directory.

**Capy search:** Before refining the idea, search `kk:arch-decisions` and `kk:project-conventions` for prior design context related to the feature area being discussed.

**Step 3: Refine the idea**

**Detect active profiles before refining.** The design phase runs before any code exists, so file-based detection is impossible. Run the design interaction pattern from [shared-profile-detection.md §The `/kk:design` interaction pattern](shared-profile-detection.md) — it iterates all profiles with `## Design signals`, matches their declared tokens against the idea prose, and handles confirmation prompts. Never auto-activate a profile silently.

For each active profile, use the `Read` tool on `<plugin_root>/profiles/<name>/design/index.md` — where `<plugin_root>` is the absolute plugin-root path you already know from SKILL.md context. Skip silently if absent; not every profile populates a `design/` subdirectory. Load every file listed under **Always load**; a profile's `questions.md` (when present) seeds the refinement question pool. Integrate the profile's questions into the sub-phases below — one question per message, as always.

Note: [frameworks.md](frameworks.md) and [refinement-criteria.md](refinement-criteria.md) are already loaded during the mandatory instruction-load phase (SKILL.md step 2). Do not reload them here.

**Interaction style throughout:** one question per message, multiple choice preferred. Open-ended questions are OK too. The sub-phases below add structure to _what_ is asked, not _how_.

**Step 3 Progress:**
- [ ] 3a HMW framing confirmed
- [ ] 3b who/persona confirmed
- [ ] 3b success metric confirmed
- [ ] 3b constraints confirmed
- [ ] 3c complexity classification confirmed
- [ ] 3c alternatives presented
- [ ] 3d direction chosen
- [ ] 3e assumptions and Not Doing presented

**3a. Frame the problem.** Restate the idea as a rough "How Might We" problem statement — a directional anchor, not a fully specified template. Use [frameworks.md §HMW](frameworks.md#how-might-we-hmw) for format quality guidance (good vs bad HMW qualities), but do not attempt to fill every slot (specific user, key constraint) yet — those come from 3b. Present the framing to the user for confirmation or correction before proceeding. This anchors all subsequent questions on the problem, not a solution.

**3b. Establish foundations.** Three things must be explicitly answered before advancing to alternatives. Ask one at a time, multiple choice preferred:

1. **Who is this for** — specific user, persona, or role. "Everyone" is not an answer.
2. **What does success look like** — a measurable outcome, not a feature name. "Users can log in" → "Login p99 latency under 500ms with zero-downtime deployment."
3. **Technical/system constraints** — what existing systems, APIs, data stores, infrastructure, or conventions must be respected. What is off-limits to change.

Do not advance to 3c until all three are confirmed.

**3c. Explore alternatives.** Select frameworks from the already-loaded [frameworks.md](frameworks.md) that fit the idea — pick by "Best for" guidance, never run every framework.

Classify the idea before generating alternatives. **Non-trivial** if it involves architectural choices, multiple valid implementation approaches, or significant unknowns. **Simple** if the implementation path is singular and the main decisions are parameter-level. State which classification and why, then confirm with the user:

- **For simple ideas:**
  > "This looks like a straightforward single-path problem — I'll propose the direct approach plus one alternative. Want me to explore more broadly instead?"
- **For non-trivial ideas:**
  > "This has multiple valid approaches with real trade-offs — I'll explore 2-3 alternative directions using [selected frameworks] and summarize their trade-offs. Sound right, or should I narrow the focus?"

Two paths:

- **Non-trivial ideas** (multiple valid approaches, significant unknowns, architectural choices): generate 2-3 alternative directions using selected lenses. Present each with a one-sentence trade-off summary.
- **Simple ideas** (single-concern, low-uncertainty, obvious path): propose the direct implementation path plus briefly mention one alternative optimized for a different constraint (e.g., "We could also do X if extensibility matters more than simplicity"). Ask which to proceed with.

Never skip this step silently — the user always sees at least two options. If the user rejects all alternatives, ask what constraint or dimension was missed, then loop back to 3c with that input as an additional lens.

**3d. Converge.** Evaluate each direction against the already-loaded [refinement-criteria.md](refinement-criteria.md) (User Value, Feasibility, Differentiation) via criteria-based analysis. Present a pros/cons matrix and recommend one direction with a one-line rationale per rejected alternative.

If alternatives make specific factual claims about APIs, libraries, or existing code, offer the user an explicit choice: "Some of these alternatives make specific technical claims I can fact-check. Want me to run `/kk:chain-of-verification:isolated` to verify them, or should I proceed with the analysis as-is?" Let the user decide — do not auto-invoke or auto-skip CoVe.

**3e. Surface assumptions and scope.** Before moving to Step 4, produce and present to the user:

- **Assumptions** — what is baked into the chosen direction but has not been validated. Each assumption should be specific enough to be testable or falsifiable — not vague hedges like "the API is fast enough."
- **Not Doing** — explicit scope exclusions with a one-line reason each.

Both become first-class artifacts in the design document (Step 5) and tasks.md header (Step 6).

**Step 4: Describe the design**

Once you believe you understand what we're trying to achieve, stop and **describe the whole design** to me, **in sections of 200-300 words at a time**, **asking after each section whether it looks right so far**.

**If the design recommends a specific library, SDK, framework, or API** — especially one not already in use in this project — apply the `/kk:dependency-handling` skill BEFORE committing to that recommendation. Verifying behavior against context7 at design time prevents proposing something that doesn't actually work the way you assumed.

**Step 5: Document the design**

Document in .md files the entire design and write a comprehensive implementation plan.

Feel free to break out the design/implementation documents into multi-part files, if necessary.

**For each active profile** (from Step 3), re-consult `<plugin_root>/profiles/<name>/design/index.md` (using the same resolved plugin-root path you used in Step 3) and apply every always-load entry whose content shapes the final design document. Profile-contributed `sections.md` (when present) names required sections the design document must cover. Do not drop a required section silently; if a section genuinely does not apply, state so explicitly with a one-line justification.

When creating documentation, follow this approach:

- IF this is this a completely new feature - document it in in `/docs/wip/[feature-title]/{design,implementation}.md`.
- ELSE this an improvement or an addition to an existing feature:
  - If the feature is still WIP (documented under `/docs/wip`) - ask the user if you should update the existing design/implementation documents, or create new ones in a sub-directory of the existing feature.
  - Else the feature is completed (documented under root of `/docs`) - create new design/implementation documents in a sub-directory of the existing feature.

**When documenting design and implementation plan**:

- Assume the developer who is going to implement the feature is an experienced and highly-skilled %LANGUAGE% developer, but has zero context for our codebase, and knows almost nothing about our problem domain. Basically - a first-time contributor with a lot of programming experience in %LANGUAGE%.
- **Document everything the developer may need to know**: which files to touch for each task, code structure to be aware of, testing approaches, any potential docs they might need to check. Give them the whole plan as bite-sized tasks.
- **Make sure the plan is unambiguous, detailed and comprehensive** so the developer can adhere to DRY, YAGNI, TDD, atomic/self-contained commits principles when following this plan.
- **Pair each step with an explicit verification.** Every implementation step should name *how the developer will know it worked* — a specific test to run, a command whose output to check, or an observable behavior. Use the form `Step → verify: <check>`. Steps without a verification are a smell: either the step is too vague, or the work isn't really done when the step is.
- **Include an Assumptions section** — carried from Step 3e. List assumptions baked into the design, each specific enough to be validated or invalidated during implementation. Assumptions are not caveats — they are testable bets the design depends on.
- **Include a Not Doing section** — carried from Step 3e. Explicit scope exclusions with a one-line rationale each. These are genuine scope decisions, not deferred work items. If something is deferred (will be done later), say so in the implementation plan, not in Not Doing.

But, of course, **DO NOT:**

- **DO NOT add complete code examples**. The documentation should be a guideline that gives the developer all the information they may need when writing the actual code, not copy-paste code chunks.
- **DO NOT add commit message templates** to tasks, that the developer should use when committing the changes.
- **DO NOT add other small, generic details that do not bring value** and/or are not specifically relevant to this particular feature. For example, adding something like "to run tests, execute: 'go test ./...'" to a task does not bring value. Remember, the developer is experienced and skilled!

**Capy index:** After documenting the design, index key architecture decisions and trade-offs as `kk:arch-decisions`. Only index non-obvious rationale — skip if the decisions are self-evident from the docs themselves.

**Step 6: Create the task list**

Based on the implementation plan documented in Step 5, create a `tasks.md` file in the same `/docs/wip/[feature-title]/` directory.

Follow the structure and conventions in the [example task file](./example-tasks.md). Key points:

- **Header metadata** links back to design/implementation docs and tracks overall feature status
- **One H2 per task** with status, dependencies, and a link to the relevant docs section
- **Checkbox subtasks** are concrete, actionable implementation steps — specific enough that a developer with no project context can follow them
- **Subtask descriptions** name the file/function/component being touched and what to do with it — not vague ("implement auth") but precise ("create `internal/auth/token.go` with `GenerateToken` and `ValidateToken` functions")
- **Dependencies** reference other tasks by number when ordering matters
- **Status values:** `pending`, `in-progress`, `done`, `blocked` (with reason)
- Tasks should map roughly 1:1 to atomic, self-contained commits
- **Always include a final verification task** that depends on all other tasks — it should invoke `/kk:test` to run the full test suite, `/kk:document` to update any relevant docs, `/kk:review-code` with project's language input to review the code, and `/kk:review-spec` to verify the implementation matches the design and implementation docs
- **Not Doing in header:** The tasks.md header metadata block includes a `> Not Doing:` line listing the concise scope exclusions from design.md (names only, no extended rationale). The implement skill reads tasks.md first; this puts scope boundaries front and center.
- **Vertical slicing:** Each task delivers one complete, testable user-facing path — not a horizontal layer. Anti-pattern: "Do not create tasks that complete an entire layer (all database work, then all API work, then all UI work) — this defers integration risk to the end." A task like "create all DB models" is wrong; "create user registration end-to-end (model + endpoint + validation + test)" is right.
- **Size tags:** Each task gets a `**Size:** S/M/L` field. S = 1-2 files, M = 3-5 files, L = 5+ files. Size measures complexity, not raw file count — exclude boilerplate registrations, test fixtures, and config entries that are mechanical consequences of the main change. Hard rule: any task tagged L is forbidden as a single task. Break it into smaller vertical slices.
- **Slicing strategies:** Three strategies, noted per-task only when deviating from default:
  - **Vertical** (default): each task delivers one complete path from input to output, testable in isolation.
  - **Contract-First**: define the interface/API boundary first, then implement each side independently. Use when introducing a new external boundary (API, SDK, message queue).
  - **Risk-First**: tackle the most uncertain piece first to surface unknowns early. Use when one task carries significantly more uncertainty than others.
- **Parallel markers:** Each task gets a `**Can run in parallel with:**` field listing task numbers with no blocking dependency, or `—`.
- **Dependency graph:** After all tasks, add a `## Dependency Graph` section with an ASCII diagram showing task relationships. Written once, never updated during implementation.

At the end of Step 6, recommend invoking `/kk:review-design <feature>` as the post-design gate. The default scope reviews all documents (`design.md + implementation.md + tasks.md`), including the task-format checks.
