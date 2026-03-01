# Task ID: 5

**Title:** Tailscale Serve Config, Health Check Script, and Makefile

**Status:** pending

**Dependencies:** 2

**Priority:** high

**Description:** Write config/tailscale-serve.json, scripts/healthcheck.sh, and the operational Makefile.

**Details:**

tailscale-serve.json: TCP 443 HTTPS true, Web handler for TS_CERT_DOMAIN:443 proxying to http://127.0.0.1:18789 (loopback works because openclaw shares tailscale network namespace). healthcheck.sh: netcat TCP check to MAC_TAILSCALE_IP:PORT with 3s timeout, writes online/offline to /run/openclaw/mac-online, appends timestamped log entry, rotates to last 1000 lines. Makefile targets: up/down/restart/logs/build, status (compose ps + mac status + tailscale status), tailscale-ip, mac-reachable, backup (docker run alpine tar to export workspace and rag-data to dated archives), restore, ingest-notes, ingest-code, rag-health, check-env.

**Test Strategy:**

healthcheck.sh writes correct status to file. make check-env exits 0 with all vars set. make backup creates two tar.gz archives in backups/YYYYMMDD/. Tailscale serve status shows active HTTPS proxy to localhost:18789.
