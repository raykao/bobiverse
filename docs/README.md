# Documentation

This is the documentation index for the bobiverse agent framework.

For the project overview and quick start, see the [root README](../README.md).
For the orchestrator reference, see [AGENTS.md](../AGENTS.md).
For canonical rules that all replicants follow, see the [DNA modules](../dna/).

---

## Documents

| Document | Audience | Summary |
|----------|----------|---------|
| [Philosophy](philosophy.md) | Everyone | Design principles and the Bobiverse metaphor |
| [Replicant Guide](replicant-guide.md) | Agent builders | How to create, customize, and manage replicants |
| [Git Workflow](contributing/git-workflow.md) | Everyone | Worktree isolation, branching, conventional commits |
| [Artifact Production](contributing/artifact-production.md) | Contributors producing files | Incremental write-commit cycle, gates, checkpoints |
| [Scoping and Clarification](contributing/scoping-and-clarification.md) | Everyone | How to scope work and ask clarifying questions |

## Contributing

The [Contributing Guide](contributing/README.md) covers engineering practices for
both humans and AI agents: git workflow, artifact production, and the scoping
protocol.

## DNA Modules (Canonical Rules)

The `dna/` directory contains the canonical rules that all replicants inherit.
Documentation in this folder provides context, examples, and rationale - but
`dna/` is the source of truth.

| DNA Module | What it governs |
|------------|-----------------|
| `dna/core.md` | Identity, writing style, communication norms |
| `dna/git-workflow.md` | Branch naming, commit conventions, PR workflow |
| `dna/artifact-production.md` | How to produce deliverables (code, docs, configs) |
| `dna/quality-gates.md` | Testing, coverage, linting, validation |
| `dna/memory.md` | Persistent knowledge across sessions |
| `dna/scoping.md` | Work scoping, avoiding scope creep |
| `dna/github-issues.md` | Issue conventions, epic structure, task tracking |
