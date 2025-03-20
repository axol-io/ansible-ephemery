#!/bin/bash
# Version: 1.0.0
# test_genesis_validator_setup.sh - Tests for genesis validator setup and functionality
# This script verifies that genesis validators can be properly configured, deployed,
# and function correctly in an Ephemery testnet environment.

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# Source core utilities (with error handling if not found)
source "${PROJECT_ROOT}/scripts/core/path_config.sh" 2>/dev/null || echo "Warning: path_config.sh not found"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh" 2>/dev/null || echo "Warning: error_handling.sh not found"
source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" 2>/dev/null || echo "Warning: common_consolidated.sh not found"

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

# Initialize test environment
init_test_env() {
  # Create test report directory if it doesn't exist
  TEST_REPORT_DIR="${PROJECT_ROOT}/scripts/testing/reports"
  mkdir -p "${TEST_REPORT_DIR}"

  # Set up mock environment if enabled
  if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
    # Ensure test_mock.sh is sourced
    if ! type mock_init &>/dev/null; then
      source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"
      mock_init
      override_commands
    fi

    # Register default mock behavior for common tools
    mock_register "systemctl" "success"
    mock_register "curl" "success"
    mock_register "ansible-playbook" "success"
    mock_register "geth" "success"
    mock_register "lighthouse" "success"

    # Use shorter test duration in mock mode
    MOCK_TEST_DURATION=60 # 1 minute for mock testing
  fi

  # Create a temporary directory for test artifacts
  TEST_TMP_DIR=$(mktemp -d -t "ephemery_test_XXXXXX")
  export TEST_TMP_DIR

  # Set the fixture directory
  TEST_FIXTURE_DIR="${PROJECT_ROOT}/scripts/testing/fixtures"
  export TEST_FIXTURE_DIR

  echo "Test environment initialized"
  echo "- Project root: ${PROJECT_ROOT}"
  echo "- Report directory: ${TEST_REPORT_DIR}"
  echo "- Temporary directory: ${TEST_TMP_DIR}"
  echo "- Mock mode: ${TEST_MOCK_MODE:-false}"
  echo "- Fixture directory: ${TEST_FIXTURE_DIR}"
}

# Initialize test environment
init_test_env

# Setup error handling if function exists
if type setup_error_handling &>/dev/null; then
  setup_error_handling
fi

# Test configuration - adjust based on mock mode
GENESIS_TEST_DIR="${TEST_FIXTURE_DIR}/genesis_validator_test"
RESULTS_FILE="${TEST_REPORT_DIR}/genesis_validator_test_$(date +%Y%m%d-%H%M%S).log"
TEST_VALIDATOR_KEYS="${GENESIS_TEST_DIR}/validator_keys"

if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  TEST_DURATION=${MOCK_TEST_DURATION:-60} # 1 minute for mock testing
else
  TEST_DURATION=600 # 10 minutes for the full test
fi

# Create results directory
mkdir -p "$(dirname "${RESULTS_FILE}")"

# Create report header
{
  echo "Ephemery Genesis Validator Test Report"
  echo "======================================"
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Test directory: ${GENESIS_TEST_DIR}"
  echo "--------------------------------------------------------"
  echo ""
} >"${RESULTS_FILE}"

# Function to set up the test environment
setup_test_env() {
  echo -e "${BLUE}Setting up genesis validator test environment${NC}"
  echo "Setting up genesis validator test environment" >>"${RESULTS_FILE}"

  # Create test directory
  mkdir -p "${GENESIS_TEST_DIR}"
  mkdir -p "${TEST_VALIDATOR_KEYS}"

  # Generate test validator keys
  echo "Generating test validator keys..." >>"${RESULTS_FILE}"

  # Check if eth2-val-tools is installed
  if ! command -v eth2-val-tools &>/dev/null; then
    echo "⚠️ eth2-val-tools not installed, using mock validator keys" >>"${RESULTS_FILE}"

    # Create mock validator keys
    for i in {1..3}; do
      mkdir -p "${TEST_VALIDATOR_KEYS}/validator_${i}"
      touch "${TEST_VALIDATOR_KEYS}/validator_${i}/keystore-m_12381_3600_${i}_0_0-1.json"
      echo "password123" >"${TEST_VALIDATOR_KEYS}/validator_${i}/password.txt"
    done
  else
    # Generate actual validator keys using eth2-val-tools
    eth2-val-tools deposit-data \
      --source-min=0 \
      --source-max=2 \
      --fork-version=0x00000000 \
      --withdrawals-mnemonic="test test test test test test test test test test test junk" \
      --validators-mnemonic="test test test test test test test test test test test junk" \
      >"${GENESIS_TEST_DIR}/deposit-data.json"

    # Generate keystores
    eth2-val-tools keystores \
      --source-min=0 \
      --source-max=2 \
      --validators-mnemonic="test test test test test test test test test test test junk" \
      --wallet-password="password123" \
      --out-loc="${TEST_VALIDATOR_KEYS}"
  fi

  echo "✓ Test environment setup complete" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Test environment setup complete${NC}"

  return 0
}

