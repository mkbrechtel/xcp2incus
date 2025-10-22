#!/bin/bash
set -euo pipefail

# Start the target Incus VM in rescue mode
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

# Read instance name
INSTANCE_NAME=$(cat incus-instance-name)

echo "Starting Incus VM in rescue mode: $INSTANCE_NAME"
echo "Using Incus project: $INCUS_PROJECT"

# Check if VM exists
if ! incus --project "$INCUS_PROJECT" list -f csv | grep -q "^${INSTANCE_NAME},"; then
    echo "Error: VM '$INSTANCE_NAME' not found. Run 20-init-target-vm.sh first."
    exit 1
fi

# Start the VM
echo ""
echo "Starting VM..."
incus --project "$INCUS_PROJECT" start "$INSTANCE_NAME"

echo "✓ VM started successfully in rescue mode"
echo ""
echo "The VM is running with the 'rescue' profile, which should provide:"
echo "  - Access to the VM console"
echo "  - Ability to mount and restore disk images"
echo ""
echo "To access the VM console, run:"
echo "  incus --project $INCUS_PROJECT console $INSTANCE_NAME"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
