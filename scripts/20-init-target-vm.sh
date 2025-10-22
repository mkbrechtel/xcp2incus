#!/bin/bash
set -euo pipefail

# Initialize target Incus VM using prepared configuration
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

# Trap errors and mark status as failed
trap 'if [ $? -ne 0 ]; then echo "FAIL-$(cat status)" > status; fi' EXIT

# Read instance name
INSTANCE_NAME=$(cat incus-instance-name)

echo "Initializing Incus VM: $INSTANCE_NAME"

# Check if incus-vm-rescue.yaml exists
if [ ! -f incus-vm-rescue.yaml ]; then
    echo "Error: incus-vm-rescue.yaml not found. Run 15-prepare-vm-config.sh first."
    exit 1
fi

echo "Using rescue configuration:"
cat incus-vm-rescue.yaml

# Initialize the VM using local Incus CLI (already configured to connect to remote)
echo ""
echo "Initializing VM on Incus host with rescue profile..."
echo "Using Incus project: $INCUS_PROJECT"
incus --project "$INCUS_PROJECT" init --empty --vm "$INSTANCE_NAME" < incus-vm-rescue.yaml

echo "✓ VM initialized successfully"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
