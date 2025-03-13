#!/usr/bin/env bash
#
# Script Name: config.sh
# Description: Configuration utility functions for Ephemery Node scripts
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

# Default config locations
DEFAULT_CONFIG_DIR="${HOME}/.ephemery"
DEFAULT_CONFIG_FILE="${DEFAULT_CONFIG_DIR}/config.env"

# Make sure config directory exists
[[ ! -d "${DEFAULT_CONFIG_DIR}" ]] && mkdir -p "${DEFAULT_CONFIG_DIR}"

# -----------------------------------------------------------------------------
# Function: load_config
# Description: Load configuration from a file
# Parameters:
#   $1 - Config file path (optional, defaults to DEFAULT_CONFIG_FILE)
# Returns:
#   0 - Success
#   1 - Config file not found or could not be loaded
# -----------------------------------------------------------------------------
load_config() {
  local config_file="${1:-$DEFAULT_CONFIG_FILE}"

  # Check if config file exists
  if [[ ! -f "$config_file" ]]; then
    if type log_warn &>/dev/null; then
      log_warn "Config file not found: $config_file"
    else
      echo "WARN: Config file not found: $config_file" >&2
    fi
    return 1
  fi

  # Source the config file
  # shellcheck disable=SC1090
  source "$config_file"

  if type log_debug &>/dev/null; then
    log_debug "Config loaded from: $config_file"
  else
    echo "DEBUG: Config loaded from: $config_file" >&2
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: save_config
# Description: Save configuration to a file
# Parameters:
#   $1 - Config file path (optional, defaults to DEFAULT_CONFIG_FILE)
#   $@ - List of variable names to save
# Returns:
#   0 - Success
#   1 - Could not save config file
# -----------------------------------------------------------------------------
save_config() {
  local config_file="${1:-$DEFAULT_CONFIG_FILE}"
  shift

  # Create or truncate config file
  > "$config_file" || {
    if type log_error &>/dev/null; then
      log_error "Could not create config file: $config_file"
    else
      echo "ERROR: Could not create config file: $config_file" >&2
    fi
    return 1
  }

  # Add header
  {
    echo "# Ephemery Node Configuration"
    echo "# Generated on: $(date)"
    echo
  } >> "$config_file"

  # Save variables
  for var_name in "$@"; do
    if [[ -v "$var_name" ]]; then
      declare -p "$var_name" | sed 's/^declare -. //' >> "$config_file"
    fi
  done

  if type log_debug &>/dev/null; then
    log_debug "Config saved to: $config_file"
  else
    echo "DEBUG: Config saved to: $config_file" >&2
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: get_config
# Description: Get a configuration value with a default
# Parameters:
#   $1 - Variable name
#   $2 - Default value (optional)
# Returns:
#   The value of the variable or the default
# -----------------------------------------------------------------------------
get_config() {
  local var_name="$1"
  local default_value="${2:-}"

  if [[ -v "$var_name" ]]; then
    echo "${!var_name}"
  else
    echo "$default_value"
  fi
}

# -----------------------------------------------------------------------------
# Function: set_config
# Description: Set a configuration value
# Parameters:
#   $1 - Variable name
#   $2 - Value
# Returns:
#   None
# -----------------------------------------------------------------------------
set_config() {
  local var_name="$1"
  local value="$2"

  # Export the variable
  export "$var_name"="$value"
}

# Export functions
export -f load_config
export -f save_config
export -f get_config
export -f set_config
