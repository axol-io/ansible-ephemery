#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: validation.sh
# Description: Validation utility functions for Ephemery Node scripts
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

# -----------------------------------------------------------------------------
# Function: validate_file_exists
# Description: Check if a file exists
# Parameters:
#   $1 - File path to check
# Returns:
#   0 - File exists
#   1 - File does not exist
# -----------------------------------------------------------------------------
validate_file_exists() {
  local file_path="$1"

  if [[ ! -f "${file_path}" ]]; then
    if type log_error &>/dev/null; then
      log_error "File does not exist: ${file_path}"
    else
      echo "ERROR: File does not exist: ${file_path}" >&2
    fi
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: validate_directory_exists
# Description: Check if a directory exists
# Parameters:
#   $1 - Directory path to check
# Returns:
#   0 - Directory exists
#   1 - Directory does not exist
# -----------------------------------------------------------------------------
validate_directory_exists() {
  local dir_path="$1"

  if [[ ! -d "${dir_path}" ]]; then
    if type log_error &>/dev/null; then
      log_error "Directory does not exist: ${dir_path}"
    else
      echo "ERROR: Directory does not exist: ${dir_path}" >&2
    fi
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: validate_is_executable
# Description: Check if a file is executable
# Parameters:
#   $1 - File path to check
# Returns:
#   0 - File is executable
#   1 - File is not executable
# -----------------------------------------------------------------------------
validate_is_executable() {
  local file_path="$1"

  if [[ ! -x "${file_path}" ]]; then
    if type log_error &>/dev/null; then
      log_error "File is not executable: ${file_path}"
    else
      echo "ERROR: File is not executable: ${file_path}" >&2
    fi
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: validate_ip_address
# Description: Check if a string is a valid IP address
# Parameters:
#   $1 - String to check
# Returns:
#   0 - String is a valid IP address
#   1 - String is not a valid IP address
# -----------------------------------------------------------------------------
validate_ip_address() {
  local ip="$1"

  if [[ ! "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if type log_error &>/dev/null; then
      log_error "Invalid IP address: ${ip}"
    else
      echo "ERROR: Invalid IP address: ${ip}" >&2
    fi
    return 1
  fi

  # Check each octet
  IFS='.' read -r -a octets <<<"${ip}"
  for octet in "${octets[@]}"; do
    if ((octet < 0 || octet > 255)); then
      if type log_error &>/dev/null; then
        log_error "Invalid IP address octet: ${octet}"
      else
        echo "ERROR: Invalid IP address octet: ${octet}" >&2
      fi
      return 1
    fi
  done

  return 0
}

# -----------------------------------------------------------------------------
# Function: validate_port
# Description: Check if a number is a valid port number
# Parameters:
#   $1 - Number to check
# Returns:
#   0 - Number is a valid port
#   1 - Number is not a valid port
# -----------------------------------------------------------------------------
validate_port() {
  local port="$1"

  if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    if type log_error &>/dev/null; then
      log_error "Invalid port number: ${port}"
    else
      echo "ERROR: Invalid port number: ${port}" >&2
    fi
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Function: validate_url
# Description: Check if a string is a valid URL
# Parameters:
#   $1 - String to check
# Returns:
#   0 - String is a valid URL
#   1 - String is not a valid URL
# -----------------------------------------------------------------------------
validate_url() {
  local url="$1"

  if [[ ! "${url}" =~ ^https?:// ]]; then
    if type log_error &>/dev/null; then
      log_error "Invalid URL: ${url}"
    else
      echo "ERROR: Invalid URL: ${url}" >&2
    fi
    return 1
  fi

  return 0
}

# Export functions
export -f validate_file_exists
export -f validate_directory_exists
export -f validate_is_executable
export -f validate_ip_address
export -f validate_port
export -f validate_url
