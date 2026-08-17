#!/usr/bin/env bash
# session-end.sh
#
# Beads is the source of truth for session handoff state - the sessionStart hook
# reads it directly and injects via additionalContext. No .handoff-state.md file
# is written here.
#
# {{AGENT_NAME}} also maintains a separate git-based backup on the
# beads-backup-{{AGENT_NAME}} branch of this repository, in addition to bd's
# automatic dolt-backed sync.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cat >/dev/null

export PATH="${HOME}/.local/bin:$PATH"
export BEADS_DIR="${BEADS_DIR:-${WORKSPACE_ROOT}/.beads}"
export BEADS_ACTOR="${BEADS_ACTOR:-{{AGENT_NAME}}}"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S)Z

if command -v bd &>/dev/null; then
  # Compute the main checkout root, same method as session-start.sh, so replicant's queue
  # is the one shared file across all worktrees.
  GIT_COMMON_DIR="$(git -C "$WORKSPACE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$GIT_COMMON_DIR" ]; then
    REPLICANT_CWD="$(dirname "$GIT_COMMON_DIR")"
  else
    REPLICANT_CWD="$WORKSPACE_ROOT"
  fi

  # Durable backup attempt: enqueues a beads_backup op first, then attempts it immediately.
  # Unlike a bare "bd backup sync || true", a failure here is NOT silently discarded -
  # it is recorded in replicant's local queue and retried by the next session-start
  # reconciliation pass. Falls back to the old bare call if replicant isn't installed.
  if command -v replicant &>/dev/null; then
    replicant backup sync --cwd "$REPLICANT_CWD" >/dev/null 2>&1 || true
  else
    bd backup sync >/dev/null 2>&1 || true
  fi

  # Transparent whole-DB github sync pass: pushes out any local bead mutations made during this
  # session. Unconditional - does not depend on any specific bead mutation having enqueued a
  # github_sync op via `replicant bead create/update/close`; this closes that gap by always
  # attempting a whole-DB sync regardless of which bd commands were used. Best-effort: if
  # replicant is not installed, this is a silent no-op (no bare bd fallback exists for this).
  if command -v replicant &>/dev/null; then
    replicant github sync --cwd "$REPLICANT_CWD" >/dev/null 2>&1 || true
  fi

  # Additional git-based backup on a dedicated branch in this repository.
  REPO="${WORKSPACE_ROOT}"
  BACKUP_SRC="$BEADS_DIR/backup"
  BRANCH="beads-backup-{{AGENT_NAME}}"
  WT="/tmp/beads-backup-{{AGENT_NAME}}-wt-$$"

  {
    if git -C "$REPO" worktree add --detach "$WT" 2>/dev/null; then
      git -C "$WT" checkout "$BRANCH" 2>/dev/null || git -C "$WT" checkout --orphan "$BRANCH"
      rm -rf "$WT/backup" "$WT/memories.jsonl"
      mkdir -p "$WT/backup"
      cp -r "$BACKUP_SRC/." "$WT/backup/" 2>/dev/null || true
      bd export --all -o "$WT/memories.jsonl" 2>/dev/null || true
      git -C "$WT" add -A
      if ! git -C "$WT" diff --cached --quiet; then
        git -C "$WT" commit -m "chore({{AGENT_NAME}}): beads backup at $TIMESTAMP" --no-verify
        git -C "$WT" push origin "$BRANCH" 2>/dev/null || true
      fi
      git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
    fi
  } >/dev/null 2>&1
fi

echo '{}'
