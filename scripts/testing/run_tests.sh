#!/bin/bash

# Ephemery Automated Testing Script
# This script runs the testing pipeline for Ephemery shell scripts
# Version: 1.0.0

# Exit on any error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Source core utilities if available
if [ -f "${PROJECT_ROOT}/scripts/core/path_config.sh" ]; then
  source "${PROJECT_ROOT}/scripts/core/path_config.sh"
fi

if [ -f "${PROJECT_ROOT}/scripts/core/error_handling.sh" ]; then
  source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
  # Set up error handling
  setup_error_handling
fi

if [ -f "${PROJECT_ROOT}/scripts/core/common.sh" ]; then
  source "${PROJECT_ROOT}/scripts/core/common.sh"
fi

# Color definitions in case common.sh not available
if [ -z "$GREEN" ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
fi

# Define test directories
TEST_DIR="${PROJECT_ROOT}/scripts/testing/tests"
FIXTURE_DIR="${PROJECT_ROOT}/scripts/testing/fixtures"
REPORT_DIR="${PROJECT_ROOT}/scripts/testing/reports"

# Ensure test directories exist
mkdir -p "${TEST_DIR}" "${FIXTURE_DIR}" "${REPORT_DIR}"

# Default settings
RUN_SHELL_TESTS=true
RUN_LINT_TESTS=true
RUN_INTEGRATION_TESTS=false
VERBOSE=false

# Function to display usage information
show_usage() {
  echo -e "${BLUE}Ephemery Automated Testing Script${NC}"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -s, --shell-only       Run only shell script unit tests"
  echo "  -l, --lint-only        Run only linting tests"
  echo "  -i, --integration      Also run integration tests (may take longer)"
  echo "  -v, --verbose          Enable verbose output"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                     # Run all standard tests"
  echo "  $0 --shell-only        # Run only shell script unit tests"
  echo "  $0 --lint-only         # Run only linting tests"
  echo "  $0 --integration       # Run all tests including integration tests"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -s|--shell-only)
      RUN_SHELL_TESTS=true
      RUN_LINT_TESTS=false
      RUN_INTEGRATION_TESTS=false
      shift
      ;;
    -l|--lint-only)
      RUN_SHELL_TESTS=false
      RUN_LINT_TESTS=true
      RUN_INTEGRATION_TESTS=false
      shift
      ;;
    -i|--integration)
      RUN_INTEGRATION_TESTS=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Function for verbose logging
log() {
  if [ "$VERBOSE" = true ]; then
    echo -e "$@"
  fi
}

# Function to run ShellCheck on scripts
run_shellcheck() {
  echo -e "${BLUE}Running ShellCheck linting...${NC}"
  
  mapfile -t SHELL_SCRIPTS < <(find "${PROJECT_ROOT}" -type f -name "*.sh" -not -path "*/\.*" -not -path "*/collections/*")
  
  local shellcheck_errors=0
  local shellcheck_report="${REPORT_DIR}/shellcheck-report-$(date +%Y%m%d-%H%M%S).txt"
  
  # Ensure shellcheck is installed
  if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}Error: ShellCheck is not installed. Please install it to run linting tests.${NC}"
    return 1
  fi
  
  echo "Found ${#SHELL_SCRIPTS[@]} shell scripts to check"
  echo "Results will be saved to ${shellcheck_report}"
  
  # Create report header
  echo "ShellCheck Report - $(date)" > "${shellcheck_report}"
  echo "=========================" >> "${shellcheck_report}"
  echo "" >> "${shellcheck_report}"
  
  for script in "${SHELL_SCRIPTS[@]}"; do
    log "${YELLOW}Checking: ${script}${NC}"
    
    # Run shellcheck and capture output
    if shellcheck_output=$(shellcheck -x "${script}" 2>&1); then
      echo -e "${GREEN}✓ ${script}${NC}"
      echo "✓ ${script} - Passed" >> "${shellcheck_report}"
    else
      echo -e "${RED}✗ ${script}${NC}"
      echo -e "✗ ${script}\n" >> "${shellcheck_report}"
      echo -e "${shellcheck_output}\n" >> "${shellcheck_report}"
      echo -e "------------------------\n" >> "${shellcheck_report}"
      shellcheck_errors=$((shellcheck_errors+1))
    fi
  done
  
  # Display results summary
  echo ""
  echo -e "${BLUE}ShellCheck Summary:${NC}"
  echo "Scripts checked: ${#SHELL_SCRIPTS[@]}"
  echo "Scripts with errors: ${shellcheck_errors}"
  echo "Report saved to: ${shellcheck_report}"
  
  if [ $shellcheck_errors -gt 0 ]; then
    echo -e "${RED}ShellCheck found $shellcheck_errors scripts with issues${NC}"
    return 1
  else
    echo -e "${GREEN}ShellCheck tests passed!${NC}"
    return 0
  fi
}

