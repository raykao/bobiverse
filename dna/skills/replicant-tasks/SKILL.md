---
name: replicant-tasks
description: Use when a repository's session hooks reconcile or back up Beads (bd) state through replicant, or when a task/memory operation needs a durable retry guarantee instead of a fire-and-forget bd call that could silently fail. Trigger when the user asks why a backup or sync silently failed, wants to inspect queued/failed durability operations, or is wiring up a new agent's hooks.
---

# replicant-tasks

`replicant` is a thin durability/reconciliation wrapper around `bd` (Beads). It exists because bare hook calls like `bd backup sync >/dev/null 2>&1 || true` silently discard failures with no record - `replicant` enqueues every attempt in a local SQLite file (`.replicant/queue.sqlite`) first, so a failure is durably recorded and automatically retried on the next reconciliation pass, instead of vanishing.

## First Step

Check whether `replicant` is installed and what it currently knows about:

```bash
replicant --help
cd <main-checkout-root> && replicant queue list
```

If `replicant` is not installed, run `dna/bootstrap.sh` from this repo (`raykao/bobiverse`) to install both `bd` and `replicant`.

## Core CLI Workflow

- `replicant reconcile [--dry-run] [--cwd PATH]` - replays every pending/failed queued operation. Prints a JSON summary (`total_pending`, `synced`, `failed`, `would_sync`, `skipped_unknown_operation_type`). Exits 1 if anything failed.
- `replicant backup sync [--cwd PATH]` - enqueues and immediately attempts a `beads_backup` operation (wraps `bd backup sync`).
- `replicant bead create/update/close [--cwd PATH]` - durable wrappers around the equivalent `bd` task-mutation commands.
- `replicant queue list` - inspect the queue (operates on the current directory - no `--cwd` flag; `cd` to the target root first).

## Critical: cross-worktree queue sharing

`replicant`'s queue file has NO automatic cross-worktree discovery, unlike `bd`'s own `.beads/` directory. Any hook or script invoking `replicant` across multiple git worktrees of the same repo MUST resolve `--cwd` to the main checkout root explicitly, or the queue silently fragments per-worktree and the durability guarantee is defeated:

```bash
GIT_COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
REPLICANT_CWD="$([ -n "$GIT_COMMON_DIR" ] && dirname "$GIT_COMMON_DIR" || pwd)"
```

Use `--path-format=absolute` specifically - the bare `--git-common-dir` flag returns a relative path (e.g. `.git`) when run from the main checkout itself, but an absolute path from a linked worktree. Skipping `--path-format=absolute` breaks silently in exactly the main-checkout case.

## Rules

- Do not treat a missing `replicant` install as blocking - every hook call is guarded with `if command -v replicant &>/dev/null` and falls back to the old bare `bd` call.
- Do not invent new operation types without updating `eridanilabs/replicant-tasks`'s `reconcile.py` dispatch loop first - the queue only knows about `github_sync` and `beads_backup`.
- If a queued operation stays `failed` across multiple reconciliation passes, inspect `replicant queue list` for the recorded `last_error` before assuming the whole pipeline is broken - it may be a legitimate, actionable failure (e.g. no backup destination configured yet).
