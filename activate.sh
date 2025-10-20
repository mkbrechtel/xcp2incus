#!/bin/bash
# Source this file to add the bin directory to your PATH
# Usage: source activate.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add bin directory to PATH if not already present
if [[ ":$PATH:" != *":$SCRIPT_DIR/bin:"* ]]; then
    export PATH="$SCRIPT_DIR/bin:$PATH"
    echo "Added $SCRIPT_DIR/bin to PATH"
else
    echo "$SCRIPT_DIR/bin is already in PATH"
fi
