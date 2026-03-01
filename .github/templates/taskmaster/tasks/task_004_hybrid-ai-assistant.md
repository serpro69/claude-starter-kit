# Task ID: 4

**Title:** VPS OpenClaw Configuration

**Status:** pending

**Dependencies:** 3

**Priority:** high

**Description:** Write config/openclaw.json for the VPS instance with agent definitions and model profiles.

**Details:**

Gateway: bind 127.0.0.1:18789, auth tailscale, tailscale serve mode. Models: claude-primary (anthropic, claude-opus-4-6), openai-fallback (openai, gpt-4o), failoverChain [claude-primary, openai-fallback]. Channels.telegram: dmPolicy pairing, allowedUsers from env, defaultSkill router. Agents: router (stateless, STATUS_FILE + RAG_URL in env), coding-cloud (persistent), personal-cloud (persistent). Zero hardcoded secrets — all via ENV_VAR references.

**Test Strategy:**

python3 -m json.tool validates. All secret refs use env var syntax. OpenClaw starts without config errors in docker logs.
