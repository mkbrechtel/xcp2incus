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

    # Create VM directory
    mkdir -p "$VM_NAME"

    # Write metadata files
    echo "$UUID" > "$VM_NAME/xcp-vm-uuid"
    echo "$XCP_HOST" > "$VM_NAME/xcp-host"
    echo "00" > "$VM_NAME/status"
    touch "$VM_NAME/xcp2incus.env"

    echo "Created migration folder for VM: $VM_NAME ($UUID)"
done
