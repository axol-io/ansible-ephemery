#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: hello_ephemery.sh
# Description: A simple example script demonstrating the common library
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./hello_ephemery.sh [options]
#
# Options:
#   -h, --help     Display this help message
#   -v, --verbose  Enable verbose output
#
# Dependencies:
#   - bash

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help     Display this help message"
      echo "  -v, --verbose  Enable verbose output"
      exit 0
      ;;
    -v | --verbose)
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
print_banner "Hello Ephemery"

# Display some information
log_info "This is a simple example script that demonstrates the common library."

if [[ "$VERBOSE" == "true" ]]; then
  log_debug "This debug message will only appear with --verbose flag."
fi

# Check if some commands are available
commands=("ls" "docker" "python3")
available_commands=()
missing_commands=()

log_info "Checking for available commands..."

for cmd in "${commands[@]}"; do
  if is_command_available "$cmd"; then
    available_commands+=("$cmd")
    log_info "- $cmd: Available"
  else
    missing_commands+=("$cmd")
    log_warn "- $cmd: Not available"
  fi
done

# Ask for confirmation
if confirm_action "Would you like to see more information?"; then
  log_info "Showing more information..."
  log_info "Current script: $(get_script_name)"
  log_info "Script directory: ${SCRIPT_DIR}"
  log_info "Available commands: ${available_commands[*]}"

  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    log_warn "Missing commands: ${missing_commands[*]}"
  fi

  if is_ephemery_environment; then
    log_success "This is running in an Ephemery environment."
  else
    log_warn "This is not running in an Ephemery environment."
  fi
else
  log_info "Skipping additional information."
fi

# Successful completion
log_success "Script completed successfully!"
exit 0
