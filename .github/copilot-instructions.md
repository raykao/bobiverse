# Copilot Instructions for bobiverse

This repository is an **agent harness framework** called bobiverse. It defines
orchestration patterns, replicant (sub-agent) templates, and shared DNA modules
for AI-assisted development workflows.

---

## What This Repo Is (and Is Not)

**This repo IS**: the framework definition - agent configurations, DNA modules,
documentation, and tooling that govern how agents work.

**This repo is NOT**: a place for project work. Projects go in `workbench/`,
which is gitignored.

### What Belongs Here

| Path | Contents |
|------|----------|
| `AGENTS.md` | Bob Prime orchestrator definition |
| `dna/` | Shared DNA modules (conventions inherited by all replicants) |
| `.github/agents/` | Replicant definitions (.agent.md files) |
| `.github/prompts/` | Prompt files for replicant invocation |
| `.github/ISSUE_TEMPLATE/` | Issue templates (epics, tasks) |
| `docs/` | Framework documentation |
| `research/` | Research documents and spikes |

### What Does NOT Belong

- Source code for projects (goes in `workbench/` or separate repos)
- Cloned repositories
- Experiment code
- Build artifacts
- Credentials or secrets

---

## Default Agent Behavior

When working in this repository:

- **Asked to work on a project**: use `workbench/` for all project files.
  Create a worktree if needed. Never put project code in the repo root.

- **Asked to improve agents**: edit `AGENTS.md`, files in `.github/agents/`,
  or DNA modules in `dna/`.

- **Asked to add documentation**: add or edit files in `docs/`.

- **Asked to create a new replicant**: use the agent-builder replicant
  (`/agent agent-builder`) or create a `.agent.md` file in `.github/agents/`.

---

## Session Memory

This framework uses Beads (`bd`) for persistent task memory across sessions.
Key commands:

- `bd remember "<fact>"` - store a fact
- `bd recall "<query>"` - recall relevant facts
- `bd status` - check current task state

---

## Git Conventions

Follow the conventions defined in `dna/git-workflow.md`:

- **Conventional commits**: `<type>(<scope>): <description>`
- **Worktree isolation**: all feature work happens in `workbench/<topic>`
- **Branch naming**: `<context>/<topic>` (e.g., `feature/add-auth`, `docs/update-readme`)
- **Incremental commits**: commit after each meaningful chunk of work

See `docs/contributing/git-workflow.md` for detailed examples.

---

## Writing Style

All output - code comments, documentation, commit messages, issue bodies -
must follow these rules:

- **No em dashes** (U+2014). Use hyphens (-) with spaces, colons, or rephrase.
- **Plain ASCII punctuation** only. No curly quotes, no smart punctuation.
- **Imperative mood** in commit messages: "add feature" not "added feature."
- **Concise by default**. Expand only when the reader needs the detail.

See `dna/core.md` for the full writing and communication conventions.

---

## Documentation Conventions

From `dna/core.md`:

- **Issues** are the living record - update the body as understanding evolves
- **PR bodies** are for the reviewer - concise, focused on what changed and why
- **Commit messages** capture the why - subject says what, body says why

---

## Key References

- [AGENTS.md](../AGENTS.md) - orchestrator definition
- [docs/](../docs/README.md) - documentation index
- [dna/](../dna/) - canonical DNA modules
- [docs/philosophy.md](../docs/philosophy.md) - design principles
- [docs/contributing/](../docs/contributing/README.md) - engineering practices
