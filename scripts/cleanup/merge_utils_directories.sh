#!/bin/bash
#
# This script merges scripts/utils into scripts/utilities
# 

set -e

# Print header
echo "====================================================="
echo "       Merging Utils into Utilities Directory         "
echo "====================================================="

SOURCE_DIR="scripts/utils"
TARGET_DIR="scripts/utilities"
BACKUP_DIR="utils_backup_$(date +%Y%m%d_%H%M%S)"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR does not exist."
    exit 1
fi

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Target directory $TARGET_DIR does not exist."
    echo "Creating directory $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Backup both directories
echo "Backing up source directory..."
cp -r "$SOURCE_DIR" "$BACKUP_DIR/utils"
echo "Backing up target directory..."
cp -r "$TARGET_DIR" "$BACKUP_DIR/utilities"

# Find all files in source directory
SOURCE_FILES=$(find "$SOURCE_DIR" -type f -not -path "*/\.*")
echo "Found $(echo "$SOURCE_FILES" | wc -l) files in $SOURCE_DIR"

# Check for file conflicts
CONFLICTS=()
for source_file in $SOURCE_FILES; do
    filename=$(basename "$source_file")
    target_file="$TARGET_DIR/$filename"
    
    if [ -f "$target_file" ]; then
        if ! diff -q "$source_file" "$target_file" >/dev/null 2>&1; then
            CONFLICTS+=("$filename")
        fi
    fi
done

# Report conflicts
if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "WARNING: Found ${#CONFLICTS[@]} file conflicts:"
    printf '%s\n' "${CONFLICTS[@]}"
    echo
    echo "These files exist in both directories with different content."
    
    read -p "Do you want to create a conflict report for manual resolution? (y/n): " CREATE_REPORT
    if [[ "$CREATE_REPORT" == "y" || "$CREATE_REPORT" == "Y" ]]; then
        REPORT_FILE="utils_conflicts_$(date +%Y%m%d_%H%M%S).txt"
        echo "# File Conflicts Report" > "$REPORT_FILE"
        echo "# Generated on $(date)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        for conflict in "${CONFLICTS[@]}"; do
            echo "## File: $conflict" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "### Source ($SOURCE_DIR/$conflict)" >> "$REPORT_FILE"
            echo '```bash' >> "$REPORT_FILE"
            cat "$SOURCE_DIR/$conflict" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "### Target ($TARGET_DIR/$conflict)" >> "$REPORT_FILE"
            echo '```bash' >> "$REPORT_FILE"
            cat "$TARGET_DIR/$conflict" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "### Diff" >> "$REPORT_FILE"
            echo '```diff' >> "$REPORT_FILE"
            diff -u "$TARGET_DIR/$conflict" "$SOURCE_DIR/$conflict" >> "$REPORT_FILE" 2>/dev/null || true
            echo '```' >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        done
        
        echo "Conflict report saved to $REPORT_FILE"
    fi
    
    read -p "How do you want to handle conflicts? [s]kip, [o]verwrite target, [k]eep target: " CONFLICT_STRATEGY
    case "$CONFLICT_STRATEGY" in
        s|S)
            CONFLICT_STRATEGY="skip"
            echo "Will skip conflict files"
            ;;
        o|O)
            CONFLICT_STRATEGY="overwrite"
            echo "Will overwrite target files with source files"
            ;;
        k|K)
            CONFLICT_STRATEGY="keep"
            echo "Will keep target files"
            ;;
        *)
            echo "Invalid option. Defaulting to skip."
            CONFLICT_STRATEGY="skip"
            ;;
    esac
else
    echo "No file conflicts found."
    CONFLICT_STRATEGY="overwrite"  # Default strategy when no conflicts
fi

# Copy files from source to target
echo "Copying files from $SOURCE_DIR to $TARGET_DIR..."
for source_file in $SOURCE_FILES; do
    filename=$(basename "$source_file")
    target_file="$TARGET_DIR/$filename"
    
    # Handle conflicts based on strategy
    if [ -f "$target_file" ]; then
        if ! diff -q "$source_file" "$target_file" >/dev/null 2>&1; then
            case "$CONFLICT_STRATEGY" in
                skip)
                    echo "Skipping conflict file: $filename"
                    continue
                    ;;
                keep)
                    echo "Keeping target file: $filename"
                    continue
                    ;;
                overwrite)
                    echo "Overwriting target file: $filename"
                    ;;
            esac
        else
            echo "Files are identical, skipping: $filename"
            continue
        fi
    fi
    
    cp "$source_file" "$target_file"
    echo "Copied: $filename"
done

# Create script to update imports
cat > update_imports.sh << 'EOF'
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
EOF
chmod +x update_imports.sh

echo 
echo "Files have been copied from $SOURCE_DIR to $TARGET_DIR"
echo "Backup of both directories saved to $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Run './update_imports.sh' to update import statements in scripts"
echo "2. Review any conflicts if applicable"
echo "3. After verifying everything works, you can remove the source directory with:"
echo "   rm -rf '$SOURCE_DIR'" 