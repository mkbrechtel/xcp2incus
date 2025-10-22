#!/bin/bash
set -euo pipefail

# Shutdown the XCP VM gracefully
# Usage: Run from within the VM directory

# Extract step info from script name
SCRIPT_NAME=$(basename "$0" .sh)
STEP_NUM=$(echo "$SCRIPT_NAME" | cut -d- -f1)

# Source environment variables
source xcp2incus.env

# Read VM UUID and XCP host
VM_UUID=$(cat xcp-vm-uuid)
XCP_HOST=$(cat xcp-host)

# Update status
echo "$SCRIPT_NAME" > status

# Trap errors and mark status as failed
trap 'if [ $? -ne 0 ]; then echo "FAIL-$(cat status)" > status; fi' EXIT

# Get VM name for display
VM_NAME=$(cat xcp-vm-name 2>/dev/null || echo "unknown")

echo "Shutting down VM: $VM_NAME ($VM_UUID)"

# Check current power state
POWER_STATE=$(ssh "$XCP_HOST" "xe vm-param-get uuid=$VM_UUID param-name=power-state")
echo "Current power state: $POWER_STATE"

if [ "$POWER_STATE" = "halted" ]; then
    echo "VM is already halted, skipping shutdown"
elif [ "$POWER_STATE" = "running" ]; then
    echo "Initiating clean shutdown..."
    ssh "$XCP_HOST" "xe vm-shutdown uuid=$VM_UUID"

    # Wait for VM to shutdown (timeout after 5 minutes)
    TIMEOUT=300
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        POWER_STATE=$(ssh "$XCP_HOST" "xe vm-param-get uuid=$VM_UUID param-name=power-state")
        if [ "$POWER_STATE" = "halted" ]; then
            echo "VM shutdown completed successfully"
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        echo "Waiting for shutdown... ($ELAPSED seconds elapsed)"
    done

    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Warning: VM did not shut down within timeout period"
        echo "Current power state: $POWER_STATE"
        exit 1
    fi
else
    echo "VM is in unexpected power state: $POWER_STATE"
    exit 1
fi

echo "VM shutdown completed"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
