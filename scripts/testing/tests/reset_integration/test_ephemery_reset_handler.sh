#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: test_ephemery_reset_handler.sh
# Description: Tests for the ephemery_reset_handler.sh script
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
TEST_UTILS_DIR="${PROJECT_ROOT}/scripts/testing"

# Source the test utilities
source "${TEST_UTILS_DIR}/test_utils.sh"

# Script under test
SCRIPT_UNDER_TEST="${PROJECT_ROOT}/scripts/core/ephemery_reset_handler.sh"

# Setup test cleanup on exit
setup_test_cleanup

# Create a temporary test directory for this test file
TEST_TEMP_DIR=$(create_temp_test_dir "ephemery_reset_handler_test")

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment"
    
    # Create necessary directories
    mkdir -p "${TEST_TEMP_DIR}/data"
    mkdir -p "${TEST_TEMP_DIR}/data/logs"
    mkdir -p "${TEST_TEMP_DIR}/config"
    mkdir -p "${TEST_TEMP_DIR}/scripts/utilities"
    
    # Create a mock genesis file
    cat > "${TEST_TEMP_DIR}/config/genesis.json" << EOF
{
    "genesis_time": "2025-03-17T00:00:00Z",
    "other_field": "value"
}
EOF

    # Create a mock key restore wrapper
    cat > "${TEST_TEMP_DIR}/scripts/utilities/ephemery_key_restore_wrapper.sh" << EOF
#!/usr/bin/env bash
echo "Mock key restore executed with args: \$@"
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/scripts/utilities/ephemery_key_restore_wrapper.sh"
    
    # Mock docker command
    mock_command "docker" "Mock docker command executed" 0
    
    # Export test environment variables
    export EPHEMERY_DATA_DIR="${TEST_TEMP_DIR}/data"
    export EPHEMERY_CONFIG_DIR="${TEST_TEMP_DIR}/config"
    export EPHEMERY_LOGS_DIR="${TEST_TEMP_DIR}/data/logs"
}

# Clean up the test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    remove_temp_test_dir "${TEST_TEMP_DIR}"
    clean_mocks
    unset EPHEMERY_DATA_DIR
    unset EPHEMERY_CONFIG_DIR
    unset EPHEMERY_LOGS_DIR
}

# Test detecting a fresh setup (no previous reset)
test_fresh_setup() {
    setup_test_environment
    
    # Run the script (should not detect a reset)
    log_info "Testing fresh setup (no previous reset)"
    run_and_capture "${SCRIPT_UNDER_TEST} --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check that last_genesis_time file was created
    assert_file_exists "${TEST_TEMP_DIR}/data/last_genesis_time"
    
    # Check that the file contains the correct genesis time
    assert_file_contains "${TEST_TEMP_DIR}/data/last_genesis_time" "2025-03-17T00:00:00Z"
    
    # Ensure reset was not detected
    assert_file_not_exists "${TEST_TEMP_DIR}/data/reset_detected"
    
    cleanup_test_environment
    return 0
}

# Test detecting a network reset
test_detect_reset() {
    setup_test_environment
    
    # Create last_genesis_time with a different time
    echo "2025-03-16T00:00:00Z" > "${TEST_TEMP_DIR}/data/last_genesis_time"
    
    # Run the script (should detect a reset)
    log_info "Testing reset detection"
    run_and_capture "${SCRIPT_UNDER_TEST} --dry-run --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check that reset was detected
    assert_file_exists "${TEST_TEMP_DIR}/data/reset_detected"
    
    # Check that last_genesis_time was updated
    assert_file_contains "${TEST_TEMP_DIR}/data/last_genesis_time" "2025-03-17T00:00:00Z"
    
    cleanup_test_environment
    return 0
}

# Test force reset
test_force_reset() {
    setup_test_environment
    
    # Create last_genesis_time with the same time (would not normally trigger a reset)
    echo "2025-03-17T00:00:00Z" > "${TEST_TEMP_DIR}/data/last_genesis_time"
    
    # Run the script with force option
    log_info "Testing force reset"
    run_and_capture "${SCRIPT_UNDER_TEST} --force --dry-run --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check that reset was detected due to force option
    assert_file_exists "${TEST_TEMP_DIR}/data/reset_detected"
    
    cleanup_test_environment
    return 0
}

# Test handling a previously detected reset
test_handle_previous_reset() {
    setup_test_environment
    
    # Create reset_detected file but not reset_handled
    touch "${TEST_TEMP_DIR}/data/reset_detected"
    
    # Run the script (should handle the reset)
    log_info "Testing handling a previously detected reset"
    run_and_capture "${SCRIPT_UNDER_TEST} --dry-run --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check output for expected handling message
    assert_file_contains "${TEST_TEMP_DIR}/output.log" "Previously detected reset found"
    assert_file_contains "${TEST_TEMP_DIR}/output.log" "DRY RUN: Would handle network reset here"
    
    cleanup_test_environment
    return 0
}

# Test handling with no key restore
test_no_key_restore() {
    setup_test_environment
    
    # Create reset_detected file
    touch "${TEST_TEMP_DIR}/data/reset_detected"
    
    # Run the script with no-keys option
    log_info "Testing reset handling with no key restore"
    run_and_capture "${SCRIPT_UNDER_TEST} --no-keys --dry-run --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check output for expected messages
    assert_file_contains "${TEST_TEMP_DIR}/output.log" "Previously detected reset found"
    assert_file_not_contains "${TEST_TEMP_DIR}/output.log" "Restoring validator keys"
    
    cleanup_test_environment
    return 0
}

# Helper function: assert file does not contain
assert_file_not_contains() {
    local file_path="$1"
    local string="$2"
    local message="${3:-File should not contain string: $string}"
    
    if [[ -f "$file_path" ]] && ! grep -q "$string" "$file_path"; then
        return 0
    else
        log_error "$message"
        return 1
    fi
}

# Test handling with no container restart
test_no_container_restart() {
    setup_test_environment
    
    # Create reset_detected file
    touch "${TEST_TEMP_DIR}/data/reset_detected"
    
    # Run the script with no-containers option
    log_info "Testing reset handling with no container restart"
    run_and_capture "${SCRIPT_UNDER_TEST} --no-containers --dry-run --verbose" "${TEST_TEMP_DIR}/output.log"
    
    # Check output for expected messages
    assert_file_contains "${TEST_TEMP_DIR}/output.log" "Previously detected reset found"
    assert_file_not_contains "${TEST_TEMP_DIR}/output.log" "Stopping Ephemery containers"
    assert_file_not_contains "${TEST_TEMP_DIR}/output.log" "Starting Ephemery containers"
    
    cleanup_test_environment
    return 0
}

# Run all the tests
log_info "Starting tests for ephemery_reset_handler.sh"

# Run tests
run_test test_fresh_setup
run_test test_detect_reset
run_test test_force_reset
run_test test_handle_previous_reset
run_test test_no_key_restore
run_test test_no_container_restart

log_info "All tests completed for ephemery_reset_handler.sh" 