#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_version_check.sh
# Description: Test version checking functionality
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-21
#
# This script tests the version checking functionality for Ethereum clients.

# Set up environment
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Source common libraries
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# Parse command line arguments
MOCK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)
      MOCK_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      export MOCK_VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--mock] [--verbose]"
      exit 1
      ;;
  esac
done

# Initialize test environment
export TEST_MOCK_MODE="${MOCK_MODE}"
export TEST_VERBOSE="${VERBOSE}"

# Load configuration
load_config

# Initialize mock framework if in mock mode
if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  mock_init
  override_commands
fi

# Test functions
test_geth_version() {
  echo "Testing geth version check..."

  if ! is_tool_available "geth"; then
    if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
      mock_register "geth" "success"
    else
      echo "SKIP: geth not available"
      return 0
    fi
  fi

  # Run version check
  local version_output
  version_output=$(geth version 2>/dev/null)

  # Extract version from output
  local version
  version=$(echo "$version_output" | grep -i "Version:" | awk '{print $2}')

  if [[ -z "${version}" ]]; then
    echo "FAIL: Could not determine geth version"
    return 1
  fi

  echo "PASS: geth version is ${version}"
  return 0
}

test_lighthouse_version() {
  echo "Testing lighthouse version check..."

  if ! is_tool_available "lighthouse"; then
    if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
      mock_register "lighthouse" "success"
    else
      echo "SKIP: lighthouse not available"
      return 0
    fi
  fi

  # Run version check
  local version_output
  version_output=$(lighthouse --version 2>/dev/null)

  # Extract version from output
  local version
  version=$(echo "$version_output" | head -1 | awk '{print $2}')

  if [[ -z "${version}" ]]; then
    echo "FAIL: Could not determine lighthouse version"
    return 1
  fi

  echo "PASS: lighthouse version is ${version}"
  return 0
}

# Run tests
echo "=== Running Version Checker Tests ==="
echo "Mock mode: ${TEST_MOCK_MODE}"
echo "Verbose mode: ${TEST_VERBOSE}"
echo

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Run geth version test
test_geth_version
if [[ $? -eq 0 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run lighthouse version test
test_lighthouse_version
if [[ $? -eq 0 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Cleanup
if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  restore_commands
fi

# Print summary
echo
echo "=== Test Summary ==="
echo "Passed: ${TESTS_PASSED}"
echo "Failed: ${TESTS_FAILED}"
echo "Skipped: ${TESTS_SKIPPED}"
echo "Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

# Exit with appropriate code
if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
else
  exit 0
fi
