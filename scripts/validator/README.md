# Validator Management Scripts

This directory contains scripts for managing validators in Ephemery nodes.

## Available Scripts

### `manage_validator_keys.sh`

A comprehensive validator key management script that provides the following functionality:

- Generate new validator keys
- Import existing validator keys
- List current validator keys
- Backup validator keys
- Restore validator keys from backup
- Validate key integrity

#### Usage

```bash
./manage_validator_keys.sh [operation] [options]
```

#### Operations

- `generate`: Generate new validator keys
- `import`: Import existing validator keys
- `list`: List current validator keys
- `backup`: Backup validator keys
- `restore`: Restore validator keys from backup
- `validate`: Validate key integrity

#### Options

- `-n, --network NAME`: Network name (default: ephemery)
- `-c, --client NAME`: Client name (default: lighthouse)
- `-k, --key-count NUM`: Number of keys to generate (for generate operation)
- `-m, --mnemonic STRING`: Mnemonic for key generation (optional)
- `-w, --withdrawal ADDR`: Withdrawal address (for generate operation)
- `-f, --fee-recipient ADDR`: Fee recipient address (for generate operation)
- `-s, --source PATH`: Source path for import operation
- `-b, --backup-dir PATH`: Backup directory (default: ~/ephemery/backups/validator/keys)
- `-t, --timestamp TIME`: Backup timestamp for restore (default: latest)
- `--force`: Force operation without confirmation
- `--dry-run`: Show what would be done without making changes
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

#### Examples

```bash
# Generate 10 validator keys
./manage_validator_keys.sh generate --key-count 10 --withdrawal 0x123...

# Import keys from a directory
./manage_validator_keys.sh import --source /path/to/keys

# List all validator keys
./manage_validator_keys.sh list

# Backup validator keys
./manage_validator_keys.sh backup

# Restore validator keys from a specific backup
./manage_validator_keys.sh restore --timestamp 20240313-123045

# Validate key integrity
./manage_validator_keys.sh validate
```

### `monitor_validator.sh`

A unified interface for monitoring validators in Ephemery nodes. This script integrates with the existing monitoring scripts and provides a simple interface for checking validator status, performance, and health.

#### Usage

```bash
./monitor_validator.sh [operation] [options]
```

#### Operations

- `status`: Show current validator status (default)
- `performance`: Show validator performance metrics
- `health`: Check validator health
- `dashboard`: Show live dashboard

#### Options

- `-b, --beacon-api URL`: Beacon API URL (default: http://localhost:5052)
- `-v, --validator-api URL`: Validator API URL (default: http://localhost:5062)
- `-m, --metrics-api URL`: Validator metrics API URL (default: http://localhost:5064/metrics)
- `-c, --continuous`: Enable continuous monitoring
- `-i, --interval SEC`: Monitoring interval in seconds (default: 60)
- `-t, --threshold NUM`: Alert threshold percentage (default: 90)
- `--verbose`: Enable verbose output
- `-h, --help`: Show help message

#### Examples

```bash
# Show current validator status
./monitor_validator.sh status

# Show validator performance metrics with verbose output
./monitor_validator.sh performance --verbose

# Check validator health with a custom threshold
./monitor_validator.sh health --threshold 95

# Show live dashboard with continuous updates every 30 seconds
./monitor_validator.sh dashboard --continuous --interval 30
```

### `test_validator_config.sh`

A test script for the validator configuration that verifies the validator configuration in the inventory file and checks if the validator container is running correctly.

#### Usage

```bash
./test_validator_config.sh [options]
```

#### Options

- `-i, --inventory FILE`: Inventory file to test (default: REPO_ROOT/inventory.yaml)
- `-c, --container NAME`: Validator container name (default: ephemery-validator)
- `--inventory-only`: Only test the inventory file
- `--container-only`: Only test the validator container
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

#### Examples

```bash
# Test validator configuration with default settings
./test_validator_config.sh

# Test only the inventory file with verbose output
./test_validator_config.sh --inventory-only --verbose

# Test only the validator container with a custom container name
./test_validator_config.sh --container-only --container ephemery-validator-lighthouse

# Test a specific inventory file
./test_validator_config.sh --inventory /path/to/custom-inventory.yaml
```

## Integration with Deployment

The validator management scripts are integrated with the Ephemery deployment system. When deploying an Ephemery node with validator support enabled, you can use the following options:

```bash
./scripts/deployment/deploy-ephemery.sh --validator
```

This will enable validator support and prompt for additional validator configuration options during the deployment process.

## Validator Monitoring

For monitoring validator performance, see the scripts in the `scripts/monitoring` directory, particularly:

- `advanced_validator_monitoring.sh`: Comprehensive validator monitoring and reporting
- `validator_performance_monitor.sh`: Collects performance metrics from validator clients

## Validator Key Restore

For automated handling of validator keys during network resets, see:

- `scripts/utilities/ephemery_key_restore_wrapper.sh`: Simplified interface for restoring validator keys
- `scripts/utilities/enhanced_key_restore.sh`: Advanced key restore functionality

## Related Ansible Playbooks

The following Ansible playbooks are available for validator management:

- `ansible/playbooks/validator.yaml`: Deploy or update validator
- `ansible/playbooks/improve-validator.yaml`: Improve validator key loading and synchronization
- `ansible/playbooks/deploy_validator_dashboard.yaml`: Deploy validator performance dashboard
- `ansible/playbooks/restore_validator_keys.yaml`: Restore validator keys from backup
- `ansible/playbooks/setup_enhanced_key_restore.yaml`: Setup enhanced validator key restore system
- `ansible/playbooks/deploy_validator_monitoring.yaml`: Deploy validator performance monitoring
- `ansible/playbooks/deploy_key_performance_metrics.yaml`: Deploy key performance metrics 