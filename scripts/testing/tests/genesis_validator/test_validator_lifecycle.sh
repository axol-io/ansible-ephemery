#!/bin/bash
# Version: 1.0.0
# test_validator_lifecycle.sh - Test the complete lifecycle of a genesis validator
# This script verifies the validator from registration to attestation

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# Source test utilities and core utilities with error handling if not found
source "${PROJECT_ROOT}/scripts/core/test_utils.sh" 2>/dev/null || echo "Warning: test_utils.sh not found"
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
LIFECYCLE_TEST_DIR="${TEST_FIXTURE_DIR}/genesis_validator_test"
RESULTS_FILE="${TEST_REPORT_DIR}/validator_lifecycle_test_$(date +%Y%m%d-%H%M%S).log"
TEST_VALIDATOR_KEYS="${LIFECYCLE_TEST_DIR}/validator_keys"

if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  TEST_DURATION=${MOCK_TEST_DURATION:-60}      # 1 minute for mock testing
  ATTESTATION_WAIT=${MOCK_ATTESTATION_WAIT:-5} # 5 seconds in mock mode
else
  TEST_DURATION=1800   # 30 minutes for the full test
  ATTESTATION_WAIT=300 # 5 minutes attestation wait time
fi

# Create report file
create_report_file "${RESULTS_FILE}" "Genesis Validator Lifecycle Test"

# Function to check prerequisites
check_prerequisites() {
  local required_tools="curl jq grep systemctl date bc timeout"

  if ! check_tools "${required_tools}"; then
    report "Missing required tools. Cannot proceed with test." "${RESULTS_FILE}"
    return 1
  fi

  report "All required tools are available." "${RESULTS_FILE}"
  return 0
}

# Function to get validator key path
get_validator_keys_path() {
  local consensus_client=$(get_consensus_client)

  # Common paths for different clients
  case "${consensus_client}" in
    lighthouse)
      echo "/var/lib/ethereum/lighthouse/validators"
      ;;
    prysm)
      echo "/var/lib/ethereum/prysm/validator/keys"
      ;;
    teku)
      echo "/var/lib/ethereum/teku/validator/keys"
      ;;
    nimbus)
      echo "/var/lib/ethereum/nimbus/validator/keys"
      ;;
    lodestar)
      echo "/var/lib/ethereum/lodestar/validator/keys"
      ;;
    *)
      # Default fallback
      echo "/var/lib/ethereum/validator/keys"
      ;;
  esac
}

# Function to check if validator keys exist
check_validator_keys() {
  local keys_path=$(get_validator_keys_path)

  echo -e "${BLUE}Checking for validator keys in ${keys_path}...${NC}"
  report "Checking for validator keys in ${keys_path}..." "${RESULTS_FILE}"

  if [ -d "${keys_path}" ] && [ "$(ls -A "${keys_path}" 2>/dev/null)" ]; then
    local key_count=$(find "${keys_path}" -name "*.json" | wc -l)
    echo -e "${GREEN}✓ Found ${key_count} validator keys${NC}"
    report "✓ Found ${key_count} validator keys" "${RESULTS_FILE}"

    # List first few keys for reference
    local sample_keys=$(find "${keys_path}" -name "*.json" | head -3)
    report "Sample keys:" "${RESULTS_FILE}"
    report "${sample_keys}" "${RESULTS_FILE}"

    return 0
  else
    echo -e "${RED}✗ No validator keys found in ${keys_path}${NC}"
    report "✗ No validator keys found in ${keys_path}" "${RESULTS_FILE}"
    return 1
  fi
}

# Function to check if validator is registered
check_validator_registration() {
  local consensus_client=$(get_consensus_client)
  local validator_count=0

  echo -e "${BLUE}Checking validator registration...${NC}"
  report "Checking validator registration..." "${RESULTS_FILE}"

  # Different APIs for different clients
  validator_count=$(count_active_validators)

  if [ "${validator_count}" -gt 0 ]; then
    echo -e "${GREEN}✓ Found ${validator_count} registered validators${NC}"
    report "✓ Found ${validator_count} registered validators" "${RESULTS_FILE}"
    return 0
  else
    echo -e "${RED}✗ No registered validators found${NC}"
    report "✗ No registered validators found" "${RESULTS_FILE}"
    return 1
  fi
}

