# Ephemery Testing Guide

This guide provides comprehensive information about testing the Ephemery node software, including automated tests, integration tests, performance tests, and manual testing procedures.

## Testing Philosophy

The Ephemery project follows these testing principles:

1. **Automated Testing**: Whenever possible, tests should be automated to ensure consistency and enable continuous integration.
2. **Test Coverage**: Tests should cover all critical functionality, including edge cases and error conditions.
3. **Realistic Scenarios**: Tests should simulate real-world usage patterns and environments.
4. **Incremental Testing**: New features should come with corresponding tests.
5. **Performance Validation**: Performance aspects should be systematically tested.

## Testing Categories

### 1. Unit Tests

Unit tests verify the functionality of individual components in isolation.

#### Shell Script Testing

For shell scripts, we use a combination of shellcheck for static analysis and mock-based testing:

```bash
# Run shellcheck on all shell scripts
shellcheck scripts/*.sh scripts/*/*.sh

# Run unit tests for shell scripts
scripts/development/run_shell_unit_tests.sh
```

#### Ansible Role Testing

For Ansible roles, we use Molecule for testing:

```bash
# Install Molecule prerequisites
pip install -r requirements-dev.txt

# Run Molecule tests for a specific role
cd ansible/roles/ephemery_core
molecule test
```

### 2. Integration Tests

Integration tests verify that different components work together correctly.

#### Validator Dashboard Testing

The validator dashboard has a dedicated test script that verifies its functionality:

```bash
# Run validator dashboard tests
scripts/development/test_validator_dashboard.sh
```

This script tests:
- Different dashboard view modes (compact, detailed, full)
- Historical analysis functionality
- Integration with the validator monitoring system
- Handles various data edge cases correctly

#### Client Integration Testing

To test integration between execution and consensus clients:

```bash
# Run client integration tests
scripts/development/test_client_integration.sh
```

### 3. System Tests

System tests verify the behavior of the complete system in a realistic environment.

#### End-to-End Testing

```bash
# Run end-to-end test suite
scripts/development/run_e2e_tests.sh
```

This test:
1. Deploys a complete Ephemery node
2. Verifies successful sync with the network
3. Tests validator operations (if enabled)
4. Verifies monitoring and dashboard functionality

#### Reset Testing

To test the weekly reset mechanism:

```bash
# Test reset functionality
scripts/development/test_reset_process.sh
```

### 4. Performance Testing

Performance tests verify the system behaves correctly under load and measure key performance metrics.

#### Sync Performance Test

```bash
# Test sync performance with different configurations
scripts/development/test_sync_performance.sh --checkpoint=true --execution-client=geth --consensus-client=lighthouse
```

#### Validator Performance Test

```bash
# Test validator performance with varying validator counts
scripts/development/test_validator_performance.sh --count=10
```

### 5. Chaos Testing

Chaos tests verify the system's resilience to unexpected failures and conditions.

```bash
# Run chaos tests
scripts/development/run_chaos_tests.sh
```

The chaos tests include:
- Network partitioning
- Container restarts
- Resource constraints
- Disk space limitations
- High CPU/memory load
- Checkpoint server failures

## Continuous Integration

The Ephemery project uses GitHub Actions for continuous integration testing. The CI pipeline includes:

1. **Static Analysis**: Linting and static analysis of shell scripts and Ansible playbooks
2. **Unit Tests**: Automated unit tests for all components
3. **Integration Tests**: Basic integration tests for critical functionality
4. **Deployment Tests**: Testing deployment on various supported platforms

CI runs are triggered on:
- Pull requests
- Commits to the main branch
- Release tags
- Weekly scheduled runs

## Test Data

For reproducible testing, the project provides mock test data in the `scripts/development/test_data` directory. This data simulates:

- Validator states and metrics
- Beacon chain and execution client status
- Historical performance data
- Network events

## Manual Testing Procedures

Some aspects of the system benefit from manual testing:

### Manual Reset Testing

1. Set up a test environment with a shortened epoch time
2. Trigger a network reset
3. Verify all components handle the reset correctly
4. Check data pruning and state handling
5. Verify clients re-sync successfully

### Manual Dashboard Testing

1. Launch the dashboard in different views
2. Verify metrics display correctly
3. Test interactive features
4. Verify alert functionality
5. Check historical data visualization

## Writing Tests

### Test Script Structure

New test scripts should follow this structure:

1. **Setup**: Prepare the test environment
2. **Execution**: Run the functionality being tested
3. **Verification**: Check that outcomes match expectations
4. **Cleanup**: Restore the system to its original state

### Test Script Template

```bash
#!/bin/bash
#
# Test script for [component]
# Description: Tests [specific functionality]

set -e

# Load common test library
source "$(dirname "${BASH_SOURCE[0]}")/test_common.sh"

# Setup test environment
setup() {
  echo "Setting up test environment..."
  # Setup code here
}

# Execute test
execute() {
  echo "Executing test..."
  # Test execution code here
}

# Verify results
verify() {
  echo "Verifying results..."
  # Verification code here

  if [[ $expected == $actual ]]; then
    return 0
  else
    echo "Test failed: Expected $expected but got $actual"
    return 1
  fi
}

# Clean up
cleanup() {
  echo "Cleaning up..."
  # Cleanup code here
}

# Run the test
run_test() {
  setup
  execute
  verify
  local result=$?
  cleanup
  return $result
}

# Execute test and exit with appropriate code
run_test
exit $?
```

## Test Coverage

The goal is to maintain at least 80% test coverage for all critical components. Coverage is measured by:

1. **Shell Scripts**: Counting functions and ensuring test cases for each function
2. **Ansible Roles**: Using Molecule's coverage report
3. **Manual Features**: Maintaining a checklist of manually verified features

## Testing Schedule

Regular testing should be performed according to this schedule:

- **Daily**: Automated CI tests run on all new code
- **Weekly**: Full end-to-end test suite run
- **Monthly**: Complete manual testing of all interfaces
- **Pre-release**: Comprehensive testing of all features
- **Post-reset**: Verification that resets don't impact functionality

## Conclusion

Following this testing guide will help ensure the reliability and quality of the Ephemery node software. By combining automated tests with strategic manual testing, we can provide users with a robust and dependable system.
