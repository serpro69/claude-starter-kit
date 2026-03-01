# Task ID: 7

**Title:** RAG Ingestion Pipeline and Dockerfile

**Status:** pending

**Dependencies:** 6

**Priority:** high

**Description:** Implement ingest.py CLI with per-type chunking strategies and build the rag/ Docker image.

**Details:**

ingest.py CLI: --collection and --source args, rglob file discovery filtered by extension. Chunkers: Python AST (FunctionDef/ClassDef line boundaries, fallback sliding window on SyntaxError); other code sliding window 512 tokens / 64 overlap; markdown/txt split on headings then sub-chunk 384/48; health split on YYYY-MM-DD date headers then sub-chunk 256/32. Batch upsert every 50 chunks via httpx. file_id = MD5(path)[:8]_{index} for deterministic dedup on re-ingest. rag/Dockerfile: python:3.12-slim base, install build-essential, pip install requirements.txt, pre-download CrossEncoder model at build time, EXPOSE 18790, CMD uvicorn service:app --host 0.0.0.0 --port 18790.

**Test Strategy:**

Python file ingest produces function-level chunks. Markdown ingest produces heading-split chunks. Health records produce date-bounded chunks. Re-ingest same files: same IDs, no Chroma duplicates. Docker build succeeds, CrossEncoder in image, /health returns 200 within 15s of container start.
