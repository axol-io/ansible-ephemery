#!/bin/bash
#
# This script consolidates validator wrapper scripts
# 

set -e

# Print header
echo "====================================================="
echo "     Consolidating Validator Wrapper Scripts          "
echo "====================================================="

# Define wrapper scripts to consolidate
WRAPPER_FILES=(
    "scripts/utilities/ephemery_key_restore_wrapper.sh"
    "scripts/core/restore_validator_keys_wrapper.sh"
    "scripts/script_backups/restore_validator_keys_wrapper.sh"
)

# Define the target consolidated script
TARGET_SCRIPT="scripts/validator/validator_key_restore.sh"
BACKUP_DIR="validator_wrappers_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Create target directory if it doesn't exist
TARGET_DIR=$(dirname "$TARGET_SCRIPT")
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    echo "Created target directory: $TARGET_DIR"
fi

# Verify wrapper files
EXISTING_WRAPPERS=()
for wrapper in "${WRAPPER_FILES[@]}"; do
    if [ -f "$wrapper" ]; then
        EXISTING_WRAPPERS+=("$wrapper")
        cp "$wrapper" "$BACKUP_DIR/$(basename "$wrapper")"
        echo "Backed up $wrapper"
    else
        echo "Warning: Wrapper $wrapper not found, skipping"
    fi
done

