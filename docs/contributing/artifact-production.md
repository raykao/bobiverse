# Artifact Production

How to produce deliverables (code, docs, configs) in the bobiverse framework.
This guide expands on `dna/artifact-production.md` with detailed examples and
recovery scenarios.

---

## Why Incremental Write-Commit Matters

Two failure modes drive this discipline:

1. **Session interruptions** - AI agent sessions can be interrupted at any time
   (timeout, crash, network failure). If all work is uncommitted, it is lost.
   Incremental commits ensure that the worst case is losing only the current
   chunk, not the entire task.

2. **Recoverability** - when a session resumes (or a different agent picks up
   the work), it needs to understand what was done and what remains. A clean
   commit history tells this story. A single massive commit or a pile of
   uncommitted changes does not.

---

## The Three Steps

Every artifact follows this cycle:

### Step 1: Scaffold

Create the file structure with empty or stub content. Commit the skeleton.

```bash
# Example: scaffolding a new module
mkdir -p src/auth
touch src/auth/index.ts src/auth/middleware.ts src/auth/types.ts
touch src/auth/__tests__/middleware.test.ts

git add -A
git commit -m "chore(auth): scaffold auth module structure"
```

**Why scaffold first?**

- Establishes the file layout before any logic is written
- Gives reviewers a preview of the architecture
- Creates a restore point - if the implementation goes sideways, you can
  reset to the scaffold commit

### Step 2: Implement Incrementally

Write content in logical chunks. Commit after each chunk.

```bash
# Chunk 1: type definitions
# ... write types.ts ...
git add -A
git commit -m "feat(auth): add token and user types"

# Chunk 2: core middleware logic
# ... write middleware.ts ...
git add -A
git commit -m "feat(auth): implement JWT validation middleware"

# Chunk 3: tests
# ... write middleware.test.ts ...
git add -A
git commit -m "test(auth): add middleware validation tests"

# Chunk 4: exports and wiring
# ... write index.ts ...
git add -A
git commit -m "feat(auth): wire up auth module exports"
```

**What counts as a "chunk"?**

A good chunk is a logically complete unit that:

- Compiles (or at least does not break the build)
- Can be understood in isolation from the diff
- Is small enough to review without scrolling

Bad chunks:

- One commit per line changed (too granular)
- The entire feature in one commit (too coarse)
- Half a function (not logically complete)

### Step 3: Validate

Run tests, linting, and any other quality gates defined in
`dna/quality-gates.md`.

```bash
# Run tests
npm test

# Run linter
npm run lint

# Check types
npx tsc --noEmit
```

Fix any failures, commit the fixes, and validate again.

---

## Prerequisite Gates

Before producing artifacts, verify these prerequisites:

| Gate | Check | Why |
|------|-------|-----|
| Worktree exists | `git worktree list` shows your branch | Artifacts must go in an isolated worktree |
| Branch is correct | `git branch --show-current` matches expected | Prevents committing to the wrong branch |
| Clean state | `git status` shows no uncommitted changes | Stale changes from a prior session can cause confusion |
| Dependencies installed | Build tools and deps are available | Prevents mid-task failures from missing tools |

If any gate fails, fix it before starting work. Do not begin producing
artifacts in a broken environment.

---

## Checkpoint Discipline

A checkpoint is a commit that marks a recoverable point in the work.

### Good Checkpoint History

```
chore(auth): scaffold auth module structure
feat(auth): add token and user types
feat(auth): implement JWT validation middleware
test(auth): add middleware validation tests
feat(auth): wire up auth module exports
fix(auth): handle expired token edge case
```

Each commit tells you what was done. You can understand the progression.
You can revert to any point if needed.

### Bad Checkpoint History

```
WIP
more stuff
fix
fix again
done
```

This tells you nothing. You cannot review it. You cannot recover from a
partial failure. You cannot understand the intent of any individual change.

### Rules for Good Checkpoints

1. **Every commit message follows conventional commits** - see
   [Git Workflow](git-workflow.md) for the format
2. **Every commit is logically complete** - it should not leave the codebase
   in a state that cannot be understood
3. **Commits are ordered by dependency** - types before implementation,
   implementation before tests, core before wiring
4. **No empty commits** - if there is nothing to commit, do not force one
5. **No mega-commits** - if a commit touches more than ~100 lines across
   many files, it probably should have been split

---

## Recovery Scenarios

### Scenario 1: Session Interrupted Mid-Task

**Situation**: An agent session dies after 3 of 5 commits were made.

**Recovery**:
1. Open the worktree: `cd workbench/<topic>`
2. Check state: `git log --oneline -10` and `git status`
3. The last 3 commits are preserved. Continue from where it stopped.
4. If there are uncommitted changes, review them: `git diff`
5. Either commit them if they are good, or discard: `git checkout .`

### Scenario 2: Bad Commit Pushed

**Situation**: A commit introduced a bug that was not caught before pushing.

**Recovery**:
1. Do NOT force-push or rewrite history on shared branches
2. Create a fix commit: `fix(auth): handle null token in validation`
3. The fix commit is part of the audit trail - it shows that a problem
   was found and fixed

### Scenario 3: Worktree Left in Dirty State

**Situation**: A worktree has uncommitted changes from a previous session.

**Recovery**:
1. Review the changes: `git diff`
2. If the changes look intentional, commit them with an appropriate message
3. If the changes look broken or unclear, stash them: `git stash`
4. Start fresh from the last clean commit

### Scenario 4: Wrong Branch

**Situation**: Work was committed to the wrong branch.

**Recovery**:
1. Note the commit hashes: `git log --oneline -5`
2. Switch to the correct branch
3. Cherry-pick the commits: `git cherry-pick <hash>`
4. Go back to the wrong branch and reset: `git reset --hard HEAD~N`

---

## How to Apply

### For Human Contributors

Follow the same scaffold-write-commit cycle. The discipline is the same
whether you are writing code in an IDE or drafting documentation. The goal
is recoverable, reviewable work with a clean commit trail.

### For AI Agents (Replicants)

Replicants must follow this workflow mechanically. The DNA module
`dna/artifact-production.md` encodes the rules. If a replicant is producing
artifacts without incremental commits, it is violating DNA and the review
replicant should flag it.

### For Reviewers

When reviewing a PR, check the commit history:

- Does it tell a coherent story?
- Are commits logically ordered?
- Could you revert to any commit and have a working (if incomplete) state?
- Are commit messages descriptive and conventional?

If the commit history is messy, request cleanup before approving.

---

## Canonical Reference

This guide expands on `dna/artifact-production.md` with examples and
scenarios. When this guide and the DNA module disagree, the DNA module wins.
