#!/usr/bin/env bash
# init_test_env.sh - Template for initializing test environment
# Include this file or copy the init_test_env function to tests that require it

# Function to initialize test environment
init_test_env() {
  # Get script directory and project root
  local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  local project_root="${PROJECT_ROOT:-$(git rev-parse --show-toplevel)}"

  # Create test report directory if it doesn't exist
  TEST_REPORT_DIR="${project_root}/scripts/testing/reports"
  mkdir -p "${TEST_REPORT_DIR}"

  # Set up mock environment if enabled
  if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
    # Ensure test_mock.sh is sourced
    if ! type mock_init &>/dev/null; then
      source "${project_root}/scripts/lib/test_mock.sh"
      mock_init
      override_commands
    fi

    # Register default mock behavior for common tools
    mock_register "systemctl" "success"
    mock_register "ip" "success"
    mock_register "curl" "success"
    mock_register "ansible-playbook" "success"
    mock_register "geth" "success"
    mock_register "lighthouse" "success"

    # Use shorter intervals in performance tests when in mock mode
    SAMPLE_INTERVAL="${MOCK_SAMPLE_INTERVAL:-5}" # 5 seconds instead of longer periods
    TEST_DURATION="${MOCK_TEST_DURATION:-30}"    # 30 seconds instead of minutes
    TEST_SAMPLES="${MOCK_TEST_SAMPLES:-3}"       # 3 samples instead of 30
  fi

  # Create a temporary directory for test artifacts
  TEST_TMP_DIR=$(mktemp -d -t "ephemery_test_XXXXXX")
  export TEST_TMP_DIR

  # Set the fixture directory
  TEST_FIXTURE_DIR="${project_root}/scripts/testing/fixtures"
  export TEST_FIXTURE_DIR

  # Log test initialization
  echo "Test environment initialized:"
  echo "- Project root: ${project_root}"
  echo "- Report directory: ${TEST_REPORT_DIR}"
  echo "- Temporary directory: ${TEST_TMP_DIR}"
  echo "- Mock mode: ${TEST_MOCK_MODE:-false}"
  echo "- Fixture directory: ${TEST_FIXTURE_DIR}"
}

# Export the function so it's available to the tests
export -f init_test_env
