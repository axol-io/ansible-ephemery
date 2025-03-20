#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_utils.sh
# Description: Common utilities for shell script testing
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library if not already loaded
if [[ -z "${_EPHEMERY_COMMON_LOADED}" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common.sh"
fi

# Define flag to prevent multiple sourcing
_EPHEMERY_TEST_UTILS_LOADED=true

# Run a test function and report success/failure
run_test() {
  local test_func="$1"
  local test_name=${test_func/test_/}
  local test_description=${test_name//_/ }

  log_info "Running test: ${test_description}"

  # Run the test function
  if $test_func; then
    log_success "Test passed: ${test_description}"
    return 0
  else
    log_error "Test failed: ${test_description}"
    return 1
  fi
}

# Create a temporary testing directory
create_temp_test_dir() {
  local prefix="${1:-ephemery_test}"
  local temp_dir

  temp_dir=$(mktemp -d -t "${prefix}_XXXXXXXX")

  if [[ -d "$temp_dir" ]]; then
    log_debug "Created temporary directory: $temp_dir"
    echo "$temp_dir"
    return 0
  else
    log_error "Failed to create temporary directory"
    return 1
  fi
}

# Safely remove a temporary test directory
remove_temp_test_dir() {
  local temp_dir="$1"

  if [[ -d "$temp_dir" && "$temp_dir" == *"ephemery_test"* ]]; then
    log_debug "Removing temporary directory: $temp_dir"
    rm -rf "$temp_dir"
    return 0
  else
    log_error "Not a valid temporary test directory: $temp_dir"
    return 1
  fi
}

# Mock a command for testing
mock_command() {
  local command_name="$1"
  local output="$2"
  local exit_code="${3:-0}"

  # Create a temporary mock script directory if it doesn't exist
  local mock_dir="${PROJECT_ROOT}/scripts/testing/.mocks"
  mkdir -p "$mock_dir"

  # Add mock directory to PATH
  export PATH="$mock_dir:$PATH"

  # Create mock script
  cat >"${mock_dir}/${command_name}" <<EOF
#!/usr/bin/env bash
echo "${output}"
exit ${exit_code}
EOF

  # Make it executable
  chmod +x "${mock_dir}/${command_name}"

  log_debug "Mocked command '${command_name}' with output '${output}' and exit code ${exit_code}"
}

# Clean up all mocked commands
clean_mocks() {
  local mock_dir="${PROJECT_ROOT}/scripts/testing/.mocks"

  if [[ -d "$mock_dir" ]]; then
    log_debug "Cleaning up mocked commands"
    rm -rf "$mock_dir"
  fi
}

# Assert that a file exists
assert_file_exists() {
  local file_path="$1"
  local message="${2:-File should exist: $file_path}"

  if [[ -f "$file_path" ]]; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Assert that a file does not exist
assert_file_not_exists() {
  local file_path="$1"
  local message="${2:-File should not exist: $file_path}"

  if [[ ! -f "$file_path" ]]; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Assert that a directory exists
assert_dir_exists() {
  local dir_path="$1"
  local message="${2:-Directory should exist: $dir_path}"

  if [[ -d "$dir_path" ]]; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Assert that a file contains a string
assert_file_contains() {
  local file_path="$1"
  local string="$2"
  local message="${3:-File should contain string: $string}"

  if [[ -f "$file_path" ]] && grep -q "$string" "$file_path"; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Assert that a file has specific permissions
assert_file_permissions() {
  local file_path="$1"
  local expected_perms="$2"
  local message="${3:-File should have permissions $expected_perms: $file_path}"

  if [[ ! -f "$file_path" ]]; then
    log_error "File does not exist: $file_path"
    return 1
  fi

  local actual_perms
  actual_perms=$(stat -c "%a" "$file_path" 2>/dev/null || stat -f "%Lp" "$file_path")

  if [[ "$actual_perms" == "$expected_perms" ]]; then
    return 0
  else
    log_error "$message (actual: $actual_perms)"
    return 1
  fi
}

# Assert that a command succeeds
assert_command_succeeds() {
  local command="$1"
  local message="${2:-Command should succeed: $command}"

  if eval "$command"; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Assert that a command fails
assert_command_fails() {
  local command="$1"
  local message="${2:-Command should fail: $command}"

  if ! eval "$command"; then
    return 0
  else
    log_error "$message"
    return 1
  fi
}

# Run command and capture output for assertions
run_and_capture() {
  local command="$1"
  local output_file="$2"

  # Run command and capture stdout and stderr
  eval "$command" >"$output_file" 2>&1
  return $?
}

# Set up cleanup for tests
setup_test_cleanup() {
  trap 'clean_mocks; cleanup 2>/dev/null || true' EXIT
}

# Export functions
export -f run_test
export -f create_temp_test_dir
export -f remove_temp_test_dir
export -f mock_command
export -f clean_mocks
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_dir_exists
export -f assert_file_contains
export -f assert_file_permissions
export -f assert_command_succeeds
export -f assert_command_fails
export -f run_and_capture
export -f setup_test_cleanup
