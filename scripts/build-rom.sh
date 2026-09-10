#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
: "${BUILD_LOG:=$LINEAGE_ROOT/lineage17-build.log}"
: "${TARGET_DEVICE:=gts3llte}"

cd "$LINEAGE_ROOT"
source build/envsetup.sh
lunch "lineage_${TARGET_DEVICE}-userdebug"

set +e
brunch "$TARGET_DEVICE" 2>&1 | tee "$BUILD_LOG"
status=${PIPESTATUS[0]}
set -e

exit "$status"
