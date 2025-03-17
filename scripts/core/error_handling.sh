#!/bin/bash

# Ephemery Error Handling Script
# This script provides standardized error handling for all Ephemery scripts
# Version: 1.0.0

# Initialize variable before use to avoid "unbound variable" error
: "${_EPHEMERY_ERROR_HANDLING_LOADED:=}"

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_ERROR_HANDLING_LOADED}" ]] && return 0
readonly _EPHEMERY_ERROR_HANDLING_LOADED=1

# Source path configuration if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
: "${_EPHEMERY_PATH_CONFIG_LOADED:=}"
if [[ -z "${_EPHEMERY_PATH_CONFIG_LOADED}" && -f "${SCRIPT_DIR}/path_config.sh" ]]; then
  source "${SCRIPT_DIR}/path_config.sh"
fi

# Source common library if not already loaded
: "${_EPHEMERY_COMMON_LOADED:=}"
if [[ -z "${_EPHEMERY_COMMON_LOADED}" && -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Gets error level numeric value
# Usage: get_error_level "ERROR"
get_error_level() {
  local level="$1"

  case "${level}" in
    INFO)
      echo "0"
      ;;
    WARNING)
      echo "1"
      ;;
    ERROR)
      echo "2"
      ;;
    CRITICAL)
      echo "3"
      ;;
    FATAL)
      echo "4"
      ;;
    *)
      echo "2" # Default to ERROR
      ;;
  esac
}

# Gets exit code for a given type
# Usage: get_exit_code "INVALID_ARGUMENT"
get_exit_code() {
  local code_type="$1"

  case "${code_type}" in
    SUCCESS)
      echo "0"
      ;;
    GENERAL_ERROR)
      echo "1"
      ;;
    INVALID_ARGUMENT)
      echo "2"
      ;;
    CONFIGURATION_ERROR)
      echo "3"
      ;;
    EXECUTION_ERROR)
      echo "4"
      ;;
    PERMISSION_ERROR)
      echo "5"
      ;;
    DEPENDENCY_ERROR)
      echo "6"
      ;;
    NETWORK_ERROR)
      echo "7"
      ;;
    TIMEOUT_ERROR)
      echo "8"
      ;;
    DOCKER_ERROR)
      echo "10"
      ;;
    CLIENT_ERROR)
      echo "20"
      ;;
    VALIDATOR_ERROR)
      echo "30"
      ;;
    *)
      echo "1" # Default to GENERAL_ERROR
      ;;
  esac
}

# Define default error levels - Shell compatible version
ERROR_LEVEL_INFO=0
ERROR_LEVEL_WARNING=1
ERROR_LEVEL_ERROR=2
ERROR_LEVEL_CRITICAL=3
ERROR_LEVEL_FATAL=4

# Set default exit codes - Shell compatible version
EXIT_CODE_SUCCESS=0
EXIT_CODE_GENERAL_ERROR=1
EXIT_CODE_INVALID_ARGUMENT=2
EXIT_CODE_CONFIGURATION_ERROR=3
EXIT_CODE_EXECUTION_ERROR=4
EXIT_CODE_PERMISSION_ERROR=5
EXIT_CODE_DEPENDENCY_ERROR=6
EXIT_CODE_NETWORK_ERROR=7
EXIT_CODE_TIMEOUT_ERROR=8
EXIT_CODE_DOCKER_ERROR=10
EXIT_CODE_CLIENT_ERROR=20
EXIT_CODE_VALIDATOR_ERROR=30

# Default error level
ERROR_LEVEL="${ERROR_LEVEL:-ERROR}"

# Default error actions
ERROR_LOG_FILE="${ERROR_LOG_FILE:-${EPHEMERY_LOGS_DIR:-/tmp}/ephemery_error.log}"
ERROR_CONTINUE_ON_WARNING="${ERROR_CONTINUE_ON_WARNING:-true}"
ERROR_CONTINUE_ON_ERROR="${ERROR_CONTINUE_ON_ERROR:-false}"
ERROR_NOTIFY_ON_ERROR="${ERROR_NOTIFY_ON_ERROR:-false}"
ERROR_NOTIFY_COMMAND="${ERROR_NOTIFY_COMMAND:-""}"

# Ensure error log directory exists
mkdir -p "$(dirname "${ERROR_LOG_FILE}")" 2>/dev/null || true

###############################################################################
# Error handling functions
###############################################################################

