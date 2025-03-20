#!/bin/bash
# Version: 1.0.0
#
# Name: run_shellcheck.sh
# Description: Run shellcheck on all shell scripts in the project
# Usage: ./scripts/core/run_shellcheck.sh [--fix]
#

set -euo pipefail

# Source path configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/path_config.sh"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/error_handling.sh"

# Define project root if not set by path_config
if [ -z "${PROJECT_ROOT+x}" ]; then
  PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

  # Source the common library
  source "${PROJECT_ROOT}/scripts/lib/common.sh"
fi

# Parse arguments
FIX_MODE=false
SEVERITY="style" # Default severity level is style (includes everything)

while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --severity)
      SEVERITY="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--fix] [--severity <error|warning|info|style>]"
      echo "  --fix        Automatically apply fixes where possible"
      echo "  --severity   Set minimum severity level (error|warning|info|style)"
      exit 0
      ;;
    *)
      error_exit "Unknown option: ${key}"
      ;;
  esac
done

# Verify shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  error_exit "shellcheck is not installed. Please install it first."
fi

# Find all shell scripts
log_info "Finding shell scripts..."
SHELL_SCRIPTS=$(find "${PROJECT_ROOT}" -type f -name "*.sh" -o -name "*.bash" | sort)
SCRIPT_COUNT=$(echo "${SHELL_SCRIPTS}" | wc -l | tr -d ' ')
log_success "Found ${SCRIPT_COUNT} shell scripts to check."

# Initialize counters
PASSED=0
FAILED=0
FIXED=0

# Run shellcheck on each script
for script in ${SHELL_SCRIPTS}; do
  log_info "Checking $(basename "${script}")..."

  if [ "${FIX_MODE}" = true ]; then
    # In fix mode, we'll create a temporary file with fixes
    TEMP_SCRIPT=$(mktemp)

    # Get shellcheck suggestions and apply them where possible
    if shellcheck --severity="${SEVERITY}" --format=diff "${script}" >"${TEMP_SCRIPT}" 2>/dev/null; then
      log_success "✓ $(basename "${script}") passed shellcheck."
      PASSED=$((PASSED + 1))
      rm "${TEMP_SCRIPT}"
    else
      if [ -s "${TEMP_SCRIPT}" ]; then
        # Apply the diff if it contains fixes
        if patch -p0 "${script}" "${TEMP_SCRIPT}"; then
          log_warning "✓ Fixed $(basename "${script}")."
          FIXED=$((FIXED + 1))
        else
          log_error "✗ $(basename "${script}") has issues that couldn't be fixed automatically."
          FAILED=$((FAILED + 1))
        fi
      else
        log_error "✗ $(basename "${script}") has issues that couldn't be fixed automatically."
        FAILED=$((FAILED + 1))
      fi
      rm "${TEMP_SCRIPT}"
    fi
  else
    # In check-only mode
    if shellcheck --severity="${SEVERITY}" "${script}"; then
      log_success "✓ $(basename "${script}") passed shellcheck."
      PASSED=$((PASSED + 1))
    else
      log_error "✗ $(basename "${script}") has shellcheck issues."
      FAILED=$((FAILED + 1))
    fi
  fi
done

# Display summary
echo ""
log_info "Shellcheck summary:"
log_success "✓ ${PASSED} scripts passed"
if [ "${FIX_MODE}" = true ]; then
  log_warning "✓ ${FIXED} scripts were fixed"
fi
log_error "✗ ${FAILED} scripts have remaining issues"

if [ ${FAILED} -eq 0 ]; then
  log_success "All shell scripts passed shellcheck!"
  exit 0
else
  log_error "Some shell scripts need attention."
  exit 1
fi
