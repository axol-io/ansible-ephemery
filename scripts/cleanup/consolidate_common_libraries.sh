#!/bin/bash
#
# This script consolidates common utility libraries into a single location
# 

set -e

# Print header
echo "====================================================="
echo "       Consolidating Common Utility Libraries         "
echo "====================================================="

# Define paths
LIB_COMMON="scripts/lib/common.sh"
UTILITIES_COMMON="scripts/utilities/common.sh"
CORE_COMMON="scripts/core/common.sh"
TARGET_COMMON="scripts/lib/common_consolidated.sh"
BACKUP_DIR="library_backups_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Warning: File $1 does not exist"
        return 1
    fi
    return 0
}

# Function to extract functions from a file
extract_functions() {
    local file="$1"
    local output="$2"
    
    echo "# Functions from $file" >> "$output"
    echo "# $(date)" >> "$output"
    echo "" >> "$output"
    
    # Capture all function definitions
    grep -n "^[[:space:]]*function[[:space:]]\+[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$file" | \
    while IFS=":" read -r line_num pattern; do
        local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*function[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\1/')
        echo "Extracting function: $func_name from $file"
        
        # Find the end of the function
        local start_line=$line_num
        local end_line=$(tail -n +$start_line "$file" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
        end_line=$((start_line + end_line))
        
        # Extract the function with a header comment
        echo "# Function: $func_name from $file" >> "$output"
        sed -n "${start_line},${end_line}p" "$file" >> "$output"
        echo "" >> "$output"
    done
    
    # Also look for bash style functions without 'function' keyword
    grep -n "^[[:space:]]*[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$file" | \
    while IFS=":" read -r line_num pattern; do
        local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\1/')
        echo "Extracting function: $func_name from $file"
        
        # Find the end of the function
        local start_line=$line_num
        local end_line=$(tail -n +$start_line "$file" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
        end_line=$((start_line + end_line))
        
        # Extract the function with a header comment
        echo "# Function: $func_name from $file" >> "$output"
        sed -n "${start_line},${end_line}p" "$file" >> "$output"
        echo "" >> "$output"
    done
}

# Backup original files
for file in "$LIB_COMMON" "$UTILITIES_COMMON" "$CORE_COMMON"; do
    if check_file "$file"; then
        cp "$file" "$BACKUP_DIR/$(basename "$file")"
        echo "Backed up $file to $BACKUP_DIR/$(basename "$file")"
    fi
done

# Create header for the consolidated file
cat > "$TARGET_COMMON" << 'EOF'
#!/usr/bin/env bash
# Version: 1.0.0
#
# Ephemery Node Scripts Library - Consolidated Common Functions
# This file combines functionality from:
#   - scripts/lib/common.sh
#   - scripts/utilities/common.sh
#   - scripts/core/common.sh
# 
# Usage: Source this file in other scripts
#
# Author: Ephemery Team
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_COMMON_CONSOLIDATED_LOADED-}" ]] && return 0
readonly _EPHEMERY_COMMON_CONSOLIDATED_LOADED=1

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Enable strict mode
set -euo pipefail

# Initialize standard paths
EPHEMERY_CONFIG_DIR="${EPHEMERY_CONFIG_DIR:-/opt/ephemery/config}"
EPHEMERY_DATA_DIR="${EPHEMERY_DATA_DIR:-/opt/ephemery/data}"
EPHEMERY_LOG_DIR="${EPHEMERY_LOG_DIR:-/opt/ephemery/logs}"

# Load any external configuration if available
CONFIG_FILE="${EPHEMERY_CONFIG_DIR}/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  source "${CONFIG_FILE}"
fi

EOF

# Extract functions from each file
for file in "$LIB_COMMON" "$UTILITIES_COMMON" "$CORE_COMMON"; do
    if check_file "$file"; then
        extract_functions "$file" "$TARGET_COMMON"
    fi
done

echo "Created consolidated library at $TARGET_COMMON"

# Create symlinks script
cat > create_symlinks.sh << 'EOF'
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
EOF
chmod +x create_symlinks.sh

# Create consolidation function script for config files
cat > consolidate_config_libraries.sh << 'EOF'
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
cat > "$TARGET_CONFIG" << 'EOH'
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
    
    echo "# Functions from $file" >> "$output"
    echo "# $(date)" >> "$output"
    echo "" >> "$output"
    
    # Find all function definitions (both styles)
    grep -n "^[[:space:]]*\(function[[:space:]]+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$file" | \
    while IFS=":" read -r line_num pattern; do
        local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/')
        echo "Extracting function: $func_name from $file"
        
        # Find the end of the function
        local start_line=$line_num
        local end_line=$(tail -n +$start_line "$file" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
        end_line=$((start_line + end_line))
        
        # Extract the function with a header comment
        echo "# Function: $func_name from $file" >> "$output"
        sed -n "${start_line},${end_line}p" "$file" >> "$output"
        echo "" >> "$output"
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
EOF
chmod +x consolidate_config_libraries.sh

echo 
echo "Consolidation script created: consolidate_common_libraries.sh"
echo "Symlink creation script created: create_symlinks.sh"
echo "Config consolidation script created: consolidate_config_libraries.sh"
echo
echo "Next steps:"
echo "1. Review the consolidated common library at $TARGET_COMMON"
echo "2. Run './create_symlinks.sh' to create symbolic links"
echo "3. Run './consolidate_config_libraries.sh' to consolidate config libraries"
echo "4. Update any hardcoded paths in scripts that refer to the original files" 