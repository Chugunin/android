#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
: "${BUILD_LOG:=$LINEAGE_ROOT/lineage17-build.log}"
: "${TARGET_DEVICE:=gts3llte}"

OUT="${GITHUB_WORKSPACE:-$PWD}/orchestration/artifacts"
mkdir -p "$OUT"

find "$LINEAGE_ROOT/out/target/product/$TARGET_DEVICE" -maxdepth 1 -type f -name 'lineage-17.1-*.zip' -exec cp -f {} "$OUT/" \; 2>/dev/null || true
[ -f "$BUILD_LOG" ] && cp -f "$BUILD_LOG" "$OUT/" || true
[ -f "$LINEAGE_ROOT/repo-sync.log" ] && cp -f "$LINEAGE_ROOT/repo-sync.log" "$OUT/" || true

ls -lh "$OUT" || true
