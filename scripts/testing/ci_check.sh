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
if ! "${SCRIPT_DIR}/lint_shell_scripts.sh" --check; then
  echo -e "${RED}Shell script linting failed.${NC}"
  FAILURES=$((FAILURES + 1))
else
  echo -e "${GREEN}Shell script linting passed.${NC}"
fi

echo

# Run tests in mock mode
echo -e "${BLUE}Running tests in mock mode...${NC}"
if ! "${SCRIPT_DIR}/run_tests.sh" --mock; then
  echo -e "${RED}Tests failed.${NC}"
  FAILURES=$((FAILURES + 1))
else
  echo -e "${GREEN}All tests passed.${NC}"
fi

echo

# Report overall status
if [ $FAILURES -gt 0 ]; then
  echo -e "${RED}CI check failed with $FAILURES failures.${NC}"
  exit 1
else
  echo -e "${GREEN}CI check passed successfully.${NC}"
  exit 0
fi
