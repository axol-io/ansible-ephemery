#!/bin/bash
#
# Script to complete the organization of scripts directory according to the PRD roadmap
# This implements the "Scripts Directory Consolidation" high-priority task from the roadmap

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}    Ephemery Script Organization - Phase 2${NC}"
echo -e "${BLUE}    Implementing Roadmap Priorities${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Define directories and their descriptions using simple variables instead of associative arrays
CORE_DESC="Core ephemery functionality scripts"
DEPLOYMENT_DESC="Scripts for deploying ephemery nodes"
MONITORING_DESC="Monitoring and alerting scripts"
MAINTENANCE_DESC="Scripts for maintenance tasks"
UTILITIES_DESC="Helper utilities and shared functions"
DEVELOPMENT_DESC="Scripts for development environment setup and testing"

# Check for remaining loose scripts
echo -e "\n${GREEN}Checking for remaining loose scripts in the scripts directory...${NC}"
loose_scripts=$(find . -maxdepth 1 -type f -name "*.sh" | grep -v "complete_script_organization.sh" | grep -v "organize_scripts.sh")

if [ -n "$loose_scripts" ]; then
    echo -e "${YELLOW}Found $(echo "$loose_scripts" | wc -l | tr -d ' ') loose scripts that need organization:${NC}"
    echo "$loose_scripts"
else
    echo -e "${GREEN}No loose scripts found! Basic organization is complete.${NC}"
fi

# Function to analyze scripts and provide categorization suggestions
analyze_scripts() {
    echo -e "\n${GREEN}Analyzing loose scripts and suggesting categorization...${NC}"

    for script in $loose_scripts; do
        script_name=$(basename "$script")
        content=$(head -n 20 "$script")

        echo -e "${YELLOW}Script: $script_name${NC}"

        # Extract script description
        description=$(grep -m 1 "^#" "$script" | sed 's/^#//' | sed 's/^ *//')
        if [ -z "$description" ]; then
            description="No description found"
        fi
        echo -e "  Description: $description"

        # Suggest category based on filename and content
        suggested_category="utilities" # Default category

        if [[ "$script_name" == *deploy* || "$script_name" == *setup* || "$script_name" == *install* ]]; then
            suggested_category="deployment"
        elif [[ "$script_name" == *monitor* || "$script_name" == *check* || "$script_name" == *status* ]]; then
            suggested_category="monitoring"
        elif [[ "$script_name" == *fix* || "$script_name" == *reset* || "$script_name" == *troubleshoot* ]]; then
            suggested_category="maintenance"
        elif [[ "$script_name" == *dev* || "$script_name" == *test* || "$script_name" == *standard* ]]; then
            suggested_category="development"
        elif [[ "$script_name" == *ephemery* || "$script_name" == *validator* ]]; then
            suggested_category="core"
        fi

        echo -e "  Suggested category: ${BLUE}$suggested_category${NC}"
        echo ""
    done
}

# Step 1: Manually organize scripts
organize_scripts_manually() {
    echo -e "\n${GREEN}Manual script organization...${NC}"

    echo -e "${YELLOW}Please use the following guidelines to organize scripts:${NC}"
    echo -e "- core/: Core ephemery functionality scripts (ephemery_*.sh, validator core functionality)"
    echo -e "- deployment/: Scripts for deploying ephemery nodes (deploy-*.sh, setup-*.sh)"
    echo -e "- monitoring/: Monitoring and alerting scripts (check_*.sh, *_monitor.sh)"
    echo -e "- maintenance/: Scripts for maintenance tasks (fix_*.sh, reset_*.sh, troubleshoot-*.sh)"
    echo -e "- utilities/: Helper utilities and shared functions (common tools, key management)"
    echo -e "- development/: Scripts for development environment setup and testing (dev-*.sh, test-*.sh)"

    echo -e "\n${GREEN}Suggested actions for loose scripts:${NC}"

    for script in $loose_scripts; do
        script_name=$(basename "$script")

        # Suggest category based on filename
        target_dir="utilities" # Default category

        if [[ "$script_name" == *deploy* || "$script_name" == *setup* || "$script_name" == *install* ]]; then
            target_dir="deployment"
        elif [[ "$script_name" == *monitor* || "$script_name" == *check* || "$script_name" == *status* ]]; then
            target_dir="monitoring"
        elif [[ "$script_name" == *fix* || "$script_name" == *reset* || "$script_name" == *troubleshoot* ]]; then
            target_dir="maintenance"
        elif [[ "$script_name" == *dev* || "$script_name" == *test* || "$script_name" == *standard* ]]; then
            target_dir="development"
        elif [[ "$script_name" == *ephemery* || "$script_name" == *validator* ]]; then
            target_dir="core"
        fi

        echo -e "${YELLOW}Move $script_name to $target_dir/${NC}"

        # Create directory if it doesn't exist
        mkdir -p "$target_dir"

        # Ask whether to move the script
        echo -e "${GREEN}Move $script_name to $target_dir/? (y/n)${NC}"
        read -r answer

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            # Create backup
            mkdir -p "script_backups"
            cp "$script" "script_backups/"

            # Move the script
            mv "$script" "$target_dir/"
            echo -e "${GREEN}Moved $script_name to $target_dir/${NC}"
        else
            echo -e "${YELLOW}Skipped $script_name${NC}"
        fi
    done
}

