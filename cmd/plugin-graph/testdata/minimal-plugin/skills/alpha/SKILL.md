# Alpha skill

Alpha links a shared instruction directly, delegates to a peer skill, and spawns
a review agent. Together these exercise the markdown-link, symlink (via the
sibling `shared-common-helper.md`), skill-invocation, and agent-delegation edges.

See [profile detection](../_shared/profile-detection.md) for the profile list.

When a deeper pass is warranted, delegate to /kk:beta.

## Delegation

| Tool call | Notes |
|-----------|-------|
| `subagent_type` | spawn kk:example-reviewer for an independent review pass |
