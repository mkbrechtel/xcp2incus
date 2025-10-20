#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path

def find_vm_dirs():
    """Find all VM directories identified by xcp2incus.env marker file"""
    vm_dirs = []
    for root, dirs, files in os.walk('.', topdown=True):
        if 'xcp2incus.env' in files:
            vm_dirs.append(root)
        # Don't recurse deeper than 2 levels
        if root.count(os.sep) >= 2:
            dirs.clear()
    return sorted(vm_dirs)

def read_file(path):
    """Read file content, return empty string if not exists"""
    try:
        return Path(path).read_text().strip()
    except FileNotFoundError:
        return ""

def get_vdbs(vm_dir):
    """Get list of VDB directories for a VM"""
    vdbs = []
    for item in sorted(Path(vm_dir).iterdir()):
        if item.is_dir() and item.name.startswith('vdb-'):
            device = item.name[4:]  # Remove 'vdb-' prefix
            vdi_size = read_file(item / "xcp-vdi-size")
            # Convert bytes to GiB if size is available
            if vdi_size and vdi_size.isdigit():
                size_gib = int(vdi_size) / 1073741824
                vdbs.append(f"{device}({size_gib:.1f}GiB)")
            else:
                vdbs.append(device)
    return ",".join(vdbs) if vdbs else ""

def format_status(status):
    """Format status with leading zero for single digit numbers (1-9)"""
    if status and status.isdigit():
        num = int(status)
        if 0 < num < 10:
            return '0' + status
    return status

def main():
    parser = argparse.ArgumentParser(description='List VMs in migration')
    parser.add_argument('--all', action='store_true', help='Show all VMs including those with status 100')
    args = parser.parse_args()

    vm_dirs = find_vm_dirs()

    if not vm_dirs:
        print("No VM migration folders found.")
        return 0

    # Collect data
    rows = []
    headers = ["INFO", "VM NAME", "STATUS", "PLAN", "XCP HOST", "INCUS INSTANCE", "PRIMARY IP", "VDBS"]

    for vm_dir in vm_dirs:
        vm_name = os.path.basename(vm_dir)
        status = read_file(os.path.join(vm_dir, "status"))

        # Skip VMs with status "100" unless --all flag is set
        if status == "100" and not args.all:
            continue

        info = read_file(os.path.join(vm_dir, "info"))
        plan = read_file(os.path.join(vm_dir, "plan")).split('\n')[0] if read_file(os.path.join(vm_dir, "plan")) else ""
        xcp_host = read_file(os.path.join(vm_dir, "xcp-host"))
        incus_instance = read_file(os.path.join(vm_dir, "incus-instance-name"))
        primary_ip = read_file(os.path.join(vm_dir, "primary-ip"))
        vdbs = get_vdbs(vm_dir)

        # Format status with leading zero if needed
        formatted_status = format_status(status)

        rows.append([info, vm_name, formatted_status, plan, xcp_host, incus_instance, primary_ip, vdbs])

    # Calculate column widths
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(cell))

    # Print header
    header_line = "  ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers))
    print(header_line)
    print("  ".join("=" * col_widths[i] for i in range(len(headers))))

    # Print rows
    for row in rows:
        print("  ".join(cell.ljust(col_widths[i]) for i, cell in enumerate(row)))

if __name__ == "__main__":
    sys.exit(main() or 0)
