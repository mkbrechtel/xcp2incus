# xcp2incus

Migration toolkit for moving production VMs from XCP-ng to Incus via Restic storage.

## Overview

This project provides scripts to migrate VMs from XCP-ng to Incus, tracking migration progress with a percentage-based status system.

## Migration Status System

Each migration step is represented by a percentage integer that indicates progress:

- Scripts are named with their step number: `<percentage>-<action>.sh`
- Example: `40-shutdown-vm.sh` executes at 40% progress and shuts down the VM
- The status integer marks both progress and the current migration step

## VM Metadata Storage

Each VM being migrated has its own directory containing metadata files. A directory is identified as an xcp2incus migration folder by the presence of an `xcp2incus.env` file, which allows discovery via `find`:

```
<vm-name>/
├── xcp2incus.env          # Global environment variables for the VM migration
├── xcp-vm-uuid            # UUID of the source XCP-ng VM
├── xcp-host               # Hostname/IP of the source XCP-ng host
├── incus-instance-name    # Name for the VM instance in Incus
├── primary-ip             # Primary IP address of the VM
└── status                 # Current migration status and action step
```

### Metadata Files

- **xcp2incus.env**: Global environment variables for the VM migration (also serves as marker file)
- **xcp-vm-uuid**: UUID of the VM in XCP-ng
- **xcp-host**: Source XCP-ng host hostname or IP address
- **incus-instance-name**: Name for the VM instance in Incus
- **primary-ip**: Primary IP address of the VM
- **status**: Current migration status. Contains just a number when idle (e.g., "35"), the script name without extension when a step is running (e.g., "40-shutdown-vm"), and increments by one when a step completes (e.g., "41")

## Migration Workflow

The migration process follows numbered steps:

1. Scripts execute in order based on their percentage prefix
2. Each script updates the VM's status file upon completion
3. The status file tracks which step has been completed
4. Migration can be resumed from the last completed step if interrupted

## Architecture

- **Source**: XCP-ng virtualization platform
- **Destination**: Incus container/VM manager
- **Transfer mechanism**: Restic backup/restore store
