# Git Workflow

How we use Git - branching, worktrees, commit messages, and merge strategy. These conventions apply to all contributors: Bob Prime, replicants, human developers, and CI pipelines.

---

## Why These Conventions Exist

Traditional git workflows assume a single developer working in a single checkout. In a system where multiple replicants and humans may operate concurrently, this breaks down:

- **Replicants cannot coordinate** - two replicants working in the same checkout will overwrite each other's changes.
- **Interrupted sessions lose work** - if a replicant accumulates changes in memory and the session drops, everything is lost.
- **Unclear provenance** - without structured commit messages, it is impossible to tell what changed, why, and by whom (or what).
- **Merge conflicts multiply** - concurrent work on the same branch creates conflicts that agents handle poorly.

---

## Worktree Isolation

Every task that produces or modifies files MUST operate in its own [git worktree](https://git-scm.com/docs/git-worktree). A worktree is a separate checkout of the same repository - it shares the `.git` directory but has its own working tree and branch.

### Why Worktrees, Not Just Branches

Branches alone do not provide isolation. If two replicants both `git checkout` different branches in the same working directory, they step on each other. Worktrees give each task a physically separate directory with its own branch checked out.

### Worktree Path Convention

```
workbench/<branch-leaf>
```

- `<branch-leaf>`: The last path segment of the branch name.

Worktrees live inside the workspace's `workbench/` directory. This keeps active work co-located with the project and avoids sibling-directory confusion.

**Example**: For branch `research-agent/keda-autoscaling`:
```
workbench/keda-autoscaling
```

### Branch Naming Convention

```
<context>/<topic>[/<sub-topic>]
```

- **context**: Identifies who or what is working (e.g., `research-agent`, `code-replicant`, `feat`, `fix`, `hotfix`)
- **topic**: The subject of the work in kebab-case
- **sub-topic** (optional): For extensions or sub-tasks

**Examples**:

| Branch | Purpose |
|--------|---------|
| `research-agent/keda-autoscaling` | New research on KEDA |
| `research-agent/keda-autoscaling/azure-sb` | Extending existing KEDA research |
| `code-replicant/auth-module` | Replicant building auth feature |
| `feat/auth-module` | Human-driven feature work |
| `fix/login-timeout` | Bug fix |

### Worktree Decision Table

Before creating a worktree, check existing state:

| Branch exists? | Worktree dir exists? | Action |
|:-:|:-:|------|
| No | No | Create new branch + worktree: `git worktree add -b "$BRANCH" "workbench/$LEAF"` |
| Yes | No | Attach worktree to existing branch: `git worktree add "workbench/$LEAF" "$BRANCH"` |
| Yes | Yes | Just `cd` into the existing worktree and continue |

### Setup Procedure

```bash
# Derive values
REPO_ROOT=$(git rev-parse --show-toplevel)
BRANCH_NAME="<context>/<topic>"
BRANCH_LEAF=$(echo "$BRANCH_NAME" | rev | cut -d'/' -f1 | rev)
WORKTREE_PATH="workbench/${BRANCH_LEAF}"

# Check for existing branch/worktree
git branch --list "$BRANCH_NAME"
git worktree list

# Create (pick one based on decision table):
git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH"    # New branch + worktree
git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"        # Existing branch, new worktree

# Switch into it
cd "$WORKTREE_PATH"
```

### Cleanup

After work is merged:

```bash
# From the main repo directory
git worktree remove "workbench/${BRANCH_LEAF}"
git branch -d "$BRANCH_NAME"
```

---

## Conventional Commits

Every commit MUST follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Rules

| Rule | Detail |
|------|--------|
| **type** | Required. Lowercase. From the approved list below. |
| **scope** | Recommended. Kebab-case. Identifies what area of the project is affected. |
| **description** | Required. Imperative mood ("add", not "added"). Lowercase. No trailing period. |
| **body** | Optional. Explain *what* and *why*, not *how*. Wrap at 72 characters. |
| **footer** | Required: `Co-authored-by` trailer. Optional: `BREAKING CHANGE:`, issue refs, etc. |

### Approved Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature or capability | `feat(auth): add JWT refresh endpoint` |
| `fix` | Bug fix | `fix(api): handle null response from upstream` |
| `docs` | Documentation only | `docs(readme): update setup instructions` |
| `refactor` | Code restructuring, no behavior change | `refactor(db): extract connection pool logic` |
| `test` | Adding or fixing tests | `test(auth): add token expiry edge case` |
| `ci` | CI/CD pipeline changes | `ci(actions): add caching for npm install` |
| `chore` | Maintenance, scaffolding, tooling | `chore(deps): update eslint to v9` |
| `research` | Research findings | `research(keda): add autoscaling analysis` |
| `spec` | Specification content | `spec(auth): define login flow requirements` |

### Breaking Changes

Append `!` after the type/scope, and include a `BREAKING CHANGE:` footer:

```
feat(api)!: change authentication to OAuth2

BREAKING CHANGE: Bearer token format has changed. All clients must update.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## Merge Strategy

- **Default**: Merge to `main` when work is complete and reviewed.
- **Fast-forward preferred**: When the branch is cleanly ahead of main, use fast-forward merge to keep history linear.
- **Squash when noisy**: If a branch has many incremental checkpoint commits that do not add value individually, squash-merge with a summary message.
- **Never force-push to `main`**: Force-pushing to shared branches is prohibited.

---

## Summary

| Convention | What | Why |
|-----------|------|-----|
| Worktree isolation | Separate directory per task | Prevents conflicts between concurrent replicants |
| Path convention | `workbench/<branch-leaf>` | Keeps active work co-located with the workspace |
| Branch naming | `<context>/<topic>` | Clear provenance and organization |
| Conventional commits | `<type>(<scope>): <desc>` | Machine-readable, scannable, consistent |
| Worktree-first workflow | Set up workspace before any work | Prevents data loss from interrupted sessions |

---

## Related Modules

- [core.md](core.md) - commit trailers and documentation conventions
- [artifact-production.md](artifact-production.md) - the scaffold-write-commit cycle that runs inside a worktree
