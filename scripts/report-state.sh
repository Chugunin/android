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
  echo "=== WSL VHD FILESYSTEM ==="
  df -h "$LINEAGE_ROOT"
  echo
  echo "=== WINDOWS HOST DISK ==="
  ROOT_DEV=$(df -P "$LINEAGE_ROOT" | awk 'NR==2 {print $1}')
  ROOT_MNT=$(df -P "$LINEAGE_ROOT" | awk 'NR==2 {print $6}')
  echo "WSL root device: $ROOT_DEV mounted at $ROOT_MNT"
  WIN_FREE=$(powershell.exe -NoProfile -Command "[math]::Round((Get-PSDrive -Name C).Free/1GB,1)" 2>/dev/null | tr -d '\r' || true)
  WIN_USED=$(powershell.exe -NoProfile -Command "[math]::Round((Get-PSDrive -Name C).Used/1GB,1)" 2>/dev/null | tr -d '\r' || true)
  WIN_TOTAL=$(powershell.exe -NoProfile -Command "[math]::Round(((Get-PSDrive -Name C).Free+(Get-PSDrive -Name C).Used)/1GB,1)" 2>/dev/null | tr -d '\r' || true)
  if [ -n "$WIN_FREE" ]; then
    echo "C: total=${WIN_TOTAL}GB used=${WIN_USED}GB free=${WIN_FREE}GB"
  else
    echo "Windows C: free space could not be queried"
  fi
  echo
  echo "=== TREE SIZE ==="
  du -sh "$LINEAGE_ROOT" 2>/dev/null || true
  du -sh "$LINEAGE_ROOT/.repo" 2>/dev/null || true
  du -sh "$LINEAGE_ROOT/out" 2>/dev/null || true
} | tee "$OUT/host-state.txt"
