#!/bin/bash
#
# This script consolidates config libraries
#

set -e

# Define paths
LIB_CONFIG="scripts/lib/config.sh"
UTILITIES_CONFIG="scripts/utilities/config.sh"
CORE_PATH_CONFIG="scripts/core/path_config.sh"
CORE_EPHEMERY_CONFIG="scripts/core/ephemery_config.sh"
TARGET_CONFIG="scripts/lib/config_consolidated.sh"
BACKUP_DIR="config_library_backups_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Backup original files
for file in "$LIB_CONFIG" "$UTILITIES_CONFIG" "$CORE_PATH_CONFIG" "$CORE_EPHEMERY_CONFIG"; do
  if [ -f "$file" ]; then
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    echo "Backed up $file to $BACKUP_DIR/$(basename "$file")"
  fi
done

# Create header for the consolidated file
cat >"$TARGET_CONFIG" <<'EOH'
#!/usr/bin/env bash
# Version: 1.0.0
#
# Ephemery Node Scripts Library - Consolidated Configuration Functions
# This file combines functionality from:
#   - scripts/lib/config.sh
#   - scripts/utilities/config.sh
#   - scripts/core/path_config.sh
#   - scripts/core/ephemery_config.sh
#
# Usage: Source this file in other scripts
#
# Author: Ephemery Team
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_CONFIG_CONSOLIDATED_LOADED-}" ]] && return 0
readonly _EPHEMERY_CONFIG_CONSOLIDATED_LOADED=1

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Enable strict mode
set -euo pipefail

# Default configuration paths
EPHEMERY_CONFIG_DIR="${EPHEMERY_CONFIG_DIR:-/opt/ephemery/config}"
EPHEMERY_CONFIG_FILE="${EPHEMERY_CONFIG_FILE:-${EPHEMERY_CONFIG_DIR}/ephemery.conf}"
EOH

# Function to extract functions from config files
extract_config_functions() {
  local file="$1"
  local output="$2"

  if [ ! -f "$file" ]; then
    echo "Warning: File $file does not exist"
    return 1
  fi

  echo "# Functions from $file" >>"$output"
  echo "# $(date)" >>"$output"
  echo "" >>"$output"

  # Find all function definitions (both styles)
  grep -n "^[[:space:]]*\(function[[:space:]]+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$file" \
    | while IFS=":" read -r line_num pattern; do
      local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/')
      echo "Extracting function: $func_name from $file"

      # Find the end of the function
      local start_line=$line_num
      local end_line=$(tail -n +$start_line "$file" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
      end_line=$((start_line + end_line))

      # Extract the function with a header comment
      echo "# Function: $func_name from $file" >>"$output"
      sed -n "${start_line},${end_line}p" "$file" >>"$output"
      echo "" >>"$output"
    done
}

# Extract functions from each config file
for file in "$LIB_CONFIG" "$UTILITIES_CONFIG" "$CORE_PATH_CONFIG" "$CORE_EPHEMERY_CONFIG"; do
  extract_config_functions "$file" "$TARGET_CONFIG"
done

echo "Created consolidated config library at $TARGET_CONFIG"

# Create symlinks for config files
for file in "$LIB_CONFIG" "$UTILITIES_CONFIG" "$CORE_PATH_CONFIG" "$CORE_EPHEMERY_CONFIG"; do
  if [ -f "$file" ]; then
    mv "$file" "${file}.old"
    echo "Moved $file to ${file}.old"

    # Create relative path for symlink
    rel_path=$(python3 -c "import os.path; print(os.path.relpath('$TARGET_CONFIG', os.path.dirname('$file')))")
    ln -sf "$rel_path" "$file"
    echo "Created symlink: $file -> $rel_path"
  fi
done

echo "Config library consolidation complete."
