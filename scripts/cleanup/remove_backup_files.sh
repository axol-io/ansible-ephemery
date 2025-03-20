#!/bin/bash
#
# This script removes all .bak files from the repository
#

set -e

# Print header
echo "==================================================="
echo "       Removing backup (.bak) files                "
echo "==================================================="

# Find all .bak files
echo "Finding all .bak files in the repository..."
BAK_FILES=$(find . -name "*.bak" -type f)
BAK_COUNT=$(echo "$BAK_FILES" | grep -c "." || echo "0")

if [ "$BAK_COUNT" -eq 0 ]; then
  echo "No .bak files found."
  exit 0
fi

# Create a backup list
BACKUP_LIST="bak_files_removed_$(date +%Y%m%d_%H%M%S).txt"
echo "$BAK_FILES" >"$BACKUP_LIST"

echo "Found $BAK_COUNT .bak files. List saved to $BACKUP_LIST"
echo

# Confirm removal
read -p "Do you want to remove all these .bak files? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Remove the files
echo "Removing .bak files..."
echo "$BAK_FILES" | xargs rm -f

echo
echo "All .bak files have been removed."
echo "A record of removed files is saved in $BACKUP_LIST"
