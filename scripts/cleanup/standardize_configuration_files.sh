#!/bin/bash
#
# This script standardizes configuration and requirements files
#

set -e

# Print header
echo "====================================================="
echo "     Standardizing Configuration Files                "
echo "====================================================="

# Define configuration file pairs (source -> target)
declare -A CONFIG_PAIRS=(
  [".config/requirements/requirements.txt"]="requirements.txt"
  [".config/requirements/requirements-dev.txt"]="requirements-dev.txt"
  [".config/requirements/requirements.yaml"]="requirements.yaml"
)

BACKUP_DIR="config_files_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Function to compare and standardize config files
standardize_config_files() {
  echo "Comparing and standardizing configuration files..."

  for source in "${!CONFIG_PAIRS[@]}"; do
    target="${CONFIG_PAIRS[$source]}"

    # Check if both files exist
    if [ -f "$source" ] && [ -f "$target" ]; then
      # Backup both files
      cp "$source" "$BACKUP_DIR/$(basename "$source")"
      cp "$target" "$BACKUP_DIR/$(basename "$target")"

      echo "Comparing $source and $target..."

      # Check if files are identical
      if diff -q "$source" "$target" >/dev/null; then
        echo "Files are identical, will keep $target and remove $source"
        rm "$source"
        echo "Removed $source"
      else
        # Files differ, create a comparison report
        DIFF_FILE="$BACKUP_DIR/diff_$(basename "$source").txt"
        echo "Files differ, creating comparison report at $DIFF_FILE"

        echo "# Comparison between $source and $target" >"$DIFF_FILE"
        echo "# Generated on $(date)" >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        # Show file contents
        echo "## $source content:" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        cat "$source" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        echo "## $target content:" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        cat "$target" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        # Show diff
        echo "## Diff:" >>"$DIFF_FILE"
        echo '```diff' >>"$DIFF_FILE"
        diff -u "$source" "$target" >>"$DIFF_FILE" 2>/dev/null || true
        echo '```' >>"$DIFF_FILE"

        # Ask user what to do
        echo "Files differ. Please review the comparison report at $DIFF_FILE"
        echo "Options:"
        echo "1. Keep $target (remove $source)"
        echo "2. Keep $source (replace $target)"
        echo "3. Merge files (keep unique lines from both)"
        echo "4. Skip (do nothing)"

        read -p "Choose option (1-4): " OPTION
        case "$OPTION" in
          1)
            rm "$source"
            echo "Removed $source"
            ;;
          2)
            cp "$source" "$target"
            rm "$source"
            echo "Replaced $target with $source and removed $source"
            ;;
          3)
            # Create merged file (sorted and unique lines)
            MERGED_FILE="$target.merged"
            sort -u "$source" "$target" >"$MERGED_FILE"
            mv "$MERGED_FILE" "$target"
            rm "$source"
            echo "Created merged file at $target and removed $source"
            ;;
          *)
            echo "Skipping $source and $target"
            ;;
        esac
      fi
    elif [ -f "$source" ]; then
      # Only source exists
      cp "$source" "$BACKUP_DIR/$(basename "$source")"

      echo "Only $source exists, moving to standard location $target"
      cp "$source" "$target"
      rm "$source"
      echo "Moved $source to $target"
    elif [ -f "$target" ]; then
      # Only target exists
      echo "Only $target exists, standard location is already used"
    else
      echo "Neither $source nor $target exist, skipping"
    fi
  done
}

# Function to create symlinks for backward compatibility
create_symlinks() {
  echo "Creating symlinks for backward compatibility..."

  for source in "${!CONFIG_PAIRS[@]}"; do
    target="${CONFIG_PAIRS[$source]}"

    # Skip if source already exists
    [ -f "$source" ] && continue

    # Only create symlink if target exists
    if [ -f "$target" ]; then
      # Create directory if it doesn't exist
      source_dir=$(dirname "$source")
      if [ ! -d "$source_dir" ]; then
        mkdir -p "$source_dir"
        echo "Created directory: $source_dir"
      fi

      # Create relative path for symlink
      rel_path=$(python3 -c "import os.path; print(os.path.relpath('$target', '$source_dir'))")

      # Create symlink
      ln -sf "$rel_path" "$source"
      echo "Created symlink: $source -> $rel_path"
    fi
  done
}

# Function to update import paths in scripts
update_imports() {
  echo "Updating import paths in scripts..."

  # Find all Python files
  PY_FILES=$(find . -name "*.py" -type f)

  # Mapping of old paths to new paths
  declare -A PATH_MAP=(
    [".config/requirements/requirements.txt"]="requirements.txt"
    [".config/requirements/requirements-dev.txt"]="requirements-dev.txt"
    [".config/requirements/requirements.yaml"]="requirements.yaml"
  )

  # Count of updated files
  UPDATED_FILES=0

  for file in $PY_FILES; do
    UPDATED=false

    # Backup the file
    cp "$file" "$BACKUP_DIR/$(basename "$file")"

    # Update paths
    for old_path in "${!PATH_MAP[@]}"; do
      new_path="${PATH_MAP[$old_path]}"

      # Check if file contains the old path
      if grep -q "$old_path" "$file"; then
        sed -i "s|$old_path|$new_path|g" "$file"
        UPDATED=true
      fi
    done

    if [ "$UPDATED" = true ]; then
      echo "Updated paths in: $file"
      UPDATED_FILES=$((UPDATED_FILES + 1))
    fi
  done

  echo "Updated paths in $UPDATED_FILES Python files"
}

# Run the functions
standardize_config_files
create_symlinks
update_imports

echo
echo "Configuration files have been standardized."
echo "Backups saved to $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Verify that the standardized configuration files work correctly"
echo "2. Check that symlinks are working properly"
echo "3. Update any hardcoded paths in scripts that aren't Python files"