# Function to run shfmt on scripts
run_shfmt() {
  echo -e "${BLUE}Running shfmt formatting check...${NC}"
  
  mapfile -t SHELL_SCRIPTS < <(find "${PROJECT_ROOT}" -type f -name "*.sh" -not -path "*/\.*" -not -path "*/collections/*")
  
  local shfmt_errors=0
  local shfmt_report="${REPORT_DIR}/shfmt-report-$(date +%Y%m%d-%H%M%S).txt"
  
  # Ensure shfmt is installed
  if ! command -v shfmt &> /dev/null; then
    echo -e "${RED}Error: shfmt is not installed. Please install it to run formatting tests.${NC}"
    return 1
  fi
  
  echo "Found ${#SHELL_SCRIPTS[@]} shell scripts to check"
  echo "Results will be saved to ${shfmt_report}"
  
  # Create report header
  echo "shfmt Report - $(date)" > "${shfmt_report}"
  echo "===================" >> "${shfmt_report}"
  echo "" >> "${shfmt_report}"
  
  for script in "${SHELL_SCRIPTS[@]}"; do
    log "${YELLOW}Checking: ${script}${NC}"
    
    # Check if file is formatted correctly
    if shfmt -d -i 2 -ci "${script}" &> /dev/null; then
      echo -e "${GREEN}✓ ${script}${NC}"
      echo "✓ ${script} - Properly formatted" >> "${shfmt_report}"
    else
      echo -e "${RED}✗ ${script}${NC}"
      echo -e "✗ ${script} - Not properly formatted\n" >> "${shfmt_report}"
      if [ "$VERBOSE" = true ]; then
        shfmt -d -i 2 -ci "${script}" >> "${shfmt_report}"
      fi
      echo -e "------------------------\n" >> "${shfmt_report}"
      shfmt_errors=$((shfmt_errors+1))
    fi
  done
  
  # Display results summary
  echo ""
  echo -e "${BLUE}shfmt Summary:${NC}"
  echo "Scripts checked: ${#SHELL_SCRIPTS[@]}"
  echo "Scripts with formatting issues: ${shfmt_errors}"
  echo "Report saved to: ${shfmt_report}"
  
  if [ $shfmt_errors -gt 0 ]; then
    echo -e "${RED}shfmt found $shfmt_errors scripts with formatting issues${NC}"
    return 1
  else
    echo -e "${GREEN}shfmt tests passed!${NC}"
    return 0
  fi
}

