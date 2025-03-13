#!/usr/bin/env bash
#
# Script Name: common.sh
# Description: Common utility functions for Ephemery Node scripts
# Author: Ephemery Team
# Created: 2023-05-15
# Last Modified: 2023-05-15
#
# Usage: Source this file in other scripts
#
# Dependencies:
#   - bash
#
# Exit Codes:
#   0 - Success
#   1 - General error

# Enable strict mode
set -euo pipefail

# Load standardized configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
  # Use quiet sourcing since this is a library file
  source "$CONFIG_FILE"
else
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
fi

# Script directory (for sourcing other files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Include other utility libraries if they exist
[[ -f "${SCRIPT_DIR}/logging.sh" ]] && source "${SCRIPT_DIR}/logging.sh"
[[ -f "${SCRIPT_DIR}/config.sh" ]] && source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/validation.sh" ]] && source "${SCRIPT_DIR}/validation.sh"

# -----------------------------------------------------------------------------
# Function: is_command_available
# Description: Check if a command is available
# Parameters:
#   $1 - Command to check
# Returns:
#   0 - Command is available
#   1 - Command is not available
# -----------------------------------------------------------------------------
is_command_available() {
  if command -v "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Function: check_dependencies
# Description: Check if required dependencies are installed
# Parameters:
#   $@ - List of required commands
# Returns:
#   0 - All dependencies are installed
#   1 - One or more dependencies are missing
# -----------------------------------------------------------------------------
check_dependencies() {
  local missing_deps=()
  for cmd in "$@"; do
    if ! is_command_available "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    if type log_error &>/dev/null; then
      log_error "Missing required dependencies: ${missing_deps[*]}"
    else
      echo "ERROR: Missing required dependencies: ${missing_deps[*]}" >&2
    fi
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: confirm_action
# Description: Ask for user confirmation before proceeding
# Parameters:
#   $1 - Question to ask
# Returns:
#   0 - User confirmed
#   1 - User declined
# -----------------------------------------------------------------------------
confirm_action() {
  local question="${1:-Are you sure you want to proceed?}"
  read -p "${question} [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Function: get_script_name
# Description: Extract the name of the calling script
# Parameters:
#   None
# Returns:
#   Script name
# -----------------------------------------------------------------------------
get_script_name() {
  basename "${0:-unknown_script}"
}

# -----------------------------------------------------------------------------
# Function: get_absolute_path
# Description: Convert a relative path to an absolute path
# Parameters:
#   $1 - Path to convert
# Returns:
#   Absolute path
# -----------------------------------------------------------------------------
get_absolute_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$(pwd)/$path"
  fi
}

# Export functions
export -f is_command_available
export -f check_dependencies
export -f confirm_action
export -f get_script_name
export -f get_absolute_path 