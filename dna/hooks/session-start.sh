#!/usr/bin/env bash
# session-start.sh
#
# Reads JSON input from copilot-bridge:
#   { "sessionId": "...", "source": "startup"|"resume"|"new", ... }
#
# Emits JSON output consumed by the SDK:
#   { "additionalContext": "<text injected into system prompt>" }
#
# Behavior: always inject the latest session-handoff memory if one exists.
# Beads is the source of truth.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Drain stdin (SDK expects us to consume it).
cat >/dev/null

export PATH="${HOME}/.local/bin:$PATH"
export BEADS_DIR="${BEADS_DIR:-${WORKSPACE_ROOT}/.beads}"
export BEADS_ACTOR="${BEADS_ACTOR:-{{AGENT_NAME}}}"

if ! command -v bd &>/dev/null; then
  echo '{}'
  exit 0
fi

# Compute the main checkout root (shared across all git worktrees of this repo, matching
# how bd itself shares .beads/ via git-common-directory discovery) so replicant's local
# queue is a single shared file regardless of which worktree this hook runs in.
GIT_COMMON_DIR="$(git -C "$WORKSPACE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$GIT_COMMON_DIR" ]; then
  REPLICANT_CWD="$(dirname "$GIT_COMMON_DIR")"
else
  REPLICANT_CWD="$WORKSPACE_ROOT"
fi

# Mandatory reconciliation pass: replay any queued replicant ops (github_sync, beads_backup)
# that did not complete in a prior session, before anything else happens. Best-effort: if
# replicant is not installed on this machine, this is a silent no-op (old behavior).
if command -v replicant &>/dev/null; then
  replicant reconcile --cwd "$REPLICANT_CWD" >/dev/null 2>&1 || true
fi

# Transparent whole-DB github sync pass: pulls in any GitHub-side changes (issue edits, comments,
# closures made directly on GitHub) before the session begins. Unconditional - does not depend on
# any specific bead mutation having enqueued a github_sync op. Best-effort: if replicant is not
# installed, this is a silent no-op.
if command -v replicant &>/dev/null; then
  replicant github sync --cwd "$REPLICANT_CWD" >/dev/null 2>&1 || true
fi

bd prime >/dev/null 2>&1 || true

# Find the latest session-handoff memory key (lexicographic sort works because keys embed ISO date).
HANDOFF_KEY=$(bd memories session-handoff --json 2>/dev/null \
  | jq -r 'keys[]? | select(startswith("session-handoff-{{AGENT_NAME}}-"))' \
  | sort | tail -1 || true)

CONTEXT=""

if [ -n "$HANDOFF_KEY" ]; then
  HANDOFF_BODY=$(bd recall "$HANDOFF_KEY" 2>/dev/null || true)
  if [ -n "$HANDOFF_BODY" ]; then
    READY=$(bd ready --json 2>/dev/null \
      | jq -r '.[]? | "  - \(.id // "?"): \(.title // "(untitled)")"' 2>/dev/null \
      | head -10 || true)
    [ -z "$READY" ] && READY="  (none)"

    CONTEXT=$(cat <<HANDOFF
## Session Resume State

The following was auto-injected by the sessionStart hook from Beads (source of truth).

**Latest handoff** (\`$HANDOFF_KEY\`):

$HANDOFF_BODY

**Top open Beads tasks:**

$READY

You are resuming a prior session. On your first turn, briefly acknowledge the handoff and confirm scope with the user before starting new work. If the first user message is unrelated to the handoff, treat the handoff as background context and proceed with the request.
HANDOFF
)
  fi
fi

REMINDER=$(cat << 'REMINDER'

=== MEMORY DISCIPLINE REMINDER ===
MEMORY.md is READ-ONLY. Do NOT attempt to write to it.
- Persistent knowledge: bd remember "fact"
- Task tracking:        bd create --title="..." --description="..."
- Search memory:        bd memories <keyword>
Writing to MEMORY.md is a bug. Use bd.
===================================
REMINDER
)
CONTEXT="${CONTEXT}${REMINDER}"

if [ -z "$CONTEXT" ]; then
  echo '{}'
  exit 0
fi

jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
