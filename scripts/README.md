# Ephemery Scripts

This directory contains scripts for managing and operating Ephemery nodes and validators.

## Core Scripts

The main scripts are located in the repository root for easy access:

| Script | Description |
|--------|-------------|
| `setup_ephemery.sh` | Sets up an Ephemery node with both execution (Geth) and consensus (Lighthouse) clients |
| `setup_ephemery_validator.sh` | Sets up a Lighthouse validator client for participating in the Ephemery network |
| `monitor_ephemery.sh` | Monitors logs and status of running Ephemery clients |
| `health_check_ephemery.sh` | Performs health checks on node performance, sync status, and more |
| `prune_ephemery_data.sh` | Manages disk space by pruning unnecessary data |
| `backup_restore_validators.sh` | Backs up and restores validator keys and slashing protection data |
| `troubleshoot_ephemery.sh` | Diagnoses and fixes common issues with Ephemery nodes |

## Script Organization

The scripts in this directory are organized into several categories:

### Core Configuration

Located in `core/` directory:

| Script | Description |
|--------|-------------|
| `ephemery_config.sh` | Common configuration shared across all scripts for consistency |

### Deployment

Located in `deployment/` directory:

| Script | Description |
|--------|-------------|
| `deploy-ephemery.sh` | Full deployment script for Ephemery nodes |
| `setup-ephemery.sh` | Another version of the setup script (used by Ansible) |
| `setup_ephemery_cron.sh` | Sets up scheduled tasks for Ephemery maintenance |
| `deploy_ephemery_retention.sh` | Configures data retention policies |
| `setup_dashboard.sh` | Sets up monitoring dashboards |
| `deploy_key_performance_metrics.sh` | Deploys performance monitoring metrics |
| `deploy_enhanced_key_restore.sh` | Advanced key restoration utility |
| `fix_mainnet_deployment.sh` | Fixes issues with mainnet deployments |

### Validator Management

Located in `validator/` directory:

| Script | Description |
|--------|-------------|
| `manage-validator.sh` | Manages validator operations |
| `start-validator-dashboard.sh` | Starts the validator monitoring dashboard |
| `restore_validator_keys.sh` | Restores validator keys (older version) |

### Monitoring and Maintenance

Located in various directories:

| Script | Description |
|--------|-------------|
| `monitoring/` | Scripts for monitoring and alerts |
| `maintenance/` | Scripts for regular maintenance tasks |
| `utilities/` | Utility scripts for common operations |

### Development and Testing

Located in `development/` and related directories:

| Script | Description |
|--------|-------------|
| `run-tests.sh` | Runs automated tests |
| `check-yaml-extensions.sh` | Validates YAML file extensions |
| `install-collections.sh` | Installs required Ansible collections |

## Script Organization Tools

Scripts to help manage and organize the script collection:

| Script | Description |
|--------|-------------|
| `organize_scripts.sh` | Organizes scripts into appropriate directories |
| `complete_script_organization.sh` | Comprehensive script organization tool |
| `update_script_readmes.sh` | Updates README files for script directories |

## Usage Guidelines

1. **Root-level Scripts**: Use the scripts in the repository root for common operations. These are designed to be user-friendly.

2. **Specialized Scripts**: The scripts in this directory are more specialized and may require additional configuration or knowledge.

3. **Configuration**: Most scripts source the common configuration from `core/ephemery_config.sh`. Modify this file to change default settings across all scripts.

4. **Execution**: Make scripts executable before running:
   ```bash
   chmod +x script_name.sh
   ```

5. **Help Options**: Most scripts provide help information with the `-h` or `--help` option.

## Best Practices

1. **Backup First**: Always backup important data before running maintenance scripts.

2. **Dry Run**: Many scripts have a dry run option to show what would be done without making changes.

3. **Test in Development**: Test scripts in a development environment before using in production.

4. **Check Logs**: Monitor logs after running scripts to ensure operations completed successfully.

5. **Security**: Be careful with scripts that modify validator keys or authentication data, as these can affect the security of your staked funds.

## Contributing

When adding new scripts:

1. Follow the existing naming conventions
2. Add appropriate error handling and help information
3. Update this README to document the new script
4. Consider adding the script to the common configuration if appropriate
