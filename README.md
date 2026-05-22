# claude-toolbox

[![GitHub Release](https://img.shields.io/github/v/release/serpro69/claude-toolbox?style=for-the-badge)](https://github.com/serpro69/claude-toolbox/releases)
[![Mentioned in Awesome Claude Code](https://img.shields.io/badge/Awesome-Claude%20Code-fc60a8?style=for-the-badge&logo=awesomelists&logoColor=white)](https://github.com/hesreallyhim/awesome-claude-code)
[![Documentation](https://img.shields.io/badge/docs-serpro69.github.io%2Fclaude--toolbox-blue?style=for-the-badge)](https://serpro69.github.io/claude-toolbox/)

claude-toolbox is a collection of "tools" for all your agentic workflows — pre-configured MCP servers, skills, sub-agents, commands, hooks, statuslines with themes, and more - everything you need for AI-powered development workflows, used and battle-tested daily on many of my own projects.

**Supported providers:** [Claude Code](https://serpro69.github.io/claude-toolbox/latest/providers/claude-code/) · [Codex](https://serpro69.github.io/claude-toolbox/latest/providers/codex/)

<div align="center">

## [Read the full documentation →](https://serpro69.github.io/claude-toolbox/)

</div>

> [!IMPORTANT]
> This project was created with the help of Claude-Code. Is it, however, always reviewed, tested, and reworked with a human-in-the-loop.
>
> No AI slop here. Purely AI-made skills are hot garbage, and that's putting it mildly.
>
> That said, if you have any problems with code that is written by AI - you've been warned. But, then again, why would you be interested in AI-related configs and skills in the first place... `¯\_(ツ)_/¯`

<img width="3440" height="521" alt="image" src="https://github.com/user-attachments/assets/27ef7269-0153-47c0-b07d-ed6a9504a176" />

## Why claude-toolbox?

Tools like Claude Code and Codex are powerful on their own, but LLMs don't know your development workflow. This project started as a way for me to streamline claude configurations across all my projects without needing to copy-paste things. With time, patterns and re-curring prompts evolved into skills and agents. Currently, claude-toolbox gives you two things:

**A minimal, opinionated Claude Code and Codex configuration** — sensible permission baselines, a rich statusline, MCP server wiring, and sync infrastructure to keep it all up to date across your projects. Think of it as a dotfiles repo for Claude Code and Codex.

**A structured development pipeline** — 11 workflow skills with explicit multi-language support that take you from idea through design, implementation, code review, testing, to documentation, with persistent knowledge that carries across sessions.

```
/kk:design → /kk:review-design → /kk:implement → /kk:review-code → /kk:test → /kk:document
```

Out of the box you get:

- **11 workflow skills** — a complete development pipeline invoked as `/kk:<skill-name>`, with many skills integrated with each other.
- **Multi-language support** — precise and distinct instructions from design, to implementation, to testing, to review for: go, java, js/ts, kotlin, kubernetes, and python
- **Multi-model code review** — independent reviewers using sub-agents and external models (Gemini, etc.)
- **Persistent knowledge base** — findings, decisions, and conventions that survive across sessions via Capy
- **Up-to-date library docs** — always-current documentation lookup via Context7
- **Battle-tested configuration** — permissions, statusline themes, hooks, sensible defaults

## Choose Your Path

**Starting a new project?** Use the template — you get the full configuration and plugin pre-wired, plus sync infrastructure to pull future updates.
→ [Template Setup](https://serpro69.github.io/claude-toolbox/latest/getting-started/template-setup/)

**Existing project, want the full setup?** Adopt the configuration, plugin, and sync infrastructure without creating from the template.
→ [Adopting into Existing Repositories](https://serpro69.github.io/claude-toolbox/latest/getting-started/adopting/)

**Just want the skills?** Install the kk plugin — no template needed.
→ [Plugin-Only Setup](https://serpro69.github.io/claude-toolbox/latest/getting-started/plugin-only/)

## Try It

After setup, try the core workflow:

1. **Start with an idea.** Type `/kk:design` and describe a feature you want to build. Claude will ask you refinement questions one at a time, then produce design docs and a task list in `docs/wip/`.

2. **Review the design.** Run `/kk:review-design your-feature` to catch gaps before writing code.

3. **Build it.** Type `/kk:implement` — Claude executes the task list with code review checkpoints between batches.

4. **Review the code.** `/kk:review-code` checks for SOLID violations, security risks, and quality issues. Use `/kk:review-code:isolated` for independent sub-agent reviewers with zero authorship bias.

This is the core loop. See the [Skills documentation](https://serpro69.github.io/claude-toolbox/latest/user-guide/skills/) for all available skills and the full workflow pipeline.

## Examples

Examples of actual Claude Code workflows executed using this template's configs, skills, and tools: [examples/](./examples)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines, [Architecture](https://serpro69.github.io/claude-toolbox/latest/contributing/architecture/) for how components fit together, and [Testing](https://serpro69.github.io/claude-toolbox/latest/contributing/testing/) for test conventions.

## License

Copyright &copy; 2025 - present, [serpro69](https://github.com/serpro69)

Distributed under the ELv2 License.

See [`LICENSE.md`](https://github.com/serpro69/claude-toolbox/blob/master/LICENSE.md) file for more information.
