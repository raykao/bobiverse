# Contributing Conventions

Engineering practices for both humans and AI agents working in the bobiverse
framework.

These conventions exist so that work is recoverable, reviewable, and consistent
regardless of whether it was produced by a person or a replicant. The canonical
rules live in the `dna/` modules. The guides below expand on those rules with
examples, rationale, and practical advice.

---

## Guides

| Guide | What it covers |
|-------|---------------|
| [Git Workflow](git-workflow.md) | Worktree isolation, branch naming, conventional commits, merge strategy |
| [Artifact Production](artifact-production.md) | Scaffold-write-commit cycle, prerequisite gates, checkpoint discipline |
| [Scoping and Clarification](scoping-and-clarification.md) | 5-question protocol, materiality test, when to clarify vs. when to proceed |

---

## Quick Reference

The basic workflow for any contribution:

```bash
# 1. Create an isolated worktree
git worktree add -b "<context>/<topic>" "workbench/<topic>"
cd "workbench/<topic>"

# 2. Scaffold files and make initial commit
touch src/new-module.ts src/new-module.test.ts
git add -A && git commit -m "chore: scaffold new-module"

# 3. Work incrementally - write a chunk, then commit
#    (repeat until done)
git add -A && git commit -m "feat: implement core logic for new-module"

# 4. Push when ready for review
git push -u origin "<context>/<topic>"
```

### Key Principles

1. **Worktree isolation** - every task gets its own worktree in `workbench/`.
   No two contributors (human or agent) share a worktree.

2. **Incremental commits** - commit after each meaningful chunk of work. This
   makes sessions recoverable and diffs reviewable.

3. **Conventional commits** - every commit message follows the format:
   `<type>(<scope>): <description>`. See [Git Workflow](git-workflow.md) for
   the full guide.

4. **Scope before you start** - use the 5-question protocol from
   [Scoping and Clarification](scoping-and-clarification.md) to resolve
   ambiguities before producing artifacts.

---

## Canonical Rules

These guides provide context and examples. The canonical rules live in:

- `dna/git-workflow.md` - branch and commit conventions
- `dna/artifact-production.md` - how to produce deliverables
- `dna/scoping.md` - how to scope work and manage boundaries
- `dna/quality-gates.md` - testing, coverage, and validation
- `dna/core.md` - identity, writing style, communication norms

When a guide and a DNA module disagree, the DNA module wins.
