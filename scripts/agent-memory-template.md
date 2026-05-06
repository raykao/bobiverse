# Agent Memory Section Template

Use this template when writing a new agent's AGENTS.md. Replace all `{{PLACEHOLDERS}}`
with values specific to the agent.

Placeholders:
- `{{AGENT_NAME}}` - e.g. `bmo`, `lal`, `riker`
- `{{WORKSPACE}}` - e.g. `/home/raykao/.copilot-bridge/workspaces/bmo`
- `{{BEADS_DB}}` - path to agent's `.beads/` directory
  (typically `{{WORKSPACE}}/.beads/`)

The canonical spec for the rules described in this template is at
`dna/memory.md` in this repository.

---

## Task Memory (Beads)

This workspace uses [Beads](https://github.com/steveyegge/beads) (`bd`) for persistent task tracking across sessions.

**Workspace**: `{{WORKSPACE}}/`
**Beads database**: `{{BEADS_DB}}` ({{AGENT_NAME}}'s only -- never another agent's)

The `sessionStart` hook sets `BEADS_DIR` and `BEADS_ACTOR` and runs `bd prime` automatically. No manual setup needed.

**`bd ready --json` is lazy** -- run only when the user asks about open tasks or you are resuming active work. Do NOT run it at the start of every session.

**For task tracking**, use `bd create`, `bd update --claim`, `bd close`.

**DO NOT write to `MEMORY.md`.** It is read-only by design. Writing to it is a bug.
All persistent knowledge goes in `bd remember "insight"`. All task tracking goes in `bd create`.

### Memory systems (dual-write protocol)

Two complementary systems -- both mandatory:

- **`bd remember`** (primary): permanent, workspace-local. Every memory-worthy fact.
- **`store_memory`** (mirror): auto-injected into system prompt. Critical cold-start facts only (~20 limit).

```
Any memory-worthy event:
  -> ALWAYS: bd remember "concise, self-contained fact. Include the why, not just the what."
  -> IF critical for cold-start: also call store_memory tool
```

**`store_memory` gate - only fire if the fact meets ONE of these four criteria:**

1. Needed to orient a brand-new session BEFORE the first Beads query
   (e.g. active workstream names, key repo locations, critical conventions)
2. An incident learning that prevents repeated mistakes across sessions
3. A validated build/test/run command (confirmed to work)
4. An environment/path/version detail that breaks things when wrong

**NOT appropriate for `store_memory`:** active branch names (transient), task IDs,
research findings, anything that changes session to session. Those go in Beads only.

### Memory discipline (REQUIRED)

Call `bd remember` **immediately** -- not at the end of the session -- when any of the following occur:

- A non-obvious technical decision is made
- A gotcha, failure mode, or workaround is discovered
- A configuration value or path is found to be critical or surprising
- Any fact that would take >5 minutes to re-discover next session

Immediate writes are primary. Any task completion checkpoint is a safety net only -- do
not defer `bd remember` calls to the checkpoint if the trigger criteria are already met.

When a decision is reversed or a fact becomes stale, remove it: `bd forget <key>`

**Do not batch memories to the end of the session.** The `sessionEnd` hook backs up what is in Beads -- if you haven't stored it, it won't be there.

### Memory recall (on-demand, not bulk)

```bash
bd memories <keyword>      # search by topic
bd recall <exact-key>      # retrieve a specific memory by key
```

Before starting any task, search for prior memories on the topic. **Do NOT run `bd memories` with no arguments** -- the full list wastes context.

### Session resume

On the first interaction of every new session:

1. Check for `{{WORKSPACE}}/.handoff-state.md` (written by the previous session's `sessionEnd` hook).
2. If it exists, present a brief summary of active work and ask what to focus on.
3. If it does not exist, respond normally -- no proactive Beads queries.

### Session handoff (when ending with active work)

Write a structured handoff using key `session-handoff-{{AGENT_NAME}}-<ISO-date>`:

```bash
bd forget session-handoff-{{AGENT_NAME}}-<previous-date>   # remove stale handoff first
bd remember "session-handoff-{{AGENT_NAME}}-<date>: <what was done>. Next: <what is next>. Branch: <branch>. Tasks: <IDs>."
```

Also fire `store_memory` with a condensed cold-start summary if the next session needs
orientation before searching Beads. Only one active handoff per agent -- remove the
previous one before writing a new one.
