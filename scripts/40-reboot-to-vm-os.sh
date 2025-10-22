#!/bin/bash
set -euo pipefail

# Reboot to VM OS - shutdown rescue mode, remove rescue profile, apply final config, and start VM
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

echo "Finalizing VM configuration for: $INSTANCE_NAME"
echo "Using Incus project: $INCUS_PROJECT"

# Check if incus-vm.yaml exists
if [ ! -f incus-vm.yaml ]; then
    echo "Error: incus-vm.yaml not found. Run 15-prepare-vm-config.sh first."
    exit 1
fi

# Check if VM exists
if ! incus --project "$INCUS_PROJECT" list -f csv | grep -q "^${INSTANCE_NAME},"; then
    echo "Error: VM '$INSTANCE_NAME' not found."
    exit 1
fi

# Check if VM is running and stop it
VM_STATE=$(incus --project "$INCUS_PROJECT" list -f csv -c ns | grep "^${INSTANCE_NAME}," | cut -d, -f2)
if [ "$VM_STATE" = "RUNNING" ]; then
    echo "Stopping VM..."
    incus --project "$INCUS_PROJECT" stop "$INSTANCE_NAME"
    echo "✓ VM stopped"
else
    echo "VM is already stopped"
fi

# Remove the rescue profile
echo ""
echo "Removing rescue profile..."
if incus --project "$INCUS_PROJECT" profile list -f csv | grep -q "^rescue,"; then
    # Remove rescue profile from the VM
    incus --project "$INCUS_PROJECT" profile remove "$INSTANCE_NAME" rescue
    echo "✓ Rescue profile removed from VM"
else
    echo "Rescue profile not found (already removed?)"
fi

# Apply the final configuration from incus-vm.yaml
echo ""
echo "Applying final configuration from incus-vm.yaml..."
echo "Configuration to apply:"
cat incus-vm.yaml

# Extract and apply configuration settings
echo ""
echo "Updating VM configuration..."

# Set memory limit
MEMORY_LIMIT=$(grep "limits.memory:" incus-vm.yaml | awk '{print $2}')
if [ -n "$MEMORY_LIMIT" ]; then
    incus --project "$INCUS_PROJECT" config set "$INSTANCE_NAME" limits.memory "$MEMORY_LIMIT"
    echo "  Set limits.memory=$MEMORY_LIMIT"
fi

# Set CPU limit
CPU_LIMIT=$(grep "limits.cpu:" incus-vm.yaml | awk '{print $2}')
if [ -n "$CPU_LIMIT" ]; then
    incus --project "$INCUS_PROJECT" config set "$INSTANCE_NAME" limits.cpu "$CPU_LIMIT"
    echo "  Set limits.cpu=$CPU_LIMIT"
fi

# Set security.secureboot
SECUREBOOT=$(grep "security.secureboot:" incus-vm.yaml | awk '{print $2}' | tr -d '"')
if [ -n "$SECUREBOOT" ]; then
    incus --project "$INCUS_PROJECT" config set "$INSTANCE_NAME" security.secureboot "$SECUREBOOT"
    echo "  Set security.secureboot=$SECUREBOOT"
fi

# Set security.csm
CSM=$(grep "security.csm:" incus-vm.yaml | awk '{print $2}' | tr -d '"')
if [ -n "$CSM" ]; then
    incus --project "$INCUS_PROJECT" config set "$INSTANCE_NAME" security.csm "$CSM"
    echo "  Set security.csm=$CSM"
fi

echo ""
echo "✓ VM configuration finalized"
echo ""
echo "The VM is now configured with:"
echo "  - No profiles (rescue profile removed)"
echo "  - Secure boot disabled"
echo "  - CSM enabled for legacy boot support"
echo ""
echo "Starting VM with native OS..."
incus --project "$INCUS_PROJECT" start "$INSTANCE_NAME"

echo ""
echo "✓ VM started successfully"
echo ""
echo "The VM is now running its native operating system."
echo "To access the VM console, run:"
echo "  incus --project $INCUS_PROJECT console $INSTANCE_NAME"

# Mark step complete
echo "$((STEP_NUM + 1))" > status
