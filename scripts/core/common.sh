#!/bin/bash

# Ephemery Common Shell Library
# This file provides reusable functions for all Ephemery scripts
# Version: 1.0.0

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_COMMON_LOADED}" ]] && return 0
readonly _EPHEMERY_COMMON_LOADED=1

# Source configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [[ -f "${SCRIPT_DIR}/ephemery_config.sh" ]]; then
  source "${SCRIPT_DIR}/ephemery_config.sh"
fi

###############################################################################
# Color and formatting constants
###############################################################################

# Colors
readonly GREEN=${GREEN:-'\033[0;32m'}
readonly YELLOW=${YELLOW:-'\033[1;33m'}
readonly RED=${RED:-'\033[0;31m'}
readonly BLUE=${BLUE:-'\033[0;34m'}
readonly CYAN=${CYAN:-'\033[0;36m'}
readonly MAGENTA=${MAGENTA:-'\033[0;35m'}
readonly NC=${NC:-'\033[0m'} # No Color

# Text formatting
readonly BOLD=${BOLD:-'\033[1m'}
readonly UNDERLINE=${UNDERLINE:-'\033[4m'}
readonly ITALIC=${ITALIC:-'\033[3m'}

###############################################################################
# Logging functions
###############################################################################

# Log a message to stdout with timestamp
# Usage: log_info "Your message here"
log_info() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO${NC}: $*"
}

# Log a success message to stdout with timestamp
# Usage: log_success "Your message here"
log_success() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}SUCCESS${NC}: $*"
}

# Log a warning message to stdout with timestamp
# Usage: log_warning "Your message here"
log_warning() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}WARNING${NC}: $*" >&2
}

# Log an error message to stderr with timestamp
# Usage: log_error "Your message here"
log_error() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR${NC}: $*" >&2
}

# Log a debug message to stdout with timestamp if DEBUG is enabled
# Usage: log_debug "Your message here"
log_debug() {
  if [[ "${EPHEMERY_DEBUG:-false}" == "true" ]]; then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${MAGENTA}DEBUG${NC}: $*"
  fi
}

###############################################################################
# Error handling functions
###############################################################################

# Trap function for error handling
# Usage: trap 'error_handler $? $LINENO' ERR
error_handler() {
  local err_code=$1
  local err_line=$2
  local command="${BASH_COMMAND}"

  log_error "Command '${command}' failed with error code ${err_code} on line ${err_line}"

  # Exit if not in interactive mode and not explicitly told to continue
  if [[ "${-}" != *"i"* && "${EPHEMERY_CONTINUE_ON_ERROR:-false}" != "true" ]]; then
    exit "${err_code}"
  fi
}

# Set up error handling in a script
# Usage: setup_error_handling
setup_error_handling() {
  set -E           # Inherit ERR trap by functions
  set -o pipefail  # Pipe fails if any command fails
  trap 'error_handler $? $LINENO' ERR
}

# Cleanup function to reset traps and perform cleanup actions
# Usage: trap cleanup EXIT
cleanup() {
  # Reset error trap
  trap - ERR

  # Add other cleanup actions here
  log_debug "Cleanup completed"
}

###############################################################################
# Path handling functions
###############################################################################

# Ensure base directory exists
# Usage: ensure_base_dir
ensure_base_dir() {
  local base_dir="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"

  # Standardize path (remove trailing slashes, resolve symbolic links)
  base_dir="$(cd "$(dirname "${base_dir}")" &>/dev/null && pwd)/$(basename "${base_dir}")"

  # Create if it doesn't exist
  if [[ ! -d "${base_dir}" ]]; then
    log_info "Creating base directory: ${base_dir}"
    mkdir -p "${base_dir}" || {
      log_error "Failed to create base directory: ${base_dir}"
      return 1
    }
  fi

  # Export standardized path
  export EPHEMERY_BASE_DIR="${base_dir}"

  return 0
}

# Get standardized path for a specific component
# Usage: get_component_path "config"
get_component_path() {
  local component="$1"
  local base_dir="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"

  case "${component}" in
    config)
      echo "${base_dir}/config"
      ;;
    data)
      echo "${base_dir}/data"
      ;;
    logs)
      echo "${base_dir}/logs"
      ;;
    scripts)
      echo "${base_dir}/scripts"
      ;;
    secrets)
      echo "${base_dir}/secrets"
      ;;
    *)
      log_error "Unknown component: ${component}"
      return 1
      ;;
  esac

  return 0
}

# Ensure all standard directories exist
# Usage: ensure_standard_dirs
ensure_standard_dirs() {
  local base_dir="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"

  # First ensure base directory exists
  ensure_base_dir || return 1

  # Create standard subdirectories
  local dirs=(
    "$(get_component_path "config")"
    "$(get_component_path "data")/geth"
    "$(get_component_path "data")/lighthouse"
    "$(get_component_path "data")/lighthouse-validator"
    "$(get_component_path "logs")"
    "$(get_component_path "scripts")"
    "$(get_component_path "secrets")"
  )

  for dir in "${dirs[@]}"; do
    if [[ ! -d "${dir}" ]]; then
      log_info "Creating directory: ${dir}"
      mkdir -p "${dir}" || {
        log_error "Failed to create directory: ${dir}"
        return 1
      }
    fi
  done

  return 0
}

###############################################################################
# Command line argument parsing
###############################################################################

# Parse boolean flag
# Usage: parse_bool_flag "$1" "--flag" && echo "Flag is set"
parse_bool_flag() {
  local arg="$1"
  local flag="$2"

  [[ "${arg}" == "${flag}" ]]
  return $?
}

# Parse flag with value
# Usage: value=$(parse_flag_value "$1" "$2" "--flag")
parse_flag_value() {
  local arg="$1"
  local next_arg="$2"
  local flag="$3"

  if [[ "${arg}" == "${flag}" ]]; then
    echo "${next_arg}"
    return 0
  fi

  # Check for --flag=value format
  if [[ "${arg}" == "${flag}="* ]]; then
    echo "${arg#*=}"
    return 0
  fi

  return 1
}

###############################################################################
# Docker helper functions
###############################################################################

# Check if Docker is installed and running
# Usage: check_docker || exit 1
check_docker() {
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker and try again."
    return 1
  fi

  if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running. Please start Docker and try again."
    return 1
  fi

  return 0
}

# Check if a Docker container is running
# Usage: is_container_running "container-name" && echo "Container is running"
is_container_running() {
  local container_name="$1"

  if [[ -z "${container_name}" ]]; then
    log_error "Container name is required"
    return 2
  fi

  # Check if container exists and is running
  if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    return 0
  fi

  return 1
}
