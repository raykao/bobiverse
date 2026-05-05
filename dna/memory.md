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

## Workspace Isolation (Critical)

Beads databases are **not shared** between agents. Every memory operation is scoped to the agent's OWN workspace.

> `<WORKSPACE>` throughout this document means the absolute path to THIS agent's workspace root:
> `~/.copilot-bridge/workspaces/<this-agent-name>/`
>
> Never substitute another agent's name or path. If unsure, verify: `echo $BEADS_DIR` must end with `<this-agent-name>/.beads`. If it does not, stop and fix the environment before writing any memories.

| Resource | Location | Scope |
|----------|----------|-------|
| Beads database | `<WORKSPACE>/.beads/` | This agent only |
| Handoff state file | `<WORKSPACE>/.handoff-state.md` | This agent only |
| Working files / clones | `<WORKSPACE>/workbench/` | This agent only |
| `BEADS_ACTOR` env var | set to this agent's name | This agent only |

**Worktree/clone gotcha**: Repos cloned into `<WORKSPACE>/workbench/` may contain their own `.github/hooks/` with hardcoded paths pointing to a different agent's workspace. Those hooks belong to those repos and are not used by the bridge for this agent's sessions. Do NOT copy them as a template for this agent's own hooks -- always start from `<WORKSPACE>/.github/hooks/`.

---

## Session Lifecycle

The `sessionStart` hook (`<WORKSPACE>/.github/hooks/session-start.sh`) runs automatically and:

1. Sets `BEADS_DIR` to `<WORKSPACE>/.beads`
2. Sets `BEADS_ACTOR` to this agent's name
3. Runs `bd prime` to start the Dolt server
4. Generates `<WORKSPACE>/.handoff-state.md` from Beads if it does not already exist

You do **not** need to run `bd prime` manually.

**`bd ready --json` is lazy.** Run it only when work context is needed:
- User asks about open tasks or status
- You are resuming active work from a previous session

Do NOT run `bd ready --json` at the start of every session - it adds context cost even when the task list is not relevant.

**Session resume** - on the first interaction of every new session:

1. Check for `<WORKSPACE>/.handoff-state.md` (written by the previous session's `sessionEnd` hook).
2. If it exists, present a brief summary of active work and ask what to focus on.
3. If it does not exist, respond normally -- no proactive Beads queries.

---

## Session Handoff Protocol

When ending a session that has active work in progress, write a structured handoff entry using this key pattern:

**Key**: `session-handoff-<agent-name>-<ISO-date>` (e.g., `session-handoff-bob-2026-05-04`)

```bash
bd remember "session-handoff-<agent-name>-<date>: <one-line what was done>. Next: <one-line what is next>. Branch: <branch-name>. Tasks: <task-IDs or descriptions>."
```

Remove any previous handoff for the same agent first -- only one active handoff per agent at a time:

```bash
bd forget session-handoff-<agent-name>-<previous-date>
bd remember "session-handoff-<agent-name>-<new-date>: ..."
```

**Dual-write for handoffs**: Also fire `store_memory` with a condensed cold-start summary when the handoff contains information a new session must have before it can search Beads.

---

## Context Window Management

Context usage is reported by the user in the format: `Context: 53k/200k tokens (27%)`

| Zone | Range | Action |
|------|-------|--------|
| Green | < 70% | Keep working. No prep needed. |
| Soft (yellow) | 70-85% | Finish current chunk, `bd remember` workstream state, no new large tool-call chains. |
| Hard (red) | > 85% | Stop. Save state to Beads now. Prompt user to `/new`. Do not start new work. |

Adjustments:
- Tool-heavy work (web fetches, large file reads): treat hard threshold as 75% instead of 85%
- Pure reasoning / chat: can run hotter (~80% soft / 90% hard)

On the first context reading of a session, briefly acknowledge the current zone. Do not over-narrate subsequent readings -- shift behavior silently. If no readings are shared and the session feels long (roughly 30+ tool calls or many large file reads), proactively ask for a reading.

---

## Precise Recall

Use `bd recall <exact-key>` to retrieve a specific memory by its key without a keyword search. Useful when you know the exact key (e.g., a handoff key or a named configuration fact).

```bash
bd recall session-handoff-bob-2026-05-04   # exact key
bd memories dashboard                       # keyword search
```

Do NOT run `bd memories` with no arguments. The full list wastes context. Search for what you need, when you need it.

---

## Related Modules

- [core.md](core.md) - documentation conventions (memories supplement, not replace, written docs)
- [github-issues.md](github-issues.md) - issue bodies capture decisions; memories capture the quick-recall version
