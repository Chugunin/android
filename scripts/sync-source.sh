#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
export PATH="$HOME/bin:$PATH"

REPO_BIN="$(command -v repo || true)"
if [ -z "$REPO_BIN" ] && [ -x "$HOME/bin/repo" ]; then
  REPO_BIN="$HOME/bin/repo"
fi
if [ -z "$REPO_BIN" ]; then
  echo "repo tool not found. Expected it in PATH or at $HOME/bin/repo" >&2
  exit 127
fi

cd "$LINEAGE_ROOT"

LOG="$LINEAGE_ROOT/repo-sync.log"
ATTEMPTS=3

for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "=== repo sync attempt $attempt/$ATTEMPTS ===" | tee -a "$LOG"
  if "$REPO_BIN" sync -c --no-tags -j2 --fail-fast 2>&1 | tee -a "$LOG"; then
    exit 0
  fi
  if [ "$attempt" -lt "$ATTEMPTS" ]; then
    echo "repo sync failed; retrying after 15 seconds" | tee -a "$LOG"
    sleep 15
  fi
done

exit 1
