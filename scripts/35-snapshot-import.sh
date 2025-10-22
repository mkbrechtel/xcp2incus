#!/bin/bash
set -euo pipefail

# Create a snapshot of the VM after successful import
# Usage: Run from within the VM directory

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

echo "Creating snapshot of imported VM: $INSTANCE_NAME"
echo "Using Incus project: $INCUS_PROJECT"

# Check if VM exists
if ! incus --project "$INCUS_PROJECT" list -f csv | grep -q "^${INSTANCE_NAME},"; then
    echo "Error: VM '$INSTANCE_NAME' not found."
    exit 1
fi

# Create snapshot with timestamp
SNAPSHOT_NAME="after-xcp-import"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo ""
echo "Creating snapshot: $SNAPSHOT_NAME"
echo "This preserves the VM state after XCP-ng disk import and before OS boot."

# Create the snapshot (can be done while VM is running in rescue mode)
incus --project "$INCUS_PROJECT" snapshot create "$INSTANCE_NAME" "$SNAPSHOT_NAME"

echo ""
echo "✓ Snapshot created successfully: $SNAPSHOT_NAME"
echo ""
echo "This snapshot can be restored if needed with:"
echo "  incus --project $INCUS_PROJECT snapshot restore $INSTANCE_NAME $SNAPSHOT_NAME"
echo ""
echo "To list all snapshots:"
echo "  incus --project $INCUS_PROJECT info $INSTANCE_NAME"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
