#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_config_validation.sh
# Description: Tests for validating Ephemery configuration files
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-21
#
# This script tests the configuration file structure and values

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source error handling
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"

# Source test configuration
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"

# Initialize test environment
init_test_env() {
  # Parse command line arguments
  local POSITIONAL=()
  MOCK_MODE=false
  VERBOSE_MODE=false

  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --mock)
        MOCK_MODE=true
        shift
        ;;
      --verbose)
        VERBOSE_MODE=true
        shift
        ;;
      *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
  done

  # Restore positional parameters
  set -- "${POSITIONAL[@]:-}"

  # Export mock mode for subprocesses
  export TEST_MOCK_MODE="${MOCK_MODE}"
  export TEST_VERBOSE_MODE="${VERBOSE_MODE}"

  # Initialize mock framework if in mock mode
  if [[ "${MOCK_MODE}" == "true" ]]; then
    source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"
    mock_init
    if [[ "${VERBOSE_MODE}" == "true" ]]; then
      MOCK_VERBOSE=true
    fi
  fi

  # Load configuration
  load_config
  
  # Set CONFIG_FILE variable for tests
  export CONFIG_FILE="${TEST_CONFIG_PATH}"

  echo "=== Running Configuration Validation Tests ==="
  echo "Mock mode: ${MOCK_MODE}"
  echo "Verbose mode: ${VERBOSE_MODE}"
  echo ""
}

# Test if the configuration file exists
test_config_exists() {
  echo "Testing configuration file existence..."
  
  if [[ -f "${CONFIG_FILE}" ]]; then
    echo "PASS: Configuration file exists at ${CONFIG_FILE}"
    return 0
  else
    echo "FAIL: Configuration file does not exist at ${CONFIG_FILE}"
    return 1
  fi
}

# Test if the configuration file has valid YAML syntax
test_config_syntax() {
  echo "Testing configuration file syntax..."
  
  # Use a basic validation approach
  if grep -q ":" "${CONFIG_FILE}" && grep -q "^[a-zA-Z]" "${CONFIG_FILE}"; then
    echo "PASS: Configuration file appears to have valid YAML syntax (basic check)"
    return 0
  else
    echo "FAIL: Configuration file appears to have invalid YAML syntax (basic check)"
    return 1
  fi
}

# Test if the configuration file has required sections
test_config_sections() {
  echo "Testing configuration file sections..."
  
  local missing_sections=0
  
  # Check for required sections
  if ! grep -q "environment:" "${CONFIG_FILE}"; then
    echo "FAIL: Missing required section 'environment'"
    missing_sections=$((missing_sections + 1))
  fi
  
  if ! grep -q "execution:" "${CONFIG_FILE}"; then
    echo "FAIL: Missing required section 'execution'"
    missing_sections=$((missing_sections + 1))
  fi
  
  if ! grep -q "playbooks:" "${CONFIG_FILE}"; then
    echo "FAIL: Missing required section 'playbooks'"
    missing_sections=$((missing_sections + 1))
  fi
  
  if [[ ${missing_sections} -eq 0 ]]; then
    echo "PASS: Configuration file has all required sections"
    return 0
  else
    echo "FAIL: Configuration file is missing ${missing_sections} required sections"
    return 1
  fi
}

# Test if the configuration file has required path values
test_config_paths() {
  echo "Testing configuration file path values..."
  
  local missing_paths=0
  
  # Check for required paths
  if ! grep -q "REPORT_PATH:" "${CONFIG_FILE}"; then
    echo "FAIL: Missing required path 'REPORT_PATH'"
    missing_paths=$((missing_paths + 1))
  fi
  
  if ! grep -q "PLAYBOOKS_PATH:" "${CONFIG_FILE}"; then
    echo "FAIL: Missing required path 'PLAYBOOKS_PATH'"
    missing_paths=$((missing_paths + 1))
  fi
  
  if [[ ${missing_paths} -eq 0 ]]; then
    echo "PASS: Configuration file has all required path values"
    return 0
  else
    echo "FAIL: Configuration file is missing ${missing_paths} required path values"
    return 1
  fi
}

# Run all tests
run_tests() {
  local passed=0
  local failed=0
  local total=0
  
  # Run test_config_exists
  if test_config_exists; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  total=$((total + 1))
  
  # Run test_config_syntax
  if test_config_syntax; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  total=$((total + 1))
  
  # Run test_config_sections
  if test_config_sections; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  total=$((total + 1))
  
  # Run test_config_paths
  if test_config_paths; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  total=$((total + 1))
  
  # Print summary
  echo ""
  echo "=== Test Summary ==="
  echo "Passed: ${passed}"
  echo "Failed: ${failed}"
  echo "Total: ${total}"
  
  # Return success if all tests passed
  if [[ ${failed} -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Clean up test environment
cleanup() {
  # Restore original commands if in mock mode
  if [[ "${MOCK_MODE}" == "true" ]]; then
    restore_commands
  fi
}

# Main function
main() {
  # Initialize test environment
  init_test_env "$@"
  
  # Run tests
  run_tests
  local result=$?
  
  # Clean up
  cleanup
  
  # Return test result
  return ${result}
}

# Run main function
main "$@" 