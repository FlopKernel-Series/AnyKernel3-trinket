# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=FloppyKernel v1.0 (early) for Ginkgo | @Flopster101
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=ginkgo
device.name2=willow
device.name3=
device.name4=
device.name5=
supported.versions=10.0-15.0
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel boot install
split_boot;

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

# Get Android version from build.prop
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


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

# end ramdisk changes

flash_boot;
flash_dtbo;
## end boot install


# shell variables
#block=vendor_boot;
#is_slot_device=1;
#ramdisk_compression=auto;
#patch_vbmeta_flag=auto;

# reset for vendor_boot patching
#reset_ak;


## AnyKernel vendor_boot install
#split_boot; # skip unpack/repack ramdisk since we don't need vendor_ramdisk access

#flash_boot;
## end vendor_boot install
