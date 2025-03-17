# Ephemery Script Templates

This directory contains templates for creating new scripts that follow Ephemery conventions and best practices.

## Available Templates

- `script_template.sh` - Basic template for creating new scripts

## Using Templates

To use a template:

1. Copy the template to the appropriate category directory
2. Rename the file to match your script's purpose
3. Replace placeholder values (in ALL_CAPS) with your specific values
4. Implement your script-specific logic
5. Test your script

Example:

```bash
# Copy the template to the desired category directory
cp scripts/development/templates/script_template.sh scripts/maintenance/cleanup_logs.sh

# Edit the script with your favorite editor
vim scripts/maintenance/cleanup_logs.sh
```

## Placeholder Values

The templates contain placeholder values that you should replace:

- `SCRIPT_NAME` - The name of your script (e.g., cleanup_logs.sh)
- `SCRIPT_DESCRIPTION` - A brief description of what your script does
- `AUTHOR_NAME` - Your name or the team name
- `CREATION_DATE` - The date the script was created (YYYY-MM-DD format)
- `LAST_MODIFIED_DATE` - The date the script was last modified (YYYY-MM-DD format)
- `SCRIPT_TITLE` - The title to display in the banner
- `DEPENDENCY1`, `DEPENDENCY2` - The dependencies required by your script
- `ADDITIONAL_DEPENDENCIES` - List additional dependencies
- `YOUR SCRIPT LOGIC HERE` - Replace with your actual script logic

## Best Practices

When creating scripts, follow these best practices:

1. Use the common library for standardized functionality
2. Implement proper error handling and exit codes
3. Use verbose mode for debugging information
4. Check for required dependencies
5. Document usage, options, and dependencies
6. Follow shellcheck recommendations
7. Test your script thoroughly

## Example Script Using Template

```bash
#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: cleanup_logs.sh
# Description: Cleans up old log files to free disk space
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./cleanup_logs.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -v, --verbose    Enable verbose output
#   -d, --days DAYS  Delete logs older than DAYS days (default: 30)
#
# Dependencies:
#   - bash
#   - find

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
VERBOSE=false
DAYS=30

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Display this help message"
            echo "  -v, --verbose    Enable verbose output"
            echo "  -d, --days DAYS  Delete logs older than DAYS days (default: 30)"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Print banner
print_banner "Log Cleanup Utility"

# Main function
main() {
    log_info "Starting cleanup_logs.sh"
    
    # Check dependencies
    if ! check_dependencies "find"; then
        log_error "Missing required dependencies"
        exit 1
    fi
    
    # Check for valid DAYS value
    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        log_error "DAYS must be a positive integer"
        exit 1
    fi
    
    log_info "Cleaning up log files older than $DAYS days"
    
    # Clean up logs
    local count=0
    while IFS= read -r log_file; do
        if [[ "$VERBOSE" == "true" ]]; then
            log_debug "Removing: $log_file"
        fi
        rm -f "$log_file"
        ((count++))
    done < <(find "${EPHEMERY_LOGS_DIR}" -name "*.log" -type f -mtime +"$DAYS")
    
    log_success "Removed $count log files successfully!"
}

# Run the main function
main
