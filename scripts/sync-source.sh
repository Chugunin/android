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
CLANG_DIR="$LINEAGE_ROOT/prebuilts/clang/host/linux-x86"
CLANG_MARKER="$CLANG_DIR/.gts3llte-q-archive-ready"
CLANG_BASE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive"
CLANG_TAG_PRIMARY="android-10.0.0_r41"
CLANG_TAG_FALLBACK="android-10.0.0_r3"
CACHE_DIR="$LINEAGE_ROOT/.bootstrap-cache/clang-q"
DOWNLOADED_ARCHIVE=""

log() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

host_free_gb() {
  local value
  value="$(powershell.exe -NoProfile -Command '[math]::Floor((Get-PSDrive -Name C).Free/1GB)' 2>/dev/null | tr -d '\r' || true)"
  [[ "$value" =~ ^[0-9]+$ ]] && printf '%s\n' "$value" || return 1
}

check_disk_budget() {
  local free_gb
  if free_gb="$(host_free_gb)"; then
    log "Windows C: free=${free_gb}GB"
    if (( free_gb < 45 )); then
      log "Refusing source sync: less than 45GB free on physical Windows C:."
      return 1
    fi
  else
    log "WARNING: could not query physical Windows C: free space; continuing with conservative source operations."
  fi
}

download_archive() {
  local subtree="$1"
  local tag="$2"
  local archive="$CACHE_DIR/${tag}-${subtree}.tar.gz"
  local url="$CLANG_BASE/$tag/$subtree.tar.gz"
  local attempt rc

  DOWNLOADED_ARCHIVE=""
  mkdir -p "$CACHE_DIR"
  for attempt in 1 2 3; do
    log "Downloading clang subtree $subtree from $tag (attempt $attempt/3; resume enabled)"
    set +e
    curl -fL --http1.1 \
      --connect-timeout 20 \
      --max-time 1800 \
      --speed-time 90 \
      --speed-limit 1024 \
      --retry 2 \
      --retry-delay 5 \
      -C - \
      "$url" -o "$archive" 2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]}
    set -e

    if (( rc == 0 )) && tar -tzf "$archive" >/dev/null 2>&1; then
      DOWNLOADED_ARCHIVE="$archive"
      return 0
    fi

    # curl exit 33 means the server rejected resume. Discard only that partial
    # file and retry cleanly instead of spawning another background git fetch.
    if (( rc == 33 )); then
      log "Server rejected resume for $subtree; discarding partial archive before retry."
      rm -f "$archive"
    elif (( rc == 0 )); then
      log "Archive validation failed for $subtree; discarding corrupt archive."
      rm -f "$archive"
    else
      log "Download failed for $subtree with curl rc=$rc; keeping partial archive for the next resume attempt."
    fi
    sleep 5
  done
  return 1
}

install_subtree() {
  local subtree="$1"
  local archive=""
  local dest="$CLANG_DIR/$subtree"

  if download_archive "$subtree" "$CLANG_TAG_PRIMARY"; then
    archive="$DOWNLOADED_ARCHIVE"
  elif download_archive "$subtree" "$CLANG_TAG_FALLBACK"; then
    archive="$DOWNLOADED_ARCHIVE"
    log "Using Android Q fallback tag $CLANG_TAG_FALLBACK for $subtree"
  else
    log "Unable to download required clang subtree: $subtree"
    return 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$archive" -C "$dest"
  log "Installed $subtree ($(du -sh "$dest" | awk '{print $1}'))"
}

bootstrap_clang() {
  if [ -f "$CLANG_MARKER" ] && [ -x "$CLANG_DIR/clang-r353983c/bin/clang" ]; then
    log "=== Android Q clang archive bootstrap already present ==="
    return 0
  fi

  log "=== bootstrapping Android Q clang from resumable per-subtree archives ==="

  # Remove the failed repo/partial-clone state for this single oversized project.
  # The archive cache is intentionally preserved across CI runs so interrupted
  # transfers resume instead of starting a multi-gigabyte fetch from zero.
  rm -rf "$CLANG_DIR"
  rm -rf .repo/projects/prebuilts/clang/host/linux-x86.git
  rm -rf .repo/project-objects/platform/prebuilts/clang/host/linux-x86.git
  rm -rf .repo/project-objects/msft-mirror-aosp/platform.prebuilts.clang.host.linux-x86.git
  mkdir -p "$CLANG_DIR"

  local subtree
  for subtree in \
    clang-r353983c \
    clang-3289846 \
    clang-stable \
    llvm-binutils-stable \
    profiles \
    soong; do
    install_subtree "$subtree"
  done

  if [ ! -x "$CLANG_DIR/clang-r353983c/bin/clang" ]; then
    log "Required compiler missing after archive bootstrap: clang-r353983c/bin/clang"
    return 1
  fi

  touch "$CLANG_MARKER"
  du -sh "$CLANG_DIR" | tee -a "$LOG"
}

check_disk_budget
bootstrap_clang

log "=== repo sync (single attempt; oversized clang excluded) ==="
"$REPO_BIN" sync -c --no-tags -j2 --fail-fast 2>&1 | tee -a "$LOG"
