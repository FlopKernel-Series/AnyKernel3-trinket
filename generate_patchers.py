#!/usr/bin/env python3
#
# FloppyKernel Feature Patcher Generator
# Generates enable/disable zip files for each feature defined in features.txt
#


import os
import sys
import shutil
import zipfile
from datetime import datetime
from pathlib import Path


def copy_directory_excluding(src, dst, exclude_patterns):
    """Copy directory tree excluding specified patterns (replaces rsync)."""
    src = Path(src)
    dst = Path(dst)

    def should_exclude(path):
        path_str = str(path)
        # Check both full path and just the name
        path_name = Path(path).name
        for pattern in exclude_patterns:
            if pattern in path_str or pattern == path_name:
                return True
        return False

    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True, exist_ok=True)

    for root, dirs, files in os.walk(src):
        root_path = Path(root)
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if not should_exclude(root_path / d)]

        # Calculate relative path for destination
        rel_root = root_path.relative_to(src)
        if str(rel_root) == '.':
            dst_root = dst
        else:
            dst_root = dst / rel_root

        # Create destination directory if needed
        dst_root.mkdir(parents=True, exist_ok=True)

        # Copy files
        for file in files:
            src_file = root_path / file
            if not should_exclude(src_file):
                dst_file = dst_root / file
                shutil.copy2(src_file, dst_file)


def create_zip_from_directory(directory, zip_path, exclude_patterns=None):
    """Create a zip file from a directory (replaces zip command)."""
    directory = Path(directory)
    zip_path = Path(zip_path)

    if exclude_patterns is None:
        exclude_patterns = ['*.git*', '*.github*', 'README.md']

    def should_exclude(path):
        path_str = str(path)
        path_name = Path(path).name
        for pattern in exclude_patterns:
            # Simple pattern matching
            if '*' in pattern:
                # Convert glob pattern to simple check
                pattern_base = pattern.replace('*', '')
                if pattern_base in path_str:
                    return True
            elif pattern == path_str or pattern == path_name or path_str.endswith(pattern):
                return True
        return False

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(directory):
            root_path = Path(root)
            # Filter out excluded directories
            dirs[:] = [d for d in dirs if not should_exclude(root_path / d)]

            for file in files:
                file_path = root_path / file
                if not should_exclude(file_path):
                    # Calculate relative path for archive
                    arcname = file_path.relative_to(directory)
                    zipf.write(file_path, arcname)


def process_bool_type(flag, feature_name, comment, script_dir, patcher_template, output_dir, date):
    """Process a boolean type feature and generate enable/disable zips."""
    print(f"Processing bool: {flag} -> {feature_name}")

    # Create enable zip
    enable_zip = output_dir / f"Floppy_{feature_name}-enabler-{date}.zip"
    enable_work_dir = script_dir / "out" / f"enable_{flag}"
    if enable_work_dir.exists():
        shutil.rmtree(enable_work_dir)
    enable_work_dir.mkdir(parents=True, exist_ok=True)

    # Copy patcher template (exclude build artifacts)
    copy_directory_excluding(
        patcher_template,
        enable_work_dir,
        ['out', 'patcher_zips', 'generate_patchers.sh', 'generate_patchers.py', 'features.txt']
    )

    # Create action, feature, and patch files
    (enable_work_dir / "patcher_action").write_text("enable")
    (enable_work_dir / "patcher_feature").write_text(flag)
    (enable_work_dir / "patcher_feature_name").write_text(feature_name)
    if comment:
        (enable_work_dir / "patcher_comment").write_text(comment)

    # Create zip
    create_zip_from_directory(enable_work_dir, enable_zip)

    shutil.rmtree(enable_work_dir)
    print(f"  Created: {enable_zip.name}")

    # Create disable zip
    disable_zip = output_dir / f"Floppy_{feature_name}-disabler-{date}.zip"
    disable_work_dir = script_dir / "out" / f"disable_{flag}"
    if disable_work_dir.exists():
        shutil.rmtree(disable_work_dir)
    disable_work_dir.mkdir(parents=True, exist_ok=True)

    # Copy patcher template (exclude build artifacts)
    copy_directory_excluding(
        patcher_template,
        disable_work_dir,
        ['out', 'patcher_zips', 'generate_patchers.sh', 'generate_patchers.py', 'features.txt']
    )

    # Create action, feature, and patch files
    (disable_work_dir / "patcher_action").write_text("disable")
    (disable_work_dir / "patcher_feature").write_text(flag)
    (disable_work_dir / "patcher_feature_name").write_text(feature_name)
    if comment:
        (disable_work_dir / "patcher_comment").write_text(comment)

    # Create zip
    create_zip_from_directory(disable_work_dir, disable_zip)

    shutil.rmtree(disable_work_dir)
    print(f"  Created: {disable_zip.name}")
    print()


