#!/bin/bash

# remove_duplicates.sh - A script to safely remove duplicated scripts
# This script identifies and removes files from scripts/utils that are duplicated in scripts/utilities

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
if [[ -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"
elif [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common.sh"
else
  echo "Error: Required common library not found"
  exit 1
fi

# Define the source and target directories
UTILS_DIR="${PROJECT_ROOT}/scripts/utils"
UTILITIES_DIR="${PROJECT_ROOT}/scripts/utilities"
CORE_DIR="${PROJECT_ROOT}/scripts/core"

# Function to check if a file is duplicated
check_duplicate() {
  local source_file="$1"
  local target_file="$2"

  if [[ ! -f "$source_file" || ! -f "$target_file" ]]; then
    return 1 # Not a duplicate if either file doesn't exist
  fi

  diff -q "$source_file" "$target_file" >/dev/null
  return $? # Return the exit code of diff (0 if identical, 1 if different)
}

# Function to find files in the codebase that reference a specific path
find_references() {
  local path_pattern="$1"
  grep -r --include="*.sh" --include="*.yml" --include="*.yaml" "$path_pattern" "${PROJECT_ROOT}" | grep -v "remove_duplicates.sh"
}

# Function to display help message
show_help() {
  echo "Duplicate Script Removal Utility"
  echo "================================"
  echo
  echo "This script identifies and removes files from scripts/utils that are duplicated"
  echo "in scripts/utilities or consolidated in scripts/core."
  echo
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -d, --dry-run     Show what would be done without making changes"
  echo "  -f, --force       Remove files without confirmation"
  echo "  -h, --help        Display this help message"
  echo
}

# Parse command line options
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if utils directory exists
if [[ ! -d "$UTILS_DIR" ]]; then
  echo "Error: Utils directory not found at $UTILS_DIR"
  exit 1
fi

# Function to process a file
process_file() {
  local file="$1"
  local filename=$(basename "$file")
  local utilities_file="${UTILITIES_DIR}/${filename}"

  echo "Processing: $filename"

  # Check if duplicated in utilities
  if check_duplicate "$file" "$utilities_file"; then
    echo "  - Duplicate found in utilities directory"

    # Check for references to this file
    local references=$(find_references "scripts/utils/${filename}")
    if [[ -n "$references" ]]; then
      echo "  - Found references to this file in the codebase:"
      echo "$references"
      echo "  - You may need to update these references manually"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  - [DRY RUN] Would remove: $file"
    else
      if [[ "$FORCE" == "true" ]]; then
        rm "$file"
        echo "  - Removed: $file"
      else
        read -p "  - Remove this file? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          rm "$file"
          echo "  - Removed: $file"
        else
          echo "  - Skipped"
        fi
      fi
    fi
  else
    # Check if it's an inventory-related script that's been consolidated
    if [[ "$filename" == "generate_inventory.sh" ||
      "$filename" == "manage_inventories.sh" ||
      "$filename" == "parse_inventory.sh" ||
      "$filename" == "validate_inventory.sh" ]]; then

      echo "  - This script has been consolidated into inventory_manager.sh in the core directory"

      # Check for references to this file
      local references=$(find_references "scripts/utils/${filename}")
      if [[ -n "$references" ]]; then
        echo "  - Found references to this file in the codebase:"
        echo "$references"
        echo "  - You should update these to use scripts/core/inventory_manager.sh instead"
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        echo "  - [DRY RUN] Would remove: $file"
      else
        if [[ "$FORCE" == "true" ]]; then
          rm "$file"
          echo "  - Removed: $file"
        else
          read -p "  - Remove this file? (y/n): " confirm
          if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            rm "$file"
            echo "  - Removed: $file"
          else
            echo "  - Skipped"
          fi
        fi
      fi
    else
      echo "  - Not a duplicate or consolidated script"
    fi
  fi

  echo
}

# Main execution
echo "Scanning for duplicated scripts..."
echo

# Skip the README.md file since it's intentionally kept for transition
for file in "$UTILS_DIR"/*; do
  if [[ -f "$file" && $(basename "$file") != "README.md" ]]; then
    process_file "$file"
  fi
done

echo "Process completed."

if [[ "$DRY_RUN" == "true" ]]; then
  echo "This was a dry run. No files were actually removed."
fi

echo
echo "Note: If you removed files, make sure to update any references to them in your codebase."
