#!/usr/bin/env bash
#
# =============================================================================
# Script Name: script_template.sh
# Description: Template for creating new Ephemery scripts
# Usage: ./script_template.sh [options]
# Parameters:
#   -h, --help     Display this help message
#   -c, --client   Client name (geth, lighthouse, etc.)
#   -n, --node     Node hostname or IP address
# Author: Ephemery Team
# Creation Date: $(date +%Y-%m-%d)
# =============================================================================

# Exit on error, undefined variables, and propagate pipe failures
set -euo pipefail

# Source common functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_DIR}/../utilities/common_functions.sh" ]]; then
  source "${SCRIPT_DIR}/../utilities/common_functions.sh"
fi

# Default values
CLIENT=""
NODE=""

# Function to display usage information
function display_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help     Display this help message"
  echo "  -c, --client   Client name (geth, lighthouse, etc.)"
  echo "  -n, --node     Node hostname or IP address"
  exit 0
}

# Function to log messages
function log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
}

# Parse command line arguments
function parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        display_usage
        ;;
      -c | --client)
        CLIENT="$2"
        shift 2
        ;;
      -n | --node)
        NODE="$2"
        shift 2
        ;;
      *)
        log_message "ERROR" "Unknown parameter: $1"
        display_usage
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$CLIENT" ]]; then
    log_message "ERROR" "Client parameter is required"
    display_usage
  fi

  if [[ -z "$NODE" ]]; then
    log_message "ERROR" "Node parameter is required"
    display_usage
  fi
}

# Main function
function main() {
  log_message "INFO" "Starting script execution"
  log_message "INFO" "Using client: ${CLIENT}"
  log_message "INFO" "Target node: ${NODE}"

  # TODO: Implement script functionality here

  log_message "INFO" "Script execution completed successfully"
  return 0
}

# Parse arguments if any were provided
if [[ $# -gt 0 ]]; then
  parse_arguments "$@"
fi

# Execute main function
main