# Function to check validator balance
check_validator_balance() {
  local consensus_client=$(get_consensus_client)
  local validator_balance=0
  local validator_index="0" # Use first validator as sample

  echo -e "${BLUE}Checking validator balance...${NC}"
  report "Checking validator balance..." "${RESULTS_FILE}"

  # Get validator index from state
  case "${consensus_client}" in
    lighthouse)
      # Get validator public key
      local keys_path=$(get_validator_keys_path)
      local first_key=$(find "${keys_path}" -name "*.json" | head -1)

      if [ -n "${first_key}" ]; then
        # Extract validator public key from keystore file
        local pubkey=$(jq -r '.pubkey' "${first_key}" 2>/dev/null || echo "")

        if [ -n "${pubkey}" ]; then
          # Get validator index
          validator_index=$(curl -s "http://localhost:5052/eth/v1/beacon/states/head/validators/${pubkey}" | jq -r '.data.index' 2>/dev/null || echo "0")
        fi
      fi

      # Get validator balance if we have an index
      if [ "${validator_index}" != "null" ] && [ "${validator_index}" != "0" ]; then
        validator_balance=$(curl -s "http://localhost:5052/eth/v1/beacon/states/head/validators/${validator_index}" | jq -r '.data.balance' 2>/dev/null || echo "0")
      fi
      ;;
      # Add cases for other clients as needed
  esac

  # Convert balance from Gwei to ETH
  local balance_eth=$(echo "scale=9; ${validator_balance} / 1000000000" | bc)

  if [ "${validator_balance}" -gt 0 ]; then
    echo -e "${GREEN}✓ Validator has a balance of ${balance_eth} ETH${NC}"
    report "✓ Validator has a balance of ${balance_eth} ETH" "${RESULTS_FILE}"
    return 0
  else
    echo -e "${YELLOW}! Validator has zero balance${NC}"
    report "! Validator has zero balance" "${RESULTS_FILE}"
    return 1
  fi
}

# Function to check if validator is actively attesting
check_validator_attestations() {
  local consensus_client=$(get_consensus_client)
  local attestations_found=false

  echo -e "${BLUE}Checking validator attestations...${NC}"
  report "Checking validator attestations..." "${RESULTS_FILE}"

  # Different methods for different clients
  case "${consensus_client}" in
    lighthouse)
      local validator_metrics=$(curl -s http://localhost:5064/metrics)

      if echo "${validator_metrics}" | grep -q "validator_attestation_published"; then
        local attestation_count=$(echo "${validator_metrics}" | grep "validator_attestation_published" | awk '{print $2}')

        if [ "${attestation_count}" -gt 0 ]; then
          attestations_found=true
          echo -e "${GREEN}✓ Found ${attestation_count} published attestations${NC}"
          report "✓ Found ${attestation_count} published attestations" "${RESULTS_FILE}"
        fi
      fi
      ;;
      # Add cases for other clients as needed
  esac

  if ${attestations_found}; then
    return 0
  else
    echo -e "${YELLOW}! No attestations found yet${NC}"
    report "! No attestations found yet" "${RESULTS_FILE}"
    return 1
  fi
}

# Function to monitor for attestations with timeout
monitor_attestations() {
  local max_wait=$1
  local check_interval=60 # Check every minute
  local waited=0

  echo -e "${BLUE}Monitoring for attestations (max wait: ${max_wait}s)...${NC}"
  report "Monitoring for attestations (max wait: ${max_wait}s)..." "${RESULTS_FILE}"

  while [ ${waited} -lt ${max_wait} ]; do
    echo -e "${YELLOW}Checking for attestations after ${waited}s...${NC}"
    report "Checking for attestations after ${waited}s..." "${RESULTS_FILE}"

    if check_validator_attestations; then
      echo -e "${GREEN}✓ Attestations detected after ${waited}s${NC}"
      report "✓ Attestations detected after ${waited}s" "${RESULTS_FILE}"
      return 0
    fi

    # Wait and increment counter
    sleep ${check_interval}
    waited=$((waited + check_interval))
  done

  echo -e "${RED}✗ No attestations detected within ${max_wait}s${NC}"
  report "✗ No attestations detected within ${max_wait}s" "${RESULTS_FILE}"
  return 1
}

# Function to check validator performance
check_validator_performance() {
  local consensus_client=$(get_consensus_client)

  echo -e "${BLUE}Checking validator performance...${NC}"
  report "Checking validator performance..." "${RESULTS_FILE}"

  # Different methods for different clients
  case "${consensus_client}" in
    lighthouse)
      local validator_metrics=$(curl -s http://localhost:5064/metrics)

      # Extract performance metrics
      local attestations_total=$(echo "${validator_metrics}" | grep "validator_attestation_published" | awk '{print $2}' || echo "0")
      local missed_attestations=$(echo "${validator_metrics}" | grep "validator_attestation_missed" | awk '{print $2}' || echo "0")

      if [ -n "${attestations_total}" ] && [ -n "${missed_attestations}" ]; then
        local total=$((attestations_total + missed_attestations))

        if [ ${total} -gt 0 ]; then
          local success_rate=$(echo "scale=2; (${attestations_total} * 100) / ${total}" | bc)

          echo -e "${GREEN}✓ Validator performance: ${success_rate}% successful attestations${NC}"
          report "✓ Validator performance: ${success_rate}% successful attestations" "${RESULTS_FILE}"
          report "  Total attestations: ${attestations_total}" "${RESULTS_FILE}"
          report "  Missed attestations: ${missed_attestations}" "${RESULTS_FILE}"

          if [ $(echo "${success_rate} > 90" | bc) -eq 1 ]; then
            return 0
          else
            return 1
          fi
        fi
      fi
      ;;
      # Add cases for other clients as needed
  esac

  echo -e "${YELLOW}! Insufficient data to evaluate validator performance${NC}"
  report "! Insufficient data to evaluate validator performance" "${RESULTS_FILE}"
  return 1
}

