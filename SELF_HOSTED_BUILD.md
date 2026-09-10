# gts3llte LineageOS 17.1 self-hosted build

This branch orchestrates persistent LineageOS builds on a GitHub Actions self-hosted runner in WSL2.

## Runner

Expected labels:

- self-hosted
- Linux
- X64
- gts3llte

Expected persistent source root:

`/home/lelouch/android/lineage17`

## Source branches

- `Chugunin/android_device_samsung_gts3llte:gts3llte-17.1-dev`
- `Chugunin/android_kernel_samsung_msm8996:gts3llte-17.1-dev`
- `Chugunin/android_vendor_samsung_gts3llte:gts3llte-17.1-dev`

## Workflow

`.github/workflows/build-gts3llte.yml`

Manual inputs:

- `sync_source`: sync source before build (default true)
- `clean_out`: delete `out/` before build (default false)

The workflow uses the persistent source tree, resolves device dependencies, builds `lineage_gts3llte-userdebug`, and uploads the ROM ZIP and logs as GitHub Actions artifacts.

## Important

The self-hosted runner does not solve upstream network failures by itself. Persistent checkout and retries prevent throwing away completed work. Large problematic prebuilts can be handled separately in the persistent source tree and then builds can run with `sync_source=false` until the transport issue is resolved.
