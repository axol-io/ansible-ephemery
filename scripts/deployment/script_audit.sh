#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: script_audit.sh
# Description: Audits scripts for common patterns and duplication
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./script_audit.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -d, --directory  Directory to audit (default: ../scripts)
#   -v, --verbose    Enable verbose output

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
DIRECTORY_TO_AUDIT="${SCRIPT_DIR}/.."
VERBOSE=false
SCRIPT_NAME=$(basename "$0")

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Display this help message"
            echo "  -d, --directory  Directory to audit (default: ../scripts)"
            echo "  -v, --verbose    Enable verbose output"
            exit 0
            ;;
        -d|--directory)
            DIRECTORY_TO_AUDIT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Print banner
print_banner "Ephemery Script Audit"

# Function to analyze script
analyze_script() {
    local script_path="$1"
    local issues=0
    
    log_info "Analyzing $script_path"
    
    # Skip self-check for color definitions
    local is_self=false
    if [[ "$(basename "$script_path")" == "${SCRIPT_NAME}" ]]; then
        is_self=true
    fi
    
    # Check if script uses common library
    if ! grep -q "source.*lib/common.sh" "$script_path"; then
        log_warn "$script_path does not use common library"
        ((issues++))
    fi
    
    # Check for color definitions that could be replaced
    if [[ "$is_self" == "false" ]] && grep -q "^[[:space:]]*[A-Z]\+=[\'\"]\\\033\[[0-9];[0-9]\+m[\'\"]\|NC=" "$script_path"; then
        log_warn "$script_path has color definitions that should be replaced with common library"
        ((issues++))
    fi
    
    # Check for common utility functions that could be replaced
    # Only look for function definitions, not function calls
    local common_patterns=(
        "log_info" "log_error" "log_warn" "log_debug"
        "print_banner" "confirm_action"
        "check_dependencies" "is_command_available"
    )
    
    for pattern in "${common_patterns[@]}"; do
        if grep -q "^[[:space:]]*\(function \)\?${pattern}[[:space:]]*()[[:space:]]*{" "$script_path"; then
            log_warn "$script_path defines '$pattern' which is available in common library"
            ((issues++))
        fi
    done
    
    # Check for shellcheck directives that might indicate problematic code
    if grep -q "shellcheck disable=SC[0-9]\+" "$script_path"; then
        log_warn "$script_path has shellcheck disabling directives which might indicate code that needs refactoring"
        ((issues++))
    fi
    
    if [[ "$issues" -eq 0 ]]; then
        log_success "$script_path looks good!"
    fi
    
    return "$issues"
}

# Main function to run the audit
run_audit() {
    log_info "Starting audit of scripts in $DIRECTORY_TO_AUDIT"
    
    local total_scripts=0
    local scripts_with_issues=0
    local script_issues=()
    
    # Find all shell scripts
    while IFS= read -r script; do
        local issues=0
        ((total_scripts++))
        
        if ! analyze_script "$script"; then
            issues=$?
            ((scripts_with_issues++))
            script_issues+=("$script:$issues")
        fi
        
        echo ""
    done < <(find "$DIRECTORY_TO_AUDIT" -name "*.sh" -type f)
    
    # Generate summary
    echo -e "\n=== Audit Summary ===\n"
    echo "Total scripts: $total_scripts"
    echo "Scripts with issues: $scripts_with_issues"
    
    if [[ ${#script_issues[@]} -gt 0 ]]; then
        echo -e "\nScripts with the most issues:"
        for script_issue in $(echo "${script_issues[@]}" | tr ' ' '\n' | sort -t: -k2 -nr | head -5); do
            IFS=":" read -r script issue_count <<< "$script_issue"
            echo "  $script - $issue_count issues"
        done
    fi
    
    echo -e "\n======================\n"
}

# Run the audit
run_audit 