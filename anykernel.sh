### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=FloppyKernel v1.0 (early) for laurel_sprout | @Flopster101
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=laurel_sprout
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
BLOCK=/dev/block/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

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
		ui_print "Two-stage init ROM detected, no need to patch"
	else
		ui_print "Legacy ROM detected, patching cmdline..."
		patch_cmdline "fstabdt_keep" "fstabdt_keep"
	fi
else
	ui_print "Skipping cmdline patch because vendor could not be mounted!"
fi

## NOT USED for laurel
# Enable bpf spoofing
# patch_uname_bpf_spoof() {
# 	patch_cmdline "uname_bpf_spoof" "uname_bpf_spoof=1"
# }

# # if device is running HyperMINT ROM
# if [ -f /vendor/build.prop ]; then
# 	if grep -q -E 'MINT|mintdevice' /vendor/build.prop; then
# 		ui_print "HyperMINT ROM detected, enabling bpf spoof..."
# 		patch_uname_bpf_spoof
# 	fi
# fi

# # Get Android version from build.prop
# android_ver=$(file_getprop /system/build.prop ro.build.version.release)

# # Convert to integer (strip potential decimal points)
# android_ver=${android_ver%%.*}

# # Check if Android version is 11 or lower
# if [ "$android_ver" -le 11 ] 2>/dev/null; then
#     patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=1"
#     ui_print "Legacy timestamp workaround enabled"
# else
#     patch_cmdline "legacy_timestamp_source" "legacy_timestamp_source=0"
#     ui_print "Timestamp patch not needed"
# fi

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

