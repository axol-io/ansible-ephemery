#!/bin/bash

# cleanup_duplicates.sh - Script to clean up duplicate directories and files in the repository
# This script helps implement the consolidation recommendations

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Import common functions if they exist
if [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
    source "${PROJECT_ROOT}/scripts/lib/common.sh"
elif [[ -f "${PROJECT_ROOT}/scripts/utilities/common_functions.sh" ]]; then
source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"
fi

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to verify directories are identical
verify_identical_dirs() {
    local dir1=$1
    local dir2=$2
    
    if ! diff -rq "$dir1" "$dir2" > /dev/null; then
        print_status "$YELLOW" "WARNING: Directories are not identical. Manual review recommended."
        return 1
    fi
    
    return 0
}

# Function to check if it's safe to remove a directory
check_safe_to_remove() {
    local dir=$1
    
    # Check if any files in the directory have been modified in the last 7 days
    if find "$dir" -type f -mtime -7 | grep -q .; then
        print_status "$YELLOW" "WARNING: Directory contains recently modified files (last 7 days)."
        return 1
    fi
    
    return 0
}

# Main function to clean up duplicate directories
cleanup_duplicates() {
    print_status "$GREEN" "Starting cleanup of duplicate directories..."
    
    # Handle utils_backup directory which is a direct duplicate of utils
    if [[ -d "${PROJECT_ROOT}/scripts/utils_backup" ]]; then
        print_status "$GREEN" "Checking if utils_backup is identical to utils..."
        
        if verify_identical_dirs "${PROJECT_ROOT}/scripts/utils" "${PROJECT_ROOT}/scripts/utils_backup"; then
            if check_safe_to_remove "${PROJECT_ROOT}/scripts/utils_backup"; then
                print_status "$GREEN" "Utils_backup appears to be a direct duplicate and safe to remove."
                read -p "Do you want to remove the utils_backup directory? (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    rm -rf "${PROJECT_ROOT}/scripts/utils_backup"
                    print_status "$GREEN" "Successfully removed utils_backup directory."
                else
                    print_status "$YELLOW" "Skipped removal of utils_backup directory."
                fi
            else
                print_status "$YELLOW" "utils_backup contains recently modified files. Manual review recommended."
            fi
        else
            print_status "$YELLOW" "utils and utils_backup are not identical. Please review manually."
        fi
    else
        print_status "$YELLOW" "utils_backup directory not found. It may have been already removed."
    fi
    
    # Check for duplicate template directories
    if [[ -d "${PROJECT_ROOT}/templates" && -d "${PROJECT_ROOT}/ansible/templates" ]]; then
        print_status "$GREEN" "Found templates in both root and ansible directories."
        print_status "$YELLOW" "Manual consolidation recommended. Use the following steps:"
        echo "1. Compare the contents of both template directories"
        echo "2. Move unique templates from /templates to /ansible/templates"
        echo "3. Remove the /templates directory once consolidated"
    fi
    
    # Check for duplicate common library files
    if [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" && -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
        print_status "$GREEN" "Found multiple common library files."
        echo "common.sh: $(wc -l < "${PROJECT_ROOT}/scripts/lib/common.sh") lines"
        echo "common_consolidated.sh: $(wc -l < "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh") lines"
        print_status "$YELLOW" "Manual consolidation recommended. Check the consolidation document for details."
    fi
    
    print_status "$GREEN" "Duplicate cleanup check completed."
}

# Run the main function
cleanup_duplicates

exit 0 