#!/bin/bash

# standardize_library_usage.sh - A script to standardize library usage across scripts
# This script identifies and updates scripts that use deprecated libraries

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

# Define the old library paths to search for
OLD_LIBS=(
    "scripts/utils/common.sh"
    "scripts/utilities/common.sh"
    "scripts/utilities/common_functions.sh"
    "scripts/utils/common_functions.sh"
    "scripts/core/common.sh"
)

# Define the new library to use
NEW_LIB="scripts/lib/common_consolidated.sh"
NEW_BASIC_LIB="scripts/lib/common_basic.sh"

# Function to display help message
show_help() {
    echo "Library Usage Standardization Utility"
    echo "====================================="
    echo
    echo "This script identifies and updates scripts that use deprecated libraries."
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -d, --dry-run     Show what would be done without making changes"
    echo "  -f, --force       Update files without confirmation"
    echo "  -h, --help        Display this help message"
    echo "  -b, --basic       Use common_basic.sh instead of common_consolidated.sh for small scripts"
    echo
}

# Function to find files that source a specific library
find_files_sourcing_library() {
    local lib_path="$1"
    grep -l "source.*${lib_path}" --include="*.sh" -r "${PROJECT_ROOT}/scripts"
}

# Function to update library reference in a file
update_library_reference() {
    local file="$1"
    local old_lib="$2"
    local new_lib="$3"
    local dry_run="$4"
    local force="$5"
    local basic_lib="$6"
    
    echo "Processing: $(basename "$file")"
    
    # Create a temporary file for edits
    local temp_file=$(mktemp)
    
    # Determine which new library to use
    local actual_new_lib="${new_lib}"
    if [[ "${basic_lib}" == "true" && $(wc -l < "${file}") -lt 100 ]]; then
        echo "  - Small script detected, using common_basic.sh"
        actual_new_lib="${NEW_BASIC_LIB}"
    fi
    
    # Create a temporary file for the initial content
    cat "${file}" > "${temp_file}"
    
    # Try to find the exact source line
    local source_line=$(grep -n "source.*${old_lib}" "${file}" | head -1 | cut -d ':' -f1)
    
    if [[ -n "${source_line}" ]]; then
        # Get the actual source line content
        local line_content=$(sed -n "${source_line}p" "${file}")
        
        # Extract any additional options (like error handling) that might follow the source command
        local extra_options=""
        if [[ "${line_content}" =~ source[[:space:]]*[\"\']*[^[:space:]\"\']*${old_lib}[^[:space:]\"\']*[\"\']*[[:space:]]*(.*)$ ]]; then
            extra_options="${BASH_REMATCH[1]}"
            # Remove trailing quotes from extra_options if they exist
            extra_options="${extra_options%\"}"
            extra_options="${extra_options%\'}"
        fi
        
        # Create the replacement line with the correct structure
        local new_line="source \"\${PROJECT_ROOT}/${actual_new_lib}\""
        
        # Add back any extra options if they exist
        if [[ -n "${extra_options}" ]]; then
            new_line="${new_line} ${extra_options}"
        fi
        
        # Create a new temp file with the changes
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS requires different sed syntax - use a different delimiter to avoid issues
            sed -i '' "${source_line}s#.*#${new_line}#" "${temp_file}" 2>/dev/null || {
                # If sed fails, try a manual approach
                head -n $((source_line-1)) "${file}" > "${temp_file}"
                echo "${new_line}" >> "${temp_file}"
                tail -n +$((source_line+1)) "${file}" >> "${temp_file}"
            }
        else
            # Linux sed - use a different delimiter to avoid issues
            sed -i "${source_line}s#.*#${new_line}#" "${temp_file}" 2>/dev/null || {
                # If sed fails, try a manual approach
                head -n $((source_line-1)) "${file}" > "${temp_file}.new"
                echo "${new_line}" >> "${temp_file}.new"
                tail -n +$((source_line+1)) "${file}" >> "${temp_file}.new"
                mv "${temp_file}.new" "${temp_file}"
            }
        fi
    else
        echo "  - Could not find source line, skipping"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Check if any changes were made
    if cmp -s "${file}" "${temp_file}"; then
        echo "  - No changes needed"
        rm -f "${temp_file}"
        return 0
    fi
    
    # Show a diff of the changes
    echo "  - Changes to be made:"
    diff -u "${file}" "${temp_file}" | grep -v "^---" | grep -v "^+++" | grep "^[+-]" | head -5
    
    if [[ "${dry_run}" == "true" ]]; then
        echo "  - [DRY RUN] Would update: ${file}"
        rm -f "${temp_file}"
        return 0
    fi
    
    if [[ "${force}" == "true" ]]; then
        mv "${temp_file}" "${file}"
        echo "  - Updated: ${file}"
    else
        read -p "  - Update this file? (y/n): " confirm
        if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
            mv "${temp_file}" "${file}"
            echo "  - Updated: ${file}"
        else
            echo "  - Skipped"
            rm -f "${temp_file}"
        fi
    fi
    
    return 0
}

# Function to add deprecation notice to scripts that can't be updated yet
add_deprecation_notice() {
    local file="$1"
    local old_lib="$2"
    local dry_run="$3"
    local force="$4"
    
    echo "Adding deprecation notice to: $(basename "$file")"
    
    # Create a temporary file for edits
    local temp_file=$(mktemp)
    
    # Find the line that sources the old library
    local source_line=$(grep -n "source.*${old_lib}" "${file}" | head -1 | cut -d ':' -f1)
    
    if [[ -z "${source_line}" ]]; then
        echo "  - Could not find source line, skipping"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Create the content with deprecation notice
    {
        head -n "${source_line}" "${file}"
        echo ""
        echo "# DEPRECATION WARNING: This script uses a deprecated library (${old_lib})."
        echo "# It should be updated to use scripts/lib/common_consolidated.sh in the future."
        echo "# See: https://github.com/your-org/ansible-ephemery/blob/master/docs/LIBRARY_MIGRATION.md"
        echo ""
        tail -n "+$((source_line + 1))" "${file}"
    } > "${temp_file}"
    
    # Check if any changes were made
    if cmp -s "${file}" "${temp_file}"; then
        echo "  - No changes needed"
        rm -f "${temp_file}"
        return 0
    fi
    
    # Show a diff of the changes
    echo "  - Changes to be made:"
    diff -u "${file}" "${temp_file}" | grep -v "^---" | grep -v "^+++" | grep "^[+-]" | head -10
    
    if [[ "${dry_run}" == "true" ]]; then
        echo "  - [DRY RUN] Would update: ${file}"
        rm -f "${temp_file}"
        return 0
    fi
    
    if [[ "${force}" == "true" ]]; then
        mv "${temp_file}" "${file}"
        echo "  - Updated: ${file}"
    else
        read -p "  - Add deprecation notice? (y/n): " confirm
        if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
            mv "${temp_file}" "${file}"
            echo "  - Updated: ${file}"
        else
            echo "  - Skipped"
            rm -f "${temp_file}"
        fi
    fi
    
    return 0
}

# Parse command line options
DRY_RUN=false
FORCE=false
USE_BASIC_LIB=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -b|--basic)
            USE_BASIC_LIB=true
            shift
            ;;
        -h|--help)
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
echo "Scanning for scripts with deprecated library references..."
echo

# Process each old library
for old_lib in "${OLD_LIBS[@]}"; do
    echo "Looking for references to ${old_lib}..."
    
    # Find files sourcing this library
    FILES=$(find_files_sourcing_library "${old_lib}")
    
    if [[ -z "${FILES}" ]]; then
        echo "  No files found sourcing ${old_lib}"
        echo
        continue
    fi
    
    # Process each file
    for file in ${FILES}; do
        # Skip the library files themselves
        if [[ "${file}" == *"/lib/"* || "${file}" == *"common_consolidated.sh"* ]]; then
            continue
        fi
        
        # For scripts in maintenance directory, prefer direct updates
        if [[ "${file}" == *"/maintenance/"* ]]; then
            update_library_reference "${file}" "${old_lib}" "${NEW_LIB}" "${DRY_RUN}" "${FORCE}" "${USE_BASIC_LIB}"
        # For recently updated scripts (after date cutoff), prefer direct updates
        elif [[ $(stat -f %m "${file}" 2>/dev/null || stat -c %Y "${file}") -gt $(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s) ]]; then
            update_library_reference "${file}" "${old_lib}" "${NEW_LIB}" "${DRY_RUN}" "${FORCE}" "${USE_BASIC_LIB}"
        # For more complex scripts, add a deprecation notice for now
        else
            add_deprecation_notice "${file}" "${old_lib}" "${DRY_RUN}" "${FORCE}"
        fi
        echo
    done
done

echo "Process completed."

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "This was a dry run. No files were actually updated."
fi

echo
echo "Note: You should manually review all updated files to ensure they work correctly."
echo "Some scripts may require additional changes to function with the consolidated library." 