#!/bin/bash
set -euox pipefail

# Restore VM disks from Restic
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

echo "Found ${#VDB_DIRS[@]} disk(s) to restore"

# Process each VDB directory
for vdb_dir in "${VDB_DIRS[@]}"; do
    if [ ! -f "$vdb_dir/xcp-vdi-uuid" ]; then
        echo "Warning: $vdb_dir/xcp-vdi-uuid not found, skipping"
        continue
    fi

    VDI_UUID=$(cat "$vdb_dir/xcp-vdi-uuid")
    VDI_SIZE=$(cat "$vdb_dir/xcp-vdi-size" 2>/dev/null || echo "unknown")
    VDI_SIZE_GIB=$(echo "scale=2; $VDI_SIZE / 1073741824" | bc 2>/dev/null || echo "unknown")

    # Extract device name from vdb_dir (e.g., vdb-xvda -> xvda)
    VDB_DEVICE="${vdb_dir#vdb-}"

    # Get VM name
    VM_NAME=$(cat xcp-vm-name 2>/dev/null || echo "unknown")

    echo ""
    echo "Restoring $vdb_dir (VDI: $VDI_UUID)"
    echo "Size: ${VDI_SIZE_GIB} GiB"

    # Restore from Restic
    # Find the latest snapshot with the matching tag
    echo "Finding latest snapshot for VDI $VDI_UUID..."
    SNAPSHOT_ID=$(restic snapshots --host "$VM_NAME" --tag "xcp-vdi-$VDI_UUID" --json --latest 1 | jq -r '.[0].short_id')

    if [ -z "$SNAPSHOT_ID" ] || [ "$SNAPSHOT_ID" = "null" ]; then
        echo "Error: No snapshot found for VDI $VDI_UUID"
        exit 1
    fi

    echo "Found snapshot: $SNAPSHOT_ID"
    echo "Restoring to $vdb_dir/vdi.raw..."

    # Restore the file from Restic to the vdb directory
    restic restore "$SNAPSHOT_ID" --target "$vdb_dir" --include "xcp-vdi-$VDI_UUID.raw"

    # Create symlink to vdi.raw
    ln -sf "xcp-vdi-$VDI_UUID.raw" "$vdb_dir/vdi.raw"
    echo "Created symlink: $vdb_dir/vdi.raw -> xcp-vdi-$VDI_UUID.raw"

    # Verify the restored file size
    RESTORED_SIZE=$(stat -c %s "$vdb_dir/xcp-vdi-$VDI_UUID.raw" 2>/dev/null || echo "0")
    echo "Restored size: $(echo "scale=2; $RESTORED_SIZE / 1073741824" | bc) GiB ($RESTORED_SIZE bytes)"

    # Create symlink to disk.raw
    ln -sf vdi.raw "$vdb_dir/disk.raw"
    echo "Created symlink: $vdb_dir/disk.raw -> vdi.raw"

    echo "✓ Restore completed for $vdb_dir"
done

echo ""
echo "All disks restored successfully"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
