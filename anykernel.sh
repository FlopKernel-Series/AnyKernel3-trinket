### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=FloppyKernel v2.0b for Xiaomi Trinket devices by @Flopster101
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=ginkgo
device.name2=willow
device.name3=laurel_sprout
supported.versions=10.0-16.0
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# Unified package support
ak3_device="$(getprop ro.product.vendor.device 2>/dev/null)";
[ "$ak3_device" ] || ak3_device="$(getprop ro.product.device 2>/dev/null)";
[ "$ak3_device" ] || ak3_device="$(getprop ro.build.product 2>/dev/null)";
ak3_device="$(echo "$ak3_device" | tr '[:upper:]' '[:lower:]')";

# Device-specific tweaks
case "$ak3_device" in
  ginkgo|willow)
    # Parse feature flags from /cache/fk_feat if present
    cache_mounted=0;
    if mountpoint -q /cache 2>/dev/null; then
      cache_mounted=1;
    else
      if mount /cache 2>/dev/null; then
        cache_mounted=1;
      fi
    fi

    fk_feat_legacy_timestamp=0
    if [ "$cache_mounted" -eq 1 ] && [ -f /cache/fk_feat ]; then
      if grep -q "no_init_protection" /cache/fk_feat 2>/dev/null; then
        ui_print "Reloaded feature: Kill init protection"
        patch_cmdline "no_init_protection" "no_init_protection=1"
      fi

      if grep -q "legacy_timestamp_source" /cache/fk_feat 2>/dev/null; then
        ui_print "Reloaded feature: Legacy Timestamp Source"
        patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
        fk_feat_legacy_timestamp=1
      fi

      if grep -q "uname_bpf_spoof=" /cache/fk_feat 2>/dev/null; then
        val=$(grep -o 'uname_bpf_spoof=[0-9]*' /cache/fk_feat | head -n1 | cut -d= -f2)
        ui_print "Reloaded feature: Linux version spoofing for BPF (mode $val)"
        patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=$val"
      elif grep -q "uname_bpf_spoof" /cache/fk_feat 2>/dev/null; then
        ui_print "Reloaded feature: Linux version spoofing for BPF (default)"
        patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=1"
      fi

      if grep -q "no_msm_perf_boost" /cache/fk_feat 2>/dev/null; then
        ui_print "Reloaded feature: Nuke MSM Performance boosting"
        patch_cmdline "no_msm_perf_boost" "no_msm_perf_boost=1"
      fi

      if grep -q "warm_reboot" /cache/fk_feat 2>/dev/null; then
        ui_print "Reloaded feature: Forced warm reboot"
        patch_cmdline "warm_reboot" "warm_reboot=1"
      fi
    fi

    # HyperMINT detection (informational only)
    if [ -f /vendor/build.prop ] && grep -q -E 'MINT|mintdevice' /vendor/build.prop; then
      ui_print "HyperMINT ROM DETECTED, you might need the BpfSpoof patch!..."
    fi

    # If legacy timestamp wasn't forced by fk_feat, decide based on Android version
    if [ "$fk_feat_legacy_timestamp" -eq 0 ]; then
      android_ver=$(file_getprop /system/build.prop ro.build.version.release)
      android_ver=${android_ver%%.*}
      if [ "$android_ver" -le 11 ] 2>/dev/null; then
        patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
        ui_print "Legacy timestamp workaround enabled"
      else
        patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=0"
        ui_print "Timestamp patch not needed"
      fi
    fi
    ;;
  laurel_sprout)
    # Laurel-specific conservative tweaks
    patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
    ui_print "Legacy timestamp workaround enabled"
    patch_cmdline "no_kernel_dimming" "no_kernel_dimming=1"
    ui_print "Disabling kernel dimming support (laurel_sprout)"
    ;;
  *)
    # No device-specific tweaks
    ;;
esac

