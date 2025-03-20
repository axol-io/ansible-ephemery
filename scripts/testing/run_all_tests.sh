#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: run_all_tests.sh
# Description: Runs all tests for the Ephemery project
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# run_all_tests.sh - Run all test scripts for Ephemery
#
# This script runs all the test scripts in the tests directory

# Strict error handling
set -euo pipefail

# Set base directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TEST_DIR="${DIR}/tests"
REPORT_DIR="${DIR}/reports"

# Create report directory if it doesn't exist
mkdir -p "${REPORT_DIR}"

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set current timestamp for the report file name
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Initialize counters
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Parse command-line arguments
TESTS_TO_RUN=()
SKIP_TESTS=()
VERBOSE=false
REPORT_FILE="${REPORT_DIR}/test_report_${TIMESTAMP}.txt"
SUMMARY_FILE="${REPORT_DIR}/test_summary_${TIMESTAMP}.txt"

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --test=*)
      TESTS_TO_RUN+=("${key#*=}")
      shift
      ;;
    --skip=*)
      SKIP_TESTS+=("${key#*=}")
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --test=TESTNAME     Run specific test(s)"
      echo "  --skip=TESTNAME     Skip specific test(s)"
      echo "  --verbose           Show detailed output"
      echo "  --help              Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Log message to both console and report file
log() {
  echo -e "$1"
  echo -e "$1" >>"${REPORT_FILE}"
}

# Print header
log "${BLUE}======================================${NC}"
log "${BLUE}    Ephemery Test Suite Runner        ${NC}"
log "${BLUE}======================================${NC}"
log "Date: $(date)"
log "Report file: ${REPORT_FILE}"
log ""