# Function to validate genesis validator setup
validate_genesis_setup() {
  echo -e "${BLUE}Validating genesis validator setup...${NC}"
  report "Validating genesis validator setup..." "${RESULTS_FILE}"

  # Check client services
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)

  echo -e "${BLUE}Checking client services...${NC}"
  report "Checking client services:" "${RESULTS_FILE}"

  if ! is_service_running "${execution_client}"; then
    echo -e "${RED}✗ Execution client service (${execution_client}) is not running${NC}"
    report "✗ Execution client service (${execution_client}) is not running" "${RESULTS_FILE}"
    return 1
  fi

  if ! is_service_running "${consensus_client}"; then
    echo -e "${RED}✗ Consensus client service (${consensus_client}) is not running${NC}"
    report "✗ Consensus client service (${consensus_client}) is not running" "${RESULTS_FILE}"
    return 1
  fi

  # Handle validator service (which may be separate or combined)
  if ! is_service_running "${consensus_client}-validator" && ! grep -q "validator" <<<"${consensus_client}"; then
    echo -e "${RED}✗ Validator service is not running${NC}"
    report "✗ Validator service is not running" "${RESULTS_FILE}"
    return 1
  fi

  echo -e "${GREEN}✓ All required services are running${NC}"
  report "✓ All required services are running" "${RESULTS_FILE}"

  # Check sync status
  echo -e "${BLUE}Checking sync status...${NC}"
  report "Checking sync status:" "${RESULTS_FILE}"

  if ! is_execution_synced; then
    echo -e "${RED}✗ Execution client is not synced${NC}"
    report "✗ Execution client is not synced" "${RESULTS_FILE}"
    return 1
  fi

  if ! is_consensus_synced; then
    echo -e "${RED}✗ Consensus client is not synced${NC}"
    report "✗ Consensus client is not synced" "${RESULTS_FILE}"
    return 1
  fi

  echo -e "${GREEN}✓ Clients are in sync${NC}"
  report "✓ Clients are in sync" "${RESULTS_FILE}"

  return 0
}

# Function to run the validator lifecycle test
run_validator_lifecycle_test() {
  echo -e "${BLUE}Starting genesis validator lifecycle test...${NC}"
  report "Starting genesis validator lifecycle test..." "${RESULTS_FILE}"

  # Validate setup
  if ! validate_genesis_setup; then
    echo -e "${RED}✗ Validator setup validation failed. Cannot proceed with test.${NC}"
    report "✗ Validator setup validation failed. Cannot proceed with test." "${RESULTS_FILE}"
    return 1
  fi

  # Check for validator keys
  if ! check_validator_keys; then
    echo -e "${RED}✗ Validator keys check failed. Cannot proceed with test.${NC}"
    report "✗ Validator keys check failed. Cannot proceed with test." "${RESULTS_FILE}"
    return 1
  fi

  # Check validator registration
  if ! check_validator_registration; then
    echo -e "${RED}✗ Validator registration check failed. Cannot proceed with test.${NC}"
    report "✗ Validator registration check failed. Cannot proceed with test." "${RESULTS_FILE}"
    return 1
  fi

  # Check validator balance (optional)
  check_validator_balance

  # Monitor for attestations
  if ! monitor_attestations ${TEST_DURATION}; then
    echo -e "${RED}✗ Failed to detect attestations within timeout period.${NC}"
    report "✗ Failed to detect attestations within timeout period." "${RESULTS_FILE}"
    return 1
  fi

  # Check validator performance (after some attestations)
  sleep ${ATTESTATION_WAIT} # Wait a bit to collect more attestations
  check_validator_performance

  echo -e "${GREEN}✓ Genesis validator lifecycle test completed successfully${NC}"
  report "✓ Genesis validator lifecycle test completed successfully" "${RESULTS_FILE}"
  return 0
}

# Main function
main() {
  echo -e "${BLUE}Genesis Validator Lifecycle Test${NC}"

  # Check prerequisites
  check_prerequisites

  # Run the test
  if run_validator_lifecycle_test; then
    echo -e "${GREEN}✓ Validator lifecycle test passed${NC}"
    report_result "passed" "Validator lifecycle test" "${RESULTS_FILE}"

    # Cleanup mock environment if used
    if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
      restore_commands
    fi

    return 0
  else
    echo -e "${RED}✗ Validator lifecycle test failed${NC}"
    report_result "failed" "Validator lifecycle test" "${RESULTS_FILE}"

    # Cleanup mock environment if used
    if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
      restore_commands
    fi

    return 1
  fi
}

# Run main function
main "$@"