# Step 2: Create a shared library for common functions
create_shared_library() {
    echo -e "\n${GREEN}Creating shared library for common functions...${NC}"

    common_lib_dir="utilities/lib"
    mkdir -p "$common_lib_dir"

    # Create the common library file
    cat > "$common_lib_dir/common.sh" << 'EOF'
#!/bin/bash
#
# Common utility functions for Ephemery scripts
# This file should be sourced by other scripts

# Set default environment variables
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)}"

# Define color codes for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Print a formatted header banner
print_banner() {
    local message="$1"
    local length=${#message}
    local padding=$((length + 10))

    echo -e "${BLUE}"
    printf '=%.0s' $(seq 1 $padding)
    echo -e "\n    $message    \n"
    printf '=%.0s' $(seq 1 $padding)
    echo -e "${NC}\n"
}

# Log a message with timestamp and log level
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${GREEN}[$timestamp] [INFO] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}"
            ;;
        *)
            echo -e "[$timestamp] [$level] $message"
            ;;
    esac
}

# Check if required command exists
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_message "ERROR" "Required command '$cmd' not found"
        return 1
    fi
    return 0
}

# Run command with proper error handling
run_command() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"

    log_message "INFO" "Running: $cmd"
    if ! eval "$cmd"; then
        log_message "ERROR" "$error_msg"
        return 1
    fi
    return 0
}

# Check if we're running in an Ephemery environment
is_ephemery_environment() {
    if [[ -f "$EPHEMERY_BASE_DIR/inventory.yaml" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if ansible is installed
check_ansible() {
    if ! check_command "ansible" || ! check_command "ansible-playbook"; then
        log_message "ERROR" "Ansible not found. Please install ansible first."
        return 1
    fi
    return 0
}

# Read a configuration value from inventory.yaml
get_inventory_value() {
    local key="$1"
    local default="${2:-}"

    if [[ ! -f "$EPHEMERY_BASE_DIR/inventory.yaml" ]]; then
        echo "$default"
        return
    fi

    # Try to extract the value using grep and sed
    local value=$(grep -E "^[[:space:]]*$key:" "$EPHEMERY_BASE_DIR/inventory.yaml" | sed -E "s/^[[:space:]]*$key:[[:space:]]*(.*)/\1/")

    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Check if a service is running
is_service_running() {
    local service="$1"
    if ! systemctl is-active --quiet "$service"; then
        return 1
    fi
    return 0
}

# Prompt user for confirmation
confirm_action() {
    local message="${1:-Are you sure you want to continue?}"

    echo -e "${YELLOW}$message (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}
EOF

    chmod +x "$common_lib_dir/common.sh"
    echo -e "${GREEN}Created common library at $common_lib_dir/common.sh${NC}"

    # Create a README for the common library
    cat > "$common_lib_dir/README.md" << 'EOF'
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
EOF

    echo -e "${GREEN}Created README for common library${NC}"
}

# Step 3: Update README files for each script directory
update_readmes() {
    echo -e "\n${GREEN}Updating README files for script directories...${NC}"

    # Process each directory
    for dir in core deployment monitoring maintenance utilities development; do
        if [ -d "$dir" ]; then
            readme_file="$dir/README.md"

            # Get a list of scripts in the directory
            scripts=$(find "$dir" -maxdepth 1 -type f -name "*.sh" | sort)

            echo -e "${YELLOW}Updating README for $dir directory...${NC}"

            # Get directory description
            dir_desc=""
            case "$dir" in
                "core") dir_desc="$CORE_DESC" ;;
                "deployment") dir_desc="$DEPLOYMENT_DESC" ;;
                "monitoring") dir_desc="$MONITORING_DESC" ;;
                "maintenance") dir_desc="$MAINTENANCE_DESC" ;;
                "utilities") dir_desc="$UTILITIES_DESC" ;;
                "development") dir_desc="$DEVELOPMENT_DESC" ;;
            esac

            # Create or update the README file
            cat > "$readme_file" << EOF
# ${dir^} Scripts

$dir_desc

## Scripts

EOF

            # Add script descriptions
            for script in $scripts; do
                script_name=$(basename "$script")
                description=$(grep -m 1 "^#" "$script" | sed 's/^#//' | sed 's/^ *//')
                if [ -z "$description" ]; then
                    description="No description found"
                fi
                echo "- \`$script_name\`: $description" >> "$readme_file"
            done

            # Add usage section
            cat >> "$readme_file" << EOF

