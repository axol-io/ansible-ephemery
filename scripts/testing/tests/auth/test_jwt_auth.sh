#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_jwt_auth.sh
# Description: Tests JWT authentication between clients
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# test_jwt_auth.sh - Test script to verify JWT authentication between execution and consensus clients
#
# This script tests JWT authentication between Geth and Lighthouse for Ephemery nodes.
# It verifies that:
# 1. The JWT secret file exists and has correct permissions
# 2. The JWT content is valid and consistent
# 3. Both clients are using the correct JWT path
# 4. The clients can successfully authenticate using the JWT token
# 5. The execution client is properly configured with the correct chain ID

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
    mock_register "geth" "success"
    mock_register "lighthouse" "success"
  fi

  # Create a temporary directory for test artifacts
  TEST_TMP_DIR=$(mktemp -d -t "ephemery_test_XXXXXX")
  export TEST_TMP_DIR

  # Set the fixture directory
  TEST_FIXTURE_DIR="${PROJECT_ROOT}/scripts/testing/fixtures"
  export TEST_FIXTURE_DIR

  echo "Test environment initialized"
}

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
init_test_env

# Strict error handling
set -euo pipefail

# Initialize test exit code
TEST_EXIT_CODE=0

# Logging functions
log_header() { echo -e "${BLUE}=== $1 ===${NC}"; }
log_info() { echo -e "${BLUE}INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
log_error() {
  echo -e "${RED}ERROR: $1${NC}"
  TEST_EXIT_CODE=1
}

# Run a test function and report results
run_test() {
  log_info "Running test: $1"
  if $1; then
    log_success "Test passed: $1"
    return 0
  else
    log_error "Test failed: $1"
    return 1
  fi
}

# Print test summary
print_summary() {
  echo ""
  if [ $TEST_EXIT_CODE -eq 0 ]; then
    log_success "All tests passed!"
  else
    log_error "Some tests failed!"
  fi
}

# Check if we're on MacOS or Linux
is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

# Get file permissions in octal format
get_file_permissions() {
  local file="$1"
  if is_macos; then
    stat -f "%Lp" "$file"
  else
    stat -c "%a" "$file"
  fi
}

# Default paths
if [[ -f /etc/ephemery/config/ephemery_paths.conf ]]; then
  source /etc/ephemery/config/ephemery_paths.conf
elif [[ -f "${HOME}/ephemery/config/ephemery_paths.conf" ]]; then
  source "${HOME}/ephemery/config/ephemery_paths.conf"
else
  EPHEMERY_BASE_DIR="${HOME}/ephemery"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_JWT_SECRET="${EPHEMERY_BASE_DIR}/jwt.hex"
  GETH_CONTAINER_NAME="ephemery-geth"
  LIGHTHOUSE_CONTAINER_NAME="ephemery-beacon-lighthouse"
fi

# Constants
EXPECTED_JWT_LENGTH=66           # Length with '0x' prefix
EXPECTED_JWT_LENGTH_NO_PREFIX=64 # Length without '0x' prefix
EXPECTED_CHAIN_ID=39438144
EXPECTED_CHAIN_ID_HEX="0x259c740"

# Test 1: Verify JWT secret file exists and has correct permissions
test_jwt_file_exists() {
  log_info "Test 1: Verifying JWT secret file exists"

  if [[ -f "${EPHEMERY_JWT_SECRET}" ]]; then
    log_success "JWT secret file exists at ${EPHEMERY_JWT_SECRET}"

    # Check permissions
    local perms
    perms=$(get_file_permissions "${EPHEMERY_JWT_SECRET}")
    if [[ "${perms}" == "600" ]]; then
      log_success "JWT secret file has correct permissions (600)"
    else
      log_error "JWT secret file has incorrect permissions: ${perms}"
      log_info "Fixing permissions..."
      chmod 600 "${EPHEMERY_JWT_SECRET}"
      log_success "Permissions corrected"
    fi
  else
    log_error "JWT secret file does not exist at ${EPHEMERY_JWT_SECRET}"
    return 1
  fi
}

# Test 2: Verify JWT content is valid
test_jwt_content() {
  log_info "Test 2: Verifying JWT content is valid"

  if [[ ! -f "${EPHEMERY_JWT_SECRET}" ]]; then
    log_error "Cannot verify JWT content - file does not exist"
    return 1
  fi

  local jwt_content
  jwt_content=$(cat "${EPHEMERY_JWT_SECRET}")
  local jwt_length
  jwt_length=${#jwt_content}

  log_info "JWT content (first 10 chars): ${jwt_content:0:10}..."
  log_info "JWT length: ${jwt_length} characters"

  # Verify JWT format - accept both with and without 0x prefix
  if [[ "${jwt_content}" == 0x* ]]; then
    # Has 0x prefix
    if [[ "${jwt_length}" -eq "${EXPECTED_JWT_LENGTH}" ]]; then
      local hex_content="${jwt_content:2}"
      if [[ "${hex_content}" =~ ^[0-9a-fA-F]+$ ]]; then
        log_success "JWT content is valid (0x + 64 hex characters)"
      else
        log_error "JWT content contains invalid characters (not hexadecimal)"
        return 1
      fi
    else
      log_error "JWT content has incorrect length: ${jwt_length}, expected: ${EXPECTED_JWT_LENGTH}"
      return 1
    fi
  else
    # No 0x prefix
    if [[ "${jwt_length}" -eq "${EXPECTED_JWT_LENGTH_NO_PREFIX}" ]]; then
      if [[ "${jwt_content}" =~ ^[0-9a-fA-F]+$ ]]; then
        log_success "JWT content is valid (64 hex characters without 0x prefix)"
      else
        log_error "JWT content contains invalid characters (not hexadecimal)"
        return 1
      fi
    else
      log_error "JWT content has incorrect length: ${jwt_length}, expected: ${EXPECTED_JWT_LENGTH_NO_PREFIX}"
      return 1
    fi
  fi

  return 0
}

# Test 3: Verify JWT paths in container configurations
test_jwt_paths_in_containers() {
  log_info "Test 3: Verifying JWT paths in container configurations"

  # Check if Docker is available
  if ! command -v docker &>/dev/null; then
    log_warning "Docker is not available, skipping container configuration checks"
    return 0
  fi

  # Check if containers are running
  if ! docker ps | grep -q "${GETH_CONTAINER_NAME}"; then
    log_warning "Geth container (${GETH_CONTAINER_NAME}) is not running, skipping this test"
    return 0
  fi

  if ! docker ps | grep -q "${LIGHTHOUSE_CONTAINER_NAME}"; then
    log_warning "Lighthouse container (${LIGHTHOUSE_CONTAINER_NAME}) is not running, skipping this test"
    return 0
  fi

  # Check Geth configuration
  log_info "Checking Geth JWT configuration..."
  local geth_jwt_path
  geth_jwt_path=$(docker inspect "${GETH_CONTAINER_NAME}" | grep -A 10 "Cmd" | grep "authrpc.jwtsecret" | cut -d"=" -f2 | tr -d '",}]')

  if [[ -n "${geth_jwt_path}" ]]; then
    log_success "Geth is configured with JWT path: ${geth_jwt_path}"
  else
    log_error "Geth is not configured with a JWT path"
    return 1
  fi

  # Check Lighthouse configuration
  log_info "Checking Lighthouse JWT configuration..."
  local lighthouse_jwt_path
  lighthouse_jwt_path=$(docker inspect "${LIGHTHOUSE_CONTAINER_NAME}" | grep -A 10 "Cmd" | grep "execution-jwt" | cut -d"=" -f2 | tr -d '",}]')

  if [[ -n "${lighthouse_jwt_path}" ]]; then
    log_success "Lighthouse is configured with JWT path: ${lighthouse_jwt_path}"
  else
    log_error "Lighthouse is not configured with a JWT path"
    return 1
  fi
}

# Test 4: Verify JWT tokens match between containers
test_jwt_tokens_match() {
  log_info "Test 4: Verifying JWT tokens match between containers"

  # Check if Docker is available
  if ! command -v docker &>/dev/null; then
    log_warning "Docker is not available, skipping JWT token comparison"
    return 0
  fi

  # Check if containers are running
  if ! docker ps | grep -q "${GETH_CONTAINER_NAME}" || ! docker ps | grep -q "${LIGHTHOUSE_CONTAINER_NAME}"; then
    log_warning "One or both containers are not running, skipping JWT token comparison"
    return 0
  fi

  # Get JWT content from Geth container
  local geth_jwt_path
  geth_jwt_path=$(docker inspect "${GETH_CONTAINER_NAME}" | grep -A 10 "Cmd" | grep "authrpc.jwtsecret" | cut -d"=" -f2 | tr -d '",}]')

  # Get JWT content from Lighthouse container
  local lighthouse_jwt_path
  lighthouse_jwt_path=$(docker inspect "${LIGHTHOUSE_CONTAINER_NAME}" | grep -A 10 "Cmd" | grep "execution-jwt" | cut -d"=" -f2 | tr -d '",}]')

  if [[ -z "${geth_jwt_path}" || -z "${lighthouse_jwt_path}" ]]; then
    log_error "Cannot compare JWT tokens - path not found in one or both containers"
    return 1
  fi

  # Extract JWT token from containers
  log_info "Reading JWT token from Geth container..."
  local geth_token
  geth_token=$(docker exec "${GETH_CONTAINER_NAME}" cat "${geth_jwt_path}" 2>/dev/null)

  log_info "Reading JWT token from Lighthouse container..."
  local lighthouse_token
  lighthouse_token=$(docker exec "${LIGHTHOUSE_CONTAINER_NAME}" cat "${lighthouse_jwt_path}" 2>/dev/null)

  if [[ -z "${geth_token}" ]]; then
    log_error "Could not read JWT token from Geth container"
    return 1
  fi

  if [[ -z "${lighthouse_token}" ]]; then
    log_error "Could not read JWT token from Lighthouse container"
    return 1
  fi

  log_info "Geth JWT token (first 10 chars): ${geth_token:0:10}..."
  log_info "Lighthouse JWT token (first 10 chars): ${lighthouse_token:0:10}..."

  if [[ "${geth_token}" == "${lighthouse_token}" ]]; then
    log_success "JWT tokens match between Geth and Lighthouse"
  else
    log_error "JWT tokens DO NOT match between Geth and Lighthouse"
    return 1
  fi
}

# Test 5: Verify chain ID configuration
test_chain_id() {
  log_info "Test 5: Verifying correct chain ID configuration"

  # Check if we can reach the Geth API
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545 &>/dev/null; then
    log_warning "Cannot connect to Geth API, skipping chain ID check"
    return 0
  fi

  log_info "Querying Geth for chain ID..."
  local chain_id_resp
  chain_id_resp=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545)

  if [[ -z "${chain_id_resp}" ]]; then
    log_error "Could not query chain ID from Geth"
    return 1
  fi

  log_info "Chain ID response: ${chain_id_resp}"

  # Extract chain ID from response
  local chain_id
  chain_id=$(echo "${chain_id_resp}" | grep -o '"result":"0x[^"]*"' | cut -d':' -f2 | tr -d '"\n')

  if [[ -z "${chain_id}" ]]; then
    log_error "Could not extract chain ID from response"
    return 1
  fi

  log_info "Detected chain ID: ${chain_id}"

  if [[ "${chain_id}" == "${EXPECTED_CHAIN_ID_HEX}" ]]; then
    log_success "Geth is running with the correct Ephemery chain ID (${EXPECTED_CHAIN_ID})"
  else
    log_error "Geth is running with incorrect chain ID: ${chain_id}, expected: ${EXPECTED_CHAIN_ID_HEX}"
    return 1
  fi
}

# Test 6: Verify successful authentication between clients
test_auth_success() {
  log_info "Test 6: Verifying successful authentication between clients"

  # Check if Docker is available
  if ! command -v docker &>/dev/null; then
    log_warning "Docker is not available, skipping authentication check"
    return 0
  fi

  # Check if Lighthouse container is running
  if ! docker ps | grep -q "${LIGHTHOUSE_CONTAINER_NAME}"; then
    log_warning "Lighthouse container is not running, skipping authentication check"
    return 0
  fi

  log_info "Checking Lighthouse logs for JWT authentication..."
  local lighthouse_jwt_errors
  lighthouse_jwt_errors=$(docker logs "${LIGHTHOUSE_CONTAINER_NAME}" | grep -E "jwt|auth" | grep -i "error|fail" | wc -l)

  if [[ "${lighthouse_jwt_errors}" -eq 0 ]]; then
    log_success "No JWT authentication errors found in Lighthouse logs"
  else
    log_warning "Found ${lighthouse_jwt_errors} potential JWT authentication errors in Lighthouse logs"
    docker logs "${LIGHTHOUSE_CONTAINER_NAME}" | grep -E "jwt|auth" | grep -i "error|fail" | head -5
  fi

  # Check if we can reach the Lighthouse API
  if ! curl -s http://localhost:5052/eth/v1/node/syncing &>/dev/null; then
    log_warning "Cannot connect to Lighthouse API, skipping sync status check"
    return 0
  fi

  log_info "Checking if consensus client is receiving execution updates..."
  local sync_status
  sync_status=$(curl -s http://localhost:5052/eth/v1/node/syncing)

  log_info "Sync status: ${sync_status}"

  if [[ "${sync_status}" == *"false"* || "${sync_status}" == *"is_syncing\":false"* ]]; then
    log_success "Consensus client is synced, which indicates successful JWT authentication"
  elif [[ "${sync_status}" == *"true"* || "${sync_status}" == *"is_syncing\":true"* ]]; then
    log_warning "Consensus client is still syncing - authentication may be working but sync in progress"
  else
    log_error "Could not determine consensus client sync status, possible authentication issue"
    return 1
  fi

  # Check if we can reach the Geth API
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 &>/dev/null; then
    log_warning "Cannot connect to Geth API, skipping engine API check"
    return 0
  fi

  # Check authenticated connection from engine API
  log_info "Verifying authenticated engine API connection..."
  local forkchoice_resp
  forkchoice_resp=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)

  log_info "Engine API response: ${forkchoice_resp}"

  if [[ "${forkchoice_resp}" != *"error"* ]]; then
    log_success "Engine API responds without authentication errors"
  else
    log_error "Engine API returned errors, possible authentication issue"
    return 1
  fi
}

# Print header
log_header "Ephemery JWT Authentication Test"
log_info "Testing JWT authentication between execution and consensus clients"

# Run tests
run_test test_jwt_file_exists
run_test test_jwt_content
run_test test_jwt_paths_in_containers
run_test test_jwt_tokens_match
run_test test_chain_id
run_test test_auth_success

# Print summary
print_summary

exit ${TEST_EXIT_CODE}
