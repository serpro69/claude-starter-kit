---
name: analysis-process
description: Turn the idea for a feature into a fully-formed PRD/design/specification and implementation-plan. Use in pre-implementation (idea-to-design) stages to make sure you understand the requirements and have a correct implementation plan before writing actual code.
---

# Task Analysis Process

**Goal: Before starting the implementation, make sure you understand the requirements and implementation plan.**

## Ideas and Prototypes

_Use this for ideas that are not fully thought out and do not have a fully-formed PRD/design/specification and/or implementation-plan._

**For example:** I've got an idea I want to talk through with you before we proceed with the implementation.

**Your task:** Help me turn it into a fully formed design and spec, and eventually an implementation plan.

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

Document in .md files the entire design and write a comprehensive implementation plan in `/docs/wip/[feature-title]/{design,implementation}.md`. Feel free to break out the design/implementation documents into multi-part files, if necessary.

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

## Existing task-master tasks

_For tasks that already exist in task-master._

**For example:** Let's work on task 6 next.

**Your task:** Make sure the task is well-documented and you understand the requirements and how to implement it. Then implement the task.

- Get the task from task-master
- Does it have linked documentation for the design and implementation plan?
    - **YES:**
        - Read the design and implementation documentation and understand what needs to be done and how.
        - Check the contributing guidelines and documentation @./CONTRIBUTING.md , @./docs/contributing/ARCHITECTURE.md , and @./docs/contributing/TESTING.md
        - Then proceed with implementing the task.
    - **NO:**
        - Follow the [Ideas and Prototypes](#ideas-and-prototypes) section.
        - Instead of creating a new task as the last step, update the existing task with necessary information.
