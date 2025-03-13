#!/usr/bin/env bash
#
# Script Name: logging.sh
# Description: Logging utility functions for Ephemery Node scripts
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

# Default log level
LOG_LEVEL=${LOG_LEVEL:-INFO}

# Log levels
declare -A LOG_LEVELS
LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRITICAL]=4)

# ANSI colors
RESET="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
GRAY="\033[0;37m"

# -----------------------------------------------------------------------------
# Function: should_log
# Description: Check if a message at the given level should be logged
# Parameters:
#   $1 - Log level of the message
# Returns:
#   0 - Should log
#   1 - Should not log
# -----------------------------------------------------------------------------
should_log() {
  local msg_level=$1
  local current_level=${LOG_LEVELS[$LOG_LEVEL]}
  local requested_level=${LOG_LEVELS[$msg_level]}

  if [[ $requested_level -ge $current_level ]]; then
    return 0
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Function: log_debug
# Description: Log a debug message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_debug() {
  if should_log "DEBUG"; then
    echo -e "${GRAY}[DEBUG]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: log_info
# Description: Log an info message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_info() {
  if should_log "INFO"; then
    echo -e "${GREEN}[INFO]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: log_warn
# Description: Log a warning message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_warn() {
  if should_log "WARN"; then
    echo -e "${YELLOW}[WARN]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: log_error
# Description: Log an error message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_error() {
  if should_log "ERROR"; then
    echo -e "${RED}[ERROR]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: log_critical
# Description: Log a critical message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_critical() {
  if should_log "CRITICAL"; then
    echo -e "${RED}[CRITICAL]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: log_success
# Description: Log a success message
# Parameters:
#   $1 - Message to log
# Returns:
#   None
# -----------------------------------------------------------------------------
log_success() {
  if should_log "INFO"; then
    echo -e "${GREEN}[SUCCESS]${RESET} $1" >&2
  fi
}

# -----------------------------------------------------------------------------
# Function: set_log_level
# Description: Set the log level
# Parameters:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR, CRITICAL)
# Returns:
#   0 - Success
#   1 - Invalid log level
# -----------------------------------------------------------------------------
set_log_level() {
  local level="$1"
  if [[ -z "${LOG_LEVELS[$level]:-}" ]]; then
    echo "Invalid log level: $level" >&2
    return 1
  fi
  LOG_LEVEL="$level"
  return 0
}

# Export functions
export -f should_log
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_critical
export -f log_success
export -f set_log_level
