#!/usr/bin/env bash
set -eo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
: "${BUILD_LOG:=$LINEAGE_ROOT/lineage17-build.log}"
: "${TARGET_DEVICE:=gts3llte}"

run_build() {
    cd "$LINEAGE_ROOT"
    source build/envsetup.sh
    lunch "lineage_${TARGET_DEVICE}-userdebug"
    brunch "$TARGET_DEVICE"
}

: > "$BUILD_LOG"
set +e
run_build 2>&1 | tee "$BUILD_LOG"
status=${PIPESTATUS[0]}
set -e

exit "$status"
