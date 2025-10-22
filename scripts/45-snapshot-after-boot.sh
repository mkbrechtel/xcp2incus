#!/bin/bash
set -euo pipefail

# Create snapshot after boot issues have been fixed (stops VM if running)
# Usage: Run from within the VM directory after verifying VM boots correctly
# Note: Works whether VM is running or already stopped

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

# Trap errors and mark status as failed
trap 'if [ $? -ne 0 ]; then echo "FAIL-$(cat status)" > status; fi' EXIT

# Read instance name
INSTANCE_NAME=$(cat incus-instance-name)

echo "Creating snapshot after boot fixes for: $INSTANCE_NAME"
echo "Using Incus project: $INCUS_PROJECT"

# Check if VM exists
if ! incus --project "$INCUS_PROJECT" list -f csv | grep -q "^${INSTANCE_NAME},"; then
    echo "Error: VM '$INSTANCE_NAME' not found."
    exit 1
fi

# Check VM state and stop if running
VM_STATE=$(incus --project "$INCUS_PROJECT" list -f csv -c ns | grep "^${INSTANCE_NAME}," | cut -d, -f2)
echo "Current VM state: $VM_STATE"

if [ "$VM_STATE" = "RUNNING" ]; then
    echo "Stopping VM gracefully..."
    incus --project "$INCUS_PROJECT" stop "$INSTANCE_NAME"
    echo "✓ VM stopped"
else
    echo "✓ VM is already stopped, proceeding with snapshot"
fi

# Create snapshot with descriptive name
SNAPSHOT_NAME="after-boot-fixes"

echo ""
echo "Creating snapshot: $SNAPSHOT_NAME"
echo "This preserves the VM state after the native OS has successfully booted"
echo "and any boot issues have been resolved."

# Create the snapshot
incus --project "$INCUS_PROJECT" snapshot create "$INSTANCE_NAME" "$SNAPSHOT_NAME"

echo ""
echo "✓ Snapshot created successfully: $SNAPSHOT_NAME"
echo ""
echo "This snapshot can be restored if needed with:"
echo "  incus --project $INCUS_PROJECT snapshot restore $INSTANCE_NAME $SNAPSHOT_NAME"
echo ""
echo "To list all snapshots:"
echo "  incus --project $INCUS_PROJECT info $INSTANCE_NAME"
echo ""
echo "To start the VM again:"
echo "  incus --project $INCUS_PROJECT start $INSTANCE_NAME"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
