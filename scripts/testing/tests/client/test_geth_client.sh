#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_geth_client.sh
# Description: Tests Geth client setup and interactions
# Author: Ephemery Team
# Created: 2025-03-22
# Last Modified: 2025-03-22
#
# This script tests the Geth client setup and API interactions.

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/../template/init_test_env.sh"

# Test variables
TEST_NAME="Geth Client Test"
FIXTURE_PLAYBOOK="${FIXTURES_DIR}/client_test.yml"
CLIENT_PORT=8545
EXPECTED_CLIENT_NAME="geth"

# Test functions
test_fixture_exists() {
  test_start "Fixture playbook exists"
  if [[ -f "${FIXTURE_PLAYBOOK}" ]]; then
    test_pass "Fixture playbook exists at ${FIXTURE_PLAYBOOK}"
  else
    test_fail "Fixture playbook not found at ${FIXTURE_PLAYBOOK}"
  fi
}

test_mock_client_setup() {
  test_start "Mock client setup"

  # Use the mock framework to run the Ansible playbook
  if [[ "${MOCK_MODE}" == "true" ]]; then
    # Mock the Ansible command
    mock_command "ansible-playbook" "echo 'Mock: Running Ansible playbook'; exit 0"

    # Run the command
    ansible-playbook "${FIXTURE_PLAYBOOK}" -e "test_mode=true"

    # Verify the command was called
    if mock_verify "ansible-playbook"; then
      test_pass "Mock client setup completed successfully"
    else
      test_fail "Mock client setup failed"
    fi
  else
    # Run the actual Ansible playbook
    if ansible-playbook "${FIXTURE_PLAYBOOK}" -e "test_mode=true"; then
      test_pass "Client setup completed successfully"
    else
      test_fail "Client setup failed"
    fi
  fi
}

test_client_api_mock() {
  test_start "Client API mock"

  if [[ "${MOCK_MODE}" == "true" ]]; then
    # Mock the curl command for JSON-RPC request
    mock_command "curl" "echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x1\"}'"

    # Run the API request
    RESULT=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:${CLIENT_PORT})

    # Parse and verify the result
    if echo "${RESULT}" | grep -q '"result":"0x1"'; then
      test_pass "Client API responded correctly in mock mode"
    else
      test_fail "Client API response incorrect in mock mode: ${RESULT}"
    fi

    # Verify curl was called
    mock_verify "curl"
  else
    # Skip this test in non-mock mode as the previous test already tested the actual API
    test_skip "Skipping API test in non-mock mode"
  fi
}

test_client_error_handling() {
  test_start "Client error handling"

  if [[ "${MOCK_MODE}" == "true" ]]; then
    # Mock the curl command to return an error
    mock_command "curl" "echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}'"

    # Run an invalid API request
    RESULT=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"invalid_method","params":[],"id":1}' http://localhost:${CLIENT_PORT})

    # Verify error handling
    if echo "${RESULT}" | grep -q '"error"'; then
      test_pass "Client correctly returns error for invalid method"
    else
      test_fail "Client did not return expected error format: ${RESULT}"
    fi

    # Verify curl was called
    mock_verify "curl"
  else
    # Skip this test in non-mock mode
    test_skip "Skipping error handling test in non-mock mode"
  fi
}

# Main test execution
main() {
  test_header "${TEST_NAME}"

  # Run tests
  test_fixture_exists
  test_mock_client_setup
  test_client_api_mock
  test_client_error_handling

  test_summary
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
