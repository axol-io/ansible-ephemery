#!/bin/bash
# Version: 1.0.0
#
# Validator Management Wrapper Script
# This script provides a simple interface to the validator management scripts
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR_SCRIPTS_DIR="${SCRIPT_DIR}/validator"

# Source the standardized paths configuration if available
if [[ -f "/opt/ephemery/config/ephemery_paths.conf" ]]; then
  source "/opt/ephemery/config/ephemery_paths.conf"
  VALIDATOR_SCRIPTS_DIR="${EPHEMERY_VALIDATOR_SCRIPTS_DIR:-${VALIDATOR_SCRIPTS_DIR}}"
fi

function show_help {
  echo "Ephemery Validator Management"
  echo ""
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  keys      Manage validator keys (generate, import, list, backup, restore)"
  echo "  monitor   Monitor validator status and performance"
  echo "  test      Test validator configuration"
  echo "  help      Show this help message"
  echo ""
  echo "For command-specific help, run: $0 [command] --help"
}

if [[ $# -lt 1 ]]; then
  show_help
  exit 1
fi

COMMAND="$1"
shift

case "${COMMAND}" in
  keys)
    "${VALIDATOR_SCRIPTS_DIR}/manage_validator_keys.sh" "$@"
    ;;
  monitor)
    "${VALIDATOR_SCRIPTS_DIR}/monitor_validator.sh" "$@"
    ;;
  test)
    "${VALIDATOR_SCRIPTS_DIR}/test_validator_config.sh" "$@"
    ;;
  help)
    show_help
    ;;
  *)
    echo "Error: Unknown command '${COMMAND}'"
    show_help
    exit 1
    ;;
esac