# Find all test scripts
if [ ${#TESTS_TO_RUN[@]} -eq 0 ]; then
  # No specific tests specified, run all tests recursively in all subdirectories
  # Use while loop instead of mapfile for better compatibility
  TEST_SCRIPTS=()
  while IFS= read -r line; do
    TEST_SCRIPTS+=("$line")
  done < <(find "${TEST_DIR}" -name "test_*.sh" -type f | sort)
else
  # Run specific tests
  TEST_SCRIPTS=()
  for test in "${TESTS_TO_RUN[@]}"; do
    # Handle different ways to specify the test
    if [[ "${test}" == "test_"* ]]; then
      # If full test name is given
      if [[ -f "${TEST_DIR}/${test}" ]]; then
        TEST_SCRIPTS+=("${TEST_DIR}/${test}")
      elif [[ -f "${TEST_DIR}/${test}.sh" ]]; then
        TEST_SCRIPTS+=("${TEST_DIR}/${test}.sh")
      else
        # Search recursively in subdirectories
        found_tests=$(find "${TEST_DIR}" -name "${test}" -o -name "${test}.sh" -type f)
        if [[ -n "${found_tests}" ]]; then
          while IFS= read -r line; do
            TEST_SCRIPTS+=("$line")
          done <<<"${found_tests}"
        else
          log "${YELLOW}Warning: Test '${test}' not found${NC}"
        fi
      fi
    elif [[ "${test}" == *"/"* ]]; then
      # If path with subdirectory is given
      if [[ -f "${TEST_DIR}/${test}" ]]; then
        TEST_SCRIPTS+=("${TEST_DIR}/${test}")
      elif [[ -f "${TEST_DIR}/${test}.sh" ]]; then
        TEST_SCRIPTS+=("${TEST_DIR}/${test}.sh")
      else
        # Try with test_ prefix
        if [[ -f "${TEST_DIR}/${test%/*}/test_${test##*/}" ]]; then
          TEST_SCRIPTS+=("${TEST_DIR}/${test%/*}/test_${test##*/}")
        elif [[ -f "${TEST_DIR}/${test%/*}/test_${test##*/}.sh" ]]; then
          TEST_SCRIPTS+=("${TEST_DIR}/${test%/*}/test_${test##*/}.sh")
        else
          log "${YELLOW}Warning: Test '${test}' not found${NC}"
        fi
      fi
    else
      # If simple name is given
      if [[ -f "${TEST_DIR}/test_${test}.sh" ]]; then
        TEST_SCRIPTS+=("${TEST_DIR}/test_${test}.sh")
      else
        # Search recursively in subdirectories
        found_tests=$(find "${TEST_DIR}" -name "test_${test}.sh" -type f)
        if [[ -n "${found_tests}" ]]; then
          while IFS= read -r line; do
            TEST_SCRIPTS+=("$line")
          done <<<"${found_tests}"
        else
          log "${YELLOW}Warning: Test '${test}' not found${NC}"
        fi
      fi
    fi
  done
fi

# Filter out skipped tests
if [ ${#SKIP_TESTS[@]} -gt 0 ]; then
  FILTERED_SCRIPTS=()
  for script in "${TEST_SCRIPTS[@]}"; do
    skip=false
    for skip_test in "${SKIP_TESTS[@]}"; do
      if [[ "${script}" == *"${skip_test}"* ]]; then
        skip=true
        break
      fi
    done
    if ! $skip; then
      FILTERED_SCRIPTS+=("${script}")
    fi
  done
  TEST_SCRIPTS=("${FILTERED_SCRIPTS[@]}")
fi

# Count total tests
TOTAL=${#TEST_SCRIPTS[@]}

# Handle case with no tests to run
if [ "${TOTAL}" -eq 0 ]; then
  log "${YELLOW}No tests to run${NC}"
  exit 1
fi

# Run each test script
for script in "${TEST_SCRIPTS[@]}"; do
  test_name=$(basename "${script}")

  log "${BLUE}Running test: ${test_name}${NC}"
  log "----------------------------------------"

  if $VERBOSE; then
    # Run with full output
    if "${script}"; then
      log "${GREEN}✓ Test passed: ${test_name}${NC}"
      ((PASSED++))
    else
      log "${RED}✗ Test failed: ${test_name}${NC}"
      ((FAILED++))
    fi
  else
    # Run with minimal output
    if output=$("${script}" 2>&1); then
      log "${GREEN}✓ Test passed: ${test_name}${NC}"
      ((PASSED++))
    else
      log "${RED}✗ Test failed: ${test_name}${NC}"
      log "Error output:"
      log "${output}"
      ((FAILED++))
    fi
  fi

  log ""
done

# Print test summary
log "${BLUE}======================================${NC}"
log "${BLUE}           Test Summary              ${NC}"
log "${BLUE}======================================${NC}"
log "Total tests: ${TOTAL}"
log "Passed tests: ${GREEN}${PASSED}${NC}"
log "Failed tests: ${RED}${FAILED}${NC}"
log "Skipped tests: ${YELLOW}${SKIPPED}${NC}"

# Create summary file
{
  echo "Test Summary"
  echo "----------------------------------------"
  echo "Date: $(date)"
  echo "Total tests: ${TOTAL}"
  echo "Passed tests: ${PASSED}"
  echo "Failed tests: ${FAILED}"
  echo "Skipped tests: ${SKIPPED}"
  echo ""
  echo "Test Results"
  echo "----------------------------------------"

  for script in "${TEST_SCRIPTS[@]}"; do
    test_name=$(basename "${script}")
    if [ -f "${REPORT_DIR}/${test_name%.sh}_passed" ]; then
      echo "✓ PASSED: ${test_name}"
    else
      echo "✗ FAILED: ${test_name}"
    fi
  done
} >"${SUMMARY_FILE}"

log "Summary written to: ${SUMMARY_FILE}"

# Set exit code based on test results
if [ "${FAILED}" -gt 0 ]; then
  log "${RED}Some tests failed!${NC}"
  exit 1
else
  log "${GREEN}All tests passed!${NC}"
  exit 0
fi
