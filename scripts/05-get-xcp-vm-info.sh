#!/bin/bash
set -euo pipefail

# Get VM information from XCP-ng and store in metadata files
# Usage: Run from within the VM directory

# Source environment variables
source xcp2incus.env

# Read VM UUID and XCP host
VM_UUID=$(cat xcp-vm-uuid)
XCP_HOST=$(cat xcp-host)

# Update status
echo "05-get-xcp-vm-info" > status

# Get VM name and save to xcp-vm-name
VM_NAME=$(ssh "$XCP_HOST" "xe vm-param-get uuid=$VM_UUID param-name=name-label")
echo "$VM_NAME" > xcp-vm-name
echo "VM name: $VM_NAME"

# Get VM parameters and save to xcp-vm-params
ssh "$XCP_HOST" "xe vm-param-list uuid=$VM_UUID" > xcp-vm-params
echo "Saved VM parameters to xcp-vm-params"

# Get VM disk list and save to xcp-vm-disks
ssh "$XCP_HOST" "xe vm-disk-list uuid=$VM_UUID" > xcp-vm-disks
echo "Saved VM disk list to xcp-vm-disks"

# Parse disk information to create VDB directories
DISK_UUIDS=$(ssh "$XCP_HOST" "xe vm-disk-list uuid=$VM_UUID --minimal")

if [ -n "$DISK_UUIDS" ]; then
    IFS=',' read -ra UUIDS <<< "$DISK_UUIDS"

    for uuid in "${UUIDS[@]}"; do
        # Trim whitespace
        uuid=$(echo "$uuid" | xargs)

        # Check if it's a VDI
        TYPE=$(ssh "$XCP_HOST" "xe vdi-list uuid=$uuid --minimal 2>/dev/null || echo ''")

        if [ -n "$TYPE" ]; then
            # It's a VDI
            echo "Found VDI: $uuid"

            # Get device name for this VDI
            DEVICE=$(ssh "$XCP_HOST" "xe vbd-list vdi-uuid=$uuid vm-uuid=$VM_UUID params=device --minimal")

            if [ -n "$DEVICE" ]; then
                # Create VDB directory
                mkdir -p "vdb-$DEVICE"

                # Get VDI size
                VDI_SIZE=$(ssh "$XCP_HOST" "xe vdi-param-get uuid=$uuid param-name=virtual-size")

                # Get VBD UUID
                VBD_UUID=$(ssh "$XCP_HOST" "xe vbd-list vdi-uuid=$uuid vm-uuid=$VM_UUID params=uuid --minimal")

                # Write metadata files
                echo "$uuid" > "vdb-$DEVICE/xcp-vdi-uuid"
                echo "$VDI_SIZE" > "vdb-$DEVICE/xcp-vdi-size"

                # Get and save VDI parameters
                ssh "$XCP_HOST" "xe vdi-param-list uuid=$uuid" > "vdb-$DEVICE/xcp-vdi-params"
                echo "  Saved VDI parameters to vdb-$DEVICE/xcp-vdi-params"

                # Get and save VBD parameters
                if [ -n "$VBD_UUID" ]; then
                    ssh "$XCP_HOST" "xe vbd-param-list uuid=$VBD_UUID" > "vdb-$DEVICE/xcp-vbd-params"
                    echo "  Saved VBD parameters to vdb-$DEVICE/xcp-vbd-params"
                fi

                # Calculate size in GiB for display
                VDI_SIZE_GIB=$(echo "scale=2; $VDI_SIZE / 1073741824" | bc)

                echo "Created vdb-$DEVICE:"
                echo "  VDI UUID: $uuid"
                echo "  VBD UUID: $VBD_UUID"
                echo "  Size: ${VDI_SIZE_GIB} GiB ($VDI_SIZE bytes)"
            fi
        fi
    done
fi

# Mark step complete
echo "06" > status
