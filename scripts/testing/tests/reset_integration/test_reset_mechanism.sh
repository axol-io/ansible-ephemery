#!/bin/bash
# Version: 1.0.0
# test_reset_mechanism.sh - Integration tests for the Ephemery reset mechanism
# This script tests the functionality of the reset mechanism to ensure proper handling
# of network resets, validator key restoration, and system recovery.

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../../" &>/dev/null && pwd)"

# Source core utilities
source "${PROJECT_ROOT}/scripts/core/path_config.sh"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
source "${PROJECT_ROOT}/scripts/core/common.sh"

# Setup error handling
setup_error_handling

# Test configuration
DEFAULT_TEST_DIR="${PROJECT_ROOT}/scripts/testing/fixtures/reset_test"
TEST_DIR="${1:-$DEFAULT_TEST_DIR}"
RETENTION_SCRIPT="${PROJECT_ROOT}/scripts/core/ephemery_retention.sh"
GENESIS_TIME_FILE="${TEST_DIR}/genesis_time.txt"
MOCK_GENESIS_FILE="${TEST_DIR}/mock_genesis.json"
TEST_VALIDATOR_KEYS="${TEST_DIR}/validator_keys"
TEST_DURATION=300 # 5 minutes for the full test

# Results file
RESULTS_FILE="${PROJECT_ROOT}/scripts/testing/reports/reset_integration_$(date +%Y%m%d-%H%M%S).log"

# Create report header
{
  echo "Ephemery Reset Mechanism Integration Test Report"
  echo "================================================"
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Test directory: ${TEST_DIR}"
  echo "--------------------------------------------------------"
  echo ""
} >"${RESULTS_FILE}"

# Setup test environment
setup_test_env() {
  echo -e "${BLUE}Setting up test environment in ${TEST_DIR}${NC}"

  # Create test directory
  mkdir -p "${TEST_DIR}"
  mkdir -p "${TEST_VALIDATOR_KEYS}"

  # Create initial mock genesis time (current time - 1 day)
  initial_genesis_time=$(($(date +%s) - 86400))
  echo "${initial_genesis_time}" >"${GENESIS_TIME_FILE}"

  # Create mock genesis.json file
  cat >"${MOCK_GENESIS_FILE}" <<EOF
{
  "genesis_time": "${initial_genesis_time}",
  "genesis_validators_root": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "genesis_fork_version": "0x00000001"
}
EOF

  # Create mock validator keys
  for i in {1..3}; do
    mkdir -p "${TEST_VALIDATOR_KEYS}/validator_${i}"
    touch "${TEST_VALIDATOR_KEYS}/validator_${i}/keystore-m_12381_3600_${i}_0_0-1.json"
    echo "password123" >"${TEST_VALIDATOR_KEYS}/validator_${i}/password.txt"
  done

  # Create backup directory
  mkdir -p "${TEST_DIR}/backups"

  echo "Test environment setup complete" >>"${RESULTS_FILE}"
}

# Mock function to simulate beacon API
mock_beacon_api() {
  # Create a modified genesis time to simulate a reset
  local new_genesis_time=$(($(date +%s) + 300)) # 5 minutes in the future

  # Update mock genesis file
  cat >"${MOCK_GENESIS_FILE}" <<EOF
{
  "genesis_time": "${new_genesis_time}",
  "genesis_validators_root": "0x1111111111111111111111111111111111111111111111111111111111111111",
  "genesis_fork_version": "0x00000002"
}
EOF

  echo "${new_genesis_time}" >"${GENESIS_TIME_FILE}"
  echo "Mock beacon API updated genesis time to ${new_genesis_time}" >>"${RESULTS_FILE}"
}

# Test reset detection
test_reset_detection() {
  echo -e "${BLUE}Testing reset detection${NC}"
  echo "Testing reset detection..." >>"${RESULTS_FILE}"

  # Record initial genesis time
  initial_genesis_time=$(cat "${GENESIS_TIME_FILE}")
  echo "Initial genesis time: ${initial_genesis_time}" >>"${RESULTS_FILE}"

  # Modify the retention script to use our test files
  local temp_retention_script="${TEST_DIR}/retention_test.sh"
  cp "${RETENTION_SCRIPT}" "${temp_retention_script}"

  # Create a custom get_genesis_time function for the test
  cat > "${TEST_DIR}/get_genesis_time.sh" << EOF
#!/bin/bash
get_genesis_time() {
  cat "${GENESIS_TIME_FILE}"
}
EOF

  # Source the custom function in the test
  echo "source \"${TEST_DIR}/get_genesis_time.sh\"" > "${temp_retention_script}.tmp"
  echo "GENESIS_TIME_FILE=\"${GENESIS_TIME_FILE}\"" >> "${temp_retention_script}.tmp"
  cat "${temp_retention_script}" >> "${temp_retention_script}.tmp"
  mv "${temp_retention_script}.tmp" "${temp_retention_script}"
  chmod +x "${temp_retention_script}"

  # Run the retention script once to establish baseline
  if bash "${temp_retention_script}" --test-mode --test-dir="${TEST_DIR}"; then
    echo "✓ Initial retention script execution successful" >>"${RESULTS_FILE}"
  else
    echo "✗ Initial retention script execution failed" >>"${RESULTS_FILE}"
    return 1
  fi

  # Simulate a genesis time change
  mock_beacon_api

  # Run the retention script again, should detect reset
  if output=$(bash "${temp_retention_script}" --test-mode --test-dir="${TEST_DIR}" 2>&1); then
    if echo "${output}" | grep -q "Reset detected"; then
      echo "✓ Reset correctly detected" >>"${RESULTS_FILE}"
      echo -e "${GREEN}✓ Reset detection test passed${NC}"
    else
      echo "✗ Reset not detected when it should have been" >>"${RESULTS_FILE}"
      echo -e "${RED}✗ Reset detection test failed${NC}"
      return 1
    fi
  else
    echo "✗ Retention script failed after genesis time change" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Retention script execution failed${NC}"
    return 1
  fi

  return 0
}

