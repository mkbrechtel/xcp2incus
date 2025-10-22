#!/bin/bash
set -euo pipefail

# Restore VDI from Restic backup using restic dump
# Usage: Run from within the VM directory
# Assumes RESTIC_REPOSITORY and RESTIC_PASSWORD are set via environment variables

# Extract step info from script name
SCRIPT_NAME=$(basename "$0" .sh)
STEP_NUM=$(echo "$SCRIPT_NAME" | cut -d- -f1)

# Source environment variables
source xcp2incus.env

# Get Incus project name (from incus-project file or parent directory)
get_incus_project() {
    if [ -f "incus-project" ]; then
        cat incus-project
    else
        basename "$(dirname "$(pwd)")"
    fi
}

INCUS_PROJECT=$(get_incus_project)

# Update status
echo "$SCRIPT_NAME" > status

# Read instance name and VM UUID
INSTANCE_NAME=$(cat incus-instance-name)
VM_UUID=$(cat xcp-vm-uuid)

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

    echo ""
    echo "Restoring $vdb_dir (VDI: $VDI_UUID)"
    echo "Size: ${VDI_SIZE_GIB} GiB"
    echo "Target device: /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_${VDB_DEVICE}"

    # Find the latest snapshot with the VDI tag
    echo "Finding latest snapshot with tag xcp-vdi-$VDI_UUID..."
    SNAPSHOT_ID=$(restic snapshots --tag "xcp-vdi-$VDI_UUID" --json --latest 1 | jq -r '.[0].id // empty')

    if [ -z "$SNAPSHOT_ID" ]; then
        echo "Error: No snapshot found with tag xcp-vdi-$VDI_UUID"
        exit 1
    fi

    echo "Using snapshot: $SNAPSHOT_ID"

    # Restore the VDI using restic dump piped through pv and dd into the Incus VM
    echo "Restoring disk image..."
    restic dump "$SNAPSHOT_ID" "xcp-vdi-$VDI_UUID.raw" | \
        pv -s "$VDI_SIZE" | \
        incus --project "$INCUS_PROJECT" exec "$INSTANCE_NAME" dd of=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_${VDB_DEVICE}

    echo "✓ Restore completed for $vdb_dir"
done

echo ""
echo "All disks restored successfully"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
