#!/bin/bash
set -euo pipefail

# Backup VM disks to Restic
# Usage: Run from within the VM directory

# Source environment variables
source xcp2incus.env

# Read VM UUID and XCP host
VM_UUID=$(cat xcp-vm-uuid)
XCP_HOST=$(cat xcp-host)

# Update status
echo "10-backup-disks-to-restic" > status

# Find all vdb-* directories
shopt -s nullglob
VDB_DIRS=(vdb-*)

if [ ${#VDB_DIRS[@]} -eq 0 ]; then
    echo "No vdb-* directories found"
    exit 1
fi

echo "Found ${#VDB_DIRS[@]} disk(s) to backup"

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

    # Get VBD UUID from file
    VBD_UUID=$(cat "$vdb_dir/xcp-vbd-uuid" 2>/dev/null || echo "unknown")

    # Get VM name
    VM_NAME=$(cat xcp-vm-name 2>/dev/null || echo "unknown")

    echo ""
    echo "Backing up $vdb_dir (VDI: $VDI_UUID)"
    echo "Size: ${VDI_SIZE_GIB} GiB"

    # Run the backup on the XCP host with tags
    ssh -t "$XCP_HOST" "xe vdi-export uuid=$VDI_UUID format=raw filename= | restic --repository-file restic.repo --password-file restic.pass backup --stdin --stdin-filename=xcp-vdi-$VDI_UUID.raw --host '$VM_NAME' --tag 'xcp-vdi-$VDI_UUID,xcp-vbd-$VBD_UUID,xcp-vm-$VM_UUID-disk-$VDB_DEVICE,xcp-disk-$VDB_DEVICE'"

    echo "✓ Backup completed for $vdb_dir"
done

echo ""
echo "All disks backed up successfully"

# Mark step complete
echo "11" > status
