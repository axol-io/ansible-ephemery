# Ephemery Scripts

This directory contains scripts for managing and operating Ephemery nodes and validators.

## Script Categories

### Setup and Deployment
- `setup/setup_ephemery.sh` - Sets up an Ephemery node with both execution (Geth) and consensus (Lighthouse) clients
- `validator/setup_ephemery_validator.sh` - Sets up a Lighthouse validator client for participating in the Ephemery network
- `deployment/setup_obol_squadstaking.sh` - Sets up Obol distributed validator technology integration

### Monitoring and Health Checks
- `monitoring/monitor_ephemery.sh` - Monitors logs and status of running Ephemery clients
- `monitoring/health_check_ephemery.sh` - Performs health checks on node performance, sync status, and more

### Maintenance and Troubleshooting
- `maintenance/prune_ephemery_data.sh` - Manages disk space by pruning unnecessary data
- `maintenance/troubleshoot_ephemery.sh` - Diagnoses and fixes common issues with Ephemery nodes

### Validator Management
- `validator/backup_restore_validators.sh` - Backs up and restores validator keys and slashing protection data

## Usage Guidelines

1. **Script Location**: All scripts are organized in subdirectories based on their functionality.

2. **Configuration**: Most scripts source common configuration from shared utilities. Modify these for default settings.

3. **Execution**: Run scripts from the repository root, for example:
   ```bash
   ./scripts/setup/setup_ephemery.sh
   ```

4. **Help Options**: All scripts provide help information with the `-h` or `--help` option.

## Best Practices

1. **Backup First**: Always backup important data before running maintenance scripts.

2. **Dry Run**: Many scripts have a dry run option to show what would be done without making changes.

3. **Test in Development**: Test scripts in a development environment before using in production.

4. **Check Logs**: Monitor logs after running scripts to ensure operations completed successfully.

5. **Security**: Be careful with scripts that modify validator keys or authentication data.

## Directory Structure

- `setup/` - Scripts for initial setup and configuration
  - `setup_ephemery.sh` - Main setup script for Ephemery node

- `validator/` - Scripts for validator management
  - `setup_ephemery_validator.sh` - Setup script for validator nodes
  - `backup_restore_validators.sh` - Backup and restore utilities for validator keys

- `monitoring/` - Scripts for monitoring and health checks
  - `monitor_ephemery.sh` - Main monitoring script
  - `health_check_ephemery.sh` - Health check utilities

- `maintenance/` - Scripts for system maintenance
  - `prune_ephemery_data.sh` - Data pruning utilities
  - `troubleshoot_ephemery.sh` - Troubleshooting utilities

- `deployment/` - Scripts for deployment and integration
  - `setup_obol_squadstaking.sh` - Obol DVT integration setup

For detailed usage instructions for each script, please refer to the main [README.md](../README.md) or run the script with the `--help` flag.
