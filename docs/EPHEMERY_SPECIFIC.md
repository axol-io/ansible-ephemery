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
4. **Simplified Deployment**: Reduces the need for complex configuration.

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
- Uses genesis sync with `--allow-insecure-genesis-sync` for reliable syncing

## JWT Secret Configuration

The JWT secret is used for secure communication between execution and consensus clients:

1. The role generates a JWT secret file at the configured location (`{{ jwt_secret_path }}`)
2. This file is mounted into both the execution and consensus client containers
3. Both containers are configured to use this JWT secret for authentication

## Manual Configuration for Other Clients

For other client combinations (not using the Ephemery-specific images), the role:
1. Uses standard Docker images with custom configuration
2. Uses genesis sync with appropriate options
3. May require additional configuration for proper operation on the Ephemery network

## Troubleshooting and Maintenance

### Common Issues

#### 1. Monitoring Configuration Issues

If Prometheus is unable to scrape metrics from clients:

- Check that the correct ports are configured in the Prometheus configuration:
  - Geth metrics are available on port 6060 with path `/debug/metrics/prometheus`
  - Lighthouse metrics should be set to a different port (e.g., 5054) than the HTTP API port (5052)
- Verify that the client containers have the appropriate metrics flags enabled:
  - For Lighthouse: `--metrics --metrics-address=0.0.0.0 --metrics-port=5054`
  - For Geth: metrics are enabled by default on port 6060

#### 2. Client Synchronization Issues

Ephemery clients may sometimes fail to sync properly, particularly after a network reset:

- Clear the data directories to start from a clean state:
  ```bash
  # Clear data directories
  rm -rf /root/ephemery/data/geth/* /root/ephemery/data/beacon/*
  ```
- Download the latest genesis files and reinitialize the clients
- Restart the containers with the correct configuration

### Periodic Resets

Since Ephemery is designed to be automatically reset, it's recommended to set up a cron job to handle this:

```bash
# Create a reset script (see scripts/reset_ephemery.sh in this repository)
# Add a cron job to run the script daily
0 0 * * * /opt/ephemery/scripts/reset_ephemery.sh > /opt/ephemery/logs/reset.log 2>&1
```

The reset process typically includes:
1. Stopping the client containers
2. Clearing data directories
3. Downloading the latest genesis files
4. Reinitializing the execution client
5. Restarting the containers

## Resources

- [Ephemery Client Wrapper](https://github.com/pk910/ephemery-client-wrapper)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Ephemery Scripts](https://github.com/ephemery-testnet/ephemery-scripts)