def process_int_type(flag, range_min, range_max, feature_name, general_desc, values, script_dir, patcher_template, output_dir, date):
    """Process an integer type feature and generate value zips plus disabler."""
    print(f"Processing int: {flag} -> {feature_name} (range: {range_min}-{range_max})")

    # Process each value
    for value_line in values:
        parts = [p.strip() for p in value_line.split('|')]
        if len(parts) < 3:
            continue

        val_flag = parts[0]
        val_value = parts[1]
        val_name = parts[2]
        val_desc = parts[3] if len(parts) > 3 else ""

        if not val_value or not val_name:
            continue

        print(f"  Processing value: {val_value} -> {val_name}")

        # Create value zip
        value_zip = output_dir / f"Floppy_{feature_name}-{val_name}-{date}.zip"
        value_work_dir = script_dir / "out" / f"value_{flag}_{val_value}"
        if value_work_dir.exists():
            shutil.rmtree(value_work_dir)
        value_work_dir.mkdir(parents=True, exist_ok=True)

        # Copy patcher template (exclude build artifacts)
        copy_directory_excluding(
            patcher_template,
            value_work_dir,
            ['out', 'patcher_zips', 'generate_patchers.sh', 'generate_patchers.py', 'features.txt']
        )

        # Create action, feature, and patch files
        (value_work_dir / "patcher_action").write_text("set")
        (value_work_dir / "patcher_feature").write_text(flag)
        (value_work_dir / "patcher_feature_name").write_text(feature_name)
        (value_work_dir / "patcher_general_desc").write_text(general_desc)
        (value_work_dir / "patcher_value_desc").write_text(val_desc)
        (value_work_dir / "patcher_value").write_text(val_value)
        (value_work_dir / "patcher_range_min").write_text(str(range_min))
        (value_work_dir / "patcher_range_max").write_text(str(range_max))

        # Create zip
        create_zip_from_directory(value_work_dir, value_zip)

        shutil.rmtree(value_work_dir)
        print(f"    Created: {value_zip.name}")

    # Create disabler zip (sets value to -1)
    disable_zip = output_dir / f"Floppy_{feature_name}-disabler-{date}.zip"
    disable_work_dir = script_dir / "out" / f"disable_{flag}"
    if disable_work_dir.exists():
        shutil.rmtree(disable_work_dir)
    disable_work_dir.mkdir(parents=True, exist_ok=True)

    # Copy patcher template (exclude build artifacts)
    copy_directory_excluding(
        patcher_template,
        disable_work_dir,
        ['out', 'patcher_zips', 'generate_patchers.sh', 'generate_patchers.py', 'features.txt']
    )

    # Create action, feature, and patch files
    (disable_work_dir / "patcher_action").write_text("disable")
    (disable_work_dir / "patcher_feature").write_text(flag)
    (disable_work_dir / "patcher_feature_name").write_text(feature_name)
    (disable_work_dir / "patcher_general_desc").write_text(general_desc)
    (disable_work_dir / "patcher_range_min").write_text(str(range_min))
    (disable_work_dir / "patcher_range_max").write_text(str(range_max))

    # Create zip
    create_zip_from_directory(disable_work_dir, disable_zip)

    shutil.rmtree(disable_work_dir)
    print(f"  Created: {disable_zip.name}")
    print()


