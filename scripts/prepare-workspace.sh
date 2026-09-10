#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
mkdir -p "$LINEAGE_ROOT/.repo/local_manifests"
cd "$LINEAGE_ROOT"

if [ ! -d .repo ]; then
  repo init -u https://github.com/Chugunin/android.git -b lineage-17.1 --depth=1 --no-clone-bundle -g default,-darwin --platform=linux
fi

cat > .repo/local_manifests/gts3llte.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="chugunin" fetch="https://github.com/Chugunin/" />
  <project name="android_device_samsung_gts3llte" path="device/samsung/gts3llte" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
  <project name="android_kernel_samsung_msm8996" path="kernel/samsung/msm8996" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
  <project name="android_vendor_samsung_gts3llte" path="vendor/samsung/gts3llte" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
</manifest>
EOF

echo "Workspace: $LINEAGE_ROOT"
echo "Local manifest:"
cat .repo/local_manifests/gts3llte.xml
