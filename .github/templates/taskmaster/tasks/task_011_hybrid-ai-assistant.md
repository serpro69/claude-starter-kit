# Task ID: 11

**Title:** Mac Pro RAG Service and Health Skill

**Status:** pending

**Dependencies:** 10, 7

**Priority:** high

**Description:** Deploy the RAG service natively on Mac Pro and write the health SKILL.md with strict local-only constraints.

**Details:**

Create Python venv at ~/.venv/openclaw-rag/. Install same requirements.txt. Pre-download CrossEncoder model. Write /etc/systemd/system/openclaw-rag.service: After=ollama.service, OPENCLAW_ROLE=mac, WORKSPACE_PATH and DATA_PATH set to local paths. Enable service. Health SKILL.md: STRICTLY LOCAL header with explicit privacy constraints, capabilities (health metrics, medications, appointments, journaling), RAG workflow (always query health_records before responding, hybrid_alpha 0.5 for keyword + semantic balance), data location note (health/ only — not notes/ which syncs to Drive), uncertainty disclosure policy, post-session storage instruction (store summary to health_records local only). Optional: create openclaw-health OS user + nftables TCP 443 egress block as third privacy layer.

**Test Strategy:**

systemctl status openclaw-rag active (After=ollama). curl 127.0.0.1:18790/health returns {role:mac}. Health query shows inference in Ollama log. tcpdump during health session: zero connections to anthropic.com or openai.com. VPS health_records query still returns 403.