case "$ak3_device" in
  laurel_sprout)
    ui_print "Selecting laurel_sprout DTB/DTBO...";
    # Unified zips must include device-named artifacts
    if [ -f "$AKHOME/dtb-laurel_sprout" ] && [ -f "$AKHOME/dtbo-laurel_sprout.img" ]; then
      cp -f "$AKHOME/dtb-laurel_sprout" "$AKHOME/dtb";
      cp -f "$AKHOME/dtbo-laurel_sprout.img" "$AKHOME/dtbo.img";
    else
      abort "laurel_sprout device detected but DTB/DTBO not present in zip. Aborting...";
    fi;
  ;;
  ginkgo|willow)
    ui_print "Selecting ginkgo/willow DTB/DTBO...";
    if [ -f "$AKHOME/dtb-ginkgo" ] && [ -f "$AKHOME/dtbo-ginkgo.img" ]; then
      cp -f "$AKHOME/dtb-ginkgo" "$AKHOME/dtb";
      cp -f "$AKHOME/dtbo-ginkgo.img" "$AKHOME/dtbo.img";
    else
      abort "ginkgo/willow device detected but DTB/DTBO not present in zip. Aborting...";
    fi;
  ;;
  *)
    # Other devices: no selection
    ;;
esac;

# boot install
split_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

# Check if vendor isn't already mounted. This should make the detection work on flasher apps.
do_patch=1;
if [ ! -e /vendor/etc/fstab.qcom ]; then
	if [ -e /dev/block/by-name/vendor ]; then
		mount /dev/block/by-name/vendor /vendor
		if [ $? -ne 0 ]; then
			do_patch=0
		fi
	else
		# If the block device for vendor isn't present at that location, it might mean this a dynamic partitions ROM.
		mount /vendor
		if [ $? -ne 0 ]; then
			do_patch=0
		fi
	fi
fi

# Check for the presence of "first_stage_mount" in /vendor/etc/fstab only for /system or /vendor
if [ $do_patch -eq 1 ]; then
	if grep "first_stage_mount" /vendor/etc/fstab.qcom | grep -E -q '(/system|/vendor)'; then
		ui_print "Two-stage init ROM detected, patching cmdline..."
		patch_cmdline "tsinit" "tsinit"
	else
		ui_print "Legacy init ROM detected, no need to patch"
	fi
else
	ui_print "Skipping cmdline patch because vendor could not be mounted!"
fi

# Check if /cache is mounted, try to mount if not
cache_mounted=0;
if mountpoint -q /cache 2>/dev/null; then
  cache_mounted=1;
else
  if mount /cache 2>/dev/null; then
    cache_mounted=1;
  fi
fi

# Check for feature flags in /cache/fk_feat
fk_feat_legacy_timestamp=0
# fk_feat_uname_bpf_spoof=0

if [ "$cache_mounted" -eq 1 ] && [ -f /cache/fk_feat ]; then
  if grep -q "no_init_protection" /cache/fk_feat 2>/dev/null; then
    ui_print "Reloaded feature: Kill init protection"
    patch_cmdline "no_init_protection" "no_init_protection=1"
  fi

  if grep -q "legacy_timestamp_source" /cache/fk_feat 2>/dev/null; then
    ui_print "Reloaded feature: Legacy Timestamp Source"
    patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
    fk_feat_legacy_timestamp=1
  fi

  if grep -q "uname_bpf_spoof=" /cache/fk_feat 2>/dev/null; then
    val=$(grep -o 'uname_bpf_spoof=[0-9]*' /cache/fk_feat | head -n1 | cut -d= -f2)
    ui_print "Reloaded feature: Linux version spoofing for BPF (mode $val)"
    patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=$val"
    # fk_feat_uname_bpf_spoof=1
  elif grep -q "uname_bpf_spoof" /cache/fk_feat 2>/dev/null; then
    ui_print "Reloaded feature: Linux version spoofing for BPF (default)"
    patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=1"
    # fk_feat_uname_bpf_spoof=1
  fi

  if grep -q "no_msm_perf_boost" /cache/fk_feat 2>/dev/null; then
    ui_print "Reloaded feature: Nuke MSM Performance boosting"
    patch_cmdline "no_msm_perf_boost" "no_msm_perf_boost=1"
  fi

  if grep -q "warm_reboot" /cache/fk_feat 2>/dev/null; then
    ui_print "Reloaded feature: Forced warm reboot"
    patch_cmdline "warm_reboot" "warm_reboot=1"
  fi
