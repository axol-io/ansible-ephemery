#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: run_tests.sh
# Description: Main test runner for Ephemery testing
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-21
#
# This script runs all tests for the Ephemery project.

# Set up environment
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Source common libraries
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
MOCK_MODE=false
VERBOSE=false
LINT_SCRIPTS=false
SPECIFIC_TEST=""
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
REPORT_FILE="${REPORT_DIR}/test_report_$(date +%Y%m%d-%H%M%S).log"

print_usage() {
  echo "Usage: $0 [options] [test_path]"
  echo "Options:"
  echo "  --mock                 Run tests in mock mode"
  echo "  --verbose              Run tests in verbose mode"
  echo "  --lint                 Lint shell scripts before running tests"
  echo "  --help                 Show this help message"
  echo "  test_path              Path to a specific test or test directory"
  echo
  echo "Examples:"
  echo "  $0                     Run all tests"
  echo "  $0 --mock              Run all tests in mock mode"
  echo "  $0 --lint              Lint scripts and run all tests"
  echo "  $0 tests/version_checker/test_version_check.sh  Run a specific test"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)
      MOCK_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --lint)
      LINT_SCRIPTS=true
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      if [[ -z "${SPECIFIC_TEST}" ]]; then
        SPECIFIC_TEST="$1"
      else
        echo "Error: Unknown option or multiple test paths specified: $1"
        print_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Initialize test environment
export TEST_MOCK_MODE="${MOCK_MODE}"
export TEST_VERBOSE="${VERBOSE}"

# Load configuration
load_config

# Function to run shellharden linting
run_shellharden_lint() {
  echo "Running shellharden linting..."
  local lint_script="${SCRIPT_DIR}/lint_shell_scripts.sh"

  if [[ ! -x "$lint_script" ]]; then
    echo -e "${YELLOW}Warning: lint_shell_scripts.sh not found or not executable.${NC}"
    return 1
  fi

  # Run in check mode but don't fail if issues are found
  if [[ "${VERBOSE}" == "true" ]]; then
    "$lint_script" --verbose
  else
    "$lint_script"
  fi

  echo "Linting completed."
  echo
}

# Initialize report file
{
  echo "Ephemery Test Report"
  echo "===================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Mock Mode: ${TEST_MOCK_MODE}"
  echo "Verbose Mode: ${TEST_VERBOSE}"
  echo "------------------------------------------"
  echo
} >"${REPORT_FILE}"

# Run shellharden linting if requested
if [[ "${LINT_SCRIPTS}" == "true" ]]; then
  run_shellharden_lint
fi

# Find and run tests
find_and_run_tests() {
  local test_dir="$1"
  local test_args="$2"
  local tests_found=0
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0
  local failed_tests=()

  echo -e "${BLUE}=== Running tests in ${test_dir} ===${NC}"
  echo "=== Running tests in ${test_dir} ===" >>"${REPORT_FILE}"

  # Find all test scripts in the directory
  while IFS= read -r test_script; do
    if [[ -x "${test_script}" && "${test_script}" == *test_*.sh ]]; then
      tests_found=$((tests_found + 1))

      echo -e "${BLUE}Running test: ${test_script}${NC}"
      echo "Running test: ${test_script}" >>"${REPORT_FILE}"

      # Run the test script
      if "${test_script}" ${test_args}; then
        echo -e "${GREEN}✓ Test passed: ${test_script}${NC}"
        echo "✓ Test passed: ${test_script}" >>"${REPORT_FILE}"
        tests_passed=$((tests_passed + 1))
      else
        local exit_code=$?
        if [[ ${exit_code} -eq 77 ]]; then
          echo -e "${YELLOW}⚠ Test skipped: ${test_script}${NC}"
          echo "⚠ Test skipped: ${test_script}" >>"${REPORT_FILE}"
          tests_skipped=$((tests_skipped + 1))
        else
          echo -e "${RED}✗ Test failed: ${test_script} (exit code: ${exit_code})${NC}"
          echo "✗ Test failed: ${test_script} (exit code: ${exit_code})" >>"${REPORT_FILE}"
          tests_failed=$((tests_failed + 1))
          failed_tests+=("${test_script}")
        fi
      fi

      echo "" >>"${REPORT_FILE}"
    fi
  done < <(find "${test_dir}" -type f -name "test_*.sh" | sort)

  # Print summary for this directory
  echo
  echo -e "${BLUE}=== Summary for ${test_dir} ===${NC}"
  echo "=== Summary for ${test_dir} ===" >>"${REPORT_FILE}"
  echo -e "Tests found: ${tests_found}"
  echo -e "Tests passed: ${GREEN}${tests_passed}${NC}"
  echo -e "Tests failed: ${RED}${tests_failed}${NC}"
  echo -e "Tests skipped: ${YELLOW}${tests_skipped}${NC}"

  echo "Tests found: ${tests_found}" >>"${REPORT_FILE}"
  echo "Tests passed: ${tests_passed}" >>"${REPORT_FILE}"
  echo "Tests failed: ${tests_failed}" >>"${REPORT_FILE}"
  echo "Tests skipped: ${tests_skipped}" >>"${REPORT_FILE}"

  if [[ ${tests_failed} -gt 0 ]]; then
    echo
    echo -e "${RED}Failed tests:${NC}"
    echo "Failed tests:" >>"${REPORT_FILE}"
    for failed_test in "${failed_tests[@]}"; do
      echo -e "  ${RED}${failed_test}${NC}"
      echo "  ${failed_test}" >>"${REPORT_FILE}"
    done
  fi

  echo
  echo "------------------------------------------" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"

  # Return the number of failed tests
  return ${tests_failed}
}

