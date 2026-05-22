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

**3a. Frame the problem.** Restate the idea as a "How Might We" problem statement (format defined in [frameworks.md §HMW](frameworks.md#how-might-we-hmw)). Present to the user for confirmation before proceeding. This anchors all subsequent questions on the problem, not a solution.

**3b. Establish foundations.** Three things must be explicitly answered before advancing to alternatives. Ask one at a time, multiple choice preferred:

1. **Who is this for** — specific user, persona, or role. "Everyone" is not an answer.
2. **What does success look like** — a measurable outcome, not a feature name. "Users can log in" → "Login p99 latency under 500ms with zero-downtime deployment."
3. **Technical/system constraints** — what existing systems, APIs, data stores, infrastructure, or conventions must be respected. What is off-limits to change.

Do not advance to 3c until all three are confirmed.

**3c. Explore alternatives.** Select frameworks from the already-loaded [frameworks.md](frameworks.md) that fit the idea — pick by "Best for" guidance, never run every framework. Before generating alternatives, state which path you are taking and why:

> "This looks like a straightforward single-path problem — I'll propose the direct approach plus one alternative. Want me to explore more broadly instead?"

Two paths:

- **Non-trivial ideas** (multiple valid approaches, significant unknowns, architectural choices): generate 2-3 alternative directions using selected lenses. Present each with a one-sentence trade-off summary.
- **Simple ideas** (single-concern, low-uncertainty, obvious path): propose the direct implementation path plus briefly mention one alternative optimized for a different constraint (e.g., "We could also do X if extensibility matters more than simplicity"). Ask which to proceed with.

Never skip this step silently — the user always sees at least two options. If the user rejects all alternatives, ask what constraint or dimension was missed, then loop back to 3c with that input as an additional lens.

**3d. Converge.** Default: evaluate each direction against the already-loaded [refinement-criteria.md](refinement-criteria.md) (User Value, Feasibility, Differentiation) via manual criteria-based analysis. Present a pros/cons matrix and recommend one direction with a one-line rationale per rejected alternative.

**CoVe for verifiable claims only:** when alternatives make specific factual or codebase claims — "API X supports feature Y", "library Z handles concurrency this way", "the existing auth middleware already does W" — invoke `/kk:chain-of-verification:isolated` to verify those claims. CoVe is fact-check oriented; it is not effective for subjective design trade-offs. Evaluate whether verifiable claims exist, then confirm the verification approach with the user before invoking CoVe.

**CoVe fallback triggers:** if CoVe's verification questions do not reference any specific technical constraint, dependency, or trade-off from the alternatives (i.e., they could apply to any idea), or if CoVe's answers for all alternatives are substantively identical — skip the CoVe results and rely on the manual criteria-based analysis alone. Note the fallback in the design doc.

**3e. Surface assumptions and scope.** Before moving to Step 4, produce and present to the user:

- **Assumptions** — what is baked into the chosen direction but has not been validated. Each should be specific enough to be testable or falsifiable.
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
