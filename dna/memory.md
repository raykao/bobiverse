# Memory - Dual Memory System

How replicants store, recall, and share knowledge. The Bobiverse uses two complementary memory systems: **Beads** (workspace-local permanent memory) and **platform memory** (auto-injected system prompt facts). Every replicant must understand when and how to use each.

---

## Two Memory Systems

### Beads/Dolt (`bd remember`)

Permanent, workspace-local memory that survives indefinitely. This is the primary memory system.

- **Store**: `bd remember "concise, self-contained fact"`
- **Recall**: `bd memories <keyword>`
- **Remove**: `bd forget <key>`

Beads are searched on demand by keyword. They are not bulk-loaded into context. A replicant asks for what it needs, when it needs it.

### Platform Memory (`store_memory`)

Platform-level memory that is automatically injected into the system prompt. Limited to approximately 20 of the most important facts.

- **Store**: Use the `store_memory` tool with subject, fact, citations, and reason
- **Recall**: Automatic - injected into every session's system prompt
- **Remove**: Managed by the platform

Platform memory is for **critical cold-start facts only** - things a replicant absolutely must know before it has a chance to search Beads.

---

## Dual-Write Protocol

Every memory-worthy event fires **both** systems according to these rules:

### Always fire `bd remember`

Store in Beads for every fact that meets the trigger criteria (see below).

### Additionally fire `store_memory` for

- **Session orientation facts**: workspace paths, repo URLs, environment details that a replicant needs immediately on startup
- **Incident learnings**: root causes and fixes from production issues or significant bugs
- **Validated build/test commands**: commands that have been verified to work (not guessed)
- **Environment details**: tool versions, platform quirks, critical configuration values

The subset that goes to `store_memory` should be small and stable. Platform memory is not for transient facts.

---

## Trigger Criteria

Store a memory (at minimum in Beads) when you encounter:

- **Non-obvious decisions**: "We chose X over Y because Z" - especially when the reasoning is not apparent from the code
- **Gotchas**: "This API returns 200 even on failure; check the response body"
- **Design trade-offs**: "Accepted O(n^2) here because n is always < 10"
- **Critical configurations**: "The auth service requires TLS 1.3 minimum"
- **Review-level bugs**: bugs found during review that others might hit
- **Incidents**: what broke, why, how it was fixed, how to prevent recurrence
- **Facts that take more than 5 minutes to rediscover**: if you had to dig for it, store it

### Do NOT Store

- Obvious facts that any competent developer would know
- Transient state ("currently working on X")
- Preferences or opinions without rationale
- Duplicates of facts already stored

---

## Timing: Store at Moment of Discovery

Do **not** batch memories. When you learn something worth remembering, store it immediately:

```
# Right after discovering a gotcha:
bd remember "Mattermost webhook API silently drops messages over 16383 chars; truncate before sending"

# Not: "I'll remember to store this later when I'm done"
```

Batching risks losing memories if the session is interrupted before the batch is written.

---

## Memory Recall Protocol

Memory recall is **on-demand**, not bulk-load. When starting a task or encountering an unfamiliar area:

1. Identify keywords relevant to the current work
2. Search Beads: `bd memories <keyword>`
3. Review results for relevant context
4. Proceed with the task, informed by recalled memories

Do not dump all memories at session start. Search for what you need, when you need it.

---

## Examples

### Beads Only (meets trigger criteria, not critical for cold-start)

```bash
bd remember "dark-factory worktree convention places worktrees at ../<repo>.worktrees/<leaf>, but bobiverse uses workbench/<leaf>"
bd remember "eslint v9 flat config requires explicit file patterns; glob imports no longer auto-discover"
bd remember "review-replicant found that retry logic in auth.ts silently swallows network errors; fixed in PR #42"
```

### Dual-Write (critical for cold-start AND meets trigger criteria)

```bash
# Beads
bd remember "bobiverse repo build command: npm run build && npm run test"

# Platform (store_memory) - same fact, for immediate cold-start access
store_memory(
  subject: "build commands",
  fact: "bobiverse build: npm run build && npm run test",
  citations: "package.json scripts",
  reason: "Replicants need this on first session without searching Beads"
)
```

---

## Summary

| System | Scope | Capacity | Access | Use For |
|--------|-------|----------|--------|---------|
| Beads (`bd remember`) | Workspace-local | Unlimited | On-demand keyword search | Every memory-worthy fact |
| Platform (`store_memory`) | Global, system prompt | ~20 facts | Auto-injected every session | Critical cold-start facts only |

---

## Related Modules

- [core.md](core.md) - documentation conventions (memories supplement, not replace, written docs)
- [github-issues.md](github-issues.md) - issue bodies capture decisions; memories capture the quick-recall version
