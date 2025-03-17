#!/bin/bash
#
# This script updates import statements to reflect the new directory structure
#

set -e

TARGET_DIR="scripts"
BACKUP_DIR="import_updates_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Find all script files
SCRIPT_FILES=$(find "$TARGET_DIR" -name "*.sh" -type f)
UPDATED_FILES=0

for file in $SCRIPT_FILES; do
    # Check if file contains reference to scripts/utils
    if grep -q "scripts/utils" "$file"; then
        # Backup the file
        cp "$file" "$BACKUP_DIR/$(basename "$file")"
        
        # Replace references
        sed -i 's|scripts/utils|scripts/utilities|g' "$file"
        
        echo "Updated imports in: $file"
        UPDATED_FILES=$((UPDATED_FILES + 1))
    fi
done

echo "Updated imports in $UPDATED_FILES files."
echo "Backups saved to $BACKUP_DIR"
