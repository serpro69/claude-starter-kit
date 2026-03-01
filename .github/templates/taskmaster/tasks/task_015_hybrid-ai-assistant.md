# Task ID: 15

**Title:** Operational Documentation and Migration Runbook

**Status:** pending

**Dependencies:** 13, 14

**Priority:** low

**Description:** Write final operational docs: README, MIGRATION.md, SECRETS-ROTATION.md, and TROUBLESHOOTING.md.

**Details:**

README.md: prerequisites (Docker, Tailscale binary, Google Drive account), first-time setup steps, post-start verification checklist (make status, make tailscale-ip, make mac-reachable, send test Telegram message), directory structure overview. MIGRATION.md: 5-step procedure (make backup on old VPS, transfer project dir + archives, install Docker, restore secrets from password manager, make restore + make up). SECRETS-ROTATION.md: per-secret rotation commands. TROUBLESHOOTING.md: Tailscale not connecting (check key expiry), RAG no results (check rag container logs, re-run ingest), health offline error (check Mac services + Tailscale peer status), sync OAuth expiry (re-run rclone config). All docs cross-referenced.

**Test Strategy:**

Follow README on clean VM — system up within 30min without external help. Follow MIGRATION.md — completes in 5min. All troubleshooting steps verified to resolve described issue.
