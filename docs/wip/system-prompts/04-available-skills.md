The following skills are available for use with the Skill tool:

- update-config: Use this skill to configure the Claude Code harness via settings.json. Automated behaviors ("from now on when X", "each time X", "whenever X", "before/after X") require hooks configured in settings.json - the harness executes these, not Claude, so memory/preferences cannot fulfill them. Also use for: permissions ("allow X", "add permission", "move permission to"), env vars ("set X=Y"), hook troubleshooting, or any changes to settings.json/settings.local.json files. Examples: "allow npm commands", "add bq permission to global settings", "move permission to user settings", "set DEBUG=true", "when claude stops show X". For simple settings like theme/model, use Config tool.
- keybindings-help: Use when the user wants to customize keyboard shortcuts, rebind keys, add chord bindings, or modify ~/.claude/keybindings.json. Examples: "rebind ctrl+s", "add a chord shortcut", "change the submit key", "customize keybindings".
- simplify: Review changed code for reuse, quality, and efficiency, then fix any issues found.
- less-permission-prompts: Scan your transcripts for common read-only Bash and MCP tool calls, then add a prioritized allowlist to project .claude/settings.json to reduce permission prompts.
- loop: Run a prompt or slash command on a recurring interval (e.g. /loop 5m /foo, defaults to 10m) - When the user wants to set up a recurring task, poll for status, or run something repeatedly on an interval (e.g. "check the deploy every 5 minutes", "keep running /babysit-prs"). Do NOT invoke for one-off tasks.
- claude-api: Build, debug, and optimize Claude API / Anthropic SDK apps. Apps built with this skill should include prompt caching. Also handles migrating existing Claude API code between Claude model versions (4.5 → 4.6, 4.6 → 4.7, retired-model replacements).
TRIGGER when: code imports `anthropic`/`@anthropic-ai/sdk`; user asks for the Claude API, Anthropic SDK, or Managed Agents; user adds/modifies/tunes a Claude feature (caching, thinking, compaction, tool use, batch, files, citations, memory) or model (Opus/Sonnet/Haiku) in a file; questions about prompt caching / cache hit rate in an Anthropic SDK project.
SKIP: file imports `openai`/other-provider SDK, filename like `*-openai.py`/`*-generic.py`, provider-neutral code, general programming/ML.
- kk:test: Guidelines describing how to test the code.
Use whenever writing new or updating existing code, for example after implementing a new feature or fixing a bug.
- kk:review-code: Code review of current git changes with an expert senior-engineer lens. Detects SOLID violations, security risks, and proposes actionable improvements.
Use when performing code reviews.
- kk:document: After implementing a new feature or fixing a bug, make sure to document the changes.
Use when writing documentation, after finishing the implementation phase for a feature or a bug-fix.
- kk:review-spec: Use after implementing tasks or mid-feature to verify code matches design docs and ensure they are in sync.
Detects spec deviations, missing implementations, doc inconsistencies, and outdated docs in design and implementation documentation.
- kk:implement: TRIGGER when: user asks to work on, implement, or continue tasks from docs/wip (e.g. "work on task 1", "do the next task", "implement first task for X").
Executes written implementation plans with review checkpoints. Use when you have a fully-formed implementation plan to execute in a separate session.
- kk:dependency-handling: TRIGGER when: adding or upgrading a dependency; calling a library, SDK, framework, or external API; unsure how a third-party function behaves; about to guess a signature, config key, or version-specific behavior.
Use BEFORE writing the call — not after it fails. Forces a context7/capy lookup instead of guessing.
- kk:review-design: Review design and implementation docs produced by plan. Evaluates document quality, internal consistency, and technical soundness.
Use after plan completes and before starting implement.
- kk:merge-docs: Compare and merge two design docs for the same feature into a single source of truth.
Use when you have competing or complementary design/implementation docs (e.g. from separate plan runs) that need reconciling into one unified document.
- kk:chain-of-verification: Apply Chain-of-Verification (CoVe) prompting to improve response accuracy through self-verification.
Use when complex questions require fact-checking, technical accuracy, or multi-step reasoning.
- kk:plan: Use in pre-implementation (idea-to-design) stages to understand spec/requirements and create a correct implementation plan before writing actual code.
Turns ideas into a fully-formed PRD/design/specification and implementation-plan. Creates design docs and task lists in docs/wip/.
- skill-creator:skill-creator: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, update or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
- init: Initialize a new CLAUDE.md file with codebase documentation
- review: Review a pull request
- security-review: Complete a security review of the pending changes on the current branch
