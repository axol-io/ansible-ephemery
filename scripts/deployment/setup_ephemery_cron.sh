#!/bin/bash
# Version: 1.0.0
# setup_ephemery_cron.sh - Set up a cron job to periodically run the Ephemery reset handler
#
# This script creates a cron job that runs the reset handler at a specified interval,
# ensuring that network resets are detected and handled automatically.

# Strict error handling
set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
CORE_DIR="${PARENT_DIR}/core"
RESET_HANDLER="${CORE_DIR}/ephemery_reset_handler.sh"

# Default settings
INTERVAL="hourly"              # Options: hourly, daily, custom
CUSTOM_SCHEDULE="*/15 * * * *" # Every 15 minutes
CRON_USER="${USER}"
FORCE_INSTALL=false
VERBOSE=false

# Print usage information
function print_usage() {
  log_info "Ephemery Cron Setup"
  echo
  echo "This script sets up a cron job to periodically run the Ephemery reset handler."
  echo
  log_warn "Usage:"
  echo "  $0 [options]"
  echo
  log_warn "Options:"
  echo "  -i, --interval TYPE    Interval type: hourly, daily, custom (default: hourly)"
  echo "  -s, --schedule CRON    Custom cron schedule (default: '*/15 * * * *')"
  echo "  -u, --user USER        User to install cron job for (default: current user)"
  echo "  -f, --force            Force install without confirmation"
  echo "  -v, --verbose          Enable verbose output"
  echo "  -h, --help             Show this help message"
  echo
  log_warn "Examples:"
  echo "  # Install hourly cron job"
  echo "  $0 --interval hourly"
  echo
  echo "  # Install custom cron job (every 5 minutes)"
  echo "  $0 --interval custom --schedule '*/5 * * * *'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -h | --help)
      print_usage
      exit 0
      ;;
    -i | --interval)
      INTERVAL="$2"
      shift
      shift
      ;;
    -s | --schedule)
      CUSTOM_SCHEDULE="$2"
      shift
      shift
      ;;
    -u | --user)
      CRON_USER="$2"
      shift
      shift
      ;;
    -f | --force)
      FORCE_INSTALL=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Validate reset handler script
if [[ ! -f "${RESET_HANDLER}" ]]; then
  log_error "Error: Reset handler script not found: ${RESET_HANDLER}"
  exit 1
fi

if [[ ! -x "${RESET_HANDLER}" ]]; then
  log_warn "Warning: Reset handler script is not executable. Setting executable permission..."
  chmod +x "${RESET_HANDLER}" || {
    log_error "Error: Could not make reset handler executable. Please check permissions."
    exit 1
  }
fi

# Determine cron schedule
CRON_SCHEDULE=""
case "${INTERVAL}" in
  hourly)
    CRON_SCHEDULE="0 * * * *" # At the start of each hour
    ;;
  daily)
    CRON_SCHEDULE="0 0 * * *" # At midnight each day
    ;;
  custom)
    CRON_SCHEDULE="${CUSTOM_SCHEDULE}"
    ;;
  *)
    log_error "Error: Invalid interval type: ${INTERVAL}"
    echo "Valid options: hourly, daily, custom"
    exit 1
    ;;
esac

# Create cron job line
LOG_REDIRECT="/dev/null"
if [[ "${VERBOSE}" == "true" ]]; then
  LOG_REDIRECT="\$HOME/ephemery/data/logs/cron_reset_handler.log"
fi

CRON_LINE="${CRON_SCHEDULE} ${RESET_HANDLER} >> ${LOG_REDIRECT} 2>&1"

# Display preview
log_info "Ephemery Reset Handler Cron Configuration:"
echo "  Reset handler: ${RESET_HANDLER}"
echo "  Cron schedule: ${CRON_SCHEDULE}"
echo "  Cron user: ${CRON_USER}"
echo "  Log output: ${LOG_REDIRECT}"
echo
log_warn "Cron entry to be added:"
echo "${CRON_LINE}"
echo

# Confirm installation
if [[ "${FORCE_INSTALL}" != "true" ]]; then
  read -p "Install cron job? (y/n) " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    log_warn "Cron job installation cancelled."
    exit 0
  fi
fi

# Install cron job
(crontab -l 2>/dev/null || echo "") | grep -v "${RESET_HANDLER}" | {
  cat
  echo "${CRON_LINE}"
} | crontab -

# Verify installation
if crontab -l | grep -q "${RESET_HANDLER}"; then
  log_success "Cron job installed successfully."
  log_info "Next steps:"
  echo "1. Monitor logs at: ${LOG_REDIRECT}"
  echo "2. Test the reset handler: ${RESET_HANDLER} --force"
  exit 0
else
  log_error "Error: Failed to install cron job."
  exit 1
fi
