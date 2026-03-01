# Task ID: 10

**Title:** Mac Pro OpenClaw Native Installation and Configuration

**Status:** pending

**Dependencies:** 9

**Priority:** high

**Description:** Install OpenClaw natively on Pop!_OS and configure for local-only inference with health agent privacy constraints.

**Details:**

Install OpenClaw via official installer. Run openclaw onboard --install-daemon for systemd user service. Write ~/.openclaw/openclaw.json: gateway bind 127.0.0.1:18789 tailscale serve mode; models section contains ONLY Ollama profiles (ollama-primary llama3:70b, ollama-fast llama3:8b) — zero cloud API key profiles; agents coding-local (ollama-primary persistent), personal-local (ollama-primary persistent), health (ollama-primary, allowCloudModels: false, modelFailover Ollama-only, sandbox networkAccess: none). Install Tailscale on Mac Pro and join tailnet with tag:openclaw. Create workspace directories: notes/, health/records/, health/memory/chroma/, health/memory/bm25_index/.

**Test Strategy:**

systemctl --user status openclaw shows active. openclaw.json contains zero API key values. Health agent cannot use cloud model — errors rather than silent fallback. tailscale ip -4 returns 100.64.y.y. curl http://127.0.0.1:18789/ping returns 200.
