# Ephemery Node

Ephemery is an Ethereum testnet that restarts weekly, providing a clean environment for testing and development.

## Quick Start

To run a simple local demo of an Ephemery node:

```bash
./run-ephemery-demo.sh
```

This will start a local Ephemery node with Geth and Lighthouse in Docker containers.

## Unified Deployment System

We now provide a simplified unified deployment system that makes it easy to deploy Ephemery nodes:

```bash
# Start the guided deployment process
./scripts/deploy-ephemery.sh
```

The unified deployment system offers:

- **Guided Configuration**: Interactive setup wizard to customize your deployment
- **One-Command Deployment**: Deploy to local or remote servers with a single command
- **Automated Verification**: Built-in verification tests ensure deployment success
- **Smart Defaults**: Sensible defaults that work for most users

### Deployment Options

```bash
# Local deployment with guided setup
./scripts/deploy-ephemery.sh --type local

# Remote deployment with guided setup
./scripts/deploy-ephemery.sh --type remote --host your-server

# Deploy with custom inventory file
./scripts/deploy-ephemery.sh --inventory custom-inventory.yaml

# Non-interactive deployment with default settings
./scripts/deploy-ephemery.sh --yes
```

### Configuration Wizard

For custom configurations, you can use our configuration wizard:

```bash
./scripts/utils/guided_config.sh --output my-inventory.yaml
```

This will guide you through creating a custom inventory file that can be used with the deployment system.

## Ephemery Automation

For production Ephemery nodes, we recommend using our automated retention system:

```bash
# Deploy retention script and cron job
./scripts/deploy_ephemery_retention.sh
```

This will set up automatic detection and handling of Ephemery network resets. For more information, see:

- [Ephemery Setup Guide](docs/EPHEMERY_SETUP.md)
- [Ephemery Script Reference](docs/EPHEMERY_SCRIPT_REFERENCE.md)
- [Ephemery-Specific Configuration](docs/EPHEMERY_SPECIFIC.md)

## Implementation Progress

We've successfully implemented several key improvements to our Ansible deployment:

✅ **Ephemery Testnet Support**
- Added automated genesis reset detection
- Implemented retention script with 5-minute polling
- Created cron job setup for automatic resets
- Added comprehensive documentation

✅ **Validator Key Management Improvements**
- Enhanced key validation and extraction
- Added multi-format archive support
- Implemented automatic key backup
- Added atomic key operations

✅ **Synchronization Monitoring**
- Created comprehensive sync dashboard
- Implemented detailed metrics collection
- Added historical sync progress tracking

✅ **Unified Deployment System**
- Created single-command deployment script
- Implemented guided configuration workflow
- Added deployment verification tests
- Provided comprehensive documentation
- For detailed info, see our [Unified Deployment Guide](docs/UNIFIED_DEPLOYMENT.md)

🚧 **In Progress**
- Advanced key management features
- Validator performance monitoring
- Checkpoint sync improvements

For detailed roadmap information, see our [Roadmap](docs/ROADMAP.md).

## Validator Support

The playbook now includes improved validator support with:

- **Robust Key Count Validation**
  - Verification of expected vs actual key count
  - Detailed logging of key loading status
  - Visual validation summary display

- **Enhanced Compressed Key Handling**
  - Support for multiple archive formats (zip and tar.gz)
  - Improved extraction validation with better error reporting
  - Staged extraction with atomic commit to prevent partial operations

- **Key Backup Functionality**
  - Automatic backup before key replacement
  - Timestamped backup directories with rotation
  - Backup tracking with "latest_backup" pointer

- **Key File Validation**
  - Comprehensive key format validation (JSON format check)
  - Detailed error reporting for invalid keys
  - Validation report file generation for troubleshooting

For detailed validator setup instructions, see:

- [Validator Guide](docs/VALIDATOR_README.md)
- [Validator Key Management](docs/VALIDATOR_KEY_MANAGEMENT.md)

## Synchronization Monitoring

New synchronization monitoring features include:

- **Comprehensive Sync Dashboard**
  - Real-time sync metrics display for both execution and consensus clients
  - Visual progress indicators with status tracking
  - Node information and resource usage statistics

- **Enhanced Status Reporting**
  - Detailed Geth sync stage logging
  - Lighthouse distance/slot metrics
  - Combined execution/consensus sync status

- **Performance Metrics**
  - Sync percentage calculation and visualization
  - Historical data collection (last 100 sync points)
  - JSON output for external tool integration

For detailed monitoring information, see our [Sync Monitoring Guide](docs/SYNC_MONITORING.md).

## Checkpoint Sync Improvements

We've implemented a comprehensive solution for fixing checkpoint sync issues:

- **Automatic Checkpoint URL Testing**
  - Tests multiple checkpoint sync URLs
  - Selects the best working URL automatically
  - Updates inventory configuration with working URL

- **Optimized Sync Configuration**
  - Configures Lighthouse with optimized parameters
  - Implements network optimizations for faster sync
  - Adds proper timeout and retry mechanisms

- **Monitoring and Recovery**
  - Creates checkpoint sync monitoring script
  - Implements automatic recovery for stuck syncs
  - Provides detailed sync progress reporting

To fix checkpoint sync issues, run:

```bash
./scripts/fix_checkpoint_sync.sh
```

For detailed information about checkpoint sync fixes, see our [Checkpoint Sync Fix Guide](docs/CHECKPOINT_SYNC_FIX.md).

The monitoring dashboard can be enabled with:

```yaml
# In your inventory file
sync_monitoring_enabled: true   # Enable sync monitoring (default: true)
sync_dashboard_enabled: true    # Enable web dashboard (default: false)
```

To access the sync status:

```bash
# CLI access
cat /path/to/ephemery/data/monitoring/sync/current_status.json

# Web dashboard (if enabled)
http://YOUR_SERVER_IP/ephemery-status/

# Monitoring logs
cat /path/to/ephemery/data/monitoring/sync/monitor.log
```

## Directory Structure

- `run-ephemery-demo.sh` - Main demo script for local testing
- `scripts/` - Advanced deployment scripts
  - `local/` - Scripts for local deployment
  - `remote/` - Scripts for remote deployment
  - `utils/` - Utility scripts for inventory management, cleanup, and more
- `config/` - Configuration files and templates
- `docs/` - Detailed documentation
- `ansible/` - Ansible playbooks and tasks
  - `tasks/` - Individual task files
  - `templates/` - Jinja2 templates for configuration files
  - `playbooks/` - Main playbook files

## Advanced Usage

For more advanced deployments, including remote server deployment and custom configurations, see the documentation in the `docs/` directory:

- [Local Deployment](docs/local-deployment.md)
- [Remote Deployment](docs/remote-deployment.md)
- [Configuration](docs/configuration.md)
- [Inventory Management](docs/inventory-management.md)
- [Implementation Details](docs/IMPLEMENTATION_DETAILS.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Known Issues](docs/KNOWN_ISSUES.md)

## Inventory Configuration Options

The following new options have been added to the inventory:

```yaml
# Validator key configuration
validator_expected_key_count: 1000  # Expected number of validator keys (set to 0 to skip validation)

# Sync monitoring configuration
sync_monitoring_enabled: true       # Enable sync monitoring
sync_dashboard_enabled: true        # Enable web dashboard for sync status
```

## Requirements

- Docker and Docker Compose
- Bash shell
- For remote deployment: SSH access to target server
- For sync monitoring: Python 3 with jq installed on the target node
- For web dashboard: nginx (optional)