fi

# # Enable bpf spoofing (only if not already set via fk_feat)
# if [ "$fk_feat_uname_bpf_spoof" -eq 0 ]; then
#   patch_uname_bpf_spoof() {
#     patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=1"
#   }

#   # if device is running HyperMINT ROM
#   if [ -f /vendor/build.prop ]; then
#     if grep -q -E 'MINT|mintdevice' /vendor/build.prop; then
#       ui_print "HyperMINT ROM detected, enabling bpf spoof..."
#       patch_uname_bpf_spoof
#     fi
#   fi
# fi

if [ -f /vendor/build.prop ]; then
  if grep -q -E 'MINT|mintdevice' /vendor/build.prop; then
    ui_print "HyperMINT ROM DETECTED, you might need the BpfSpoof patch!..."
  fi
fi

# Check for IR HAL type
if [ -f /vendor/bin/hw/android.hardware.ir-service.lineage ]; then
	ui_print "LIRC-based IR HAL detected"
else
	ui_print "Legacy spidev IR HAL detected"
	patch_cmdline "legacy_ir_hal" "legacy_ir_hal=1"
fi

# Get Android version from build.prop and set legacy_timestamp_source (only if not already set via fk_feat)
if [ "$fk_feat_legacy_timestamp" -eq 0 ]; then
  android_ver=$(file_getprop /system/build.prop ro.build.version.release)

  # Convert to integer (strip potential decimal points)
  android_ver=${android_ver%%.*}

  # Check if Android version is 11 or lower
  if [ "$android_ver" -le 11 ] 2>/dev/null; then
    patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
    ui_print "Legacy timestamp workaround enabled"
  else
    patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=0"
    ui_print "Timestamp patch not needed"
  fi
fi

flash_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
flash_dtbo;
## end boot install


## init_boot files attributes
#init_boot_attributes() {
#set_perm_recursive 0 0 755 644 $RAMDISK/*;
#set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
#} # end attributes

# init_boot shell variables
#BLOCK=init_boot;
#IS_SLOT_DEVICE=1;
#RAMDISK_COMPRESSION=auto;
#PATCH_VBMETA_FLAG=auto;

# reset for init_boot patching
#reset_ak;

# init_boot install
#dump_boot; # unpack ramdisk since it is the new first stage init ramdisk where overlay.d must go

#write_boot;
## end init_boot install


## vendor_kernel_boot shell variables
#BLOCK=vendor_kernel_boot;
#IS_SLOT_DEVICE=1;
#RAMDISK_COMPRESSION=auto;
#PATCH_VBMETA_FLAG=auto;

# reset for vendor_kernel_boot patching
#reset_ak;

# vendor_kernel_boot install
#split_boot; # skip unpack/repack ramdisk, e.g. for dtb on devices with hdr v4 and vendor_kernel_boot

#flash_boot;
## end vendor_kernel_boot install


## vendor_boot files attributes
#vendor_boot_attributes() {
#set_perm_recursive 0 0 755 644 $RAMDISK/*;
#set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
#} # end attributes

# vendor_boot shell variables
#BLOCK=vendor_boot;
#IS_SLOT_DEVICE=1;
#RAMDISK_COMPRESSION=auto;
#PATCH_VBMETA_FLAG=auto;

# reset for vendor_boot patching
#reset_ak;

# vendor_boot install
#dump_boot; # use split_boot to skip ramdisk unpack, e.g. for dtb on devices with hdr v4 but no vendor_kernel_boot

#write_boot; # use flash_boot to skip ramdisk repack, e.g. for dtb on devices with hdr v4 but no vendor_kernel_boot
## end vendor_boot install

