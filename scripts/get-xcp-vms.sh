#!/bin/bash
set -euo pipefail

# Usage: get-xcp-vms.sh <xcp-host>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <xcp-host>" >&2
    exit 1
fi

XCP_HOST="$1"

# Get all VM UUIDs (excluding control domain and templates)
VM_UUIDS=$(ssh "$XCP_HOST" "xe vm-list is-control-domain=false is-a-template=false --minimal" | tr ',' '\n')

# For each VM, create a directory with metadata
for UUID in $VM_UUIDS; do
    # Get VM name
    VM_NAME=$(ssh "$XCP_HOST" "xe vm-param-get uuid=$UUID param-name=name-label")

    # Get the first VBD (disk) for this VM to determine which host it's on
    VBD_UUID=$(ssh "$XCP_HOST" "xe vbd-list vm-uuid=$UUID type=Disk --minimal" | cut -d',' -f1)

    # Determine the actual host based on SR location
    ACTUAL_HOST="$XCP_HOST"
    if [ -n "$VBD_UUID" ]; then
        # Get VDI UUID from VBD
        VDI_UUID=$(ssh "$XCP_HOST" "xe vbd-param-get uuid=$VBD_UUID param-name=vdi-uuid" 2>/dev/null || true)

        if [ -n "$VDI_UUID" ] && [ "$VDI_UUID" != "<not in database>" ]; then
            # Get SR UUID from VDI
            SR_UUID=$(ssh "$XCP_HOST" "xe vdi-param-get uuid=$VDI_UUID param-name=sr-uuid" 2>/dev/null || true)

            if [ -n "$SR_UUID" ]; then
                # Get the host for this SR
                SR_HOST=$(ssh "$XCP_HOST" "xe sr-param-get uuid=$SR_UUID param-name=host" 2>/dev/null || true)

                # If SR has a specific host (not shared), use that host
                if [ -n "$SR_HOST" ] && [ "$SR_HOST" != "<shared>" ]; then
                    ACTUAL_HOST="$SR_HOST"
                fi
            fi
        fi
    fi

    # Create VM directory
    mkdir -p "$VM_NAME"

    # Write metadata files
    echo "$UUID" > "$VM_NAME/xcp-vm-uuid"
    echo "$ACTUAL_HOST" > "$VM_NAME/xcp-host"
    echo "00" > "$VM_NAME/status"
    touch "$VM_NAME/xcp2incus.env"

    echo "Created migration folder for VM: $VM_NAME ($UUID) on host: $ACTUAL_HOST"
done
