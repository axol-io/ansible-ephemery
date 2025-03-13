# Script Directory Structure

This document outlines the organization of the scripts directory in the Ephemery project, explaining the purpose of each subdirectory and providing examples of scripts you'll find in each location.

## Overview

The scripts directory has been reorganized according to the high-priority script consolidation initiative outlined in the [Project Roadmap](../PROJECT_MANAGEMENT/ROADMAP.md). The scripts are now organized into functional categories for improved maintainability, discoverability, and to reduce duplication.

## Directory Structure

```
scripts/
├── core/                 # Core ephemery functionality scripts
├── deployment/           # Scripts for deploying ephemery nodes
│   ├── common/           # Shared deployment utilities
│   ├── local/            # Local deployment scripts 
│   └── remote/           # Remote deployment scripts
├── development/          # Scripts for development environment setup and testing
├── examples/             # Example scripts and usage patterns
├── maintenance/          # Scripts for maintenance tasks
├── monitoring/           # Monitoring and alerting scripts
├── tools/                # Specialized tools for specific tasks
├── utilities/            # Helper utilities and shared functions
└── utils/                # Legacy utility scripts (being migrated)
```

## Script Categories

### Core Scripts

Scripts providing core Ephemery functionality:

- `ephemery_retention.sh` - Handles network resets and data retention
- `setup_ephemery_cron.sh` - Sets up automated maintenance via cron jobs
- `reset_ephemery.sh` - Manually resets an Ephemery node

### Deployment Scripts

Scripts for deploying and configuring Ephemery nodes:

- `deployment/deploy-ephemery.sh` - Main deployment script with guided configuration
- `deployment/common/inventory_generator.sh` - Generates inventory files for deployments
- `deployment/local/run-ephemery-local.sh` - Sets up a local Ephemery node
- `deployment/remote/run-ephemery-remote.sh` - Deploys Ephemery to a remote server

### Maintenance Scripts

Scripts for maintaining and fixing Ephemery nodes:

- `maintenance/enhanced_checkpoint_sync.sh` - Improved checkpoint sync with automatic recovery
- `fix_checkpoint_sync.sh` - Fixes checkpoint sync issues (being migrated)
- `test_checkpoint_sync.sh` - Tests different sync strategies (being migrated)
- `benchmark_sync.sh` - Benchmarks sync performance (being migrated)

### Monitoring Scripts

Scripts for monitoring and checking node status:

- `check_ephemery_status.sh` - Checks node status
- `check_sync_status.sh` - Verifies sync progress
- `validator_performance_monitor.sh` - Monitors validator performance
- `key_performance_metrics.sh` - Collects key performance metrics

### Utilities Scripts

Helper scripts for common tasks:

- `utilities/ephemery_key_restore_wrapper.sh` - Restores validator keys
- `utilities/checkpoint_sync_alert.sh` - Generates alerts for checkpoint sync issues
- `utilities/quick_health_vibe_check.sh` - Quick status check

### Development Scripts

Scripts for development and testing:

- `development/verify-collections.sh` - Verifies Ansible collections
- `development/test-collection-loading.sh` - Tests loading of Ansible collections
- `development/dev-env-manager.sh` - Manages development environments
- `development/setup-dev-env.sh` - Sets up development environment

## Using the Scripts

### Path References

When referencing scripts in documentation or other scripts, use the full path from the scripts directory:

```bash
# Correct path reference
./scripts/deployment/deploy-ephemery.sh

# Legacy path that needs updating 
./scripts/deploy-ephemery.sh
```

### Common Scripts

These scripts are commonly used for typical operations:

1. **Deploying a new node**:
   ```bash
   ./scripts/deployment/deploy-ephemery.sh
   ```

2. **Fixing checkpoint sync issues**:
   ```bash
   ./scripts/maintenance/enhanced_checkpoint_sync.sh --apply
   ```

3. **Checking node status**:
   ```bash
   ./scripts/monitoring/check_ephemery_status.sh
   ```

4. **Restoring validator keys**:
   ```bash
   ./scripts/utilities/ephemery_key_restore_wrapper.sh
   ```

## Script Migration Status

The script reorganization is ongoing. Legacy scripts in the root directory are gradually being migrated to their appropriate subdirectories. During this transition:

1. Scripts in the root will continue to work as before
2. Some scripts have already been moved to their respective directories
3. Documentation is being updated to reflect the new paths

See the [Scripts Directory Consolidation](../PROJECT_MANAGEMENT/ROADMAP.md#scripts-directory-consolidation) section of the roadmap for more details.

## Contributing New Scripts

When creating new scripts for the Ephemery project:

1. Place the script in the appropriate subdirectory based on its function
2. Follow the naming convention of existing scripts in that directory
3. Include a comment header describing the script's purpose
4. Add appropriate error handling and logging
5. Update relevant documentation to reference the new script

## Related Documentation

- [Project Roadmap](../PROJECT_MANAGEMENT/ROADMAP.md)
- [Contributing Guide](../DEVELOPMENT/CONTRIBUTING.md)
- [Script Reference](./EPHEMERY_SCRIPT_REFERENCE.md) 