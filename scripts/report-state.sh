#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
OUT="${GITHUB_WORKSPACE:-$PWD}/orchestration/artifacts"
mkdir -p "$OUT"
{
  echo "=== DATE ==="
  date -Is
  echo
  echo "=== HOST ==="
  uname -a
  echo
  echo "=== CPU ==="
  nproc
  echo
  echo "=== MEMORY ==="
  free -h
  echo
  echo "=== DISK ==="
  df -h "$LINEAGE_ROOT"
  echo
  echo "=== TREE SIZE ==="
  du -sh "$LINEAGE_ROOT" 2>/dev/null || true
  du -sh "$LINEAGE_ROOT/.repo" 2>/dev/null || true
} | tee "$OUT/host-state.txt"
