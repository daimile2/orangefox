# OrangeFox Recovery for Xiaomi Mi 11 Lite 5G / 11 Lite 5G NE (renoir)

Based on the OrangeFox `fox_12.1` (Android 12.1) manifest.

## Contents

- `device/xiaomi/renoir/` — OrangeFox/TWRP device tree for renoir
  (prebuilt kernel, dtb/dtbo, recovery init scripts, fox build vars).
- `patches/` — build fixes and feature patches against the `fox_12.1`
  manifest projects. Apply them after `repo sync`:

```sh
cd <fox_12.1 source root>
git -C bootable/recovery    apply /path/to/patches/bootable_recovery.patch
git -C build/make           apply /path/to/patches/build_make.patch
git -C external/libfuse     apply /path/to/patches/external_libfuse.patch
git -C system/core          apply /path/to/patches/system_core.patch
git -C system/update_engine apply /path/to/patches/system_update_engine.patch
git -C vendor/twrp          apply /path/to/patches/vendor_twrp.patch
```

### What the patches do

- `bootable_recovery.patch` — `gui/action.cpp`, `gui/gui.cpp`,
  `gui/objects.hpp`: boot-time automation hooks used by
  `fox_adb_sideload_cycle.sh` (adb disable / sideload / sideload cancel
  cycle that re-enumerates the USB ADB FunctionFS endpoint so the host
  PC picks up `adb` reliably after boot).
- `build_make.patch`, `external_libfuse.patch`, `system_core.patch`,
  `system_update_engine.patch`, `vendor_twrp.patch` — build fixes
  required to compile the fox_12.1 tree.

## Build

```sh
repo init -u https://gitlab.com/OrangeFox/misc/sync.git -b fox_12.1
repo sync
# copy device/xiaomi/renoir into the tree, apply the patches above
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_renoir-eng
mka recoveryimage
```

## Notes

- Boot-time script `device/xiaomi/renoir/recovery/root/system/bin/fox_adb_sideload_cycle.sh`
  runs the adb → sideload → cancel cycle automatically and waits for
  `sys.usb.ffs.ready=1` before reporting success. Log: `/tmp/fox_adb_boot.log`.
- Prebuilt recovery images are attached to the GitHub Releases of this repo.
