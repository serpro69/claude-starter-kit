# Task ID: 2

**Title:** Docker Compose Stack

**Status:** pending

**Dependencies:** 1

**Priority:** high

**Description:** Write docker-compose.yml defining all five services: tailscale, openclaw, healthcheck, rag, sync.

**Details:**

Services: (1) tailscale — tailscale/tailscale:latest, cap_add NET_ADMIN+NET_RAW, /dev/net/tun bind mount, ts-state volume, internal network, healthcheck via tailscale status. (2) openclaw — custom Dockerfile.openclaw build, network_mode: service:tailscale (shares Tailscale network namespace for both VPN and Docker DNS access), workspace + status volumes. (3) healthcheck — alpine:3.19, network_mode: service:tailscale, status volume, runs healthcheck.sh every 30s. (4) rag — custom build, internal network, workspace read-only + rag-data volumes, healthcheck via curl /health. (5) sync — rclone/rclone:latest, internal network, workspace volume, bisync loop every 300s with health/** hardcoded exclusion. Named volumes: ts-state, workspace, rag-data, status. Network: internal bridge.

**Test Strategy:**

docker compose config parses without error. docker compose up -d on clean VPS — all 5 services reach healthy/running within 120s. docker compose ps shows zero restart counts.
