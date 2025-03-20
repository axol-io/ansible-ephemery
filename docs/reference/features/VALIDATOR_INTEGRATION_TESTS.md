# Validator Integration Tests

This document describes the validator integration test system for Ephemery nodes.

## Overview

The validator integration test system provides a comprehensive way to test the integration of validator management scripts with the Ephemery deployment system. It verifies that the scripts work correctly in a real environment.

## Integration Test Script

The integration test script (`scripts/validator/integration_test.sh`) is designed to:

1. Set up a test environment for validator scripts
2. Test key management operations (generate, import, list, backup, restore)
3. Test monitoring operations (status, performance, health, dashboard)
4. Test validator configuration
5. Clean up the test environment after testing

## Usage

```bash
./scripts/validator/integration_test.sh [options]
```

Or using the wrapper script:

```bash
./scripts/manage-validator.sh test integration [options]
```

## Options

- `-e, --env ENV`: Test environment (local, docker, remote) (default: local)
- `-d, --dir PATH`: Ephemery base directory (default: ~/ephemery-test)
- `-h, --host HOST`: Remote host for testing (required for remote env)
- `-u, --user USER`: SSH user for remote testing (default: root)
- `-k, --key FILE`: SSH key file for remote testing
- `--no-cleanup`: Don't clean up test environment after testing
- `-v, --verbose`: Enable verbose output
- `--help`: Show help message

## Test Environments

The integration test script supports three test environments:

1. **Local**: Tests the scripts on the local machine
2. **Docker**: Tests the scripts in a Docker container
3. **Remote**: Tests the scripts on a remote server

### Local Environment

The local environment is the default test environment. It sets up a test directory on the local machine and runs the tests there.

```bash
./scripts/validator/integration_test.sh --env local
```

### Docker Environment

The Docker environment runs the tests in a Docker container. This is useful for testing in a clean environment without affecting the local machine.

```bash
./scripts/validator/integration_test.sh --env docker
```

### Remote Environment

The remote environment runs the tests on a remote server. This is useful for testing in a production-like environment.

```bash
./scripts/validator/integration_test.sh --env remote --host example.com --user admin --key ~/.ssh/id_rsa
```

## Test Phases

The integration test script runs through several phases:

1. **Setup**: Sets up the test environment
2. **Key Management**: Tests key management operations
3. **Monitoring**: Tests monitoring operations
4. **Configuration**: Tests validator configuration
5. **Cleanup**: Cleans up the test environment

Each phase includes multiple tests that verify different aspects of the validator management system.

## Test Results

The test script provides detailed output of each test, including:

- Test name and description
- Test status (PASS/FAIL)
- Detailed output for failed tests
- Summary of all tests at the end

## Integration with CI/CD

The integration test script can be integrated with CI/CD pipelines to automatically test the validator management system on each commit or pull request.

Example GitHub Actions workflow:

```yaml
name: Validator Integration Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run integration tests
      run: ./scripts/validator/integration_test.sh --env docker
```

## Troubleshooting

If the integration tests fail, check the following:

1. Make sure the validator management scripts are properly installed
2. Check the test environment setup
3. Look for detailed error messages in the test output
4. Try running with the `--verbose` option for more detailed output
5. Check the logs in the test directory

## Related Documentation

- [Validator Management](VALIDATOR_MANAGEMENT.md)
- [Validator Monitoring](VALIDATOR_MONITORING.md)
- [Validator Key Management](VALIDATOR_KEY_MANAGEMENT.md)
