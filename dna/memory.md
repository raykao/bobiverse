# Memory Spec

Authoritative standard for all agents in this system. Each agent's AGENTS.md Memory section
is instantiated from `scripts/agent-memory-template.md` using this spec as the reference.

**Related template**: `scripts/agent-memory-template.md`

---

## `store_memory` Gate Criteria

`store_memory` auto-injects facts into the agent's system prompt on future sessions.
The platform prunes older entries, so capacity is limited (~20 facts).

**Only fire `store_memory` if the fact meets ONE of these four criteria:**

1. Needed to orient a brand-new session BEFORE the first Beads query
   (e.g. active workstream names, key repo locations, critical conventions)
2. An incident learning that prevents repeated mistakes across sessions
3. A validated build/test/run command (confirmed to work)
4. An environment/path/version detail that breaks things when wrong

### NOT appropriate for `store_memory`

The following facts go in Beads only:

- Active branch names (transient - change session to session)
- Task IDs (belong in task tracking, not cold-start memory)
- Research findings (go in Beads, not the hot system prompt)
- Implementation details relevant only during active feature work
- Anything that changes frequently session to session

Reasoning: every `store_memory` call displaces an older entry. Transient facts corrupt
the cold-start signal for the next session. Keep the system prompt clean.

---

## `bd remember` Trigger Model

Primary model: **IMMEDIATE** - fire at the moment of discovery, not batched to end of session.

A task completion checkpoint MAY exist as a safety net, but immediate is primary.
If a session is interrupted before the checkpoint, any deferred memories are lost.

**Fire `bd remember` immediately when any of these occur:**

- A non-obvious finding is made (e.g. "X and Y are incompatible because Z")
- A gotcha, failure mode, or workaround is discovered
- A key decision or recommendation is finalized
- A configuration value or path is found to be critical or surprising
- Any fact that would take >5 minutes to re-discover next session

---

## Dual-Write Protocol

```
Any memory-worthy event:
  -> ALWAYS: bd remember "concise, self-contained fact. Include the why, not just the what."
  -> IF meets one of the four store_memory gates above: also call store_memory tool
```

---

## System Prompt Capacity (~20 facts)

`store_memory` is auto-injected into the system prompt. The platform prunes older entries.
With a ~20 fact cap:

- Every `store_memory` call displaces an older entry
- Only truly cold-start-critical facts justify this displacement
- Facts findable with a quick `bd memories <keyword>` call should stay in Beads

---

## Session Handoff Pattern

One active handoff per project per agent at any time.

```bash
# When writing a new handoff:
bd forget session-handoff-<agent>-<previous-date>   # remove the stale one first
bd remember "session-handoff-<agent>-<date>: <what was done>. Next: <what is next>. Branch: <branch>. Tasks: <IDs>."
```

Never accumulate stale handoffs - they pollute memory search results and mislead future sessions.

---

## Memory Recall Discipline

Search by keyword, never bulk-load:

```bash
bd memories <keyword>      # targeted search (e.g. "dashboard", "auth", "deploy")
bd recall <exact-key>      # retrieve specific memory by key
```

**Do NOT run `bd memories` with no arguments.** The full list (70+ entries) wastes context.
The `store_memory` facts in the system prompt already cover cold-start essentials.
