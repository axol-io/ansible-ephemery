# Molecule Testing Framework for Ephemery

This directory contains the Molecule tests for the Ephemery project. Molecule is used to test the Ansible roles in isolation to ensure they work correctly.

## Test Structure

The tests are organized into scenarios, each with its own directory:

```bash
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

We have test infrastructure for various combinations of execution clients and consensus clients in the `molecule/clients/` directory, but **currently only the geth-lighthouse combination is fully implemented and tested**. Other client combinations are placeholders for future development.

| Execution Client | Consensus Client | Scenario Name | Implementation Status |
|-----------------|------------------|---------------|------------------------|
| geth            | lighthouse       | geth-lighthouse | ✅ Implemented and tested |
| geth            | prysm           | geth-prysm | 🔄 Placeholder for future development |
| geth            | teku            | geth-teku | 🔄 Placeholder for future development |
| geth            | lodestar        | geth-lodestar | 🔄 Placeholder for future development |
| reth            | lighthouse      | reth-lighthouse | 🔄 Placeholder for future development |
| reth            | prysm           | reth-prysm | 🔄 Placeholder for future development |
| reth            | teku            | reth-teku | 🔄 Placeholder for future development |
| reth            | lodestar        | reth-lodestar | 🔄 Placeholder for future development |
| erigon          | lighthouse      | erigon-lighthouse | 🔄 Placeholder for future development |
| erigon          | prysm           | erigon-prysm | 🔄 Placeholder for future development |
| erigon          | teku            | erigon-teku | 🔄 Placeholder for future development |
| erigon          | lodestar        | erigon-lodestar | 🔄 Placeholder for future development |
| nethermind      | lighthouse      | nethermind-lighthouse | 🔄 Placeholder for future development |
| nethermind      | prysm           | nethermind-prysm | 🔄 Placeholder for future development |
| nethermind      | teku            | nethermind-teku | 🔄 Placeholder for future development |
| nethermind      | lodestar        | nethermind-lodestar | 🔄 Placeholder for future development |
| besu            | lighthouse      | besu-lighthouse | 🔄 Placeholder for future development |
| besu            | prysm           | besu-prysm | 🔄 Placeholder for future development |
| besu            | teku            | besu-teku | 🔄 Placeholder for future development |
| besu            | lodestar        | besu-lodestar | 🔄 Placeholder for future development |

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

## Using Different Molecule Drivers

The test infrastructure now supports multiple drivers for running Molecule tests:

### Docker Driver (Default)

By default, Molecule uses the Docker driver. The Docker socket path is automatically detected or can be specified with an environment variable:

```bash
# Use default detection (recommended)
./run-tests.sh

# Or specify a custom Docker socket path
DOCKER_HOST_SOCK="/path/to/docker.sock" ./run-tests.sh
```

### Delegated Driver (No Docker Required)

For environments where Docker isn't available or when you want to test directly on the local system, you can use the delegated driver:

```bash
# Run tests with the delegated driver
MOLECULE_DRIVER=delegated ./run-tests.sh
```

When using the delegated driver, tests will be executed on the local machine without requiring Docker containers.

### Other Drivers

You can configure other Molecule drivers by:

1. Creating a corresponding `molecule-<driver>.yml` file in the scenario directory
2. Running with `MOLECULE_DRIVER=<driver>` environment variable
