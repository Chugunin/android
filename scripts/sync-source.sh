#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
export PATH="$HOME/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOADER="$SCRIPT_DIR/github-tag-tree-downloader.py"
TAG="android-10.0.0_r41"
LOG="$LINEAGE_ROOT/repo-sync.log"
MANUAL_CACHE="$HOME/android/manual-prebuilts"

REPO_BIN="$(command -v repo || true)"
if [ -z "$REPO_BIN" ] && [ -x "$HOME/bin/repo" ]; then REPO_BIN="$HOME/bin/repo"; fi
if [ -z "$REPO_BIN" ]; then echo "repo tool not found" >&2; exit 127; fi
if [ ! -f "$DOWNLOADER" ]; then echo "Downloader missing: $DOWNLOADER" >&2; exit 127; fi

cd "$LINEAGE_ROOT"
: > "$LOG"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

host_free_gb() {
  local value
  value="$(powershell.exe -NoProfile -Command '[math]::Floor((Get-PSDrive -Name C).Free/1GB)' 2>/dev/null | tr -d '\r' || true)"
  [[ "$value" =~ ^[0-9]+$ ]] && printf '%s\n' "$value" || return 1
}

check_disk_budget() {
  local free_gb
  if free_gb="$(host_free_gb)"; then
    log "Windows C: free=${free_gb}GB"
    if (( free_gb < 40 )); then
      log "Refusing source operation: less than 40GB free on physical Windows C:."
      exit 1
    fi
  else
    log "WARNING: unable to query physical Windows C: free space."
  fi
}

adopt_manual_cache() {
  local cache="$1" dest="$2"
  if [ -d "$cache" ] && [ ! -e "$dest" ]; then
    log "Adopting manually downloaded tree: $cache -> $dest"
    mkdir -p "$(dirname "$dest")"
    mv "$cache" "$dest"
  fi
}

bootstrap_github_tree() {
  local github_repo="$1" dest="$2" cache="$3"
  adopt_manual_cache "$cache" "$dest"
  mkdir -p "$dest"
  log "=== verify/bootstrap $github_repo@$TAG ==="
  python3 "$DOWNLOADER" "$github_repo" "$TAG" "$dest" -j 8 --retries 10 2>&1 | tee -a "$LOG"
  rm -rf "$dest/.bootstrap-meta"
  log "Ready: $dest ($(du -sh "$dest" | awk '{print $1}'))"
}

check_clang() {
  local clang="$LINEAGE_ROOT/prebuilts/clang/host/linux-x86/clang-r353983c/bin/clang"
  if [ ! -x "$clang" ]; then
    log "ERROR: Android Q clang-r353983c is missing. Existing manual clang bootstrap is required on this persistent runner."
    exit 1
  fi
  log "=== clang ready ==="
  "$clang" --version | head -2 | tee -a "$LOG"
}

check_disk_budget
check_clang
bootstrap_github_tree "msft-mirror-aosp/platform.prebuilts.gradle-plugin" "$LINEAGE_ROOT/prebuilts/gradle-plugin" "$MANUAL_CACHE/gradle-plugin-r41"
bootstrap_github_tree "msft-mirror-aosp/platform.prebuilts.tools" "$LINEAGE_ROOT/prebuilts/tools" "$MANUAL_CACHE/tools-r41"
check_disk_budget

log "=== repo sync (large manual prebuilts excluded) ==="
"$REPO_BIN" sync -c --no-tags -j2 --retry-fetches=5 --fail-fast 2>&1 | tee -a "$LOG"
log "=== repo sync completed successfully ==="
