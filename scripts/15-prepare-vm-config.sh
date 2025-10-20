#!/bin/bash
set -euo pipefail

# Prepare Incus VM configuration from XCP-ng metadata
# Usage: Run from within the VM directory

# Extract step info from script name
SCRIPT_NAME=$(basename "$0" .sh)
STEP_NUM=$(echo "$SCRIPT_NAME" | cut -d- -f1)

# Source environment variables
source xcp2incus.env

# Update status
echo "$SCRIPT_NAME" > status

echo "Preparing Incus VM configuration"

# Set default instance name from folder name if not specified
if [ ! -f incus-instance-name ]; then
    INSTANCE_NAME=$(basename "$PWD")
    echo "$INSTANCE_NAME" > incus-instance-name
    echo "Using default instance name from folder: $INSTANCE_NAME"
else
    INSTANCE_NAME=$(cat incus-instance-name)
    echo "Using existing instance name: $INSTANCE_NAME"
fi

# Find all vdb-* directories
shopt -s nullglob
VDB_DIRS=(vdb-*)

if [ ${#VDB_DIRS[@]} -eq 0 ]; then
    echo "Error: No vdb-* directories found"
    exit 1
fi

echo "Found ${#VDB_DIRS[@]} disk(s) to configure"

# Start creating incus-vm.yaml
cat > incus-vm.yaml << 'EOF'
config:
  limits.memory: 1GiB
  limits.cpu: 2
  #security.secureboot: "false"
  #security.csm: "true"
profiles:
- rescue
devices:
EOF

# Process each VDB directory
FIRST_DISK=true
for vdb_dir in "${VDB_DIRS[@]}"; do
    if [ ! -f "$vdb_dir/xcp-vdi-size" ]; then
        echo "Warning: $vdb_dir/xcp-vdi-size not found, skipping"
        continue
    fi

    # Extract device name from vdb_dir (e.g., vdb-xvda -> xvda)
    DEVICE_NAME="${vdb_dir#vdb-}"

    # Read VDI size in bytes
    VDI_SIZE_BYTES=$(cat "$vdb_dir/xcp-vdi-size")

    # Convert bytes to GiB (rounded up to ensure sufficient space)
    VDI_SIZE_GIB=$(echo "scale=0; ($VDI_SIZE_BYTES + 1073741823) / 1073741824" | bc)

    echo "Disk $DEVICE_NAME: ${VDI_SIZE_GIB}GiB (${VDI_SIZE_BYTES} bytes)"

    # Add disk to yaml
    if [ "$FIRST_DISK" = true ]; then
        # First disk is the root disk
        cat >> incus-vm.yaml << EOF
  $DEVICE_NAME:
    type: disk
    path: /
    pool: default
    size: ${VDI_SIZE_GIB}GiB
EOF
        FIRST_DISK=false
    else
        # Additional disks
        cat >> incus-vm.yaml << EOF
  $DEVICE_NAME:
    type: disk
    pool: default
    size: ${VDI_SIZE_GIB}GiB
EOF
    fi
done

echo ""
echo "Created incus-vm.yaml:"
cat incus-vm.yaml

# Mark step complete
echo "$((STEP_NUM + 1))" > status
