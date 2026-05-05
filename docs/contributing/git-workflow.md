# Git Workflow

Detailed git workflow conventions for the bobiverse framework. This guide
expands on `dna/git-workflow.md` with examples and rationale.

---

## Why Worktree Isolation Matters

Worktrees solve three problems that arise when multiple agents (or humans)
work in the same repository:

1. **Concurrent agents** - two replicants working on different tasks cannot
   safely share a working directory. Worktrees give each one a private
   checkout.

2. **Interrupted sessions** - if a session dies mid-task, the worktree
   preserves all committed work. The next session can pick up where it
   left off by checking the worktree state.

3. **Merge conflicts** - worktrees keep feature work isolated until it is
   ready. Conflicts surface at merge time, not during development.

---

## Worktree Setup

All worktrees live under `workbench/` at the repo root. This directory is
gitignored.

### Creating a Worktree

```bash
# Standard pattern
git worktree add -b "feature/add-auth" "workbench/add-auth"
cd "workbench/add-auth"

# From an existing branch
git worktree add "workbench/fix-typo" "bugfix/fix-typo"
cd "workbench/fix-typo"
```

### Decision Table

| Branch exists? | Worktree exists? | Action |
|----------------|------------------|--------|
| No | No | Create branch from main, create worktree |
| Yes | No | Create worktree from existing branch |
| Yes | Yes | Reuse (verify clean state first) |
| No | Yes | Error: orphan worktree. Remove and recreate. |

### Verifying Clean State

Before reusing an existing worktree:

```bash
cd "workbench/<topic>"
git status              # should show nothing uncommitted
git log --oneline -5    # verify you are on the right branch
```

---

## Branch Naming

Branches follow the pattern: `<context>/<topic>`

### Context Types

| Context | When to use | Example |
|---------|-------------|---------|
| `feature` | New functionality | `feature/add-auth` |
| `bugfix` | Fixing a bug | `bugfix/fix-token-expiry` |
| `chore` | Maintenance, cleanup, deps | `chore/update-deps` |
| `docs` | Documentation changes | `docs/add-replicant-guide` |
| `refactor` | Restructuring without behavior change | `refactor/extract-router` |
| `research` | Investigation or spike | `research/evaluate-llm-options` |
| `agent` | Agent/replicant definition changes | `agent/add-deploy-replicant` |

### Naming Rules

- Use lowercase with hyphens: `feature/add-user-search` (not `Feature/AddUserSearch`)
- Keep topics short but descriptive: `bugfix/fix-auth` (not `bugfix/fix`)
- No spaces, underscores, or special characters in branch names
- The topic segment becomes the worktree folder name: `workbench/add-user-search`

---

## Conventional Commits

Every commit message follows this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type | Purpose | Example |
|------|---------|---------|
| `feat` | New feature | `feat(auth): add JWT validation middleware` |
| `fix` | Bug fix | `fix(api): handle null response from upstream` |
| `docs` | Documentation only | `docs(readme): add installation section` |
| `chore` | Maintenance, tooling, deps | `chore(deps): update express to 4.19` |
| `refactor` | Code restructure, no behavior change | `refactor(router): extract route handlers` |
| `test` | Adding or updating tests | `test(auth): add token expiry edge cases` |
| `style` | Formatting, whitespace, no logic change | `style(api): fix indentation in handler` |
| `ci` | CI/CD configuration | `ci: add lint step to GitHub Actions` |
| `perf` | Performance improvement | `perf(query): add index for user lookup` |

### Scope

The scope is optional but recommended. It identifies the area of the codebase
affected:

- Use the module or component name: `feat(auth)`, `fix(api)`, `test(router)`
- Use `deps` for dependency changes: `chore(deps)`
- Use `*` or omit for cross-cutting changes: `refactor: rename config keys`

### Description Rules

- Use imperative mood: "add feature" not "added feature" or "adds feature"
- Lowercase first letter: "add feature" not "Add feature"
- No period at the end
- Keep it under 72 characters

### Body

The body is optional. Use it for:

- Explaining *why* the change was made (the *what* is in the diff)
- Documenting alternatives considered
- Noting gotchas discovered during implementation

Separate the body from the subject with a blank line.

### Examples

Simple commit:

```
feat(auth): add JWT validation middleware
```

Commit with body:

```
fix(api): handle null response from upstream

The upstream service returns null instead of an empty array when there
are no results. This caused a TypeError in the response mapper.

Wrapping the response in a null check before mapping is safer than
changing the upstream contract.
```

Commit with breaking change:

```
feat(config)!: switch from YAML to JSON config format

BREAKING CHANGE: Configuration files must now be in JSON format.
Run `bobiverse migrate-config` to convert existing YAML configs.
```

---

## Breaking Changes

Breaking changes are signaled in two ways:

1. **Exclamation mark** after the type/scope: `feat(config)!: change format`
2. **Footer** with `BREAKING CHANGE:` followed by a description

Use both for maximum visibility. The footer explains what broke and how to
migrate.

---

## Merge Strategy

### Recommendations

- **Squash merge** for small, single-purpose PRs - produces one clean commit
  on main
- **Merge commit** for larger PRs where the individual commit history tells a
  useful story
- **Rebase** only if the branch is short-lived and has no merge conflicts

### Before Merging

1. Verify the branch is up to date with main
2. Verify all checks pass
3. Verify the review-fix loop has exited cleanly (see AGENTS.md Section 8)
4. Get user approval if required

---

## Cleanup

After a branch is merged:

```bash
# Remove the worktree
git worktree remove "workbench/<topic>"

# Delete the local branch
git branch -d "<context>/<topic>"

# Delete the remote branch (if not auto-deleted by GitHub)
git push origin --delete "<context>/<topic>"

# Pull latest main
git checkout main && git pull
```

### Verifying Clean State

After cleanup:

```bash
# List remaining worktrees - should only show main
git worktree list

# List branches - merged branches should be gone
git branch --list
```

---

## Canonical Reference

This guide expands on `dna/git-workflow.md` with examples and rationale.
When this guide and the DNA module disagree, the DNA module wins.
