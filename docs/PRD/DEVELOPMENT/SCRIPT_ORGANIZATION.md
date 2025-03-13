# Script Organization

This document outlines the organization of scripts in the Ephemery Node project, following the scripts directory consolidation initiative described in the project roadmap.

## Directory Structure

The scripts have been reorganized into the following directory structure to improve maintainability, discoverability, and reduce duplication:

- `/scripts/core/` - Core Ephemery functionality scripts
  - Scripts that provide essential Ephemery network functionality
  - Reset detection and handling
  - Network maintenance routines
  
- `/scripts/deployment/` - Scripts for deploying Ephemery nodes
  - Unified deployment system scripts
  - Environment setup scripts
  - Configuration generators
  
- `/scripts/monitoring/` - Monitoring and alerting scripts
  - Validator performance monitoring
  - Sync status monitoring
  - Health checks and alerting
  
- `/scripts/maintenance/` - Scripts for maintenance tasks
  - Checkpoint synchronization tools
  - Troubleshooting utilities
  - Performance benchmarking
  
- `/scripts/development/` - Scripts for development environment setup and testing
  - Repository standardization
  - Collection management
  - Development environment setup
  
- `/scripts/utilities/` - Helper utilities and shared functions
  - Key management tools
  - Shared libraries and functions
  - Miscellaneous helpers

## Script Categories

### Core Scripts

These scripts are essential for the core functionality of Ephemery nodes:

- `ephemery_retention.sh` - Monitors for network resets and handles necessary actions
- `setup_ephemery_cron.sh` - Sets up scheduled tasks for Ephemery operations
- `reset_ephemery.sh` - Performs manual reset of an Ephemery node

### Deployment Scripts

These scripts facilitate the deployment of Ephemery nodes:

- `deploy-ephemery.sh` - Main unified deployment script
- `deploy_ephemery_retention.sh` - Deploys the retention script and monitoring
- `setup_dashboard.sh` - Sets up monitoring dashboards
- `validator.sh` - Deploys and configures validators

### Monitoring Scripts

These scripts provide monitoring and reporting capabilities:

- `check_ephemery_status.sh` - Checks the current status of an Ephemery node
- `check_sync_status.sh` - Checks synchronization status
- `validator_performance_monitor.sh` - Monitors validator performance
- `run_validator_monitoring.sh` - Runner for the validator monitoring system
- `key_performance_metrics.sh` - Collects and analyzes validator key performance
- `advanced_validator_monitoring.sh` - Enhanced validator monitoring with alerts and dashboard

### Maintenance Scripts

These scripts help maintain and troubleshoot Ephemery nodes:

- `fix_checkpoint_sync.sh` - Fixes checkpoint synchronization issues
- `enhanced_checkpoint_sync.sh` - Improved checkpoint sync with automatic URL testing
- `test_checkpoint_sync.sh` - Tests various checkpoint sync configurations
- `troubleshoot-ephemery.sh` - Provides troubleshooting functionality
- `run-fast-sync.sh` - Configures fast synchronization
- `benchmark_sync.sh` - Benchmarks synchronization performance

### Development Scripts

These scripts assist with development and testing:

- `verify-collections.sh` - Verifies Ansible collections
- `test-collection-loading.sh` - Tests loading of Ansible collections
- `dev-env-manager.sh` - Manages development environments
- `setup-dev-env.sh` - Sets up development environments
- `create_client_tasks.sh` - Creates client-specific Ansible tasks
- `create_all_client_configs.sh` - Creates configuration for all supported clients

### Utility Scripts

These scripts provide various utilities and helper functions:

- `restore_validator_keys.sh` - Restores validator keys from backup
- `restore_validator_keys_wrapper.sh` - Wrapper for key restoration
- `checkpoint_sync_alert.sh` - Alerts for checkpoint sync issues
- `quick_health_vibe_check.sh` - Quick health check utility
- `organize_scripts.sh` - Script to organize scripts according to the new structure

## Migration Process

The script reorganization was performed using the `organize_scripts.sh` utility which:

1. Identified each script's appropriate category
2. Created backups of all scripts before moving
3. Moved scripts to their target directories
4. Created README files for each directory
5. Preserved script functionality by maintaining execution permissions

## Usage Guidelines

When adding new scripts to the repository, please follow these guidelines:

1. Place the script in the appropriate category directory
2. Follow the naming convention of existing scripts in that directory
3. Include a descriptive comment at the top of the script
4. Add execution permissions (`chmod +x`)
5. Update the relevant README file with script information
6. Consider creating shared functions for common operations

## Testing After Reorganization

After reorganizing scripts, the following verification steps are recommended:

1. Verify all scripts are executable
2. Test core functionality of critical scripts
3. Ensure any scripts referenced by other scripts or documentation are accessible
4. Check that documentation references point to the new script locations

## Future Improvements

The following improvements are planned for future script organization efforts:

1. Standardize argument parsing across all scripts
2. Create a shared library for common functions
3. Implement consistent logging and error handling
4. Add comprehensive help text to all scripts
5. Create a script testing framework

## References

- [Project Roadmap](../PROJECT_MANAGEMENT/ROADMAP.md)
- [Development Guide](./DEVELOPMENT_SETUP.md)
- [Contributing Guidelines](./CONTRIBUTING.md) 