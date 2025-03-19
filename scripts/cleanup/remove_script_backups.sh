#!/bin/bash
#
# This script verifies and removes the scripts/script_backups directory
# 

set -e

SCRIPT_BACKUPS_DIR="scripts/script_backups"

# Print header
echo "====================================================="
echo "       Removing script_backups directory             "
echo "====================================================="

# Check if directory exists
if [ ! -d "$SCRIPT_BACKUPS_DIR" ]; then
    echo "Directory $SCRIPT_BACKUPS_DIR does not exist."
    exit 0
fi

# Count files
FILE_COUNT=$(find "$SCRIPT_BACKUPS_DIR" -type f | wc -l)
echo "Found $FILE_COUNT files in $SCRIPT_BACKUPS_DIR"

# Create a list of all files in the directory
BACKUP_LIST="script_backups_removed_$(date +%Y%m%d_%H%M%S).txt"
find "$SCRIPT_BACKUPS_DIR" -type f > "$BACKUP_LIST"
echo "List of files saved to $BACKUP_LIST"

# Check for unique files that don't exist elsewhere
echo "Checking for unique files that don't exist elsewhere in the repository..."
UNIQUE_FILES=()

while IFS= read -r backup_file; do
    # Get filename without path and .bak extension
    if [[ "$backup_file" == *".bak" ]]; then
        base_filename=$(basename "$backup_file" .bak)
    else
        base_filename=$(basename "$backup_file")
    fi
    
    # Look for same filename outside script_backups directory
    other_file=$(find . -path "./$SCRIPT_BACKUPS_DIR" -prune -o -name "$base_filename" -type f -print | head -1)
    
    if [ -z "$other_file" ]; then
        # No same-named file found, potentially unique
        UNIQUE_FILES+=("$backup_file")
    else
        # Same-named file found, check if content is different
        if ! diff -q "$backup_file" "$other_file" >/dev/null 2>&1; then
            UNIQUE_FILES+=("$backup_file - content differs from $other_file")
        fi
    fi
done < "$BACKUP_LIST"

# Report findings
if [ ${#UNIQUE_FILES[@]} -gt 0 ]; then
    echo "WARNING: Found ${#UNIQUE_FILES[@]} potentially unique files:"
    printf '%s\n' "${UNIQUE_FILES[@]}"
    echo
    echo "These files may contain unique content not found elsewhere."
    echo "Please review these files before proceeding."
    
    read -p "Do you still want to remove the entire directory? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
else
    echo "No unique content found in backup directory."
    read -p "Do you want to remove the script_backups directory? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Create a compressed backup
echo "Creating a compressed backup of the directory before removal..."
BACKUP_ARCHIVE="script_backups_archive_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_ARCHIVE" "$SCRIPT_BACKUPS_DIR"
echo "Backup saved as $BACKUP_ARCHIVE"

# Remove the directory
echo "Removing $SCRIPT_BACKUPS_DIR directory..."
rm -rf "$SCRIPT_BACKUPS_DIR"

echo 
echo "The script_backups directory has been removed."
echo "A record of removed files is saved in $BACKUP_LIST"
echo "A backup archive is saved as $BACKUP_ARCHIVE" 