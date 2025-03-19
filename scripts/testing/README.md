# testing


Scripts for testing Ephemery nodes and validators.

## Available Scripts

*(Scripts will be listed automatically as they are added)*

## Usage

See individual script files for detailed usage instructions.

# Ephemery Testing Framework

This directory contains the testing framework for the Ephemery project. The framework is designed to allow testing of Ephemery components in both real and mock environments.

## Directory Structure

- `tests/` - Contains all test scripts organized by category
- `fixtures/` - Contains test fixtures and mock data
- `reports/` - Contains test reports and logs
- `config/` - Contains test configuration files
- `run_tests.sh` - Main test runner script
- `lint_shell_scripts.sh` - Script for linting and fixing shell scripts

## Running Tests

To run all tests:

```bash
./run_tests.sh
```

To run tests in mock mode (no real dependencies required):

```bash
./run_tests.sh --mock
```

To run tests in verbose mode:

```bash
./run_tests.sh --verbose
```

To run a specific test:

```bash
./run_tests.sh tests/version_checker/test_version_check.sh
```

## Shell Script Linting with Shellharden

The framework includes support for linting and automatically fixing shell scripts using [shellharden](https://github.com/anordal/shellharden), a tool that makes shell scripts more robust.

### Using the Shell Linting Tool

Check your shell scripts for issues:

```bash
./lint_shell_scripts.sh
```

Fix issues automatically:

```bash
./lint_shell_scripts.sh --fix
```

Lint a specific script or directory:

```bash
./lint_shell_scripts.sh path/to/script.sh
./lint_shell_scripts.sh path/to/directory
```

Get verbose output:

```bash
./lint_shell_scripts.sh --verbose
```

Run in CI mode (exit with error if issues found):

```bash
./lint_shell_scripts.sh --check
```

### Installing Shellharden

The `lint_shell_scripts.sh` script will attempt to install shellharden automatically if it's not found on your system. This requires [Rust and Cargo](https://www.rust-lang.org/tools/install) to be installed.

You can also install shellharden manually:

```bash
cargo install shellharden
```

### Benefits of Shellharden

Shellharden helps to:

- Properly quote variables to prevent word splitting and globbing
- Identify unsafe shell practices
- Find and fix common shell script issues
- Make scripts more robust and reliable

## Continuous Integration

For automated testing and linting in CI environments, use the `ci_check.sh` script:

```bash
./ci_check.sh
```

This script will:
1. Run shellharden linting in check mode (fails if issues are found)
2. Run all tests in mock mode
3. Exit with a non-zero code if either step fails

This is ideal for use in CI pipelines to ensure code quality.

## Mock Framework

The mock framework allows tests to run without real dependencies by providing mock implementations of system commands and services. This is particularly useful for testing on platforms where certain tools are not available (e.g., systemctl on macOS).

The mock framework is implemented in `scripts/lib/test_mock.sh` and provides:

- Mock implementations of common system commands (systemctl, ip, curl, etc.)
- Mock implementations of Ethereum clients (geth, lighthouse, etc.)
- Mock implementations of Linux-specific tools (journalctl, systemd-analyze, etc.)
- Mock implementations of Ansible playbooks

### Using the Mock Framework

To use the mock framework in a test:

1. Source the mock framework:
   ```bash
   source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"
   ```

2. Initialize the mock framework:
   ```bash
   mock_init
   ```

3. Register mock behavior for specific commands:
   ```bash
   mock_register "command_name" "success"  # or "failure"
   ```

4. Override system commands:
   ```bash
   override_commands
   ```

5. Restore original commands when done:
   ```bash
   restore_commands
   ```

## Test Configuration

Test configuration is managed through `scripts/lib/test_config.sh` and YAML configuration files in the `config/` directory. The configuration system allows tests to be configured for different environments and scenarios.

### Using Test Configuration

To use test configuration in a test:

1. Source the configuration library:
   ```bash
   source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
   ```

2. Load configuration:
   ```bash
   load_config
   ```

3. Access configuration values:
   ```bash
   echo "Config value: ${CONFIG_VALUE}"
   ```

## Creating New Tests

To create a new test:

1. Create a new test script in the appropriate category directory under `tests/`
2. Use the template in `tests/template/test_template.sh` as a starting point
3. Implement test functions and logic
4. Add the `init_test_env` function to initialize the test environment
5. Run the test with `./run_tests.sh path/to/your/test.sh`

### Test Environment Initialization

All tests should include the `init_test_env` function to initialize the test environment. This function sets up the test directory, mock environment, and other common test requirements.

You can copy the template from `tests/template/init_test_env.sh` or include it directly:

```bash
source "${PROJECT_ROOT}/scripts/testing/tests/template/init_test_env.sh"
```

## Test Fixtures

Test fixtures are stored in the `fixtures/` directory and include:

- Mock Ansible playbooks
- Test data files
- Configuration templates

Use fixtures to provide consistent test data and avoid duplicating test setup code.

## Performance Considerations

When running tests in mock mode, performance tests should use shorter durations and fewer samples. The `init_test_env` function sets the following variables when in mock mode:

- `SAMPLE_INTERVAL`: 5 seconds (instead of 60)
- `TEST_DURATION`: 30 seconds (instead of 1800)
- `TEST_SAMPLES`: 3 samples (instead of 30)

Use these variables in performance tests to adjust timing based on the test mode.

## Troubleshooting

Common issues and solutions:

- **Path issues**: Ensure `PROJECT_ROOT` is set correctly in your test script
- **Missing dependencies**: Use mock mode (`--mock`) to run tests without real dependencies
- **Test not found**: Check the path to the test script and ensure it's executable
- **Mock not working**: Ensure `mock_init` and `override_commands` are called before using mocked commands

## Contributing

When adding new tests or modifying existing ones:

1. Follow the template structure
2. Include the `init_test_env` function
3. Support both real and mock modes
4. Add appropriate fixtures if needed
5. Document any special requirements or considerations

## Test Categories

### Client Combinations Testing

Tests compatibility between different execution and consensus client combinations. These tests verify that all supported client pairs work correctly in the Ephemery testnet environment.

- `test_client_compatibility.sh`: Verifies that different client combinations can be properly deployed and function correctly.

### Reset Integration Testing

Tests the node's ability to recover after Ephemery network resets. These tests validate that the reset detection and recovery mechanisms are functioning properly.

- `test_reset_recovery.sh`: Simulates an Ephemery network reset and verifies that the node can recover and resume normal operations.

### Performance Benchmarking

Benchmarks performance metrics for different client configurations. These tests help identify the most efficient client combinations and configurations.

- `test_client_performance.sh`: Collects and analyzes performance data for different clients, including CPU usage, memory usage, network metrics, and sync speed.

### Chaos Testing

Tests node resilience under adverse conditions. These tests verify that nodes can withstand network disruptions, high load, and other challenging scenarios.

- `test_network_disruption.sh`: Simulates various network disruptions (latency, packet loss, disconnections) and verifies node recovery.

### Genesis Validator Testing

Tests the complete lifecycle of genesis validators. These tests verify that validators can register, attest, and operate correctly.

- `test_validator_lifecycle.sh`: Validates the complete lifecycle of a genesis validator, from key registration to attestation.

## Test Results

Test scripts should return the following exit codes:

- `0`: Test passed
- `1`: Test failed 
- `77`: Test skipped (special code for tests that can't run in current environment)

## Integration with CI/CD

The testing framework is designed to work in CI/CD environments by:

1. Automatically detecting available tools
2. Using mock mode when real infrastructure is unavailable
3. Providing clear pass/fail status for CI/CD pipelines

## Adding New Mock Implementations

To add a new mock implementation:

1. Edit the `test_mock.sh` file to add the new mock function
2. Register the mock for the command in your test using `mock_register`
3. Override the command by calling `override_commands` in mock mode
4. Restore original commands with `restore_commands` before test completion

## Requirements

The test framework requires the following tools:

- bash
- curl
- jq
- bc
- grep
- systemctl (for service management)
- timeout
- awk

## Troubleshooting

If tests are failing, check the detailed logs in the `reports` directory. Common issues include:

- Missing required tools (check with `command -v tool_name`)
- Insufficient permissions (tests may require sudo for some operations)
- Network connectivity issues
- Incorrect configuration of client services

## Contents

- **run_all_tests.sh**: Runs all tests for the Ephemery project
- **run_tests.sh**: 
- **test_utils.sh**: Common utilities for shell script testing
- **version_check_test.sh**: 
