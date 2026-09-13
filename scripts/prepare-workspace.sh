#!/usr/bin/env bash
set -euo pipefail

: "${LINEAGE_ROOT:=/home/lelouch/android/lineage17}"
export PATH="$HOME/bin:$PATH"

mkdir -p "$LINEAGE_ROOT"
cd "$LINEAGE_ROOT"

REPO_BIN="$(command -v repo || true)"
if [ -z "$REPO_BIN" ] && [ -x "$HOME/bin/repo" ]; then REPO_BIN="$HOME/bin/repo"; fi
if [ -z "$REPO_BIN" ]; then echo "repo tool not found. Expected it in PATH or at $HOME/bin/repo" >&2; exit 127; fi

if [ ! -d .repo ]; then
  "$REPO_BIN" init -u https://github.com/Chugunin/android.git -b lineage-17.1 --depth=1 --no-clone-bundle -g default,-darwin --platform=linux
fi

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/gts3llte.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="chugunin" fetch="https://github.com/Chugunin/" />
  <project name="android_device_samsung_gts3llte" path="device/samsung/gts3llte" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
  <project name="android_kernel_samsung_msm8996" path="kernel/samsung/msm8996" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
  <project name="android_vendor_samsung_gts3llte" path="vendor/samsung/gts3llte" remote="chugunin" revision="gts3llte-17.1-dev" clone-depth="1" />
</manifest>
EOF

rm -f .repo/local_manifests/prebuilt-mirrors.xml .repo/local_manifests/manual-clang.xml
cat > .repo/local_manifests/manual-prebuilts.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remove-project name="platform/prebuilts/clang/host/linux-x86" />
  <remove-project name="platform/prebuilts/gradle-plugin" />
  <remove-project name="platform/prebuilts/tools" />
</manifest>
EOF

# The clang project is intentionally excluded from repo sync because the large
# upstream repository is unreliable on this runner. The manually installed
# clang-r353983c directory therefore has no repository-root Android.bp. Restore
# the Q-era Soong export needed by header-checker and other host LLVM tools.
CLANG_PREBUILT_ROOT="$LINEAGE_ROOT/prebuilts/clang/host/linux-x86"
if [ -d "$CLANG_PREBUILT_ROOT/clang-r353983c" ] && [ ! -f "$CLANG_PREBUILT_ROOT/Android.bp" ]; then
  cat > "$CLANG_PREBUILT_ROOT/Android.bp" <<'EOF'
// Minimal Soong metadata retained alongside the manually installed Q clang.
// Export LLVM_BUILD_HOST_TOOLS.
llvm_host_defaults {
    name: "llvm-build-host-tools-defaults",
}
EOF
fi

echo "Workspace: $LINEAGE_ROOT"
echo "Local manifests:"
cat .repo/local_manifests/gts3llte.xml
cat .repo/local_manifests/manual-prebuilts.xml
