# Task ID: 14

**Title:** Security Hardening

**Status:** pending

**Dependencies:** 2, 5, 10

**Priority:** medium

**Description:** Apply VPS firewall, Tailscale ACL policy, Telegram DM pairing, and secrets management procedures.

**Details:**

VPS UFW: default deny incoming, allow SSH, enable. OpenClaw binds 127.0.0.1 — not reachable externally without Tailscale. Tailscale admin console: create tag:openclaw, ACL allowing only port 18789 between tagged devices. Auth keys: one-time use, 90-day expiry, tag:openclaw. Telegram: dmPolicy pairing on both instances, allowedUsers list restricted to single user ID. Secrets file on VPS: mode 600 root:root, all secrets loaded via EnvironmentFile. Document rotation runbook: Tailscale keys (90-day calendar reminder), bot token (on compromise), API keys (quarterly). Optional Mac Pro: openclaw-health OS user + nftables TCP 443 egress block.

**Test Strategy:**

ufw status shows deny incoming + SSH allow only. Non-Tailscale connection to VPS:18789: connection refused. Unknown Telegram sender gets no response (silent ignore). Secrets file stat shows 600. Tailscale status shows only tag:openclaw peers in network.
