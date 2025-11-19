#!/bin/bash
# Disk Consolidation Script
# Automates backup and verification for consolidating two ~100GB disks into one larger disk
# Manual steps required for Recovery Mode and Disk Utility

echo "=== Disk Consolidation Script ==="
echo "This script handles backups and verification. Manual GUI steps are required."
echo ""

# Step 1: Backup critical data
echo "Step 1: Backing up Documents and Desktop to USB..."
rsync -av --progress ~/Documents /Volumes/Fuaad/Storage_Hierarchy/Backups/
if [ $? -eq 0 ]; then
    echo "✓ Documents backup complete."
else
    echo "✗ Documents backup failed."
    exit 1
fi

rsync -av --progress ~/Desktop /Volumes/Fuaad/Storage_Hierarchy/Backups/
if [ $? -eq 0 ]; then
    echo "✓ Desktop backup complete."
else
    echo "✗ Desktop backup failed."
    exit 1
fi

echo ""
echo "=== MANUAL STEPS REQUIRED ==="
echo "1. Restart your Mac and hold Cmd+R to enter Recovery Mode."
echo "2. Open Disk Utility from the menu bar."
echo "3. Select your main disk, click Partition, and resize the macOS partition to use free space."
echo "4. Apply changes and restart normally."
echo ""
echo "After completing manual steps, run this script again with 'verify' argument."
echo "Example: ./disk_consolidation.sh verify"

# If run with 'verify' argument, do verification
if [ "$1" == "verify" ]; then
    echo ""
    echo "Step 2: Verifying consolidation..."
    diskutil list
    echo ""
    df -h
    echo ""
    echo "✓ Verification complete. Check if disk space increased to ~200GB."
fi

echo "Script complete."