# Test key backup functionality
test_key_backup() {
  echo -e "${BLUE}Testing validator key backup${NC}"
  echo "Testing validator key backup..." >>"${RESULTS_FILE}"

  # Simulate backup process
  local backup_dir="${TEST_DIR}/backups/keys_backup_$(date +%Y%m%d%H%M%S)"
  mkdir -p "${backup_dir}"

  # Copy keys to backup
  if cp -r "${TEST_VALIDATOR_KEYS}/"* "${backup_dir}/"; then
    echo "✓ Key backup created successfully" >>"${RESULTS_FILE}"
    echo -e "${GREEN}✓ Key backup test passed${NC}"
  else
    echo "✗ Key backup creation failed" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Key backup test failed${NC}"
    return 1
  fi

  # Verify backup contains all keys
  local original_count=$(find "${TEST_VALIDATOR_KEYS}" -name "keystore-m*.json" | wc -l | xargs)
  local backup_count=$(find "${backup_dir}" -name "keystore-m*.json" | wc -l | xargs)

  if [ "${original_count}" -eq "${backup_count}" ]; then
    echo "✓ Backup contains all ${original_count} validator keys" >>"${RESULTS_FILE}"
  else
    echo "✗ Backup is missing keys: found ${backup_count}, expected ${original_count}" >>"${RESULTS_FILE}"
    return 1
  fi

  return 0
}

# Test key restoration process
test_key_restoration() {
  echo -e "${BLUE}Testing validator key restoration${NC}"
  echo "Testing validator key restoration..." >>"${RESULTS_FILE}"

  # Remove keys to simulate post-reset state
  rm -rf "${TEST_VALIDATOR_KEYS:?}"/*
  mkdir -p "${TEST_VALIDATOR_KEYS}"

  # Get the most recent backup
  local latest_backup=$(find "${TEST_DIR}/backups" -type d -name "keys_backup_*" | sort | tail -n 1)

  if [ -z "${latest_backup}" ]; then
    echo "✗ No backup found for restoration" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Key restoration test failed: No backup found${NC}"
    return 1
  fi

  # Restore keys
  if cp -r "${latest_backup}/"* "${TEST_VALIDATOR_KEYS}/"; then
    echo "✓ Keys restored successfully from ${latest_backup}" >>"${RESULTS_FILE}"
  else
    echo "✗ Key restoration failed" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Key restoration test failed${NC}"
    return 1
  fi

  # Verify restoration
  local restored_count=$(find "${TEST_VALIDATOR_KEYS}" -name "keystore-m*.json" | wc -l | xargs)
  local expected_count=3

  if [ "${restored_count}" -eq "${expected_count}" ]; then
    echo "✓ All ${expected_count} keys restored successfully" >>"${RESULTS_FILE}"
    echo -e "${GREEN}✓ Key restoration test passed${NC}"
  else
    echo "✗ Key restoration incomplete: found ${restored_count}, expected ${expected_count}" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Key restoration test failed${NC}"
    return 1
  fi

  return 0
}

# Run all tests
run_tests() {
  local errors=0

  # Set up test environment
  setup_test_env

  # Run tests
  if ! test_reset_detection; then
    errors=$((errors + 1))
  fi

  if ! test_key_backup; then
    errors=$((errors + 1))
  fi

  if ! test_key_restoration; then
    errors=$((errors + 1))
  fi

  # Test summary
  {
    echo ""
    echo "Reset Integration Test Summary"
    echo "=============================="
    if [ ${errors} -eq 0 ]; then
      echo "All tests PASSED"
      echo -e "${GREEN}All reset integration tests passed!${NC}"
    else
      echo "${errors} tests FAILED"
      echo -e "${RED}${errors} reset integration tests failed${NC}"
    fi
  } | tee -a "${RESULTS_FILE}"

  # Return error count
  return ${errors}
}

# Clean up test environment
cleanup() {
  if [ -d "${TEST_DIR}" ]; then
    echo -e "${BLUE}Cleaning up test environment${NC}"
    rm -rf "${TEST_DIR}"
  fi
}

# Main execution
main() {
  echo -e "${BLUE}Starting Ephemery reset mechanism integration tests${NC}"

  # Run tests
  run_tests
  local test_result=$?

  # Clean up test environment (comment this out for debugging)
  # cleanup

  echo "Complete test report available at: ${RESULTS_FILE}"

  return ${test_result}
}

# Run main function
main "$@"
