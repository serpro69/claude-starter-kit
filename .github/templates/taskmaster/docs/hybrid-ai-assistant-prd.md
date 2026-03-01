# PRD: Hybrid Personal AI Assistant System

## Overview

Build a hybrid AI assistant that routes tasks intelligently between a VPS (always-on
cloud gateway) and a local Mac Pro (GPU-accelerated inference). The system uses Telegram
as the user interface, Tailscale for secure inter-node communication, OpenClaw as the
agent framework, and a RAG pipeline for grounded, memory-augmented responses.

All sensitive health data must remain exclusively on the local Mac Pro and must never
be routed to cloud LLMs or synced off-device.

## Goals

- 24/7 availability via VPS even when Mac Pro is offline
- Privacy-first: health agent is physically isolated from cloud APIs and VPS logs
- RAG-augmented responses: all agents retrieve from a relevant vector store before generating
- Fully reconstructible: re-deploying on a new VPS requires only docker-compose + .env
- Portable memory: shared workspace synced to Google Drive (excluding health data)

---

## Phase 1: VPS Docker Infrastructure

### 1.1 Project Scaffold

Create the canonical directory structure at `/opt/openclaw/` on the VPS:

```
/opt/openclaw/
├── docker-compose.yml
├── .env.example
├── Makefile
├── Dockerfile.openclaw
├── config/
│   ├── openclaw.json
│   ├── tailscale-serve.json
│   └── rclone.conf         (not committed — populated during setup)
├── scripts/
│   └── healthcheck.sh
└── rag/
    ├── Dockerfile
    ├── requirements.txt
    ├── service.py
    ├── ingest.py
    └── config.py
```

Deliverables:
- All files created with correct content
- `.gitignore` excluding `.env` and `config/rclone.conf`
- `README.md` with setup steps

### 1.2 Docker Compose Stack

Write `docker-compose.yml` with five services:

1. `tailscale` — official `tailscale/tailscale:latest` image; uses `TS_AUTHKEY` from env;
   mounts `/dev/net/tun`; connected to `internal` bridge network
2. `openclaw` — custom image; `network_mode: service:tailscale` (shares Tailscale's
   network namespace for VPN + Docker DNS access); mounts workspace volume and status volume
3. `healthcheck` — Alpine image; `network_mode: service:tailscale`; runs
   `healthcheck.sh` in a loop every 30 seconds; writes result to `status` volume
4. `rag` — custom Python image; on `internal` network; exposes port 18790;
   mounts workspace (read-only) and rag-data volumes
5. `sync` — official `rclone/rclone` image; on `internal` network; runs bisync loop
   every 300 seconds; excludes `health/**` unconditionally

Named volumes: `ts-state`, `workspace`, `rag-data`, `status`
Network: single `internal` bridge (default Docker NAT to internet)

### 1.3 OpenClaw Dockerfile

`Dockerfile.openclaw`:
- Base: `debian:bookworm-slim`
- Install curl + ca-certificates
- Install OpenClaw binary via official install script
- EXPOSE 18789
- ENTRYPOINT `openclaw start --foreground`

### 1.4 VPS OpenClaw Configuration

`config/openclaw.json` for VPS:
- gateway: bind 127.0.0.1:18789, auth mode tailscale, tailscale serve mode
- agent: model claude-opus-4-6, workspace /root/.openclaw/workspace
- models: claude-opus-4-6 as primary, gpt-4o as fallback, failover chain defined
- channels.telegram: dmPolicy pairing, allowedUsers from env, defaultSkill router
- agents: router (stateless), coding-cloud (persistent), personal-cloud (persistent)
- All secrets via ${ENV_VAR} references — no hardcoded values

### 1.5 Tailscale Serve Configuration

`config/tailscale-serve.json`:
- TCP 443 with HTTPS
- Web handler proxying to http://127.0.0.1:18789 (OpenClaw in shared network namespace)
- Hostname substituted by Tailscale via ${TS_CERT_DOMAIN}

