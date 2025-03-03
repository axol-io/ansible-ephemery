# Ephemery-Specific Configuration

This document provides details about the Ephemery-specific configurations and Docker images used in this Ansible role.

## Ephemery-Specific Docker Images

### Available Images

The role automatically uses specialized Docker images for certain client combinations:

| Client Type | Standard Selection | Ephemery-Specific Image |
|-------------|-------------------|-------------------------|
| Execution   | `el: "geth"`      | `pk910/ephemery-geth`   |
| Consensus   | `cl: "lighthouse"`| `pk910/ephemery-lighthouse` |

### Benefits of Ephemery-Specific Images

These specialized images offer several advantages:

1. **Pre-configured for Ephemery**: These images are specifically built for the Ephemery testnet with all necessary configurations.
2. **Built-in Genesis Configuration**: Contains the correct genesis state and configuration for the Ephemery network.
3. **Automatic Network Reset Handling**: Handles Ephemery network resets automatically.
4. **Simplified Deployment**: Reduces the need for complex configuration and checkpoint sync URLs.

## Implementation Details

### Execution Client (Geth)

When `el: "geth"` is selected, the role:
- Uses `pk910/ephemery-geth` instead of `ethereum/client-go`
- Runs the container with a wrapper script (`./wrapper.sh`) that handles Ephemery-specific initialization

### Consensus Client (Lighthouse)

When `cl: "lighthouse"` is selected, the role:
- Uses `pk910/ephemery-lighthouse` instead of `sigp/lighthouse`
- Runs the container with the `lighthouse beacon_node` command
- Includes the `--testnet-dir=/ephemery_config` parameter to use the built-in Ephemery network configuration

## JWT Secret Configuration

The JWT secret is used for secure communication between execution and consensus clients:

1. The role generates a JWT secret file at the configured location (`{{ jwt_secret_path }}`)
2. This file is mounted into both the execution and consensus client containers
3. Both containers are configured to use this JWT secret for authentication

## Manual Configuration for Other Clients

For other client combinations (not using the Ephemery-specific images), the role:
1. Uses standard Docker images with custom configuration
2. Requires checkpoint sync URLs for consensus clients
3. May require additional configuration for proper operation on the Ephemery network

## Resources

- [Ephemery Client Wrapper](https://github.com/pk910/ephemery-client-wrapper)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Ephemery Scripts](https://github.com/ephemery-testnet/ephemery-scripts)
