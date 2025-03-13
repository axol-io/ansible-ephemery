# Common Script Library

This directory contains common utility functions and libraries that can be shared across all Ephemery scripts.

## Usage

To use this library in your scripts, add the following at the beginning of your script:

```bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common library
source "${SCRIPT_DIR}/../utilities/lib/common.sh"

# Now you can use the common functions
print_banner "My Script Title"
log_message "INFO" "Starting script execution"
```

## Available Functions

- `print_banner "message"` - Print a formatted header banner
- `log_message "level" "message"` - Log a message with timestamp and level (INFO, WARN, ERROR)
- `check_command "command"` - Check if a required command exists
- `run_command "command" ["error_message"]` - Run a command with error handling
- `is_ephemery_environment` - Check if running in an Ephemery environment
- `check_ansible` - Check if ansible is installed
- `get_inventory_value "key" ["default"]` - Get a value from inventory.yaml
- `is_service_running "service"` - Check if a service is running
- `confirm_action ["message"]` - Prompt user for confirmation

## Environment Variables

- `EPHEMERY_BASE_DIR` - Base directory of the Ephemery installation