# Function to test validator key import
test_validator_key_import() {
  echo -e "${BLUE}Testing validator key import${NC}"
  echo "Testing validator key import..." >>"${RESULTS_FILE}"

  # Create inventory file for validator setup
  local inventory_file="${GENESIS_TEST_DIR}/inventory.yaml"

  cat >"${inventory_file}" <<EOF
all:
  hosts:
    ephemery_genesis_test:
      ansible_connection: local
      execution_client: geth
      consensus_client: lighthouse
      validator_client: lighthouse
      network_name: ephemery
      setup_validator: true
      validator_keys_dir: ./validator_keys
      is_genesis_validator: true
      checkpoint_sync_url: https://beaconstate.info
      enable_metrics: true
      enable_watchtower: true
      data_dir: ./data
EOF

  # Run ansible in check mode to verify configuration
  echo "Verifying validator configuration..." >>"${RESULTS_FILE}"
  if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${inventory_file}" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml" --check --tags validator; then
    echo "✗ Validator configuration check failed" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator key import test failed${NC}"
    return 1
  fi

  echo "✓ Validator configuration check passed" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Validator key import test passed${NC}"

  return 0
}

# Function to test validator deployment
test_validator_deployment() {
  echo -e "${BLUE}Testing validator deployment${NC}"
  echo "Testing validator deployment..." >>"${RESULTS_FILE}"

  # Use the inventory file created in the previous test
  local inventory_file="${GENESIS_TEST_DIR}/inventory.yaml"

  # Deploy validator
  echo "Deploying validator..." >>"${RESULTS_FILE}"
  if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${inventory_file}" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml" --tags validator; then
    echo "✗ Validator deployment failed" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator deployment test failed${NC}"
    return 1
  fi

  # Check if validator container is running
  if ! docker ps | grep -q "ephemery_lighthouse_validator"; then
    echo "✗ Validator container not running after deployment" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator deployment test failed${NC}"
    return 1
  fi

  echo "✓ Validator container is running" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Validator deployment test passed${NC}"

  return 0
}

# Function to test validator key backup
test_validator_key_backup() {
  echo -e "${BLUE}Testing validator key backup${NC}"
  echo "Testing validator key backup..." >>"${RESULTS_FILE}"

  # Create backup directory
  local backup_dir="${GENESIS_TEST_DIR}/backups"
  mkdir -p "${backup_dir}"

  # Run backup script if it exists
  if [ -f "${PROJECT_ROOT}/scripts/validator/backup_validator_keys.sh" ]; then
    echo "Running validator key backup script..." >>"${RESULTS_FILE}"
    if ! "${PROJECT_ROOT}/scripts/validator/backup_validator_keys.sh" --source "${TEST_VALIDATOR_KEYS}" --destination "${backup_dir}" --test-mode; then
      echo "✗ Validator key backup script failed" >>"${RESULTS_FILE}"
      echo -e "${RED}✗ Validator key backup test failed${NC}"
      return 1
    fi
  else
    # Manual backup if script doesn't exist
    echo "Backup script not found, performing manual backup..." >>"${RESULTS_FILE}"
    local backup_file="${backup_dir}/validator_keys_backup_$(date +%Y%m%d%H%M%S).tar.gz"
    if ! tar -czf "${backup_file}" -C "$(dirname "${TEST_VALIDATOR_KEYS}")" "$(basename "${TEST_VALIDATOR_KEYS}")"; then
      echo "✗ Manual validator key backup failed" >>"${RESULTS_FILE}"
      echo -e "${RED}✗ Validator key backup test failed${NC}"
      return 1
    fi
  fi

  # Verify backup exists
  if [ ! -d "${backup_dir}" ] || [ -z "$(ls -A "${backup_dir}")" ]; then
    echo "✗ Backup directory is empty or doesn't exist" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator key backup test failed${NC}"
    return 1
  fi

  echo "✓ Validator key backup created successfully" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Validator key backup test passed${NC}"

  return 0
}

