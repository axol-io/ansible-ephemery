#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: ci_check.sh
# Description: CI script to run linting and tests
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-21
#
# This script runs shellharden linting and tests in CI mode.

set -euo pipefail

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Ensure lib directory exists
mkdir -p "${SCRIPT_DIR}/lib"

# Check if common libraries exist in testing/lib, if not copy them
if [[ ! -f "${SCRIPT_DIR}/lib/common.sh" && -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
  echo "Copying common.sh from main lib directory to testing/lib"
  cp "${PROJECT_ROOT}/scripts/lib/common.sh" "${SCRIPT_DIR}/lib/"
fi

if [[ ! -f "${SCRIPT_DIR}/lib/common_consolidated.sh" && -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
  echo "Copying common_consolidated.sh from main lib directory to testing/lib"
  cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "${SCRIPT_DIR}/lib/"
fi

if [[ ! -f "${SCRIPT_DIR}/lib/test_config.sh" && -f "${PROJECT_ROOT}/scripts/lib/test_config.sh" ]]; then
  echo "Copying test_config.sh from main lib directory to testing/lib"
  cp "${PROJECT_ROOT}/scripts/lib/test_config.sh" "${SCRIPT_DIR}/lib/"
fi

# Source the common library
# Try multiple potential locations for common.sh
COMMON_SH=""
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  COMMON_SH="${SCRIPT_DIR}/lib/common.sh"
elif [[ -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
  COMMON_SH="${SCRIPT_DIR}/../lib/common.sh"
elif [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
  COMMON_SH="${PROJECT_ROOT}/scripts/lib/common.sh"
elif [[ -f "/home/runner/work/ansible-ephemery/ansible-ephemery/scripts/lib/common.sh" ]]; then
  COMMON_SH="/home/runner/work/ansible-ephemery/ansible-ephemery/scripts/lib/common.sh"
fi

if [[ -n "$COMMON_SH" ]]; then
  source "$COMMON_SH"
else
  echo "Error: Could not find common.sh library in any of the expected locations."
  echo "Searched in:"
  echo " - ${SCRIPT_DIR}/lib/common.sh"
  echo " - ${SCRIPT_DIR}/../lib/common.sh"
  echo " - ${PROJECT_ROOT}/scripts/lib/common.sh"
  echo " - /home/runner/work/ansible-ephemery/ansible-ephemery/scripts/lib/common.sh"
  # List the contents of directories to help debug
  echo "Contents of ${SCRIPT_DIR}/..:"
  ls -la "${SCRIPT_DIR}/.."
  echo "Contents of ${PROJECT_ROOT}/scripts:"
  ls -la "${PROJECT_ROOT}/scripts"
  exit 1
fi

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0

# Run shellharden linting in check mode
echo -e "${BLUE}Running shellharden linting...${NC}"
if ! "${PROJECT_ROOT}/scripts/testing/lint_shell_scripts.sh" --check; then
  echo -e "${RED}Shell script linting failed.${NC}"
  FAILURES=$((FAILURES + 1))
else
  echo -e "${GREEN}Shell script linting passed.${NC}"
fi

echo

# Run tests in mock mode
echo -e "${BLUE}Running tests in mock mode...${NC}"
if ! "${PROJECT_ROOT}/scripts/testing/run_tests.sh" --mock; then
  echo -e "${RED}Tests failed.${NC}"
  FAILURES=$((FAILURES + 1))
else
  echo -e "${GREEN}All tests passed.${NC}"
fi

echo

# Report overall status
if [ "${FAILURES}" -gt 0 ]; then
  echo -e "${RED}CI check failed with $FAILURES failures.${NC}"
  exit 1
else
  echo -e "${GREEN}CI check passed successfully.${NC}"
  exit 0
fi
