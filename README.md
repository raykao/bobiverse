# bobiverse

> "We Are Legion (We Are Bob)" - an agent harness framework where one orchestrator spawns an army of specialized replicants, each inheriting shared DNA but adapting to the mission at hand.

[![License](https://img.shields.io/github/license/raykao/bobiverse)](LICENSE)

## What is this?

Bobiverse is an **agent harness framework** for GitHub Copilot and AI coding agents. It provides the scaffolding, conventions, and automation that let a primary orchestrator agent ("Bob Prime") spawn specialized sub-agents ("replicants") on demand - each one inheriting a shared foundation but tailored to its task.

Think of it as the operating system for your AI-powered development workflow.

## The Metaphor

In Dennis E. Taylor's *Bobiverse* book series, software engineer Bob Johansson wakes up as a Von Neumann probe - a self-replicating spacecraft. He copies himself to explore the galaxy, and each copy (Riker, Homer, Bill, Mario...) inherits Bob's core memories and personality but develops its own specialization and quirks over time.

Our framework works the same way:

- **Bob Prime** is the orchestrator. It understands the full picture, delegates work, and never writes code directly. It spawns replicants for every task.
- **Replicants** are specialized agents. A code-replicant writes implementations. A review-replicant audits quality. A docs-replicant writes documentation. Each one inherits shared conventions but focuses on its domain.
- **DNA** is the shared foundation - conventions, quality gates, memory protocols, and workflow rules that every replicant inherits by default.

## Key Concepts

| Concept | Bobiverse Term | What It Does |
|---------|---------------|--------------|
| Orchestrator | **Bob Prime** | Decomposes work, spawns replicants, validates results. Never writes code. |
| Sub-agents | **Replicants** | Specialized agents that inherit DNA and execute focused tasks. |
| Conventions | **DNA** | Shared rules (git workflow, quality gates, commit format) inherited by all replicants. |
| Shared memory | **Beads** | Cross-project knowledge that any replicant can access and contribute to. |
| Quality loop | **Review-Fix Cycle** | Automated, non-negotiable quality gates. No exceptions, no shortcuts. |

## Repo Structure

```
bobiverse/
  dna/                    # Shared conventions inherited by all replicants
  .github/
    agents/               # Replicant definitions (agent YAML/MD configs)
    hooks/                # Git hooks for automated quality enforcement
    prompts/              # Prompt templates for common agent tasks
    scripts/              # Automation scripts (CI, setup, tooling)
    skills/               # Reusable skill definitions for agents
    ISSUE_TEMPLATE/       # Standardized issue templates
  docs/
    philosophy.md         # Design philosophy and the Bobiverse metaphor
    contributing/         # Contributor guides
  workbench/              # Scratch space for active work and experiments
  CHANGELOG.md            # Release history
```

## Quick Start

### 1. Use as your agent harness

Clone the repo into your workspace:

```bash
git clone https://github.com/raykao/bobiverse.git
cd bobiverse
```

### 2. Understand the DNA

Read through the `dna/` directory. These are the shared conventions that every replicant inherits - git workflow, quality gates, commit message format, memory protocols, and more.

### 3. Meet the replicants

Check `.github/agents/` for the available replicant definitions. Each one is a specialized agent configuration that Bob Prime can spawn.

### 4. Read the philosophy

Start with [docs/philosophy.md](docs/philosophy.md) to understand the *why* behind the design. The metaphor is not just cute - it encodes real architectural decisions about inheritance, delegation, and quality.

### 5. Customize

The DNA is composable. You can override individual convention files for specific projects without touching the rest. Want relaxed quality gates for a prototype? Override `quality-gates.md`. Everything else stays inherited.

## Documentation

- **[Design Philosophy](docs/philosophy.md)** - why the Bobiverse metaphor matters and the principles behind the framework
- **[Replicant Guide](docs/replicant-guide.md)** - how to create, configure, and deploy replicants
- **[Contributing](docs/contributing/)** - how to contribute to the bobiverse project

## Lineage

Bobiverse evolved from the **dark-factory** project - an earlier agent harness that proved the concept of orchestrator-driven AI development workflows. The lessons learned there (and from the copilot admin agent that managed multi-agent bridge configurations) were distilled into this unified framework.

The key insight: you don't need a dozen bespoke agent setups. You need one solid foundation (DNA) and the ability to spawn specialized replicants from it. That is the Bobiverse.

## License

See [LICENSE](LICENSE) for details.