# Function to test validator monitoring
test_validator_monitoring() {
  echo -e "${BLUE}Testing validator monitoring${NC}"
  echo "Testing validator monitoring..." >>"${RESULTS_FILE}"

  # Check if Prometheus is running
  if ! docker ps | grep -q "ephemery_prometheus"; then
    echo "⚠️ Prometheus container not running, skipping monitoring test" >>"${RESULTS_FILE}"
    echo -e "${YELLOW}⚠️ Validator monitoring test skipped${NC}"
    return 0
  fi

  # Check if validator metrics endpoint is accessible
  local validator_container="ephemery_lighthouse_validator"
  local metrics_port=5064

  if ! docker exec "${validator_container}" curl -s "http://localhost:${metrics_port}/metrics" &>/dev/null; then
    echo "✗ Validator metrics endpoint not accessible" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator monitoring test failed${NC}"
    return 1
  fi

  echo "✓ Validator metrics endpoint is accessible" >>"${RESULTS_FILE}"

  # Check for specific validator metrics
  if ! docker exec "${validator_container}" curl -s "http://localhost:${metrics_port}/metrics" | grep -q "validator_"; then
    echo "✗ Validator-specific metrics not found" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Validator monitoring test failed${NC}"
    return 1
  fi

  echo "✓ Validator-specific metrics found" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Validator monitoring test passed${NC}"

  return 0
}

# Function to test reset handling for genesis validators
test_reset_handling() {
  echo -e "${BLUE}Testing reset handling for genesis validators${NC}"
  echo "Testing reset handling for genesis validators..." >>"${RESULTS_FILE}"

  # Check if retention script exists
  if [ ! -f "${PROJECT_ROOT}/scripts/core/retention.sh" ]; then
    echo "⚠️ Retention script not found, skipping reset handling test" >>"${RESULTS_FILE}"
    echo -e "${YELLOW}⚠️ Reset handling test skipped${NC}"
    return 0
  fi

  # Create a modified version of the retention script for testing
  local test_retention_script="${GENESIS_TEST_DIR}/test_retention.sh"
  cp "${PROJECT_ROOT}/scripts/core/retention.sh" "${test_retention_script}"

  # Modify the script to use test mode
  sed -i.bak 's|VALIDATOR_KEYS_DIR=.*|VALIDATOR_KEYS_DIR="'"${TEST_VALIDATOR_KEYS}"'"|g' "${test_retention_script}"

  # Run the retention script in test mode
  echo "Running retention script in test mode..." >>"${RESULTS_FILE}"
  if ! bash "${test_retention_script}" --test-mode; then
    echo "✗ Retention script failed in test mode" >>"${RESULTS_FILE}"
    echo -e "${RED}✗ Reset handling test failed${NC}"
    return 1
  fi

  echo "✓ Retention script executed successfully in test mode" >>"${RESULTS_FILE}"
  echo -e "${GREEN}✓ Reset handling test passed${NC}"

  return 0
}

# Clean up test environment
cleanup() {
  echo -e "${BLUE}Cleaning up genesis validator test environment${NC}"
  echo "Cleaning up genesis validator test environment" >>"${RESULTS_FILE}"

  # Stop and remove containers
  docker stop ephemery_lighthouse_validator ephemery_lighthouse ephemery_geth || true
  docker rm ephemery_lighthouse_validator ephemery_lighthouse ephemery_geth || true

  # Remove test directory (optional - keep for debugging)
  # rm -rf "${GENESIS_TEST_DIR}"

  echo "Cleanup complete" >>"${RESULTS_FILE}"

  return 0
}

# Main function to run all tests
main() {
  echo -e "${BLUE}Starting Ephemery genesis validator tests${NC}"

  # Track test results
  local errors=0

  # Setup test environment
  setup_test_env

  # Run tests
  if ! test_validator_key_import; then
    errors=$((errors + 1))
  fi

  if ! test_validator_deployment; then
    errors=$((errors + 1))
  fi

  if ! test_validator_key_backup; then
    errors=$((errors + 1))
  fi

  if ! test_validator_monitoring; then
    errors=$((errors + 1))
  fi

  if ! test_reset_handling; then
    errors=$((errors + 1))
  fi

  # Generate summary
  {
    echo ""
    echo "Genesis Validator Test Summary"
    echo "============================="
    echo "Tests completed: 5"

    local pass_count=$(grep -c "✓.*test passed" "${RESULTS_FILE}")
    local skip_count=$(grep -c "⚠️.*test skipped" "${RESULTS_FILE}")
    local fail_count=${errors}

    echo "Tests passed: ${pass_count}"
    echo "Tests skipped: ${skip_count}"
    echo "Tests failed: ${fail_count}"

    if [ ${fail_count} -eq 0 ]; then
      echo "OVERALL RESULT: PASSED"
    else
      echo "OVERALL RESULT: FAILED"
    fi
  } | tee -a "${RESULTS_FILE}"

  # Cleanup
  cleanup

  echo -e "${GREEN}Genesis validator testing completed. Full report available at:${NC}"
  echo "${RESULTS_FILE}"

  # Cleanup mock environment if used
  if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
    restore_commands
  fi

  return ${errors}
}

# Run main function
main "$@"