## Usage

Please refer to the individual script comments or the main project documentation for usage information.
EOF

            echo -e "${GREEN}Updated $readme_file${NC}"
        fi
    done
}

# Step 4: Create standardization template for script development
create_script_template() {
    echo -e "\n${GREEN}Creating standardized script template...${NC}"

    mkdir -p "development/templates"
    template_file="development/templates/script_template.sh"

    cat > "$template_file" << 'EOF'
#!/bin/bash
#
# [SCRIPT PURPOSE]: Brief description of what this script does
#
# Usage: ./script_name.sh [options]
#
# Options:
#   -h, --help     Display this help message
#   -v, --verbose  Enable verbose output
#
# Author: [AUTHOR NAME]
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common library
source "${SCRIPT_DIR}/../../utilities/lib/common.sh"

# Default configuration
VERBOSE=false
CONFIG_FILE="${EPHEMERY_BASE_DIR}/inventory.yaml"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help     Display this help message"
            echo "  -v, --verbose  Enable verbose output"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_message "ERROR" "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Print banner
print_banner "[SCRIPT TITLE]"

# Check prerequisites
check_ansible || exit 1
is_ephemery_environment || {
    log_message "ERROR" "Not in an Ephemery environment"
    exit 1
}

# Main function
main() {
    log_message "INFO" "Starting script execution"

    # TODO: Implement script logic here

    log_message "INFO" "Script completed successfully"
}

# Run the main function
main
EOF

    chmod +x "$template_file"
    echo -e "${GREEN}Created standardized script template at $template_file${NC}"

    # Create a README for the template
    cat > "development/templates/README.md" << 'EOF'
# Script Templates

This directory contains standardized templates for creating new scripts in the Ephemery project.

## Templates

- `script_template.sh`: Standard template for new bash scripts

## Usage

To create a new script using the template:

1. Copy the template to your target directory:
   ```bash
   cp development/templates/script_template.sh my_new_script.sh
   ```

2. Modify the script header to include your script's purpose, usage, and author information.

3. Implement your script logic in the main function.

4. Make sure your script follows the project's coding standards and includes proper error handling.

## Script Structure

All scripts should follow this general structure:

1. Shebang and header comments
2. Script usage and author information
3. Environment setup and error handling
4. Common library sourcing
5. Command-line argument parsing
6. Main function declaration
7. Helper function declarations
8. Main function execution

## Coding Standards

- Use the common library functions for consistency
- Include proper error handling
- Validate all inputs and prerequisites
- Use meaningful variable and function names
- Add comments for complex operations
- Follow the principle of least privilege
EOF

    echo -e "${GREEN}Created README for templates directory${NC}"
}

# Step 5: Update main scripts README
update_main_readme() {
    echo -e "\n${GREEN}Updating main scripts README...${NC}"

    readme_file="README.md"

    cat > "$readme_file" << 'EOF'
# Ephemery Scripts

This directory contains scripts for deploying, managing, and maintaining Ephemery nodes.

## Directory Structure

The scripts are organized into the following categories:

- **core/**: Core ephemery functionality scripts
- **deployment/**: Scripts for deploying ephemery nodes
- **monitoring/**: Monitoring and alerting scripts
- **maintenance/**: Scripts for maintenance tasks
- **utilities/**: Helper utilities and shared functions
- **development/**: Scripts for development environment setup and testing

## Common Library

A shared library of common functions is provided in `utilities/lib/common.sh`. All scripts should use this library to ensure consistency in logging, error handling, and user interaction.

## Script Development

When creating new scripts, please use the templates provided in `development/templates/` and follow the project's coding standards. All scripts should:

1. Include a clear purpose in the header comment
2. Use the common library for consistency
3. Include proper error handling
4. Follow the standard directory structure
5. Be well-documented

## Example Usage

Most scripts include a help option that can be accessed with `-h` or `--help`:

```bash
./deployment/deploy-ephemery.sh --help
```

For more detailed information about specific scripts, please refer to the README files in each directory.

## Script Inventory

For a complete list of all available scripts and their purposes, see the README files in each subdirectory.
EOF

    echo -e "${GREEN}Updated main README at $readme_file${NC}"
}

# Main execution flow
analyze_scripts
organize_scripts_manually
create_shared_library
update_readmes
create_script_template
update_main_readme

echo -e "\n${GREEN}Script organization and standardization complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review all scripts to ensure they're properly categorized"
echo -e "2. Update any scripts that need to use the common library"
echo -e "3. Update the main project documentation to reference the new script structure"
echo -e "4. Consider creating a migration guide for users of the old script structure"
echo -e "\n${BLUE}Thank you for implementing the roadmap priorities!${NC}"
