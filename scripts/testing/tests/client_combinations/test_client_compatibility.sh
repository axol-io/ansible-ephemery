#!/bin/bash
# Version: 1.0.0
# test_client_compatibility.sh - Test compatibility between different client combinations
# This script verifies that all supported client combinations can be properly deployed
# and function correctly in an Ephemery testnet environment.

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# Source core utilities with error handling if not found
source "${PROJECT_ROOT}/scripts/core/path_config.sh" 2>/dev/null || echo "Warning: path_config.sh not found"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh" 2>/dev/null || echo "Warning: error_handling.sh not found"
source "${PROJECT_ROOT}/scripts/core/common.sh" 2>/dev/null || echo "Warning: core/common.sh not found"

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
    mock_register "teku" "success"
    mock_register "nimbus" "success"
    mock_register "prysm" "success"
    mock_register "nethermind" "success"
    mock_register "besu" "success"
    
    # Use shorter intervals in mock mode
    MOCK_TEST_DURATION=60    # 60 seconds instead of longer periods
    MOCK_WAIT_INTERVAL=5     # 5 seconds instead of longer wait times
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
RESULTS_FILE="${TEST_REPORT_DIR}/client_compatibility_test_$(date +%Y%m%d-%H%M%S).log"

if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  TEST_DURATION=${MOCK_TEST_DURATION:-60}  # 1 minute for mock testing
  WAIT_INTERVAL=${MOCK_WAIT_INTERVAL:-5}   # 5 seconds wait interval
else
  TEST_DURATION=600                        # 10 minutes for the full test
  WAIT_INTERVAL=30                         # 30 seconds wait interval
fi

# Define supported clients
EXECUTION_CLIENTS=("geth" "nethermind" "besu" "erigon")
CONSENSUS_CLIENTS=("lighthouse" "prysm" "teku" "nimbus" "lodestar")

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Create report header
{
  echo "Ephemery Client Compatibility Test Report"
  echo "========================================"
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "--------------------------------------------------------"
  echo ""
} > "${RESULTS_FILE}"

# Function to test a specific client combination
test_client_combination() {
  local execution_client=$1
  local consensus_client=$2
  
  echo -e "${BLUE}Testing combination: ${execution_client} + ${consensus_client}${NC}"
  echo "Testing: ${execution_client} + ${consensus_client}" >> "${RESULTS_FILE}"
  
  # Create temporary inventory file for this test
  local temp_inventory="${PROJECT_ROOT}/scripts/testing/fixtures/temp_inventory_${execution_client}_${consensus_client}.yaml"
  
  # Create inventory file with the client combination
  cat > "${temp_inventory}" << EOF
all:
  hosts:
    ephemery_test:
      ansible_connection: local
      execution_client: ${execution_client}
      consensus_client: ${consensus_client}
      validator_client: ${consensus_client}
      network_name: ephemery
      setup_validator: true
      checkpoint_sync_url: https://beaconstate.info
      enable_metrics: true
      enable_watchtower: true
EOF

  # Increment total tests
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  # Attempt to run a test deployment in check mode
  if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${temp_inventory}" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml" --check; then
    echo -e "${GREEN}✓ Compatibility check passed for ${execution_client} + ${consensus_client}${NC}"
    echo "✓ PASSED: Compatibility check" >> "${RESULTS_FILE}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}✗ Compatibility check failed for ${execution_client} + ${consensus_client}${NC}"
    echo "✗ FAILED: Compatibility check" >> "${RESULTS_FILE}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  
  echo "" >> "${RESULTS_FILE}"
  echo "--------------------------------------------------------" >> "${RESULTS_FILE}"
  echo "" >> "${RESULTS_FILE}"
}

# Function to check if a client is supported in the current environment
is_client_supported() {
  local client_type=$1
  local client_name=$2
  
  # Check if client-specific tasks exist
  if [ "${client_type}" == "execution" ]; then
    if [ ! -d "${PROJECT_ROOT}/ansible/tasks/${client_name}" ] && [ ! -f "${PROJECT_ROOT}/ansible/tasks/setup_${client_name}.yaml" ]; then
      return 1
    fi
  elif [ "${client_type}" == "consensus" ]; then
    if [ ! -d "${PROJECT_ROOT}/ansible/tasks/${client_name}" ] && [ ! -f "${PROJECT_ROOT}/ansible/tasks/setup_${client_name}.yaml" ]; then
      return 1
    fi
  fi
  
  return 0
}

# Main test execution
main() {
  echo -e "${BLUE}Starting client compatibility tests${NC}"
  echo "Testing ${#EXECUTION_CLIENTS[@]} execution clients and ${#CONSENSUS_CLIENTS[@]} consensus clients"
  echo "Possible combinations: $((${#EXECUTION_CLIENTS[@]} * ${#CONSENSUS_CLIENTS[@]}))"
  
  # Create fixtures directory if it doesn't exist
  mkdir -p "${PROJECT_ROOT}/scripts/testing/fixtures"
  
  # Test each client combination
  for exec_client in "${EXECUTION_CLIENTS[@]}"; do
    for cons_client in "${CONSENSUS_CLIENTS[@]}"; do
      # Check if both clients are supported
      if ! is_client_supported "execution" "${exec_client}"; then
        echo -e "${YELLOW}Skipping unsupported execution client: ${exec_client}${NC}"
        echo "SKIPPED: Unsupported execution client: ${exec_client}" >> "${RESULTS_FILE}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        continue
      fi
      
      if ! is_client_supported "consensus" "${cons_client}"; then
        echo -e "${YELLOW}Skipping unsupported consensus client: ${cons_client}${NC}"
        echo "SKIPPED: Unsupported consensus client: ${cons_client}" >> "${RESULTS_FILE}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        continue
      fi
      
      # Test this combination
      test_client_combination "${exec_client}" "${cons_client}"
    done
  done
  
  # Print test summary
  {
    echo "Client Compatibility Test Summary"
    echo "================================="
    echo "Total combinations tested: ${TOTAL_TESTS}"
    echo "Passed: ${PASSED_TESTS}"
    echo "Failed: ${FAILED_TESTS}"
    echo "Skipped: ${SKIPPED_TESTS}"
    echo ""
    echo "See detailed results in: ${RESULTS_FILE}"
  } | tee -a "${RESULTS_FILE}"
  
  # Return non-zero exit code if any tests failed
  if [ ${FAILED_TESTS} -gt 0 ]; then
    # Cleanup mock environment if used
    if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
      restore_commands
    fi
    return 1
  fi
  
  # Cleanup mock environment if used
  if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
    restore_commands
  fi
  return 0
}

# Run main function
main "$@" 
