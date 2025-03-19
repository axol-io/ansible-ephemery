#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Script to add version strings to all shell scripts in the repository

# Find all shell scripts
find . -name "*.sh" -type f | while read -r script; do
  # Check if the script already has a version string
  if ! grep -q "# Version: [0-9]" "$script"; then
    echo "Adding version string to $script"
    # Create a temporary file
    temp_file=$(mktemp)
    # Get the first line (shebang)
    head -n 1 "$script" > "$temp_file"
    # Add the version string
    echo "# Version: 1.0.0" >> "$temp_file"
    # Add the rest of the file
    tail -n +2 "$script" >> "$temp_file"
    # Replace the original file
    mv "$temp_file" "$script"
    chmod +x "$script"
  fi
done

echo "Version strings added to all shell scripts" 
