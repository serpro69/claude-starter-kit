# Task ID: 13

**Title:** End-to-End Integration Testing

**Status:** pending

**Dependencies:** 2, 5, 6, 7, 8, 10, 11, 12

**Priority:** high

**Description:** Execute the full integration test suite covering routing, RAG, tunnel, failover, and privacy enforcement.

**Details:**

Six test groups documented in test-results.md: (1) VPS stack — all containers healthy, tailscale IP valid, RAG /health 200, healthcheck file correct. (2) Tunnel — online within 35s of Mac start, offline within 35s of Mac shutdown, sessions_send routes test message to Mac, Telegram receives response. (3) RAG — ingest 10 docs, query returns score >0.5 chunks, BM25 surfaces keyword matches, cross-encoder changes ordering, VPS health_records query returns 403. (4) Privacy — HEALTH+online: VPS log has no health content, Ollama log shows inference, tcpdump shows zero Anthropic/OpenAI connections; HEALTH+offline: error message delivered, zero cloud calls. (5) Failover — Anthropic key disabled: OpenAI fallback activates; Ollama killed: llama3:8b fallback activates; Mac down: VPS cloud fallback for CODING/PERSONAL. (6) Migration dry-run on clean Debian VM.

**Test Strategy:**

All 6 test groups pass and results documented. tcpdump capture file proves zero health data leakage to cloud. Migration dry-run completes within 5min. test-results.md committed to repo.
