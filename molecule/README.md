# Molecule Testing Framework for Ephemery

This directory contains the Molecule tests for the Ephemery project. Molecule is used to test the Ansible roles in isolation to ensure they work correctly.

## Test Structure

The tests are organized into scenarios, each with its own directory:

```
molecule/
├── clients/               # Client combination scenarios
│   ├── <client-pair>/     # e.g., geth-lighthouse
│   │   ├── converge.yml   # Playbook to apply the role
│   │   ├── molecule.yml   # Molecule configuration
│   │   └── verify.yml     # Tests to verify the role applied correctly
├── <special-scenario>/    # e.g., default, validator, etc.
├── shared/                # Shared resources across scenarios
└── run-tests.sh           # Helper script to run tests locally
```

## Available Scenarios

### Client Combinations

We have tests for all combinations of execution clients and consensus clients in the `molecule/clients/` directory:

| Execution Client | Consensus Client | Scenario Name |
|-----------------|------------------|---------------|
| geth            | lighthouse       | geth-lighthouse |
| geth            | prysm           | geth-prysm |
| geth            | teku            | geth-teku |
| geth            | lodestar        | geth-lodestar |
| reth            | lighthouse      | reth-lighthouse |
| reth            | prysm           | reth-prysm |
| reth            | teku            | reth-teku |
| reth            | lodestar        | reth-lodestar |
| erigon          | lighthouse      | erigon-lighthouse |
| erigon          | prysm           | erigon-prysm |
| erigon          | teku            | erigon-teku |
| erigon          | lodestar        | erigon-lodestar |
| nethermind      | lighthouse      | nethermind-lighthouse |
| nethermind      | prysm           | nethermind-prysm |
| nethermind      | teku            | nethermind-teku |
| nethermind      | lodestar        | nethermind-lodestar |
| besu            | lighthouse      | besu-lighthouse |
| besu            | prysm           | besu-prysm |
| besu            | teku            | besu-teku |
| besu            | lodestar        | besu-lodestar |

### Special Scenarios

- `default`: Tests the base Ephemery role setup
- `validator`: Tests the validator setup
- `security`: Tests security configurations
- `monitoring`: Tests monitoring setup
- `backup`: Tests backup functionality

## Running Tests Locally

To run a specific test locally:

```bash
# Run a specific test
molecule test -s <scenario-name>

# Example: Test the geth-lighthouse client combination
molecule test -s clients/geth-lighthouse
```

You can also use the provided `run-tests.sh` script:

```bash
# Run all tests
./run-tests.sh

# Run a specific test
./run-tests.sh clients/geth-lighthouse
```

## Adding a New Test

To add a new test scenario:

1. Create a new directory `molecule/<scenario-name>/`
2. Create the required files:
   - `molecule.yml`: Configuration for the test environment
   - `converge.yml`: Playbook to apply the role
   - `verify.yml`: Tests to verify the role worked correctly

Alternatively, you can use the `generate-molecule-tests.sh` script in the scripts directory to generate tests for all client combinations:

```bash
# Generate all client combination tests
../scripts/generate-molecule-tests.sh
```

## Test Verification

The verification phase checks that:

1. Required services are running
2. Necessary ports are open
3. Configuration files exist and have correct permissions
4. Components can communicate with each other

## Continuous Integration

Tests run automatically on GitHub Actions for all pull requests and pushes to the main/master branch. The workflow is defined in `.github/workflows/molecule.yaml`.

## Troubleshooting

If tests fail, check:

1. Docker is running and accessible
2. The Docker socket is available at `/var/run/docker.sock`
3. You have sufficient permissions to access the Docker socket
4. The containers have network connectivity
5. The client binaries are installed correctly

For detailed logs, run tests with increased verbosity:

```bash
molecule --debug test -s <scenario-name>
```

## Port References

| Client | Port | Description |
|--------|------|-------------|
| All execution clients | 8545 | JSON-RPC API |
| Lighthouse | 5052 | HTTP API |
| Prysm | 4000 | gRPC API |
| Teku | 5051 | REST API |
| Lodestar | 9000 | HTTP API |

## Contributing

When contributing new tests, ensure they:

1. Are idempotent (can run multiple times without error)
2. Clean up after themselves
3. Test for actual functionality, not just presence of files
4. Include clear assertions with helpful error messages
