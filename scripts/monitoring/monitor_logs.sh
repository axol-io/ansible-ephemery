#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# monitor_logs.sh
# A script to monitor Ephemery logs in real-time
# Usage: ./scripts/monitor_logs.sh [options]

# Default values
LOG_DIR="${EPHEMERY_LOGS_DIR:-/tmp/ephemery-test/logs}"
FILTER=""
FOLLOW=true
LINES=20
CLIENT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d | --dir)
      LOG_DIR="$2"
      shift 2
      ;;
    -f | --filter)
      FILTER="$2"
      shift 2
      ;;
    -n | --no-follow)
      FOLLOW=false
      shift
      ;;
    -l | --lines)
      LINES="$2"
      shift 2
      ;;
    -c | --client)
      CLIENT="$2"
      shift 2
      ;;
    -h | --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -d, --dir DIR       Specify logs directory (default: ${LOG_DIR})"
      echo "  -f, --filter REGEX  Filter logs by regex pattern"
      echo "  -n, --no-follow     Don't follow logs (default: follow)"
      echo "  -l, --lines LINES   Number of lines to show (default: 20)"
      echo "  -c, --client CLIENT Monitor specific client (geth, lighthouse, validator)"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Check if logs directory exists
if [ ! -d "${LOG_DIR}" ]; then
  echo "Error: Logs directory '${LOG_DIR}' does not exist"
  exit 1
fi

# Function to monitor logs
monitor_logs() {
  local log_file="$1"
  local follow_flag="$2"
  local lines="$3"
  local filter="$4"

  if [ ! -f "${log_file}" ]; then
    echo "Error: Log file '${log_file}' does not exist"
    return 1
  fi

  echo "Monitoring ${log_file}..."

  if [ -n "${filter}" ]; then
    if [ "${follow_flag}" = true ]; then
      tail -n "${lines}" -f "${log_file}" | grep --color=auto -E "${filter}"
    else
      tail -n "${lines}" "${log_file}" | grep --color=auto -E "${filter}"
    fi
  else
    if [ "${follow_flag}" = true ]; then
      tail -n "${lines}" -f "${log_file}"
    else
      tail -n "${lines}" "${log_file}"
    fi
  fi
}

# Function to list available log files
list_logs() {
  echo "Available log files in ${LOG_DIR}:"
  find "${LOG_DIR}" -type f -name "*.log" | sort
}

# Main logic
if [ -n "${CLIENT}" ]; then
  # Monitor specific client logs
  case "${CLIENT}" in
    geth)
      monitor_logs "${LOG_DIR}/geth.log" "${FOLLOW}" "${LINES}" "${FILTER}"
      ;;
    lighthouse)
      monitor_logs "${LOG_DIR}/lighthouse.log" "${FOLLOW}" "${LINES}" "${FILTER}"
      ;;
    validator)
      monitor_logs "${LOG_DIR}/validator.log" "${FOLLOW}" "${LINES}" "${FILTER}"
      ;;
    *)
      echo "Unknown client: ${CLIENT}"
      echo "Available clients: geth, lighthouse, validator"
      list_logs
      exit 1
      ;;
  esac
else
  # No specific client specified, list available logs
  list_logs

  # If there's only one log file, monitor it
  log_count=$(find "${LOG_DIR}" -type f -name "*.log" | wc -l)
  if [ "${log_count}" -eq 1 ]; then
    log_file=$(find "${LOG_DIR}" -type f -name "*.log")
    monitor_logs "${log_file}" "${FOLLOW}" "${LINES}" "${FILTER}"
  elif [ "${log_count}" -gt 1 ]; then
    echo ""
    echo "To monitor a specific log file, use:"
    echo "  $0 -c geth         # Monitor geth logs"
    echo "  $0 -c lighthouse   # Monitor lighthouse logs"
    echo "  $0 -c validator    # Monitor validator logs"
    echo "Or specify a custom log file:"
    echo "  tail -f <log_file>"
  else
    echo "No log files found in ${LOG_DIR}"
  fi
fi
