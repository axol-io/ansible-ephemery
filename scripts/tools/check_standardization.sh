#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: check_standardization.sh
# Description: Checks if all shell scripts follow standardization guidelines
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./check_standardization.sh [options]
#
# Options:
#   -h, --help     Display this help message
#   -v, --verbose  Enable verbose output
#   -q, --quiet    Suppress all output except errors and final result
#   -c, --ci       Run in CI mode (exit with non-zero if any failures found)

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
VERBOSE=false
QUIET=false
CI_MODE=false
TOTAL_SCRIPTS=0
NON_COMPLIANT=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help     Display this help message"
            echo "  -v, --verbose  Enable verbose output"
            echo "  -q, --quiet    Suppress all output except errors and final result"
            echo "  -c, --ci       Run in CI mode (exit with non-zero if any failures found)"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -c|--ci)
            CI_MODE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Print banner if not in quiet mode
if [[ "$QUIET" == "false" ]]; then
    print_banner "Script Standardization Check"
fi

# Function to check if a script is compliant with standardization guidelines
check_script_compliance() {
    local script_path="$1"
    local issues=0
    
    # Skip if not a shell script
    if ! grep -q "^#!/.*sh" "$script_path"; then
        [[ "$VERBOSE" == "true" ]] && log_warn "$script_path does not appear to be a shell script, skipping"
        return 0
    fi
    
    # 1. Check if script has common library imported
    if [[ "$script_path" != *"/scripts/lib/common.sh" ]] && ! grep -q "source.*scripts/lib/common.sh" "$script_path"; then
        [[ "$QUIET" == "false" ]] && log_error "$script_path: Missing common library import"
        issues=$((issues + 1))
    fi
    
    # 2. Check if script has SCRIPT_DIR defined
    if ! grep -q "SCRIPT_DIR=.*dirname.*BASH_SOURCE" "$script_path"; then
        [[ "$QUIET" == "false" ]] && log_error "$script_path: Missing SCRIPT_DIR definition"
        issues=$((issues + 1))
    fi
    
    # 3. Check if script has PROJECT_ROOT defined
    if ! grep -q "PROJECT_ROOT=" "$script_path"; then
        [[ "$QUIET" == "false" ]] && log_error "$script_path: Missing PROJECT_ROOT definition"
        issues=$((issues + 1))
    fi
    
    # 4. Check if script contains redundant color definitions
    if grep -q "^[[:space:]]*[A-Z]\+=['\"]\\\\033\[[0-9];[0-9]\+m['\"]" "$script_path"; then
        [[ "$QUIET" == "false" ]] && log_error "$script_path: Contains redundant color definitions"
        issues=$((issues + 1))
    fi
    
    # 5. Check if script has version information
    if ! grep -q "# Version: [0-9]" "$script_path"; then
        [[ "$QUIET" == "false" ]] && log_error "$script_path: Missing version information"
        issues=$((issues + 1))
    fi
    
    # Report result
    if [[ $issues -eq 0 ]]; then
        [[ "$VERBOSE" == "true" ]] && log_success "$script_path: Compliant with standardization guidelines"
        return 0
    else
        return 1
    fi
}

# Find all shell scripts in the repository
find_shell_scripts() {
    find "${PROJECT_ROOT}/scripts" -name "*.sh" -type f | grep -v "\.bak$" | sort
}

# Main function
main() {
    [[ "$QUIET" == "false" ]] && log_info "Starting standardization compliance check"
    
    # Get list of scripts to check
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(find_shell_scripts)
    TOTAL_SCRIPTS=${#scripts[@]}
    
    [[ "$QUIET" == "false" ]] && log_info "Found $TOTAL_SCRIPTS scripts to check"
    
    # Check each script
    for script in "${scripts[@]}"; do
        if ! check_script_compliance "$script"; then
            NON_COMPLIANT=$((NON_COMPLIANT + 1))
        fi
    done
    
    # Print summary
    [[ "$QUIET" == "false" ]] && echo ""
    if [[ $NON_COMPLIANT -eq 0 ]]; then
        log_success "All scripts ($TOTAL_SCRIPTS) comply with standardization guidelines"
        exit 0
    else
        log_error "$NON_COMPLIANT out of $TOTAL_SCRIPTS scripts do not comply with standardization guidelines"
        if [[ "$CI_MODE" == "true" ]]; then
            exit 1
        else
            exit 0
        fi
    fi
}

# Run main function
main 