### 1.6 Health Check Script

`scripts/healthcheck.sh`:
- TCP check to MAC_TAILSCALE_IP:MAC_OPENCLAW_PORT using netcat with 3s timeout
- Write "online" or "offline" to /run/openclaw/mac-online
- Append timestamped log entry to /run/openclaw/healthcheck.log
- Rotate log to last 1000 lines

### 1.7 Makefile

Operational commands:
- `make up` / `make down` / `make restart [service=X]` / `make logs [service=X]`
- `make status` — shows compose ps + Mac Pro status + Tailscale status
- `make backup` — exports workspace and rag-data volumes to dated tar.gz files
- `make restore DATE=YYYYMMDD` — imports volume archives
- `make ingest-notes` / `make ingest-code` — trigger RAG ingestion in rag container
- `make check-env` — validates required .env vars are set
- `make tailscale-ip` / `make mac-reachable`

---

## Phase 2: RAG Service

### 2.1 RAG Service (`rag/service.py`)

FastAPI application with:
- Lifespan handler initialising Chroma clients, cross-encoder reranker, OpenAI client
- `GET /health` — returns status and machine role
- `POST /ingest` — accepts documents + metadatas, embeds, upserts to Chroma, rebuilds BM25
- `POST /query` — hybrid retrieval pipeline:
  1. Embed query (backend determined by collection + machine role)
  2. Semantic search via Chroma (top-k)
  3. BM25 search via rank_bm25 (top-k)
  4. RRF fusion with configurable alpha (0=BM25, 1=semantic)
  5. Cross-encoder re-ranking to top-n
  6. Return chunks, scores, metadatas

Privacy guard: `_guard_collection()` raises HTTP 403 if VPS tries to access
`health_records` collection.

Embedding routing:
- VPS: coding_docs + personal_notes → OpenAI text-embedding-3-small; conversations → Ollama
- Mac: all collections including health_records → Ollama nomic-embed-text (no cloud path)

Separate Chroma client instances for health vs shared collections (different storage paths).

### 2.2 RAG Ingestion Pipeline (`rag/ingest.py`)

CLI script: `python ingest.py --collection <name> --source <path>`

Chunking strategies:
- Code (.py): AST-based (function/class boundaries), fallback to sliding window
- Code (other languages): sliding window, 512 tokens, 64 overlap
- Markdown/text: split on headings, sub-chunk large sections, 384 tokens, 48 overlap
- Health records: date-header splitting, 256 tokens, 32 overlap (maximum precision)

File processors for: .py, .ts, .js, .go, .rs, .sh, .sql, .yaml, .md, .txt, .rst

Batch upsert to RAG service in groups of 50 chunks.

### 2.3 RAG Configuration (`rag/config.py`)

Docker-aware paths via environment variables:
- `WORKSPACE_PATH` defaults to ~/.openclaw/workspace
- `DATA_PATH` defaults to ~/.openclaw/rag-data
- `OPENCLAW_ROLE` controls embedding backend routing

Chroma paths: `{DATA_PATH}/chroma/{collection_name}/`
Health Chroma: `{WORKSPACE_PATH}/health/memory/chroma/` (separate client)
BM25 index: `{DATA_PATH}/bm25_index/{collection}.pkl`

Model pre-download at Docker build time (cross-encoder/ms-marco-MiniLM-L-6-v2).

### 2.4 RAG Dockerfile

- Base: python:3.12-slim
- Install build-essential + curl
- pip install requirements
- Pre-download cross-encoder model during build (avoids cold-start latency)
- EXPOSE 18790
- CMD uvicorn service:app, host 0.0.0.0

---

## Phase 3: Skill Files (VPS)

### 3.1 Router Skill (`workspace/skills/router/SKILL.md`)

