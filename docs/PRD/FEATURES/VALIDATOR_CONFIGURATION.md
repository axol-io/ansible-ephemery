# Validator Configuration Guide

This document provides a comprehensive guide to configuring and setting up validators in the Ephemery deployment system.

## Table of Contents

1. [Introduction](#introduction)
2. [Validator Configuration Options](#validator-configuration-options)
3. [Deployment Methods](#deployment-methods)
4. [Validator Key Management](#validator-key-management)
5. [Performance Tuning](#performance-tuning)
6. [MEV-Boost Configuration](#mev-boost-configuration)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)

## Introduction

Validators are a critical component of Ethereum's consensus mechanism. In the Ephemery deployment system, validators can be configured and deployed alongside execution and consensus clients to participate in the network's consensus process.

## Validator Configuration Options

The Ephemery deployment system supports the following validator configuration options:

### Basic Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `validator_enabled` | Enable or disable validator functionality | `false` |
| `validator_client` | Validator client to use (lighthouse, prysm, teku, nimbus) | Same as consensus client |
| `validator_image` | Docker image for validator client | Default image for selected client |
| `validator_graffiti` | Custom graffiti for validator blocks | "Ephemery" |
| `validator_fee_recipient` | Fee recipient address for transaction fees | 0x0000000000000000000000000000000000000000 |

### Key Management

| Option | Description | Default |
|--------|-------------|---------|
| `validator_keys_password_file` | Path to password file for validator keys | 'files/passwords/validators.txt' |
| `validator_keys_src` | Path to validator keys directory | 'files/validator_keys' |
| `validator_expected_key_count` | Expected number of validator keys | 1000 |

### Performance Settings

| Option | Description | Default |
|--------|-------------|---------|
| `validator_memory_limit` | Memory limit for validator container | "2g" |
| `validator_cpu_limit` | CPU limit for validator container | "2" |
| `validator_extra_opts` | Additional options for validator client | "" |

### MEV-Boost Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `mev_boost_enabled` | Enable or disable MEV-Boost | `false` |
| `mev_boost_relays` | List of MEV-Boost relays to use | [] |

## Deployment Methods

### Using the Deployment Script

The easiest way to deploy a validator is using the `deploy-ephemery.sh` script with the `--validator` flag:

```bash
./scripts/deployment/deploy-ephemery.sh --type remote --host my-server.example.com --validator
```

This will guide you through the validator configuration process with interactive prompts.

### Manual Configuration

You can also manually configure the validator by creating or editing an inventory file:

```yaml
ephemery:
  hosts:
    my-node:
      ansible_host: 192.168.1.100
      el: geth
      cl: lighthouse
      validator_enabled: true
      validator_client: "lighthouse"
      validator_graffiti: "My Validator"
      validator_fee_recipient: "0x0000000000000000000000000000000000000000"
      validator_keys_password_file: 'files/passwords/validators.txt'
      validator_keys_src: 'files/validator_keys'
      validator_expected_key_count: 1000
      validator_memory_limit: "2g"
      validator_cpu_limit: "2"
      mev_boost_enabled: false
```

Then deploy using:

```bash
ansible-playbook -i my-inventory.yaml ansible/playbooks/main.yaml
```

## Validator Key Management

For detailed information about validator key management, please refer to the [Validator Key Management](VALIDATOR_KEY_MANAGEMENT.md) document.

### Key Generation

You can generate validator keys using the Ethereum staking deposit CLI:

```bash
./scripts/validator/generate_validator_keys.sh --count 10 --network ephemery
```

### Key Import

To import existing validator keys:

```bash
./scripts/validator/import_validator_keys.sh --source /path/to/keys --password-file /path/to/password.txt
```

## Performance Tuning

### Memory and CPU Allocation

Validator performance can be optimized by adjusting the memory and CPU limits:

```yaml
validator_memory_limit: "4g"  # Increase for better performance
validator_cpu_limit: "4"      # Increase for better performance
```

### Client-Specific Optimizations

Each validator client has specific optimization parameters:

#### Lighthouse

```yaml
validator_extra_opts: "--suggested-fee-recipient=0x... --metrics-address 0.0.0.0"
```

#### Prysm

```yaml
validator_extra_opts: "--suggested-fee-recipient=0x... --monitoring-host 0.0.0.0"
```

## MEV-Boost Configuration

To enable MEV-Boost:

```yaml
mev_boost_enabled: true
mev_boost_relays:
  - "https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net"
  - "https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com"
```

## Monitoring

Validator performance can be monitored using the built-in monitoring tools:

```bash
./scripts/deployment/deploy-ephemery.sh --type remote --host my-server.example.com --validator --monitoring --dashboard
```

This will deploy Prometheus and Grafana with pre-configured dashboards for validator monitoring.

### Metrics Endpoints

- Validator Metrics: `http://your-server:5064/metrics`
- Grafana Dashboard: `http://your-server:3000`

## Troubleshooting

### Common Issues

1. **Validator not starting**
   - Check Docker logs: `docker logs ephemery-validator`
   - Verify key permissions: `ls -la /root/ephemery/data/validator/keys`

2. **No validator keys found**
   - Verify key path: `validator_keys_src: 'files/validator_keys'`
   - Check key format: Keys should be in EIP-2335 format

3. **Validator not attesting**
   - Check consensus client sync status: `curl http://localhost:5052/eth/v1/node/syncing`
   - Verify validator is active: `curl http://localhost:5064/metrics | grep validator_active`

### Logs

Validator logs can be viewed with:

```bash
docker logs -f ephemery-validator
```

For more detailed troubleshooting, use:

```bash
./scripts/troubleshoot-ephemery.sh --validator
```

## Related Documentation

- [Validator Key Management](VALIDATOR_KEY_MANAGEMENT.md)
- [Validator Performance Monitoring](VALIDATOR_PERFORMANCE_MONITORING.md)
- [Validator Status Dashboard](VALIDATOR_STATUS_DASHBOARD.md) 