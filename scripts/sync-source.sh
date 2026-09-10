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
CLANG_MARKER="$CLANG_DIR/.gts3llte-q-sparse-ready"
CLANG_URL="https://github.com/msft-mirror-aosp/platform.prebuilts.clang.host.linux-x86.git"
CLANG_TAG="android-10.0.0_r41"

bootstrap_clang() {
  if [ -f "$CLANG_MARKER" ] && [ -x "$CLANG_DIR/clang-r353983c/bin/clang" ]; then
    echo "=== clang sparse prebuilt already present ===" | tee -a "$LOG"
    return 0
  fi

  echo "=== bootstrapping Android Q clang via partial+sparse clone ===" | tee -a "$LOG"

  # Remove failed repo-managed caches/worktree for this one project only.
  rm -rf "$CLANG_DIR"
  rm -rf .repo/projects/prebuilts/clang/host/linux-x86.git
  rm -rf .repo/project-objects/platform/prebuilts/clang/host/linux-x86.git
  rm -rf .repo/project-objects/msft-mirror-aosp/platform.prebuilts.clang.host.linux-x86.git

  mkdir -p "$(dirname "$CLANG_DIR")"

  # Blobless clone downloads repository metadata first, then only blobs from the
  # selected Android-Q compiler paths instead of the whole historical prebuilt repo.
  git -c http.version=HTTP/1.1 clone \
    --filter=blob:none \
    --no-checkout \
    --depth=1 \
    --branch "$CLANG_TAG" \
    "$CLANG_URL" \
    "$CLANG_DIR" 2>&1 | tee -a "$LOG"

  git -C "$CLANG_DIR" sparse-checkout init --cone 2>&1 | tee -a "$LOG"
  git -C "$CLANG_DIR" sparse-checkout set \
    clang-r353983c \
    clang-3289846 \
    clang-stable \
    llvm-binutils-stable \
    profiles \
    soong 2>&1 | tee -a "$LOG"
  git -C "$CLANG_DIR" checkout "$CLANG_TAG" 2>&1 | tee -a "$LOG"

  if [ ! -x "$CLANG_DIR/clang-r353983c/bin/clang" ]; then
    echo "Required compiler missing after sparse checkout: clang-r353983c/bin/clang" | tee -a "$LOG" >&2
    return 1
  fi

  touch "$CLANG_MARKER"
  du -sh "$CLANG_DIR" | tee -a "$LOG"
}

bootstrap_clang

echo "=== repo sync (single attempt; oversized clang excluded) ===" | tee -a "$LOG"
"$REPO_BIN" sync -c --no-tags -j2 --fail-fast 2>&1 | tee -a "$LOG"
