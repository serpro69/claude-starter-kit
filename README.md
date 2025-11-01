# claude-starter-kit

Starter template repo for all your Claude Code needs

## Features

**TODO**

## Requirements

You will need the following on your workstation:

### Tools

- [npm](https://www.npmjs.com/package/npm)
- [uv](https://docs.astral.sh/uv/)

### API Keys

- [Context7](https://context7.com/) API key
- Gemini API key for [zen-mcp-server](https://github.com/BeehiveInnovations/zen-mcp-server). You don't need to use gemini and can configure zen with any other provider/models. See [zen getting started docs](https://github.com/BeehiveInnovations/zen-mcp-server/blob/main/docs/getting-started.md) for more details.

### Claude `claude.json` mcp settings

You need to have `mcpServers` present and configured in your `~/.claude.json`. 
The reason we put them in the user's claude.json configuration, instead of repo local settings, is for reusability across projects, and to prevent committing API keys, which some MPC servers might require.

Here's an example `mcpServers` object that you can use as a reference:

```json
{
  "context7": {
    "type": "http",
    "url": "https://mcp.context7.com/mcp",
    "headers": {
      "CONTEXT7_API_KEY": "YOUR_CONTEXT7_API_KEY"
    }
  },
  "serena": {
    "type": "stdio",
    "command": "uvx",
    "args": [
      "--from",
      "git+https://github.com/oraios/serena",
      "serena",
      "start-mcp-server",
      "--context",
      "ide-assistant",
      "--project",
      "."
    ],
    "env": {}
  },
  "task-master-ai": {
    "type": "stdio",
    "command": "npx",
    "args": [
      "-y",
      "--package=task-master-ai",
      "task-master-ai"
    ],
    "headers": {}
  },
  "zen": {
    "command": "sh",
    "args": [
      "-c",
      "uvx --from git+https://github.com/BeehiveInnovations/zen-mcp-server.git zen-mcp-server"
    ],
    "env": {
      "PATH": "/usr/local/bin:/usr/bin:/bin:~/.local/bin",
      "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY",
      "GOOGLE_ALLOWED_MODELS": "gemini-2.5-pro,gemini-2.5-flash"
    }
  }
}
```

## Quick Start

1. [Create a new project based on this template repository](https://github.com/new?template_name=claude-starter-kit&template_owner=serpro69) using the Use this template button. 

2. A scaffold repo will appear in your GitHub account.

3. Run the `template-cleanup` workflow from your new repo, and provide some inputs for your specific use-case.

**Serena MCP Configuration Params:**

- `LANGUAGE` - the main language(s) of your project (see [Serena Programming Language Support & Semantic Analysis Capabilities](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities) for more details on supported languages)

**Task-Master MCP Configuration Params:**

- `TM_CUSTOM_SYSTEM_PROMPT` - Custom system prompt to override Claude Code's default behavior.

- `TM_APPEND_SYSTEM_PROMPT` - Append additional content to the system prompt.

- `TM_PERMISSION_MODE` - Permission mode for file system operations.

> [!INFO]
> See [Task Master Advanced Claude Code Settings Usage](https://github.com/eyaltoledano/claude-task-master/blob/main/docs/examples/claude-code-usage.md#advanced-settings-usage) for more details on the above parameters.

4. Clone your new repo and run `claude /mcp`.

You should see the mcp servers configured and active:

```
> /mcp
╭────────────────────────────────────────────────────────────────────╮
│ Manage MCP servers                                                 │
│                                                                    │
│ ❯ 1. context7                  ✔ connected · Enter to view details │
│   2. serena                    ✔ connected · Enter to view details │
│   3. task-master-ai            ✔ connected · Enter to view details │
│   4. zen                       ✔ connected · Enter to view details │
╰────────────────────────────────────────────────────────────────────╯
```

5. Run `claude /init` to initialize `CLAUDE.md` for your project.

6. Profit
