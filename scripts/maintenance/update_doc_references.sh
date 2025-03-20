#!/bin/bash

# update_doc_references.sh - A script to update documentation references to deprecated scripts
# This script updates references to scripts/utils/ in documentation files

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

# Define the documentation directories
DOC_DIRS=(
  "${PROJECT_ROOT}/docs"
  "${PROJECT_ROOT}/*.md"
)

# Function to find files containing references to deprecated paths
find_doc_files_with_refs() {
  find "${PROJECT_ROOT}" -type f -name "*.md" -exec grep -l "scripts/utils/" {} \;
}

# Function to display help message
show_help() {
  echo "Documentation Reference Update Utility"
  echo "====================================="
  echo
  echo "This script updates references to deprecated scripts/utils/ paths in documentation"
  echo "files with paths to the new consolidated scripts."
  echo
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -d, --dry-run     Show what would be done without making changes"
  echo "  -f, --force       Update files without confirmation"
  echo "  -h, --help        Display this help message"
  echo
}

# Function to update references in a single file
update_file_references() {
  local file="$1"
  local dry_run="$2"
  local force="$3"

  echo "Processing: $(basename "$file")"

  # Create a temporary file for edits
  local temp_file=$(mktemp)

  # Update references to inventory related scripts
  sed -e 's|scripts/utils/generate_inventory.sh|scripts/core/inventory_manager.sh generate|g' \
    -e 's|scripts/utils/validate_inventory.sh|scripts/core/inventory_manager.sh validate|g' \
    -e 's|scripts/utils/parse_inventory.sh|scripts/core/inventory_manager.sh parse|g' \
    -e 's|scripts/utils/manage_inventories.sh|scripts/core/inventory_manager.sh|g' \
    -e 's|scripts/utils/guided_config.sh|scripts/utilities/guided_config.sh|g' \
    -e 's|scripts/utils/cleanup.sh|scripts/utilities/cleanup.sh|g' \
    -e 's|scripts/utils/verify_deployment.sh|scripts/utilities/verify_deployment.sh|g' \
    "$file" >"$temp_file"

  # Check if any changes were made
  if cmp -s "$file" "$temp_file"; then
    echo "  - No changes needed"
    rm -f "$temp_file"
    return 0
  fi

  # Show a diff of the changes
  echo "  - Changes to be made:"
  diff -u "$file" "$temp_file" | grep -v "^---" | grep -v "^+++" | grep "^[+-]" | head -10

  if [[ "$dry_run" == "true" ]]; then
    echo "  - [DRY RUN] Would update: $file"
    rm -f "$temp_file"
    return 0
  fi

  if [[ "$force" == "true" ]]; then
    mv "$temp_file" "$file"
    echo "  - Updated: $file"
  else
    read -p "  - Update this file? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      mv "$temp_file" "$file"
      echo "  - Updated: $file"
    else
      echo "  - Skipped"
      rm -f "$temp_file"
    fi
  fi

  return 0
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

# Main execution
echo "Scanning for documentation files with references to deprecated scripts..."
echo

# Find documentation files with references to the deprecated utils scripts
DOC_FILES=$(find_doc_files_with_refs)

if [[ -z "$DOC_FILES" ]]; then
  echo "No files found with references to deprecated scripts"
  exit 0
fi

# Update each file
for file in $DOC_FILES; do
  update_file_references "$file" "$DRY_RUN" "$FORCE"
  echo
done

echo "Process completed."

if [[ "$DRY_RUN" == "true" ]]; then
  echo "This was a dry run. No files were actually updated."
fi

echo
echo "Note: You should manually review all documentation files to ensure references are accurate."
