#!/bin/bash
# Automated storage cleanup script
# Run weekly to maintain optimized space

echo "Starting automated storage cleanup..."

# Clear user caches (safe)
rm -rf ~/Library/Caches/* 2>/dev/null
echo "User caches cleared."

# Clear system caches (use with caution)
# sudo rm -rf /Library/Caches/* 2>/dev/null  # Uncomment if needed, but risky

# Check disk space
echo "Current disk usage:"
df -h / | tail -1

echo "Cleanup complete. Schedule via: crontab -e then add '0 2 * * 0 /Users/fuaadabdullah/ForgeMonorepo/tools/storage_cleanup.sh'"