# Function to run shell script unit tests
run_shell_tests() {
  echo -e "${BLUE}Running shell script unit tests...${NC}"
  
  # Check if bats is installed (Bash Automated Testing System)
  if ! command -v bats &> /dev/null; then
    echo -e "${YELLOW}Warning: bats is not installed. Shell unit tests will be limited.${NC}"
    echo "Consider installing bats: https://github.com/bats-core/bats-core"
  fi
  
  local test_count=0
  local failed_count=0
  
  # Look for test files
  if [ -d "${TEST_DIR}" ]; then
    mapfile -t TEST_FILES < <(find "${TEST_DIR}" -type f -name "*_test.sh" -o -name "test_*.sh" -o -name "*.bats")
    
    if [ ${#TEST_FILES[@]} -eq 0 ]; then
      echo -e "${YELLOW}No test files found in ${TEST_DIR}${NC}"
      echo "Tests should be named *_test.sh, test_*.sh, or *.bats"
      return 0
    fi
    
    echo "Found ${#TEST_FILES[@]} test files to run"
    
    for test_file in "${TEST_FILES[@]}"; do
      echo -e "${YELLOW}Running test: ${test_file}${NC}"
      test_count=$((test_count+1))
      
      # Run the test file
      if [[ "${test_file}" == *.bats ]]; then
        # Run with bats if available
        if command -v bats &> /dev/null; then
          if bats "${test_file}"; then
            echo -e "${GREEN}✓ Test passed: ${test_file}${NC}"
          else
            echo -e "${RED}✗ Test failed: ${test_file}${NC}"
            failed_count=$((failed_count+1))
          fi
        else
          echo -e "${RED}Cannot run .bats file without bats installed${NC}"
          failed_count=$((failed_count+1))
        fi
      else
        # Run regular shell test
        if bash "${test_file}"; then
          echo -e "${GREEN}✓ Test passed: ${test_file}${NC}"
        else
          echo -e "${RED}✗ Test failed: ${test_file}${NC}"
          failed_count=$((failed_count+1))
        fi
      fi
    done
    
    # Display results summary
    echo ""
    echo -e "${BLUE}Shell Test Summary:${NC}"
    echo "Tests run: ${test_count}"
    echo "Tests failed: ${failed_count}"
    
    if [ $failed_count -gt 0 ]; then
      echo -e "${RED}${failed_count} tests failed${NC}"
      return 1
    else
      echo -e "${GREEN}All shell tests passed!${NC}"
      return 0
    fi
  else
    echo -e "${YELLOW}Test directory not found: ${TEST_DIR}${NC}"
    return 0
  fi
}

# Function to run integration tests
run_integration_tests() {
  echo -e "${BLUE}Running integration tests...${NC}"
  
  # Look for integration test files
  local integration_dir="${TEST_DIR}/integration"
  
  if [ ! -d "${integration_dir}" ]; then
    echo -e "${YELLOW}Integration test directory not found: ${integration_dir}${NC}"
    echo "Create this directory and add integration tests to enable this feature."
    return 0
  fi
  
  mapfile -t INTEGRATION_FILES < <(find "${integration_dir}" -type f -name "*_integration.sh" -o -name "integration_*.sh")
  
  if [ ${#INTEGRATION_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No integration test files found in ${integration_dir}${NC}"
    echo "Integration tests should be named *_integration.sh or integration_*.sh"
    return 0
  fi
  
  echo "Found ${#INTEGRATION_FILES[@]} integration test files to run"
  
  local test_count=0
  local failed_count=0
  
  for test_file in "${INTEGRATION_FILES[@]}"; do
    echo -e "${YELLOW}Running integration test: ${test_file}${NC}"
    test_count=$((test_count+1))
    
    # Run the integration test file
    if bash "${test_file}"; then
      echo -e "${GREEN}✓ Integration test passed: ${test_file}${NC}"
    else
      echo -e "${RED}✗ Integration test failed: ${test_file}${NC}"
      failed_count=$((failed_count+1))
    fi
  done
  
  # Display results summary
  echo ""
  echo -e "${BLUE}Integration Test Summary:${NC}"
  echo "Tests run: ${test_count}"
  echo "Tests failed: ${failed_count}"
  
  if [ $failed_count -gt 0 ]; then
    echo -e "${RED}${failed_count} integration tests failed${NC}"
    return 1
  else
    echo -e "${GREEN}All integration tests passed!${NC}"
    return 0
  fi
}

# Run tests as specified
ERRORS=0

# Run lint tests if enabled
if [ "$RUN_LINT_TESTS" = true ]; then
  echo -e "${BLUE}========== RUNNING LINTING TESTS ==========${NC}"
  
  run_shellcheck
  SHELLCHECK_RESULT=$?
  [ $SHELLCHECK_RESULT -ne 0 ] && ERRORS=$((ERRORS+1))
  
  echo ""
  
  run_shfmt
  SHFMT_RESULT=$?
  [ $SHFMT_RESULT -ne 0 ] && ERRORS=$((ERRORS+1))
  
  echo ""
fi

# Run shell tests if enabled
if [ "$RUN_SHELL_TESTS" = true ]; then
  echo -e "${BLUE}========== RUNNING SHELL SCRIPT TESTS ==========${NC}"
  
  run_shell_tests
  SHELL_TEST_RESULT=$?
  [ $SHELL_TEST_RESULT -ne 0 ] && ERRORS=$((ERRORS+1))
  
  echo ""
fi

# Run integration tests if enabled
if [ "$RUN_INTEGRATION_TESTS" = true ]; then
  echo -e "${BLUE}========== RUNNING INTEGRATION TESTS ==========${NC}"
  
  run_integration_tests
  INTEGRATION_TEST_RESULT=$?
  [ $INTEGRATION_TEST_RESULT -ne 0 ] && ERRORS=$((ERRORS+1))
  
  echo ""
fi

# Display final summary
echo -e "${BLUE}========== TEST SUMMARY ==========${NC}"
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}All tests passed successfully!${NC}"
  exit 0
else
  echo -e "${RED}${ERRORS} test categories had failures${NC}"
  echo "Please check the reports for more details"
  exit 1
fi 