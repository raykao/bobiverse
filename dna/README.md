# DNA - Shared Conventions for All Replicants

> "Each copy starts with Bob's full memories, personality, and knowledge."

DNA modules are the shared conventions that **every replicant inherits by default**. They define *how* work is done - not *what* work to do. A replicant's specialization (code, review, docs, research) determines its mission. DNA determines how it executes that mission.

## How Inheritance Works

- **Automatic**: Every replicant inherits all DNA modules. No configuration needed.
- **Explicit override**: A replicant's `.agent.md` can override specific modules without affecting others. Override `quality-gates.md` for a prototype project - the git workflow, commit conventions, and memory protocols stay inherited.
- **Independent**: DNA modules are composable. Changing one module does not break or affect the others. Each file is self-contained with cross-references where relevant.

## Modules

| Module | Purpose |
|--------|---------|
| [core.md](core.md) | Identity, writing style, commit trailers, and documentation conventions |
| [git-workflow.md](git-workflow.md) | Worktree isolation, branch naming, conventional commits, merge strategy |
| [artifact-production.md](artifact-production.md) | The scaffold-write-commit cycle, prerequisite gates, checkpoint discipline |
| [quality-gates.md](quality-gates.md) | Review-fix loop, test quality standards, coverage analysis, merge gate |
| [memory.md](memory.md) | Dual memory system (Beads + platform), trigger criteria, recall protocol |
| [scoping.md](scoping.md) | The 5-question clarification protocol, materiality test, priority heuristic |
| [github-issues.md](github-issues.md) | Issue workflow, epic tracking, dashboard protocol, label strategy |

## Overriding a Module

To override a module for a specific replicant, add a section in the replicant's `.agent.md`:

```markdown
## DNA Overrides

### quality-gates

- Skip coverage ceiling for prototype work
- Review loop limited to 2 cycles max
```

The override applies only to that replicant. All other replicants continue to inherit the default DNA.

## Adding a New Module

1. Create a new `.md` file in this directory
2. Make it self-contained (a reader should understand the module without reading the others)
3. Add cross-references to related modules where helpful
4. Update this README's module table
5. All replicants automatically inherit the new module
