# Task ID: 8

**Title:** VPS Skill Files — Router, Coding, Personal

**Status:** pending

**Dependencies:** 4, 6

**Priority:** medium

**Description:** Write SKILL.md files for the three VPS agents with RAG workflow instructions embedded.

**Details:**

Router SKILL.md: HEALTH/CODING/PERSONAL classification rules with examples, status file read instruction (/run/openclaw/mac-online), 6-case routing decision table, RAG pre-query of conversations collection before classifying, privacy constraint (no health content stored or echoed in VPS session), sessions_send forwarding syntax for Mac Pro. Coding SKILL.md: capabilities list, RAG workflow (query coding_docs then inject chunks, cite source metadata field), post-task summary stored to conversations. Personal SKILL.md: capabilities, RAG workflow (search personal_notes + conversations), memory storage instructions, cloud routing acceptable, redirect health queries to Health Agent.

**Test Strategy:**

Telegram health keyword message: router classifies as HEALTH. Code question: CODING. Coding agent tool logs show RAG query before response. VPS session log contains no health message content after HEALTH routing. Router returns correct error message when HEALTH + Mac offline.
