#!/bin/bash
#
# Validator Dashboard Startup Script
# ==================================
#
# This script starts the Ephemery validator dashboard, providing a real-time
# view of validator status and performance.
#

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default settings
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"
INTERVAL=30
FULLSCREEN=false
THEME="dark"

# Help function
function show_help {
  echo -e "${BLUE}Ephemery Validator Dashboard${NC}"
  echo ""
  echo "This script starts the Ephemery validator dashboard."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -d, --dir PATH            Ephemery base directory (default: ~/ephemery)"
  echo "  -i, --interval SEC        Update interval in seconds (default: 30)"
  echo "  -f, --fullscreen          Start in fullscreen mode"
  echo "  -t, --theme THEME         Dashboard theme (light, dark) (default: dark)"
  echo "  -h, --help                Show this help message"
}

# Parse command line arguments
function parse_args {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dir)
        EPHEMERY_BASE_DIR="$2"
        shift 2
        ;;
      -i|--interval)
        INTERVAL="$2"
        shift 2
        ;;
      -f|--fullscreen)
        FULLSCREEN=true
        shift
        ;;
      -t|--theme)
        THEME="$2"
        shift 2
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Check if required tools are installed
function check_requirements {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker and try again."
    exit 1
  fi
}

# Start the dashboard
function start_dashboard {
  echo -e "${BLUE}Starting Ephemery validator dashboard...${NC}"

  # Check if validator scripts directory exists
  VALIDATOR_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts/validator"
  if [[ ! -d "${VALIDATOR_SCRIPTS_DIR}" ]]; then
    echo -e "${YELLOW}Validator scripts directory not found at ${VALIDATOR_SCRIPTS_DIR}${NC}"
    echo -e "${YELLOW}Using repository scripts instead${NC}"
    VALIDATOR_SCRIPTS_DIR="${REPO_ROOT}/scripts/validator"
  fi

  # Check if monitor_validator.sh exists
  if [[ ! -f "${VALIDATOR_SCRIPTS_DIR}/monitor_validator.sh" ]]; then
    echo -e "${RED}Error: monitor_validator.sh not found at ${VALIDATOR_SCRIPTS_DIR}${NC}"
    exit 1
  fi

  # Start the dashboard
  if [[ "${FULLSCREEN}" == "true" ]]; then
    # Clear screen and hide cursor
    clear
    echo -e "\033[?25l"

    # Trap to restore cursor on exit
    trap 'echo -e "\033[?25h"; clear' EXIT

    # Start dashboard in fullscreen mode
    "${VALIDATOR_SCRIPTS_DIR}/monitor_validator.sh" dashboard --continuous --interval "${INTERVAL}"
  else
    # Start dashboard in normal mode
    "${VALIDATOR_SCRIPTS_DIR}/monitor_validator.sh" dashboard --continuous --interval "${INTERVAL}"
  fi
}

# Main function
function main {
  parse_args "$@"
  check_requirements
  start_dashboard
}

# Execute main function
main "$@"
