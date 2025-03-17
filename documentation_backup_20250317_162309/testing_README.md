# Testing Scripts

Scripts for testing Ephemery nodes and validators.

## Available Scripts

*(Scripts will be listed automatically as they are added)*

## Usage

See individual script files for detailed usage instructions.

# Ephemery Testing Framework

This directory contains the testing framework for the Ephemery project. The framework includes various test categories to ensure all aspects of the system function correctly.

## Overview

The Ephemery testing framework is designed to validate the functionality, performance, and resilience of Ethereum nodes in the Ephemery testnet environment. It focuses particularly on proper reset handling, client compatibility, and validator operations.

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

## Running Tests

You can run all tests or a specific test category using the `run_all_tests.sh` script:

```bash
# Run all tests
./run_all_tests.sh

# Run a specific test category
./run_all_tests.sh --category client_combinations
```

Available categories:

- `client_combinations`
- `reset_integration`
- `performance_benchmark`
- `chaos_testing`
- `genesis_validator`

## Test Reports

All test results are saved in the `reports` directory. Each test run generates a timestamped log file with detailed information about the test execution and results.

## Shared Test Utilities

Common testing utilities are available in `scripts/core/test_utils.sh`. These provide shared functionality across different test categories:

- Client detection
- Service status checks
- Sync status verification
- Performance measurement
- Reporting utilities

## Adding New Tests

To add a new test:

1. Create a new test script in the appropriate category directory
2. Make the script executable (`chmod +x test_script.sh`)
3. Implement the test using the shared test utilities
4. The script should return 0 for success and non-zero for failure

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