if [ ${#EXISTING_WRAPPERS[@]} -eq 0 ]; then
    echo "No validator wrapper scripts found. Exiting."
    exit 1
fi

# Function to analyze and compare wrapper scripts
analyze_wrappers() {
    echo "Analyzing wrapper scripts..."
    
    # Create analysis report
    ANALYSIS_FILE="$BACKUP_DIR/wrapper_analysis.md"
    
    cat > "$ANALYSIS_FILE" << EOF
# Validator Wrapper Scripts Analysis
Generated on $(date)

This report analyzes the similarities and differences between validator wrapper scripts.

EOF
    
    # Compare each wrapper file
    for wrapper in "${EXISTING_WRAPPERS[@]}"; do
        echo "## $(basename "$wrapper")" >> "$ANALYSIS_FILE"
        echo "" >> "$ANALYSIS_FILE"
        
        # Count lines and functions
        TOTAL_LINES=$(wc -l < "$wrapper")
        FUNCTION_COUNT=$(grep -c "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$wrapper" || echo "0")
        
        echo "- Total lines: $TOTAL_LINES" >> "$ANALYSIS_FILE"
        echo "- Function count: $FUNCTION_COUNT" >> "$ANALYSIS_FILE"
        echo "" >> "$ANALYSIS_FILE"
        
        # Extract function names
        echo "### Functions:" >> "$ANALYSIS_FILE"
        grep -n "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$wrapper" | \
        sed -E 's/^[0-9]+:[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/g' >> "$ANALYSIS_FILE"
        
        echo "" >> "$ANALYSIS_FILE"
    done
    
    # Find common functions across all files
    echo "## Common Functions" >> "$ANALYSIS_FILE"
    echo "" >> "$ANALYSIS_FILE"
    
    # Extract all function names from all files
    ALL_FUNCTIONS=()
    for wrapper in "${EXISTING_WRAPPERS[@]}"; do
        FUNCS=$(grep -n "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$wrapper" | \
               sed -E 's/^[0-9]+:[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/g')
        for func in $FUNCS; do
            ALL_FUNCTIONS+=("$func")
        done
    done
    
    # Count occurrences of each function
    declare -A FUNCTION_COUNTS
    for func in "${ALL_FUNCTIONS[@]}"; do
        if [[ -v FUNCTION_COUNTS["$func"] ]]; then
            FUNCTION_COUNTS["$func"]=$((FUNCTION_COUNTS["$func"] + 1))
        else
            FUNCTION_COUNTS["$func"]=1
        fi
    done
    
    # List functions that appear in all files
    for func in "${!FUNCTION_COUNTS[@]}"; do
        if [ "${FUNCTION_COUNTS[$func]}" -eq "${#EXISTING_WRAPPERS[@]}" ]; then
            echo "- $func (appears in all files)" >> "$ANALYSIS_FILE"
        elif [ "${FUNCTION_COUNTS[$func]}" -gt 1 ]; then
            echo "- $func (appears in ${FUNCTION_COUNTS[$func]} files)" >> "$ANALYSIS_FILE"
        fi
    done
    
    echo "" >> "$ANALYSIS_FILE"
    echo "Analysis report saved to $ANALYSIS_FILE"
}

# Create consolidated script
create_consolidated_script() {
    echo "Creating consolidated wrapper script..."
    
    # Choose the most complete wrapper as base
    BASE_WRAPPER=""
    MAX_LINES=0
    
    for wrapper in "${EXISTING_WRAPPERS[@]}"; do
        LINES=$(wc -l < "$wrapper")
        if [ "$LINES" -gt "$MAX_LINES" ]; then
            MAX_LINES=$LINES
            BASE_WRAPPER=$wrapper
        fi
    done
    
    echo "Using $BASE_WRAPPER as base for consolidation"
    
    # Create header for consolidated script
    cat > "$TARGET_SCRIPT" << EOF
#!/usr/bin/env bash
#
# Validator Key Restore Wrapper
# This script combines functionality from multiple validator key restore wrappers
#
# Author: Ephemery Team
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)

set -euo pipefail

# Prevent sourcing
if [[ "\${BASH_SOURCE[0]}" != "\$0" ]]; then
    echo "This script should not be sourced" >&2
    return 1
fi

# Script version
VERSION="1.0.0-consolidated"

# Get the absolute path of the script directory
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

# Source common library if available
COMMON_LIB="\$PROJECT_ROOT/scripts/lib/common_consolidated.sh"
if [[ -f "\$COMMON_LIB" ]]; then
    source "\$COMMON_LIB"
fi

EOF
    
    # Extract useful functions from all wrappers
    # Start with the base wrapper to get everything
    grep -n "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$BASE_WRAPPER" | \
    while IFS=":" read -r line_num pattern; do
        local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/')
        
        # Find the end of the function
        local start_line=$line_num
        local end_line=$(tail -n +$start_line "$BASE_WRAPPER" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
        end_line=$((start_line + end_line))
        
        # Extract the function with a header comment
        echo "# Function: $func_name from $BASE_WRAPPER" >> "$TARGET_SCRIPT"
        sed -n "${start_line},${end_line}p" "$BASE_WRAPPER" >> "$TARGET_SCRIPT"
        echo "" >> "$TARGET_SCRIPT"
    done
    
    # Now check other wrappers for unique functions
    for wrapper in "${EXISTING_WRAPPERS[@]}"; do
        # Skip base wrapper
        [ "$wrapper" = "$BASE_WRAPPER" ] && continue
        
        grep -n "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$wrapper" | \
        while IFS=":" read -r line_num pattern; do
            local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/')
            
            # Check if function already exists in target file
            if ! grep -q "^[[:space:]]*\(function[[:space:]]\+\)\?${func_name}[[:space:]]*().*{" "$TARGET_SCRIPT"; then
                # Function is unique, add it
                echo "Adding unique function $func_name from $wrapper"
                
                # Find the end of the function
                local start_line=$line_num
                local end_line=$(tail -n +$start_line "$wrapper" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
                end_line=$((start_line + end_line))
                
                # Extract the function with a header comment
                echo "# Function: $func_name from $wrapper" >> "$TARGET_SCRIPT"
                sed -n "${start_line},${end_line}p" "$wrapper" >> "$TARGET_SCRIPT"
                echo "" >> "$TARGET_SCRIPT"
            fi
        done
    done
    
    # Add main execution section
    cat >> "$TARGET_SCRIPT" << 'EOF'

# Main execution function
main() {
    echo "====================================================="
    echo "     Ephemery Validator Key Restore Wrapper          "
    echo "     Version: $VERSION                               "
    echo "====================================================="
    
    # Parse command line arguments
    local force=false
    local verbose=false
    local target_dir=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -d|--directory)
                if [[ $# -lt 2 || $2 == -* ]]; then
                    echo "Error: --directory requires an argument" >&2
                    exit 1
                fi
                target_dir="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set default target directory if not specified
    if [ -z "$target_dir" ]; then
        target_dir="/opt/ephemery/validator/keys"
    fi
    
    # Display settings
    echo "Settings:"
    echo "- Target directory: $target_dir"
    echo "- Force mode: $force"
    echo "- Verbose mode: $verbose"
    echo
    
    # Validate environment and prerequisites
    validate_environment
    
    # Perform key restore
    restore_validator_keys "$target_dir" "$force" "$verbose"
    
    echo "Key restore completed successfully!"
}

# Run main function
main "$@"
EOF
    
    # Make script executable
    chmod +x "$TARGET_SCRIPT"
    
    echo "Created consolidated wrapper script: $TARGET_SCRIPT"
}

# Create symlinks for backward compatibility
create_symlinks() {
    echo "Creating symlinks for backward compatibility..."
    
    for wrapper in "${EXISTING_WRAPPERS[@]}"; do
        if [ -f "$wrapper" ]; then
            local wrapper_dir=$(dirname "$wrapper")
            local rel_path=$(python3 -c "import os.path; print(os.path.relpath('$TARGET_SCRIPT', '$wrapper_dir'))")
            
            # Rename original file
            mv "$wrapper" "${wrapper}.old"
            echo "Renamed $wrapper to ${wrapper}.old"
            
            # Create symlink
            ln -sf "$rel_path" "$wrapper"
            echo "Created symlink: $wrapper -> $rel_path"
        fi
    done
    
    echo "Symlinks created successfully."
}

# Run the functions
analyze_wrappers
create_consolidated_script
create_symlinks

echo 
echo "Validator wrapper scripts have been consolidated."
echo "Original scripts backed up to $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Review the consolidated script at $TARGET_SCRIPT"
echo "2. Test the consolidated script functionality"
echo "3. After verifying everything works, you can remove the old .old files" 