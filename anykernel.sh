### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

## FloppyKernel Feature Toggle Patcher

### AnyKernel setup
# global properties
properties() { '
kernel.string=FloppyKernel Feature Patcher for Trinket-Mi
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=ginkgo
device.name2=willow
supported.versions=
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
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# Read action, feature flag, feature name, and descriptions from files in the zip
ACTION=""
FEATURE_FLAG=""
FEATURE_NAME=""
COMMENT=""
GENERAL_DESC=""
VALUE_DESC=""
VALUE=""

if [ -f "$AKHOME/patcher_action" ]; then
  ACTION=$(cat "$AKHOME/patcher_action" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_feature" ]; then
  FEATURE_FLAG=$(cat "$AKHOME/patcher_feature" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_feature_name" ]; then
  FEATURE_NAME=$(cat "$AKHOME/patcher_feature_name" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_comment" ]; then
  COMMENT=$(cat "$AKHOME/patcher_comment" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_general_desc" ]; then
  GENERAL_DESC=$(cat "$AKHOME/patcher_general_desc" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_value_desc" ]; then
  VALUE_DESC=$(cat "$AKHOME/patcher_value_desc" 2>/dev/null)
fi

if [ -f "$AKHOME/patcher_value" ]; then
  VALUE=$(cat "$AKHOME/patcher_value" 2>/dev/null)
fi

RANGE_MIN=""
RANGE_MAX=""
if [ -f "$AKHOME/patcher_range_min" ]; then
  RANGE_MIN=$(cat "$AKHOME/patcher_range_min" 2>/dev/null | tr -d '\n')
fi
if [ -f "$AKHOME/patcher_range_max" ]; then
  RANGE_MAX=$(cat "$AKHOME/patcher_range_max" 2>/dev/null | tr -d '\n')
fi

if [ -z "$ACTION" ] || [ -z "$FEATURE_FLAG" ]; then
  ui_print "ERROR: Invalid patcher zip! Missing action or feature flag."
  exit 1
fi

# Use feature name if available, otherwise fall back to flag
if [ -z "$FEATURE_NAME" ]; then
  FEATURE_NAME="$FEATURE_FLAG"
fi

ui_print " "
ui_print "-> Patcher info"
ui_print "Feature: $FEATURE_NAME"
if [ "$ACTION" = "set" ]; then
  ui_print "Action: Set value"
else
  ui_print "Action: $ACTION"
fi

# Display descriptions based on type
if [ -n "$GENERAL_DESC" ]; then
  ui_print "General description: \"$GENERAL_DESC\""
fi
if [ -n "$VALUE_DESC" ]; then
  ui_print "Value description: \"$VALUE_DESC\""
elif [ -n "$COMMENT" ]; then
  ui_print "Description: \"$COMMENT\""
fi
ui_print " "

# Check if /cache is mounted, try to mount if not
cache_mounted=0;
if mountpoint -q /cache 2>/dev/null; then
  cache_mounted=1;
else
  ui_print "Mounting /cache..."
  if mount /cache 2>/dev/null; then
    cache_mounted=1;
  else
    ui_print "Warning: Cannot mount /cache!"
    ui_print "Your choice will NOT be saved."
    ui_print "Please ensure /cache partition is accessible."
    ui_print "Continuing anyway..."
  fi
fi

# Split boot to access cmdline
split_boot;

# Patch the kernel cmdline based on action
if [ "$ACTION" = "enable" ]; then
  # Enable feature: add flag=1 to cmdline
  patch_cmdline "$FEATURE_FLAG" "${FEATURE_FLAG}=1"
  ui_print "Feature enabled in kernel cmdline."
elif [ "$ACTION" = "disable" ]; then
  # Disable feature: remove flag from cmdline or set to 0
  # For bool types, we remove it; for int types, we might set to -1
  if [ -n "$GENERAL_DESC" ]; then
    # Int type - set to -1 or remove
    patch_cmdline "$FEATURE_FLAG" "${FEATURE_FLAG}=-1"
    ui_print "Feature disabled in kernel cmdline (set to -1)."
  else
    # Bool type - remove from cmdline by setting to empty
    patch_cmdline "$FEATURE_FLAG" ""
    ui_print "Feature disabled in kernel cmdline (removed)."
  fi
elif [ "$ACTION" = "set" ]; then
  # Set feature to specific value
  if [ -z "$VALUE" ]; then
    ui_print "ERROR: Set action requires a value!"
    exit 1
  fi
  patch_cmdline "$FEATURE_FLAG" "${FEATURE_FLAG}=${VALUE}"
  ui_print "Feature set to ${VALUE} in kernel cmdline."
else
  ui_print "ERROR: Unknown action: $ACTION"
  exit 1
fi

# Write boot partition back
flash_boot;
if [ $? -ne 0 ]; then
  ui_print "ERROR: Writing boot partition failed!"
  exit 1
fi

# Save feature flag to /cache/fk_feat for future kernel installations
if [ "$cache_mounted" -eq 1 ]; then
  # Read existing feature flags or create empty file
  FEAT_FILE="/cache/fk_feat"
  if [ -f "$FEAT_FILE" ]; then
    FEATURES=$(cat "$FEAT_FILE" 2>/dev/null)
  else
    FEATURES=""
  fi

  if [ "$ACTION" = "enable" ]; then
    # Add feature flag if not already present (bool type)
    if ! echo "$FEATURES" | grep -q "^$FEATURE_FLAG$" 2>/dev/null; then
      # Append feature flag (one per line)
      if [ -n "$FEATURES" ]; then
        echo "$FEATURES" > "$FEAT_FILE"
        echo "$FEATURE_FLAG" >> "$FEAT_FILE"
      else
        echo "$FEATURE_FLAG" > "$FEAT_FILE"
      fi
      ui_print " "
      ui_print "Feature flag saved to /cache/fk_feat."
    else
      # Flag already exists, but still confirm it's saved
      ui_print " "
      ui_print "Feature flag already saved in /cache/fk_feat."
    fi
  elif [ "$ACTION" = "set" ]; then
    # Set feature flag with value (int type)
    FLAG_ENTRY="${FEATURE_FLAG}=${VALUE}"
    # Remove any existing entry for this flag (with any value)
    NEW_FEATURES=$(echo "$FEATURES" | grep -v "^${FEATURE_FLAG}=" 2>/dev/null || true)
    # Add the new entry
    if [ -n "$NEW_FEATURES" ]; then
      echo "$NEW_FEATURES" > "$FEAT_FILE"
      echo "$FLAG_ENTRY" >> "$FEAT_FILE"
    else
      echo "$FLAG_ENTRY" > "$FEAT_FILE"
    fi
    ui_print " "
    ui_print "Feature flag saved to /cache/fk_feat."
  elif [ "$ACTION" = "disable" ]; then
    if [ -n "$GENERAL_DESC" ]; then
      # Int type disable - set to -1
      FLAG_ENTRY="${FEATURE_FLAG}=-1"
      # Remove any existing entry for this flag (with any value)
      NEW_FEATURES=$(echo "$FEATURES" | grep -v "^${FEATURE_FLAG}=" 2>/dev/null || true)
      # Add the -1 entry
      if [ -n "$NEW_FEATURES" ]; then
        echo "$NEW_FEATURES" > "$FEAT_FILE"
        echo "$FLAG_ENTRY" >> "$FEAT_FILE"
      else
        echo "$FLAG_ENTRY" > "$FEAT_FILE"
      fi
      ui_print " "
      ui_print "Feature flag set to disabled in /cache/fk_feat."
    else
      # Bool type disable - remove feature flag
      if echo "$FEATURES" | grep -q "^$FEATURE_FLAG$" 2>/dev/null; then
        # Remove the line containing the feature flag
        echo "$FEATURES" | grep -v "^$FEATURE_FLAG$" > "$FEAT_FILE"
        ui_print " "
        ui_print "Feature flag removed from /cache/fk_feat."
      else
        # Flag already removed, but still confirm
        ui_print " "
        ui_print "Feature flag already removed from /cache/fk_feat."
      fi
    fi
  fi
else
  ui_print "Warning: Could not save feature flag to /cache (not accessible)."
  ui_print "The current kernel has been patched, but the flag won't persist for future installations."
fi

ui_print " "
ui_print "Please reboot for changes to take effect."
