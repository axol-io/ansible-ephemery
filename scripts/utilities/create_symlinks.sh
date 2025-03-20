#!/bin/bash
#
# This script creates symbolic links for backward compatibility
#

set -e

CONSOLIDATED_FILE="scripts/lib/common_consolidated.sh"
LIB_COMMON="scripts/lib/common.sh"
UTILITIES_COMMON="scripts/utilities/common.sh"
CORE_COMMON="scripts/core/common.sh"

if [ ! -f "$CONSOLIDATED_FILE" ]; then
  echo "Error: Consolidated file not found at $CONSOLIDATED_FILE"
  exit 1
fi

# Create symlinks
for file in "$LIB_COMMON" "$UTILITIES_COMMON" "$CORE_COMMON"; do
  if [ -f "$file" ]; then
    mv "$file" "${file}.old"
    echo "Moved $file to ${file}.old"
  fi

  ln -sf "../../lib/common_consolidated.sh" "$file"
  echo "Created symlink: $file -> ../../lib/common_consolidated.sh"
done

echo "Symlinks created successfully."
