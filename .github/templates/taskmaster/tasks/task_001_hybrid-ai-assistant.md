# Task ID: 1

**Title:** VPS Project Scaffold

**Status:** pending

**Dependencies:** None

**Priority:** high

**Description:** Create the canonical directory structure and base files at /opt/openclaw/ on the VPS.

**Details:**

Create directories: config/, scripts/, rag/. Write .env.example with all required variable names (TS_AUTHKEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, TELEGRAM_BOT_TOKEN, YOUR_TELEGRAM_USER_ID, MAC_TAILSCALE_IP, MAC_OPENCLAW_PORT). Write .gitignore excluding the secrets env file and config/rclone.conf. Write README.md covering prerequisites, setup steps, and the 5-step migration procedure. Initialize git repo at /opt/openclaw/.

**Test Strategy:**

Verify directory tree matches spec. Confirm secrets file is excluded from git. Confirm rclone.conf excluded. README covers all 5 migration steps.
