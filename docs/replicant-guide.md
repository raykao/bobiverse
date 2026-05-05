# Replicant Guide

How to create, customize, and manage replicants in the bobiverse framework.

---

## What Is a Replicant?

A replicant is a specialized sub-agent that inherits the shared DNA modules
(`dna/`) and adds its own role, execution steps, and boundaries. Replicants
are invoked by Bob Prime (the orchestrator) or directly by users via
`/agent <name>`.

Think of replicants as clones of the original Bob - each with the same
foundational knowledge but specialized for a particular type of work.

### Current Replicants

| Replicant | Codename | Purpose |
|-----------|----------|---------|
| `researcher` | Riker | Structured research documents |
| `implement` | Homer | Implementation with disciplined git workflow |
| `review` | Bill | Code review with severity ratings |
| `agent-builder` | Mario | Creates and refines new replicant definitions |
| `beads` | Guppi | Persistent task tracking via Beads (bd) |

---

## Anatomy of a Replicant Definition

Each replicant is defined by a `.agent.md` file in `.github/agents/`. The file
has two parts: YAML frontmatter and a markdown body.

### YAML Frontmatter

```yaml
---
name: "implement"
description: "Executes implementation tasks with disciplined git workflow"
model: "claude-sonnet-4-20250514"
tools:
  - "bash"
  - "edit"
  - "create"
  - "view"
  - "grep"
  - "glob"
handoffs:
  - "review"
target: "workbench"
---
```

**Field reference:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Identifier used with `/agent <name>` |
| `description` | Yes | One-line summary of what this replicant does |
| `model` | No | LLM model override (inherits default if omitted) |
| `tools` | No | List of tools this replicant may use |
| `handoffs` | No | Replicants this one can delegate to |
| `target` | No | Default working directory context |

### Markdown Body

The body defines the replicant's behavior:

1. **Role definition** - who this replicant is and what it does
2. **Execution steps** - the ordered workflow it follows
3. **Boundaries** - what it must NOT do
4. **DNA references** - which DNA modules govern its behavior

Example structure:

```markdown
# Implement Replicant (Homer)

You are the implementation replicant. You write code, tests, and
configuration files following the project's conventions.

## Execution Steps

1. Read the task description and acceptance criteria
2. Set up worktree per `dna/git-workflow.md`
3. Scaffold files and make initial commit
4. Implement incrementally per `dna/artifact-production.md`
5. Run tests and validate per `dna/quality-gates.md`
6. Push branch and report completion to Bob Prime

## Boundaries

- Do NOT merge PRs (Bob Prime handles merges)
- Do NOT skip the scaffold-commit step
- Do NOT modify files outside your assigned worktree
```

---

## DNA Inheritance

All replicants inherit every DNA module by default. You do not need to
explicitly list them. The DNA modules in `dna/` are automatically applied.

### Overriding DNA

If a replicant needs different behavior for a specific module, it can override
it. Overrides are full replacements, not patches.

There are two ways to override:

1. **Frontmatter field** - add a `dna_overrides` key listing modules to replace
2. **Inline in body** - redefine the behavior directly in the markdown body

Example frontmatter override:

```yaml
---
name: "researcher"
description: "Research agent with relaxed commit discipline"
dna_overrides:
  - artifact-production  # researcher produces docs, not incremental code
---
```

When a module is overridden, the replicant uses the version in its `.agent.md`
file entirely instead of the default from `dna/`.

---

## Creating a New Replicant

There are two paths to creating a replicant:

### Path 1: Use the Agent-Builder Replicant (Recommended)

1. Run `/agent agent-builder` to switch to Mario
2. Describe what the new replicant should do, including:
   - Its purpose and scope
   - What types of tasks it handles
   - Any DNA overrides it needs
   - Example tasks it should handle well
3. Mario creates the `.agent.md` file in `.github/agents/`
4. Mario creates the corresponding `.prompt.md` in `.github/prompts/`
5. The replicant is immediately available via `/agent <name>`

### Path 2: Ad-Hoc Spawning by Bob Prime

For one-off tasks that do not fit existing replicants, Bob Prime can spawn an
ad-hoc replicant. This is lighter weight - no `.agent.md` file is created
unless the pattern recurs. See AGENTS.md Section 6 for the spawning protocol.

### When to Create vs. When to Reuse

- If the task fits an existing replicant with minor prompt adjustments, reuse it
- If you keep giving the same custom instructions to an existing replicant,
  that is a signal to formalize a new one
- If the task is genuinely one-off, use ad-hoc spawning

---

## Artifact-Producing Replicants

If a replicant creates files (code, docs, configs), it must follow the
artifact production workflow from `dna/artifact-production.md`:

1. **Worktree setup** - create an isolated worktree per `dna/git-workflow.md`
2. **Scaffold and commit** - create file stubs, commit the skeleton
3. **Incremental writes** - fill in content in chunks, committing after each
4. **Validation** - run tests/linting per `dna/quality-gates.md`

This ensures work survives session interruptions and produces a clean,
reviewable commit history.

---

## Testing a New Replicant

After creating a replicant:

1. Switch to it: `/agent <name>`
2. Give it a representative task - something typical of its intended use
3. Verify it follows its defined execution steps
4. Verify it respects its boundaries
5. Verify DNA compliance (git workflow, commit conventions, etc.)
6. If it produces artifacts, check the commit history for proper incremental
   commits

### Common Issues

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| Replicant ignores boundaries | Body section too vague | Make boundaries explicit and specific |
| Replicant skips DNA rules | No DNA references in body | Add explicit references to relevant DNA modules |
| Replicant does too much | Scope too broad | Narrow the role definition and add boundaries |
| Replicant does too little | Execution steps unclear | Add numbered, concrete steps |

---

## Reference Implementations

The best way to learn the replicant format is to read existing definitions:

| File | Good example of |
|------|----------------|
| `.github/agents/implement.agent.md` | Artifact-producing replicant with full git workflow |
| `.github/agents/researcher.agent.md` | Research replicant with structured output format |
| `.github/agents/review.agent.md` | Read-only replicant with severity-rated findings |
| `.github/agents/agent-builder.agent.md` | Meta-replicant that creates other replicants |
| `.github/agents/beads.agent.md` | Tool-focused replicant for persistent state |

See also:
- [AGENTS.md](../AGENTS.md) - Bob Prime orchestrator reference
- [DNA modules](../dna/) - canonical rules all replicants inherit
- [Philosophy](philosophy.md) - design principles behind the framework
