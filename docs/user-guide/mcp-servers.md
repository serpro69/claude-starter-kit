# MCP Servers

MCP servers are configured at the user level (not in the repo) to keep API keys safe. These configs are generic enough to reuse across all your projects.

You don't need all servers to get started. Add them incrementally:

1. **[Context7](https://context7.com/)** (needs API key) — up-to-date library documentation and code examples
2. **[Pal](https://github.com/serpro69/pal-mcp-server)** (needs API key) — multi-model AI integration for code review, debugging, planning, and security audit
3. **[Capy](https://github.com/serpro69/capy)** (optional, auto-configured by bootstrap) — persistent knowledge base across sessions. Install with `brew install serpro69/tap/capy`.

| Server | Purpose |
|--------|---------|
| **[Context7](https://context7.com/)** | Up-to-date library documentation and code examples |
| **[Pal](https://github.com/serpro69/pal-mcp-server)** | Multi-model AI integration — chat, debugging, code review, planning, security audit |
| **[Capy](https://github.com/serpro69/capy)** | Persistent knowledge base — cross-session project memory with FTS5 search |

## Claude Code

!!! note
    Add MCP servers to `~/.claude.json` under the `mcpServers` key.

??? example "Example `mcpServers` configuration"

    ```json
    {
      "context7": {
        "type": "http",
        "url": "https://mcp.context7.com/mcp",
        "headers": {
          "CONTEXT7_API_KEY": "YOUR_CONTEXT7_API_KEY"
        }
      },
      "pal": {
        "command": "sh",
        "args": [
          "-c",
          "$HOME/.local/bin/uvx --from git+https://github.com/serpro69/pal-mcp-server.git pal-mcp-server"
        ],
        "env": {
          "PATH": "/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin",
          "DEFAULT_MODEL": "auto",
          "DEFAULT_THINKING_MODE_THINKDEEP": "high",
          "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY",
          "GOOGLE_ALLOWED_MODELS": "gemini-3.1-pro-preview,gemini-3-flash-preview"
        }
      }
    }
    ```

    See [Pal configuration docs](https://github.com/serpro69/pal-mcp-server/blob/main/docs/configuration.md) for model and thinking mode options.

!!! tip "Using claude-in-docker?"
    If you're using [claude-in-docker](https://github.com/serpro69/claude-in-docker) images, replace `npx` and `uvx` calls with direct tool invocations. The images come with MCP tools pre-installed, avoiding dependency downloads on each launch:

    ```json
    "pal": {
      "command": "pal-mcp-server",
      "args": [],
      "env": { "..." }
    }
    ```

    Check your `env` settings, especially the `PATH` variable — custom paths not available in the image may cause the server to fail to connect.

## Codex

!!! note
    MCP servers are added via `codex mcp add` and stored in `~/.codex/config.toml`.
    Capy is already configured at the project level in `.codex/config.toml` — no user setup needed.

```bash
# Context7 — streamable HTTP, no API key env var needed (key is in the URL header)
codex mcp add context7 --url "https://mcp.context7.com/mcp"

# Pal — stdio server via uvx, with env vars for model config
codex mcp add pal \
  --env "PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin" \
  --env "DEFAULT_MODEL=auto" \
  --env "DEFAULT_THINKING_MODE_THINKDEEP=high" \
  --env "GEMINI_API_KEY=YOUR_GEMINI_API_KEY" \
  --env "GOOGLE_ALLOWED_MODELS=gemini-3.1-pro-preview,gemini-3-flash-preview" \
  -- sh -c "$HOME/.local/bin/uvx --from git+https://github.com/serpro69/pal-mcp-server.git pal-mcp-server"
```

??? example "Or manually add to `~/.codex/config.toml`"

    ```toml
    [mcp_servers.context7]
    url = "https://mcp.context7.com/mcp"
    http_headers = { "CONTEXT7_API_KEY" = "YOUR_CONTEXT7_API_KEY" }

    [mcp_servers.pal]
    command = "sh"
    args = ["-c", "$HOME/.local/bin/uvx --from git+https://github.com/serpro69/pal-mcp-server.git pal-mcp-server"]

    [mcp_servers.pal.env]
    DEFAULT_MODEL = "auto"
    DEFAULT_THINKING_MODE_THINKDEEP = "high"
    GEMINI_API_KEY = "YOUR_GEMINI_API_KEY"
    GOOGLE_ALLOWED_MODELS = "gemini-3.1-pro-preview,gemini-3-flash-preview"
    PATH = "/usr/local/bin:/usr/bin:/bin"
    ```

Verify with `codex mcp list`. See [Pal configuration docs](https://github.com/serpro69/pal-mcp-server/blob/main/docs/configuration.md) for model and thinking mode options.

## What Each Server Does

### Context7

Fetches current documentation for any library, framework, or SDK. Used by the **/kk:dependency-handling** skill to look up API signatures instead of guessing. Also available for ad-hoc queries.

### Pal

Multi-model AI integration. Powers the **/kk:review-code** skill's independent reviewer sub-agents — your code gets reviewed by Gemini (or other models) in addition to Claude, catching blind spots neither model would find alone. Also provides: `debug`, `planner`, `secaudit`, `testgen`, and more.

### Capy (Knowledge Base)

Skills are **knowledge-aware** via Capy. They search for relevant context before executing (architecture decisions, review findings, language idioms) and index valuable learnings after producing output. Knowledge persists across sessions per-project using an FTS5 full-text search index.

Without Capy, each session starts fresh — all skills still work, they just don't carry learnings forward. Install when you want cross-session memory.

**Installation:** `brew install serpro69/tap/capy` then run `capy setup` in your project directory. The bootstrap script sets up Capy automatically if the binary is on PATH.