Routing agent for the VPS. Responsibilities:
- Classify message as HEALTH, CODING, or PERSONAL (strict rules defined in skill)
- Read /run/openclaw/mac-online to determine Mac Pro availability
- Query `conversations` RAG collection for prior context before classifying
- Route according to the 6-case decision table:
  - HEALTH + online → forward to Mac Pro via sessions_send
  - HEALTH + offline → return error message (no cloud fallback)
  - CODING + online → forward to Mac Pro (Ollama preferred)
  - CODING + offline → handle locally via coding-cloud agent
  - PERSONAL + online → forward to Mac Pro
  - PERSONAL + offline → handle locally via personal-cloud agent

Privacy constraint: for HEALTH messages, do not echo, summarise, or store content
in VPS session. Only action is forward or error.

### 3.2 Coding Skill (`workspace/skills/coding/SKILL.md`)

Software engineering assistant. Capabilities:
- Code generation, review, debugging, architecture advice
- Languages: Python, TypeScript, Go, Rust, Bash, SQL
- RAG workflow: query coding_docs before answering; cite source metadata
- Post-task: store session summary to conversations collection
- Cloud fallback acceptable; note when web search is unavailable locally

### 3.3 Personal Skill (`workspace/skills/personal/SKILL.md`)

Productivity assistant. Capabilities:
- Notes, calendar, Google Drive files, email drafting, general knowledge
- RAG workflow: search personal_notes and conversations before responding
- Memory: store significant new information to conversations after each session
- Cloud routing acceptable; redirect health queries to Health Agent

---

## Phase 4: Mac Pro Native Setup

### 4.1 Ollama Installation and Models

On Pop!_OS with ROCm (AMD Radeon Pro W6900X):
- Install Ollama via official installer
- Configure ROCm environment variables for AMD GPU
- Pull models: llama3:70b, llama3:8b, nomic-embed-text, mxbai-embed-large
- Verify GPU utilisation during inference (`rocm-smi`)
- Configure Ollama systemd service to start at boot

### 4.2 OpenClaw Mac Pro Configuration

`~/.openclaw/openclaw.json` on Mac Pro:
- gateway: bind 127.0.0.1:18789, auth tailscale, tailscale serve mode
- agent: model ollama/llama3:70b, workspace ~/.openclaw/workspace
- models: ollama-primary (llama3:70b) + ollama-fast (llama3:8b), NO cloud profiles
- agents:
  - coding-local: Ollama primary, persistent session
  - personal-local: Ollama primary, persistent session
  - health: Ollama primary only, allowCloudModels false, network sandbox none

Health agent has zero cloud model profiles — physically cannot route to API even if
misconfigured.

### 4.3 Mac Pro Skill Files

Same coding and personal skills as VPS (shared workspace via Google Drive sync).

Health skill (`workspace/skills/health/SKILL.md`):
- Strict local-only constraints stated in skill header
- RAG workflow: always query health_records before responding
- hybrid_alpha 0.5 for balanced keyword (medication names, dates) + semantic retrieval
- Store session summaries to health_records (local only, never synced)
- Do not read from workspace/notes (synced to Drive); only workspace/health/

### 4.4 Privacy OS Layer (Optional)

Create dedicated system user `openclaw-health` on Mac Pro with no outbound HTTPS:
- `useradd -r -s /usr/sbin/nologin openclaw-health`
- nftables rule blocking TCP 443 egress for that UID
- Run health agent sessions under this user

### 4.5 Mac Pro RAG Service (Native)

Install Python venv for RAG service on Mac Pro:
- `~/.venv/openclaw-rag/`
- Same service.py + config.py as VPS but with OPENCLAW_ROLE=mac
- Systemd service `openclaw-rag.service` (After=ollama.service)
- Separate Chroma client for health collection at `workspace/health/memory/chroma/`

---

## Phase 5: Portable Memory & Sync

### 5.1 rclone Configuration (Both Machines)

Install rclone on VPS (inside Docker) and Mac Pro (native).
Configure `gdrive` remote via OAuth flow.
Store `config/rclone.conf` securely (not committed to git).

