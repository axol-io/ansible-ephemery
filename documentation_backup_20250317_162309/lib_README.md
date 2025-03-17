# Shared Library

This directory contains common utility functions and libraries that can be shared across all Ephemery scripts.

## Usage

To use these libraries in your scripts, add the following at the beginning of your script:

```bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
```

## Script Standardization Guidelines

### Script Header

All scripts should include a standardized header with the following information:

```bash
#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: example_script.sh
# Description: Brief description of the script purpose
# Author: Your Name
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD
#
# Usage: ./example_script.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -v, --verbose    Enable verbose output
```

### Script Structure

Follow this structure for consistent script organization:

1. Header with documentation and version
2. Script directory and path definitions
3. Source the common library
4. Define constants and default variables
5. Function declarations
6. Command-line argument parsing
7. Main execution

### Error Handling

Always include proper error handling:

```bash
# Enable strict mode
set -euo pipefail

# Use error handling from common library
trap 'handle_error $? $LINENO' ERR
```

### Path Management

For relative paths, use the following approach:

```bash
# For scripts in the main scripts directory
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# For scripts in subdirectories (e.g., monitoring)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# For deeply nested scripts, adjust as needed
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
```

## Standardization Tool

The standardization tool (`scripts/tools/standardize_scripts.sh`) helps ensure all scripts follow the standardized format.

### Usage

```bash
# Standardize a single script
scripts/tools/standardize_scripts.sh -s path/to/script.sh

# Standardize all scripts in a directory
scripts/tools/standardize_scripts.sh -d scripts/monitoring

# Force standardization without confirmation
scripts/tools/standardize_scripts.sh -d scripts/monitoring -f

# Dry run to see what would be changed
scripts/tools/standardize_scripts.sh -d scripts/monitoring -n
```

### Features

The standardization tool:

1. Adds common library import if missing
2. Removes redundant color definitions (use common library instead)
3. Ensures correct relative path calculation to project root
4. Makes scripts executable
5. Creates backups before making changes

### Options

- `-h, --help` - Display help information
- `-d, --directory` - Process all scripts in specified directory
- `-s, --script` - Process a specific script
- `-f, --force` - Force overwrite without confirmation
- `-v, --verbose` - Enable verbose output
- `-n, --dry-run` - Run without making changes

## Available Functions

### Common Functions

- `print_banner "message"` - Print a formatted header banner
- `log_info "message"` - Log an information message
- `log_warn "message"` - Log a warning message
- `log_error "message"` - Log an error message
- `log_debug "message"` - Log a debug message
- `log_success "message"` - Log a success message
- `confirm_action ["message"]` - Prompt user for confirmation
- `is_command_available "command"` - Check if a command is available
- `check_dependencies "cmd1" "cmd2" ...` - Check if required commands exist
- `get_script_name` - Get the name of the current script
- `get_absolute_path "path"` - Convert a relative path to absolute
- `is_ephemery_environment` - Check if running in an Ephemery environment
- `check_ansible` - Check if ansible is installed
- `get_inventory_value "key" ["default"]` - Get a value from inventory.yaml

## Environment Variables

- `EPHEMERY_BASE_DIR` - Base directory of the Ephemery installation
- `EPHEMERY_SCRIPTS_DIR` - Directory containing scripts
- `EPHEMERY_DATA_DIR` - Directory for storing data
- `EPHEMERY_CONFIG_DIR` - Directory for configuration files
- `EPHEMERY_LOGS_DIR` - Directory for log files

## Example

```bash
#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: Example Script
# Description: Example script using the common library
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Print a banner
print_banner "Example Script"

# Check for dependencies
check_dependencies "ansible" "jq" || exit 1

# Log some messages
log_info "Starting script"
log_debug "This is a debug message"

# Main logic
if is_ephemery_environment; then
    log_success "Found Ephemery environment"
else
    log_error "Not in an Ephemery environment"
    exit 1
fi

# Get configuration
validator_count=$(get_inventory_value "validator_count" "0")
log_info "Found ${validator_count} validators"

# Exit successfully
log_success "Script completed"
exit 0
``` 