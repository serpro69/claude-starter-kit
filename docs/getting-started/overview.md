# Overview

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)

claude-toolbox is a collection of "tools" for all your agentic workflows (**currently supports claude-code and codex!**) — pre-configured MCP servers, skills, sub-agents, commands, hooks, statuslines with themes, and more — everything you need for AI-powered development workflows, used and battle-tested daily on many of my own projects.

!!! important
    This project was created with the help of Claude-Code. It is, however, always reviewed, tested, and reworked with a human-in-the-loop.

    No AI slop here. Purely AI-made skills are hot garbage, and that's putting it mildly.

    That said, if you have any problems with code that is written by AI — you've been warned. But, then again, why would you be interested in AI-related configs and skills in the first place... `¯\_(ツ)_/¯`

## Why claude-toolbox?

Tools like Claude Code and Codex are powerful on their own, but LLMs don't know your development workflow. This project started as a way to streamline configurations across projects without copy-paste. Over time, recurring patterns evolved into skills and agents.

**A minimal, opinionated configuration** — sensible permission baselines, a rich statusline, MCP server wiring, and sync infrastructure to keep it all up to date across your projects. Think of it as a dotfiles repo for Claude Code and Codex.

**A structured development pipeline** — 10 workflow skills with explicit multi-language support that take you from idea through design, implementation, code review, testing, to documentation, with persistent knowledge that carries across sessions.

```
/design → /review-design → /implement → /review-code → /test → /document
```

## Features at a Glance

- **10 workflow skills** — a complete development pipeline invoked as `/kk:<skill-name>`, with many skills integrated with each other
- **Multi-language support** — precise and distinct instructions from design, to implementation, to testing, to review for: Go, Java, JS/TS, Kotlin, Kubernetes, and Python
- **Multi-model code review** — independent reviewers using sub-agents and external models (Gemini, etc.)
- **Persistent knowledge base** — findings, decisions, and conventions that survive across sessions via Capy
- **Up-to-date library docs** — always-current documentation lookup via Context7
- **Battle-tested configuration** — permissions, statusline themes, hooks, sensible defaults

## What's Included

### kk Plugin

The **kk** plugin contains all development workflow functionality — 10 skills, 4 commands, and hooks — distributed via the Claude Code plugin system (see [kodex-plugin](https://github.com/serpro69/claude-toolbox/tree/master/kodex-plugin) for the Codex variant). Skills are invoked as `/kk:skill-name`, commands as `/kk:dir:command`.

Alongside `skills/`, `commands/`, `agents/`, and `hooks/`, the plugin ships a top-level `profiles/` directory. Each profile (e.g., `go`, `python`, `k8s`) bundles per-domain content — detection rules, review checklists, design prompts, test validators, doc rubrics — that the workflow skills consult when the code under work matches the profile. Profiles are the extension point for new languages and IaC DSLs.

### Configuration

- **Permission allowlist/denylist** (`.claude/settings.json`) — baseline permissions: auto-approves safe bash commands and WebSearch while blocking dangerous patterns. Per-repo MCP tool permissions go in `settings.local.json`.
- **Status line** (`.claude/toolbox/scripts/statusline_enhanced.sh`) — rich statusline with model, context %, git branch, session duration, thinking mode, and rate limits. Themes: set `CLAUDE_STATUSLINE_THEME` to `darcula`, `nord`, or `catppuccin`, and `CLAUDE_STATUSLINE_MODE` to `dark` (default) or `light` to match your terminal background.

### Template Infrastructure

- **template-cleanup** — GitHub Action or local CLI script to initialize a new repo from this template
- **template-sync** — pull upstream configuration updates via PR (workflow) or locally (`/kk:template:sync`)
- **Sync exclusions** — prevent specific files from being re-added during sync
- **Test suite** — tests across 8 suites covering plugin structure, codex structure, sync/cleanup infrastructure

## Requirements

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the AI coding assistant this toolbox extends
- **[npm](https://www.npmjs.com/package/npm)** — used by some MCP server installations
- **[uv](https://docs.astral.sh/uv/)** — Python package runner for Pal MCP server
- **[jq](https://jqlang.github.io/jq/)** — JSON processor, required for template-cleanup

### API Keys

- [Context7](https://context7.com/) API key — for library documentation lookups
- Gemini API key for [Pal](https://github.com/serpro69/pal-mcp-server) (or [any other provider](https://github.com/serpro69/pal-mcp-server/blob/main/docs/getting-started.md)) — for multi-model code review

## Examples

Examples of actual Claude Code workflows executed using this template's configs, skills, and tools: [examples/](https://github.com/serpro69/claude-toolbox/tree/master/examples)
