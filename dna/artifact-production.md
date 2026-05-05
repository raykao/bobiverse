# Artifact Production

How to create, update, and manage files (artifacts) - whether you are writing code, documentation, research, specifications, or agent definitions. These conventions apply to all contributors: Bob Prime, replicants, and human developers.

**Prerequisite**: Read [git-workflow.md](git-workflow.md) first. Artifact production builds on the worktree isolation and conventional commits conventions defined there.

---

## What Is an Artifact?

An **artifact** is any file committed to the repository as a product of work:

- Research documents
- Agent/replicant definitions
- Specifications and plans
- Source code and configuration files
- Documentation

If your task produces or modifies files that will be committed, these conventions apply.

---

## The Core Problem

The traditional workflow - think about what to write, compose it mentally, then write it all at once - has a critical failure mode:

> If the session is interrupted after thinking but before writing, all work is lost.

This happens routinely with replicants (context limits, tool failures, session timeouts) and occasionally with humans (crashes, lost connections). The longer you accumulate work in memory before committing, the more you risk losing.

---

## The Incremental Write-Commit Cycle

Instead of writing everything at once, follow a **scaffold, write, commit** loop:

### Step 1: Scaffold First

Before doing any research, analysis, or generation, create the output file on disk - even if it is mostly empty:

```bash
mkdir -p research
cat > research/my-topic.md << 'EOF'
# My Topic: Descriptive Subtitle

## Summary

<!-- TODO: Add summary after research -->
EOF

git add research/my-topic.md
git commit -m "chore(my-topic): scaffold research document

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Why**: The file now exists on disk and in git history. Even if everything fails from this point, the workspace is ready and no time was wasted.

### Step 2: Write Incrementally

After each meaningful phase of work, update the file and commit:

```bash
# After completing a batch of research:
git add research/my-topic.md
git commit -m "research(my-topic): add knowns and unknowns from web search

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

# After analyzing trade-offs:
git add research/my-topic.md
git commit -m "research(my-topic): add options trade-off analysis

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**What counts as a "meaningful phase"?** Use judgment, but as a guideline:

- A batch of research on a sub-topic - commit
- A completed section of a document - commit
- A module or function in code - commit
- An analysis or comparison table - commit

**When in doubt, commit more often.** Small commits are cheap. Lost work is expensive.

### Step 3: Final Commit

When the artifact is complete, ensure everything is committed with a summary message:

```bash
git add -A
git commit -m "research(my-topic): complete initial research document

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Prerequisite Gates

Before beginning core work, verify that your workspace is ready. This checklist prevents the mistake of doing work before having a place to save it.

### The Gate Checklist

Before writing any content:

- [ ] **Worktree is active**: You are `cd`'d into the worktree directory, not the main repo
- [ ] **Output directory exists**: `mkdir -p <output-dir>` has been run
- [ ] **Target file exists on disk**: The scaffold file has been created and committed
- [ ] **Git status is clean**: No uncommitted changes from a previous interrupted session

If any gate fails, **stop and fix it before proceeding**.

### Why Gates Matter

Without gates, it is easy to:

- Start researching before creating the worktree (then realize you cannot write)
- Write to the main repo instead of the worktree (causing merge conflicts)
- Accumulate an entire document in memory because the file does not exist yet

Gates are cheap insurance against expensive mistakes.

---

## Checkpoint Discipline

The commit history of an artifact should tell the story of how it was built. Each commit is a **checkpoint** - a recoverable state that captures progress.

### Good Checkpoint Commits

```
chore(keda): scaffold research document
research(keda): add knowns from official documentation
research(keda): add unknowns and gaps analysis
research(keda): add options trade-off comparison
research(keda): add recommendations and follow-ups
research(keda): complete initial research document
```

This history tells you: scaffolded, gathered facts, identified gaps, compared options, made recommendations, finalized.

### Bad Checkpoint Commits

```
WIP
more changes
update
fix stuff
done
```

This history tells you nothing. It cannot be reviewed, bisected, or understood.

### Recovery from Checkpoints

If a session is interrupted, anyone (human or replicant) can:

1. Look at the branch's commit history
2. See exactly what has been completed
3. Pick up where the last commit left off

Without checkpoints, the next contributor starts from scratch. With them, recovery is immediate.

---

## Summary

| Practice | What | Why |
|----------|------|-----|
| Scaffold first | Create the file before starting work | Guarantees a place to write; prevents in-memory accumulation |
| Write incrementally | Update the file after each work phase | Limits blast radius of interruptions |
| Commit after each write | `git commit` after every file update | Creates recoverable checkpoints in history |
| Prerequisite gates | Verify workspace before starting | Prevents working in wrong directory or without a file |
| Checkpoint discipline | Meaningful commit sequence | Enables recovery, review, and handoff |

---

## Related Modules

- [git-workflow.md](git-workflow.md) - worktree setup and conventional commits (prerequisite)
- [core.md](core.md) - commit message conventions and trailers
- [quality-gates.md](quality-gates.md) - review and test standards applied after artifacts are produced
