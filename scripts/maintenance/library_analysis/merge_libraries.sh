#!/bin/bash

# merge_libraries.sh - Helper script to merge library files
# This script should be run manually with careful review of each step

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define the consolidated library location
CONSOLIDATED_LIB="${PROJECT_ROOT}/scripts/lib/common_unified.sh"

# Function to print colored messages
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Copy the base library first
print_status "$GREEN" "Creating unified library from common_consolidated.sh..."

if [[ ! -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
  print_status "$RED" "Base library file not found. Aborting."
  exit 1
fi

# Create a backup first
cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh.bak"
print_status "$GREEN" "Created backup of common_consolidated.sh"

# Copy as the starting point for the unified library
cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "$CONSOLIDATED_LIB"

# Inform about next steps
print_status "$YELLOW" "Next steps:"
echo "1. Use the function analysis in this directory to identify unique functions to merge"
echo "2. Manually merge the unique functions from each library into $CONSOLIDATED_LIB"
echo "3. Test the unified library thoroughly"
echo "4. Update imports in scripts to use the new unified library"

print_status "$GREEN" "Consolidation helper script finished."
