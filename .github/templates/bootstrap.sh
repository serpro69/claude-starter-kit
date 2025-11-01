#!/usr/bin/env bash

set -e

cleanup() {
  rm -f "$0"
  git add "$0" CLAUDE.md
  git commit -m "Initialize claude-code"
}

trap cleanup EXIT

claude -p --permission-mode "acceptEdits" /init

cat <<EOF >>CLAUDE.md

## Development Processes

!!! THIS SECTION IS **VERY IMPORTANT** AND **MUST BE FOLLOWED DURING ALL DEVELOPMENT WORK** !!!

### Task Analysis and Implementation Plan

**Goal: Before starting the implementation, make sure you understand the requirements and implementation plan.**

#### Ideas and Prototypes

_Use this for ideas that are not fully thought out and do not have a fully-formed PRD/design/specification/implementation-plan._

**For example:** I've got an idea I want to talk through with you before we proceed with the implementation.

**Your task:** Help me turn it into a fully formed design and spec, and eventually an implementation plan.

- Check out the current state of the project in our working directory to understand where we're starting off.
- Check the contributing guidelines and documentation @./CONTRIBUTING.md and @./docs
- Then ask me questions, one at a time, to help refine the idea. 
- Ideally, the questions would be multiple choice, but open-ended questions are OK, too. Don't forget: only one question per message!
- Once you believe you understand what we're trying to achieve, stop and describe the whole design to me, in sections of 200-300 words at a time, asking after each section whether it looks right so far.
- Then document in .md files the entire design and write a comprehensive implementation plan in @./docs/wip/[feature-title]/{design,implementation}.md . Feel free to break out the design/implementation documents into multi-part files, if necessary.
- When writing documentation:
    - Assume the developer who is going to implement the feature is an experienced and highly-skilled %LANGUAGE% developer, but has zero context for our codebase, and knows almost nothing about or problem domain. Basically - a first-time contributor with a lot of programming experience.
    - Document everything the developer may need to know: which files to touch for each task, code structure to be aware of, testing approaches, any potential docs they might need to check. Give them the whole plan as bite-sized tasks.
    - Make sure the plan is unambiguous, as well as detailed and comprehensive so the developer can adhere to DRY, YAGNI, TDD, atomic/self-contained commits principles when following this plan.
- But of course, **DO NOT:**
    - **DO NOT add complete code examples**. The documentation should be a guideline that gives the developer all the information they may need when writing the actual code, not copy-paste code chunks.
    - **DO NOT add commit message templates** to tasks, that the developer should use when commiting the changes.
    - **DO NOT add other small, generic details that do not bring value** and/or are not specifically relevant to this particular feature. For example, adding something like "to run tests, execute: $(go test ./...)" to a task does not bring value. Remember, the developer is experienced and skilled.

#### Existing task-master tasks

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

### Working with Dependencies

- Always try to use latest versions for dependencies.
- If you are not sure, **do not make assumptions about how external dependencies work**. Always consult documentation.
- Before trying alternative methods, always try to **use context7 MCP to lookup documentation for external dependencies** like libraries, SDKs, APIs and other external frameworks, tools, etc.
    - **IMPORTANT! Always make sure that documentation version is the same as declared dependency version itself.**
    - Only revert to web-search or other alternative methods if you can't find documentation in context7.

### Testing & Quality Assurance

- Always try to add tests for any new functionality, and make sure to cover all cases and code branches, according to requirements.
- Always try to add tests for any bug-fixes, if the discovered bug is not already covered by tests. If the bug was already covered by tests, fix the existing tests.
- Always run all tests after you are done with a given implementation

Use the following guidelines when working with tests:

- Comprehensive testing
- Table-/Data-driven tests and test generation
- Benchmark tests and performance regression detection
- Integration testing with test containers
- Mock generation with %LANGUAGE% best practices and well-establised %LANGUAGE% mocking tools
- Property-based testing with %LANGUAGE% best practices and well-establised %LANGUAGE% testing tools
- End-to-end testing strategies
- Code coverage analysis and reporting

### Documentation

- After completing a new feature, always see if you need to update the Architecture documentation @./docs/contributing/ARCHITECTURE.md and Test documentation @./docs/contributing/TESTING.md for other developers, so anyone could easily pick up the work and understand the project and the feature that was added.
- If the code change included prior decision-making out of several alternatives, document an ADR in @./docs/adr for any non-trivial/-obvious decisions that should be preserved.

## Task Master AI Instructions

**IMPORTANT!!! Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**

@./.taskmaster/CLAUDE.md
EOF

printf "\n"
printf "🤖 Done initializing claude-code; committing CLAUDE.md file to git and cleaning up bootstrap script...\n"
printf "🚀 Your repo is now ready for AI-driven development workflows... Have fun!\n"
