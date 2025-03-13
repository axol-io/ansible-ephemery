#!/bin/bash
#
# Common utility functions for Ephemery scripts
# This file should be sourced by other scripts

# Load standardized paths configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading configuration from $CONFIG_FILE"
  source "$CONFIG_FILE"
else
  echo "Configuration file not found, using default paths"
fi

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