# Function to run a specific test
run_specific_test() {
  local test_path="$1"
  local test_args="$2"
  local exit_code=0

  echo -e "${BLUE}=== Running specific test: ${test_path} ===${NC}"
  echo "=== Running specific test: ${test_path} ===" >>"${REPORT_FILE}"

  if [[ -x "${test_path}" ]]; then
    if "${test_path}" ${test_args}; then
      echo -e "${GREEN}✓ Test passed: ${test_path}${NC}"
      echo "✓ Test passed: ${test_path}" >>"${REPORT_FILE}"
      exit_code=0
    else
      exit_code=$?
      if [[ ${exit_code} -eq 77 ]]; then
        echo -e "${YELLOW}⚠ Test skipped: ${test_path}${NC}"
        echo "⚠ Test skipped: ${test_path}" >>"${REPORT_FILE}"
        exit_code=0
      else
        echo -e "${RED}✗ Test failed: ${test_path} (exit code: ${exit_code})${NC}"
        echo "✗ Test failed: ${test_path} (exit code: ${exit_code})" >>"${REPORT_FILE}"
      fi
    fi
  else
    echo -e "${RED}Error: Test file is not executable: ${test_path}${NC}"
    echo "Error: Test file is not executable: ${test_path}" >>"${REPORT_FILE}"
    exit_code=1
  fi

  return ${exit_code}
}

# Function to run all tests
run_all_tests() {
  local test_args="$1"
  local total_failed=0
  local total_tests_found=0

  # Debug: List all test scripts
  echo "Searching for test scripts in: ${PROJECT_ROOT}/scripts/testing/tests"
  find "${PROJECT_ROOT}/scripts/testing/tests" -type f -name "test_*.sh" | sort

  # Find all test scripts directly
  while IFS= read -r test_script; do
    if [[ -x "${test_script}" && "${test_script}" != *"/template/"* ]]; then
      echo -e "${BLUE}Running test: ${test_script}${NC}"
      echo "Running test: ${test_script}" >>"${REPORT_FILE}"

      total_tests_found=$((total_tests_found + 1))

      # Run the test script
      if "${test_script}" ${test_args}; then
        echo -e "${GREEN}✓ Test passed: ${test_script}${NC}"
        echo "✓ Test passed: ${test_script}" >>"${REPORT_FILE}"
      else
        local exit_code=$?
        if [[ ${exit_code} -eq 77 ]]; then
          echo -e "${YELLOW}⚠ Test skipped: ${test_script}${NC}"
          echo "⚠ Test skipped: ${test_script}" >>"${REPORT_FILE}"
        else
          echo -e "${RED}✗ Test failed: ${test_script} (exit code: ${exit_code})${NC}"
          echo "✗ Test failed: ${test_script} (exit code: ${exit_code})" >>"${REPORT_FILE}"
          total_failed=$((total_failed + 1))
        fi
      fi

      echo "" >>"${REPORT_FILE}"
    fi
  done < <(find "${PROJECT_ROOT}/scripts/testing/tests" -type f -name "test_*.sh" 2>/dev/null | grep -v "/template/" | sort)

  # Print overall summary
  echo
  echo -e "${BLUE}=== Overall Test Summary ===${NC}"
  echo "=== Overall Test Summary ===" >>"${REPORT_FILE}"
  echo -e "Total tests found: ${total_tests_found}"
  echo "Total tests found: ${total_tests_found}" >>"${REPORT_FILE}"

  if [[ ${total_failed} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo "All tests passed!" >>"${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}${total_failed} tests failed!${NC}"
    echo "${total_failed} tests failed!" >>"${REPORT_FILE}"
    return 1
  fi
}

# Run tests
if [[ -n "${SPECIFIC_TEST}" ]]; then
  # Run a specific test
  if [[ -f "${SPECIFIC_TEST}" ]]; then
    # Single test file
    test_args=""
    if [[ "${MOCK_MODE}" == "true" ]]; then
      test_args="${test_args} --mock"
    fi
    if [[ "${VERBOSE}" == "true" ]]; then
      test_args="${test_args} --verbose"
    fi

    run_specific_test "${SPECIFIC_TEST}" "${test_args}"
    exit $?
  elif [[ -d "${SPECIFIC_TEST}" ]]; then
    # Directory of tests
    test_args=""
    if [[ "${MOCK_MODE}" == "true" ]]; then
      test_args="${test_args} --mock"
    fi
    if [[ "${VERBOSE}" == "true" ]]; then
      test_args="${test_args} --verbose"
    fi

    find_and_run_tests "${SPECIFIC_TEST}" "${test_args}"
    exit $?
  else
    echo -e "${RED}Error: Test path not found: ${SPECIFIC_TEST}${NC}"
    echo "Error: Test path not found: ${SPECIFIC_TEST}" >>"${REPORT_FILE}"
    exit 1
  fi
else
  # Run all tests
  echo -e "${BLUE}=== Running all tests ===${NC}"
  echo "=== Running all tests ===" >>"${REPORT_FILE}"

  test_args=""
  if [[ "${MOCK_MODE}" == "true" ]]; then
    test_args="${test_args} --mock"
  fi
  if [[ "${VERBOSE}" == "true" ]]; then
    test_args="${test_args} --verbose"
  fi

  run_all_tests "${test_args}"
  exit $?
fi