Sync strategy:
- `rclone bisync` with `--conflict-loser delete` (last-write wins via mtime)
- Exclude patterns (unconditional, hardcoded in scripts):
  - `health/**`
  - `memory/chroma/health_records/**`
  - `memory/bm25_index/health_records.pkl`
  - `*.tmp`, `.git/**`

### 5.2 Sync Scheduling

VPS: rclone runs in the `sync` Docker container every 300 seconds.
Mac Pro: systemd timer `openclaw-sync.timer` every 300 seconds.

### 5.3 Nightly RAG Re-ingestion

Mac Pro cron jobs at 03:00:
- `ingest.py --collection personal_notes --source workspace/notes/`
- `ingest.py --collection health_records --source workspace/health/records/`

VPS: `make ingest-notes` triggered manually or via cron inside the rag container.

---

## Phase 6: Integration Testing

### 6.1 VPS Docker Stack Tests

- `make up` brings all 5 services to healthy state
- `make tailscale-ip` returns a valid 100.64.x.x address
- `curl http://localhost:18790/health` returns `{"status":"ok","role":"vps"}`
- Tailscale Serve proxies correctly to OpenClaw at the FQDN
- healthcheck.sh writes correct status to /run/openclaw/mac-online

### 6.2 Tunnel Tests

- VPS healthcheck reports "online" when Mac Pro is running
- VPS healthcheck reports "offline" within 35 seconds of Mac Pro shutdown
- sessions_send successfully routes a test message from VPS to Mac Pro
- Mac Pro response is delivered back to VPS and to Telegram user

### 6.3 RAG Pipeline Tests

- Ingest 10 test documents to coding_docs on VPS
- Query returns relevant chunks with scores > 0.5
- BM25 correctly surface exact keyword matches
- Cross-encoder re-ranking changes result order vs raw semantic search
- health_records query returns HTTP 403 on VPS

### 6.4 Privacy Enforcement Tests

- Send a HEALTH-classified message when Mac Pro is online → verify:
  - VPS session log contains no health content
  - Mac Pro Ollama log shows inference
  - No API call to Anthropic or OpenAI in network logs
- Send a HEALTH-classified message when Mac Pro is offline → verify:
  - User receives offline error message
  - No cloud API call attempted
- Attempt to query health_records from VPS RAG service → verify HTTP 403

### 6.5 Failover Tests

- Disable Anthropic API key → verify OpenAI fallback activates for CODING queries
- Kill Ollama on Mac Pro → verify Mac Pro coding agent falls back to llama3:8b
- Kill Mac Pro OpenClaw → verify VPS router falls back to cloud for CODING/PERSONAL

---

## Phase 7: Operational Hardening

### 7.1 Secrets Management

- All secrets in `.env` on VPS (root-owned, mode 600)
- rclone.conf in `config/` (not committed, backed up to password manager)
- Tailscale auth key rotation reminder every 90 days (calendar event)
- No secrets in docker-compose.yml or config JSON files — only ${VAR} references

### 7.2 VPS Firewall

UFW rules on VPS host:
- Default deny incoming
- Allow SSH
- Tailscale interface handled by kernel (no UFW rule needed)
- OpenClaw binds to 127.0.0.1 — not externally reachable without Tailscale

### 7.3 Telegram Security

- dmPolicy: pairing on both instances
- allowedUsers: only your Telegram user ID
- Pairing code logged on first run — retrieve from `make logs service=openclaw`

### 7.4 Migration Runbook

Document the 5-step procedure for migrating VPS:
1. `make backup` on old VPS
2. Transfer project dir + backup archives to new VPS
3. Install Docker on new VPS
4. Restore .env from password manager
5. `make restore DATE=... && make up`

---

## Non-Goals

- Multi-user support
- Web UI (Telegram is the sole interface)
- Windows support on Mac Pro (Pop!_OS only for AI workloads)
- Health data sync of any kind (permanent non-goal)
- Cloud-based vector store (Chroma is local/file-based only)
