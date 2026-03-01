# Task ID: 6

**Title:** RAG Service — FastAPI Application

**Status:** pending

**Dependencies:** 1

**Priority:** high

**Description:** Implement service.py and config.py for the hybrid retrieval service with Chroma + BM25 + cross-encoder reranking.

**Details:**

FastAPI app with async lifespan: init two Chroma PersistentClients (shared at DATA_PATH/chroma, health-isolated at WORKSPACE/health/memory/chroma), CrossEncoder reranker (cross-encoder/ms-marco-MiniLM-L-6-v2), AsyncOpenAI client if key set, load BM25 indexes from pkl. Endpoints: GET /health, POST /ingest (embed all docs, Chroma upsert, rebuild + persist BM25 index), POST /query (embed query, semantic Chroma search, BM25 search via rank_bm25, RRF fusion with configurable alpha, CrossEncoder rerank, return top-n chunks + scores + metadatas). embed() routes: VPS coding_docs/personal_notes to OpenAI text-embedding-3-small; conversations + all Mac collections to Ollama nomic-embed-text. _guard_collection() raises HTTP 403 for health_records on VPS. config.py: all paths from WORKSPACE_PATH + DATA_PATH env vars, EMBED_CONFIG dict per role, chunk sizes and retrieval constants.

**Test Strategy:**

POST /ingest 5 docs returns {ingested:5}. POST /query returns 4 chunks with scores. BM25 pkl persisted after ingest. VPS health_records query returns 403. alpha=0 vs alpha=1 yields different ordering. CrossEncoder changes order vs raw RRF.
