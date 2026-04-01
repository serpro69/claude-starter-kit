# Capy Knowledge Base Protocol

If capy MCP tools are not available in this session, skip all search and index steps below and proceed normally.

## Source Label Taxonomy

All plugin-managed labels use the `kk:` namespace prefix.

| Label | Contents |
|---|---|
| `kk:arch-decisions` | Architecture decisions, design rationale, trade-offs |
| `kk:review-findings` | Code review patterns, recurring issues, anti-patterns |
| `kk:lang-idioms` | Language best practices, idiomatic patterns from external sources |
| `kk:project-conventions` | Discovered project patterns, naming conventions, structural decisions |
| `kk:test-patterns` | Testing approaches, edge cases, test infrastructure decisions |
| `kk:debug-context` | Root causes, tricky bugs and their fixes, environment gotchas |

## Search Conventions

- Use 2-4 specific terms per query — not vague keywords
- Always scope with `source` filter to relevant `kk:*` labels
- Use `source: "kk:"` only for broad cross-domain searches (e.g., CoVe verification)
- Default `limit: 3` per query unless more context is needed
- **Cold-start fallback:** If no results, proceed with standard guidelines — empty results are normal for new projects

## Index Conventions

- Only index non-obvious learnings not derivable from reading the code or git history
- Keep content concise — summarize the insight, don't dump raw output
- Always use a `kk:` prefixed label from the taxonomy above
- One concept per `capy_index` call — don't bundle unrelated learnings
- Skip indexing if the insight is already captured in design docs or CLAUDE.md
