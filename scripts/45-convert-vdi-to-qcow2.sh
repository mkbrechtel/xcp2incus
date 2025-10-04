#!/bin/bash
set -euo pipefail

# Convert VDI raw files to qcow2 format
# Usage: Run from within the VM directory

# Extract step info from script name
SCRIPT_NAME=$(basename "$0" .sh)
STEP_NUM=$(echo "$SCRIPT_NAME" | cut -d- -f1)

# Source environment variables
source xcp2incus.env

# Read VM UUID and XCP host
VM_UUID=$(cat xcp-vm-uuid)
XCP_HOST=$(cat xcp-host)

# Update status
echo "$SCRIPT_NAME" > status

# Find all vdb-* directories
shopt -s nullglob
VDB_DIRS=(vdb-*)

if [ ${#VDB_DIRS[@]} -eq 0 ]; then
    echo "No vdb-* directories found"
    exit 1
fi

echo "Found ${#VDB_DIRS[@]} disk(s) to convert"

# Process each VDB directory
for vdb_dir in "${VDB_DIRS[@]}"; do
    if [ ! -f "$vdb_dir/vdi.raw" ]; then
        echo "Warning: $vdb_dir/vdi.raw not found, skipping"
        continue
    fi

    # Extract device name from vdb_dir (e.g., vdb-xvda -> xvda)
    VDB_DEVICE="${vdb_dir#vdb-}"

    echo ""
    echo "Converting $vdb_dir/vdi.raw to qcow2 format..."

    # Get source file size
    SOURCE_SIZE=$(stat -c %s "$vdb_dir/vdi.raw" 2>/dev/null || echo "0")
    SOURCE_SIZE_GIB=$(echo "scale=2; $SOURCE_SIZE / 1073741824" | bc)
    echo "Source size: ${SOURCE_SIZE_GIB} GiB ($SOURCE_SIZE bytes)"

    # Convert to qcow2 using qemu-img
    qemu-img convert -p -f raw -O qcow2 "$vdb_dir/vdi.raw" "$vdb_dir/disk.qcow2"

    # Get converted file size
    QCOW2_SIZE=$(stat -c %s "$vdb_dir/disk.qcow2" 2>/dev/null || echo "0")
    QCOW2_SIZE_GIB=$(echo "scale=2; $QCOW2_SIZE / 1073741824" | bc)
    echo "Converted size: ${QCOW2_SIZE_GIB} GiB ($QCOW2_SIZE bytes)"

    # Calculate compression ratio
    if [ "$SOURCE_SIZE" -gt 0 ]; then
        COMPRESSION_RATIO=$(echo "scale=2; ($SOURCE_SIZE - $QCOW2_SIZE) * 100 / $SOURCE_SIZE" | bc)
        echo "Space saved: ${COMPRESSION_RATIO}%"
    fi

    echo "✓ Conversion completed for $vdb_dir"
done

echo ""
echo "All disks converted successfully"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
