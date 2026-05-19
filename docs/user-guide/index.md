# User Guide

Learn how to use claude-toolbox's features effectively.

## Core Concepts

| Topic | Description |
|-------|-------------|
| [Skills](skills.md) | The 10 workflow skills and how they chain together |
| [Profiles](profiles.md) | Language-specific content for Go, Java, JS/TS, Kotlin, K8s, Python |
| [MCP Servers](mcp-servers.md) | Context7, Pal, and Capy — the knowledge stack |
| [Configuration](configuration.md) | Settings, permissions, statusline, and hooks |
| [Template Sync](template-sync.md) | Receiving upstream updates and managing sync |

## The Pipeline

```
/kk:design → /kk:review-design → /kk:implement → /kk:review-code → /kk:test → /kk:document
```

Each skill produces artifacts the next one consumes. See [Skills](skills.md) for the full breakdown.
