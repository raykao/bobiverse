#!/usr/bin/env bash
# bootstrap.sh
#
# Idempotent installer for the two CLI tools every Bob-family agent needs:
#   - bd (Beads)  - durable task tracking, installed via Homebrew (public formula)
#   - replicant   - durability/reconciliation layer for bd, installed from the
#                   private eridanilabs/replicant-tasks repo via a dedicated venv
#
# Safe to re-run - each tool is skipped if already on PATH. Run this before
# scaffolding a new agent's hooks (see raykao/bob AGENTS.md agent_provisioning
# Step 2), or any time on an existing agent's host to catch up a missing tool.
set -euo pipefail

echo "=== Bootstrapping bd + replicant ==="

# --- bd (Beads) ---
if command -v bd &>/dev/null; then
  echo "bd already installed: $(bd version 2>&1 | head -1)"
else
  if command -v brew &>/dev/null; then
    echo "Installing bd via Homebrew..."
    brew install beads
  else
    echo "ERROR: Homebrew not found and bd is not installed." >&2
    echo "Install Homebrew (https://brew.sh) then run: brew install beads" >&2
    exit 1
  fi
fi

# --- replicant ---
if command -v replicant &>/dev/null; then
  echo "replicant already installed: $(command -v replicant)"
else
  PYTHON_BIN="python3.10"
  if ! command -v "$PYTHON_BIN" &>/dev/null; then
    echo "ERROR: $PYTHON_BIN not found. replicant requires Python 3.10+." >&2
    echo "Install it (e.g. 'brew install python@3.10') and re-run this script." >&2
    exit 1
  fi

  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Needed to authenticate against the private" >&2
    echo "eridanilabs/replicant-tasks repo for install." >&2
    exit 1
  fi

  GH_TOKEN_VALUE="$(gh auth token 2>/dev/null || true)"
  if [ -z "$GH_TOKEN_VALUE" ]; then
    echo "ERROR: 'gh auth token' returned nothing. Run 'gh auth login' first." >&2
    exit 1
  fi

  echo "Installing replicant into a dedicated venv..."
  "$PYTHON_BIN" -m venv ~/.local/share/replicant-tasks/venv
  ~/.local/share/replicant-tasks/venv/bin/pip install --quiet --upgrade \
    "git+https://x-access-token:${GH_TOKEN_VALUE}@github.com/eridanilabs/replicant-tasks.git"

  mkdir -p ~/.local/bin
  ln -sf ~/.local/share/replicant-tasks/venv/bin/replicant ~/.local/bin/replicant
fi

echo "=== Verifying ==="
command -v bd &>/dev/null && echo "bd:        $(command -v bd)"
command -v replicant &>/dev/null && echo "replicant: $(command -v replicant)"

echo "=== Bootstrap complete ==="
