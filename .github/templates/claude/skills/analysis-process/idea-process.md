### Workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Understand the current state of the project
- [ ] Step 2: Check the documentation
- [ ] Step 3: Help refine the idea/feature
- [ ] Step 4: Describe the design
- [ ] Step 5: Document the design
- [ ] Step 6: Create task-master PRD
- [ ] Step 7: Parse the PRD with research
- [ ] Step 8: Expand the new task into subtasks
- [ ] Step 9: Update the tasks/subtasks to include links to relevant design and implementation plan docs
```

**Step 1: Understand the current state of the project**

To properly refine the idea into a fully-formed design you need to **understand the existing code** in our working directory to know where we're starting off.

**Step 2: Check the documentation**

In order to gain a better understanding of the project, **check the contributing guidelines and any relevant documentation**. For example, take a look at `CONTRIBUTING.md` and `docs` directory.

**Step 3: Help refine the idea/feature**

Once you've become familiar with the project and code, you can start asking me questions, one at a time, to **help refine the idea**.

Ideally, the questions would be multiple choice, but open-ended questions are OK too.

Don't forget: only one question per message!

**Step 4: Describe the design**

Once you believe you understand what we're trying to achieve, stop and **describe the whole design** to me, **in sections of 200-300 words at a time**, **asking after each section whether it looks right so far**.

**Step 5: Document the design**

Document in .md files the entire design and write a comprehensive implementation plan.

Feel free to break out the design/implementation documents into multi-part files, if necessary.

When creating documentation, follow this approach:

- IF this is this a completely new feature - document it in in `/docs/wip/[feature-title]/{design,implementation}.md`.
- ELSE this an improvement or an addition to an existing feature:
  - If the feature is still WIP (documented under `/docs/wip`) - ask the user if you should update the existing design/implementation documents, or create new ones in a sub-directory of the existing feature.
  - Else the feature is completed (documented under root of `/docs`) - create new design/implementation documents in a sub-directory of the existing feature.

**When documenting design and implementation plan**:

- Assume the developer who is going to implement the feature is an experienced and highly-skilled %LANGUAGE% developer, but has zero context for our codebase, and knows almost nothing about our problem domain. Basically - a first-time contributor with a lot of programming experience in %LANGUAGE%.
- **Document everything the developer may need to know**: which files to touch for each task, code structure to be aware of, testing approaches, any potential docs they might need to check. Give them the whole plan as bite-sized tasks.
- **Make sure the plan is unambiguous, detailed and comprehensive** so the developer can adhere to DRY, YAGNI, TDD, atomic/self-contained commits principles when following this plan.

But, of course, **DO NOT:**

- **DO NOT add complete code examples**. The documentation should be a guideline that gives the developer all the information they may need when writing the actual code, not copy-paste code chunks.
- **DO NOT add commit message templates** to tasks, that the developer should use when committing the changes.
- **DO NOT add other small, generic details that do not bring value** and/or are not specifically relevant to this particular feature. For example, adding something like "to run tests, execute: 'go test ./...'" to a task does not bring value. Remember, the developer is experienced and skilled!

**Step 6: Create task-master PRD**

Create a new task-master PRD based on the design.

**Step 7: Parse the PRD with research**

Parse the task-master PRD with research.

**Step 8: Expand the new task into subtasks**

Expand the task-master task into subtasks with links to existing design and implementation documents.

**Step 9: Update the tasks/subtasks to include links to relevant design and implementation plan docs**

After expanding the tasks into subtasks, we need to ensure that tasks also have links to relevant design and implementation plan docs created in Step 5.

Update each parent task's details section with links to relevant docs.