def main():
    script_dir = Path(__file__).parent.resolve()
    patcher_template = script_dir
    features_file = script_dir / "features.txt"
    output_dir = script_dir / "patcher_zips"

    if not features_file.exists():
        print(f"ERROR: features.txt not found at {features_file}", file=sys.stderr)
        sys.exit(1)

    if not patcher_template.exists():
        print(f"ERROR: Patcher template not found at {patcher_template}", file=sys.stderr)
        sys.exit(1)

    # Create output directories
    output_dir.mkdir(parents=True, exist_ok=True)

    # Clean up old generated zips
    for old_zip in output_dir.glob("*.zip"):
        old_zip.unlink()

    work_dir = script_dir / "out"
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir(parents=True, exist_ok=True)

    # Generate date string for zip filenames
    date = datetime.now().strftime('%Y%m%d-%H%M')

    print("Generating feature patcher zips...")
    print()

    # State variables for parsing
    current_type = None
    current_flag = None
    current_feature_name = None
    current_general_desc = None
    current_range_min = None
    current_range_max = None
    int_values = []

    # Read and parse features.txt
    with open(features_file, 'r') as f:
        for line in f:
            line = line.strip()

            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue

            # Check for type definition
            if line.startswith('bool:'):
                # Process previous int type if any
                if current_type == 'int' and int_values:
                    process_int_type(
                        current_flag, current_range_min, current_range_max,
                        current_feature_name, current_general_desc, int_values,
                        script_dir, patcher_template, output_dir, date
                    )
                    int_values = []

                # Parse bool type
                rest = line[5:].strip()
                parts = [p.strip() for p in rest.split('|')]
                if len(parts) >= 2:
                    flag = parts[0]
                    feature_name = parts[1]
                    comment = parts[2] if len(parts) > 2 else ""
                    if flag and feature_name:
                        process_bool_type(
                            flag, feature_name, comment,
                            script_dir, patcher_template, output_dir, date
                        )
                current_type = None

            elif line.startswith('int:'):
                # Process previous int type if any
                if current_type == 'int' and int_values:
                    process_int_type(
                        current_flag, current_range_min, current_range_max,
                        current_feature_name, current_general_desc, int_values,
                        script_dir, patcher_template, output_dir, date
                    )
                    int_values = []

                # Parse int type definition: int: flag | range: min,max | FeatureName | Description
                rest = line[4:].strip()
                parts = [p.strip() for p in rest.split('|')]
                if len(parts) >= 3:
                    flag = parts[0]
                    range_spec = parts[1]
                    feature_name = parts[2]
                    general_desc = parts[3] if len(parts) > 3 else ""

                    # Parse range: "range: min,max"
                    if range_spec.startswith('range:'):
                        range_part = range_spec[6:].strip()
                        try:
                            range_min, range_max = range_part.split(',')
                            current_range_min = int(range_min.strip())
                            current_range_max = int(range_max.strip())
                        except (ValueError, AttributeError):
                            print(f"ERROR: Invalid range specification for int type: {range_spec}", file=sys.stderr)
                            sys.exit(1)

                    current_type = 'int'
                    current_flag = flag
                    current_feature_name = feature_name
                    current_general_desc = general_desc
                    int_values = []

            elif line.startswith('valof:'):
                if current_type == 'int':
                    # Parse value definition
                    rest = line[6:].strip()
                    int_values.append(rest)

            else:
                # Legacy format (bool without type prefix) - treat as bool
                if current_type != 'int':
                    # Process previous int type if any
                    if current_type == 'int' and int_values:
                        process_int_type(
                            current_flag, current_range_min, current_range_max,
                            current_feature_name, current_general_desc, int_values,
                            script_dir, patcher_template, output_dir, date
                        )
                        int_values = []

                    parts = [p.strip() for p in line.split('|')]
                    if len(parts) >= 2:
                        flag = parts[0]
                        feature_name = parts[1]
                        comment = parts[2] if len(parts) > 2 else ""
                        if flag and feature_name:
                            process_bool_type(
                                flag, feature_name, comment,
                                script_dir, patcher_template, output_dir, date
                            )

    # Process any remaining int type
    if current_type == 'int' and int_values:
        process_int_type(
            current_flag, current_range_min, current_range_max,
            current_feature_name, current_general_desc, int_values,
            script_dir, patcher_template, output_dir, date
        )

    # Clean up work directory
    if work_dir.exists():
        shutil.rmtree(work_dir)

    print(f"Done! Generated zips are in: {output_dir}")


if __name__ == '__main__':
    main()

