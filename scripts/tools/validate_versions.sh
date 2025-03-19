#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: validate_versions.sh
# Description: Validates version requirements across the codebase
# Author: Ephemery Team
# Created: 2025-03-19
# Last Modified: 2025-03-19
#
# Usage: ./validate_versions.sh [--fix] [--verbose]

set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default options
FIX_MODE=false
VERBOSE_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE_MODE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--fix] [--verbose]"
      echo "Options:"
      echo "  --fix        Auto-fix issues when possible"
      echo "  --verbose    Show detailed output"
      echo "  --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "Running version validation..."

# Run the core validation script if it exists
CORE_VALIDATOR="${PROJECT_ROOT}/scripts/core/validate_dependencies.sh"
if [[ -f "${CORE_VALIDATOR}" ]]; then
  echo "Using core validator script"
  ARGS=""
  [[ "${FIX_MODE}" == "true" ]] && ARGS="${ARGS} --fix"
  [[ "${VERBOSE_MODE}" == "true" ]] && ARGS="${ARGS} --verbose"

  bash "${CORE_VALIDATOR}" ${ARGS}
  exit $?
else
  echo "Core validator not found, using simple validation"
  SIMPLE_VALIDATOR="${PROJECT_ROOT}/scripts/core/simple_validate_dependencies.sh"

  if [[ -f "${SIMPLE_VALIDATOR}" ]]; then
    ARGS=""
    [[ "${FIX_MODE}" == "true" ]] && ARGS="${ARGS} --fix"
    [[ "${VERBOSE_MODE}" == "true" ]] && ARGS="${ARGS} --verbose"

    bash "${SIMPLE_VALIDATOR}" ${ARGS}
    exit $?
  else
    echo "Error: No validation scripts found."
    echo "Please ensure scripts/core/validate_dependencies.sh or scripts/core/simple_validate_dependencies.sh exists."
    exit 1
  fi
fi