# Log an error message with timestamp and severity
# Usage: log_error_message "ERROR" "Something went wrong" 123
log_error_message() {
  local level="$1"
  local message="$2"
  local code="${3:-0}"
  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Format the message
  local formatted_message="[${timestamp}] [${level}] ${message}"
  if [[ "${code}" -ne 0 ]]; then
    formatted_message="${formatted_message} (code: ${code})"
  fi

  # Determine where to output
  case "${level}" in
    INFO | DEBUG)
      # Only log to stdout
      if type log_info &>/dev/null; then
        log_info "${message}"
      else
        echo -e "${formatted_message}"
      fi
      ;;
    WARNING)
      # Log to stderr and log file
      if type log_warning &>/dev/null; then
        log_warning "${message}"
      else
        echo -e "${formatted_message}" >&2
      fi
      echo "${formatted_message}" >>"${ERROR_LOG_FILE}"
      ;;
    ERROR | CRITICAL | FATAL)
      # Log to stderr and log file
      if type log_error &>/dev/null; then
        log_error "${message}"
      else
        echo -e "${formatted_message}" >&2
      fi
      echo "${formatted_message}" >>"${ERROR_LOG_FILE}"
      ;;
  esac

  # Send notification if configured
  if [[ "${ERROR_NOTIFY_ON_ERROR}" == "true" && $(get_error_level "${level}") -ge $(get_error_level "ERROR") && -n "${ERROR_NOTIFY_COMMAND}" ]]; then
    eval "${ERROR_NOTIFY_COMMAND} '${formatted_message}'" &>/dev/null || true
  fi
}

# Handle errors based on error level and continue settings
# Usage: handle_error "ERROR" "Something went wrong" 123
handle_error() {
  local level="$1"
  local message="$2"
  local code="${3:-1}"

  # Log the error
  log_error_message "${level}" "${message}" "${code}"

  # Determine if we should continue or exit
  case "${level}" in
    WARNING)
      if [[ "${ERROR_CONTINUE_ON_WARNING}" != "true" ]]; then
        exit "${EXIT_CODE_GENERAL_ERROR}"
      fi
      ;;
    ERROR)
      if [[ "${ERROR_CONTINUE_ON_ERROR}" != "true" ]]; then
        exit "${code}"
      fi
      ;;
    CRITICAL | FATAL)
      # Always exit on critical errors
      exit "${code}"
      ;;
  esac
}

# Main error handler function for trap
# Usage: trap 'error_handler $? $LINENO $BASH_COMMAND' ERR
error_handler() {
  local err_code="$1"
  local err_line="$2"
  local err_command="$3"
  local err_script="${BASH_SOURCE[1]:-${0}}"

  # Get script name
  local script_name="$(basename "${err_script}")"

  # Create error message
  local error_message="Command '${err_command}' failed with error code ${err_code} in ${script_name} on line ${err_line}"

  # Handle the error
  handle_error "ERROR" "${error_message}" "${err_code}"
}

# Setup error handling for a script
# Usage: setup_error_handling
setup_error_handling() {
  # Enable errexit, pipefail, and nounset
  set -o errexit
  set -o pipefail
  set -o nounset

  # Set error trap
  trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

  # Set exit trap to reset error trap
  trap 'trap - ERR' EXIT

  # Log that error handling is set up
  log_error_message "INFO" "Error handling initialized" 0
}

# Wrapper function to catch and handle errors for a command
# Usage: run_with_error_handling "Description" command arg1 arg2
run_with_error_handling() {
  local description="$1"
  shift

  # Log the command
  log_error_message "INFO" "Running: ${description}" 0

  # Run the command and capture result
  local output
  local status

  output="$("$@" 2>&1)" || status=$?

  if [[ ${status:-0} -ne 0 ]]; then
    handle_error "ERROR" "Failed: ${description} - ${output}" "${status}"
    return "${status}"
  fi

  # Return success
  return 0
}

# Export functions
export -f log_error_message
export -f handle_error
export -f error_handler
export -f setup_error_handling
export -f run_with_error_handling
export -f get_error_level
export -f get_exit_code

# If this script is executed directly, show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Ephemery Error Handling Script"
  echo "This script is meant to be sourced by other scripts."
  echo ""
  echo "Usage: source $(basename "$0")"
  echo ""
  echo "Functions provided:"
  echo "  log_error_message LEVEL MESSAGE [CODE]"
  echo "  handle_error LEVEL MESSAGE [CODE]"
  echo "  error_handler CODE LINE COMMAND"
  echo "  setup_error_handling"
  echo "  run_with_error_handling DESCRIPTION COMMAND [ARGS...]"
  echo ""
  echo "Error levels: INFO, WARNING, ERROR, CRITICAL, FATAL"
  echo "Exit codes:"
  for code in "SUCCESS" "GENERAL_ERROR" "INVALID_ARGUMENT" "CONFIGURATION_ERROR" "EXECUTION_ERROR" "PERMISSION_ERROR" "DEPENDENCY_ERROR" "NETWORK_ERROR" "TIMEOUT_ERROR" "DOCKER_ERROR" "CLIENT_ERROR" "VALIDATOR_ERROR"; do
    echo "  ${code}: $(get_exit_code "${code}")"
  done
fi
