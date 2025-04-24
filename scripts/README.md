# Ephemery Scripts

This directory contains scripts for managing the Ephemery validator system.

## Directory Structure

- **core/**: Essential functionality scripts
  - `run_ansible.sh`: Main script for running Ansible playbooks
  - `ephemery_output.sh`: Process Ephemery output
  - `setup_local_env.sh`: Set up local environment
  - `install-collections.sh`: Install required Ansible collections
  - `manage-validator.sh`: Manage validator operations

- **monitoring/**: All monitoring and dashboard scripts
  - `validator_dashboard.sh`: Unified dashboard script (replaces multiple dashboard scripts)
  - Original scripts (now consolidated): `ephemery_dashboard.sh`, `deploy_enhanced_validator_dashboard.sh`, `start-validator-dashboard.sh`
  - `monitor_logs.sh`: Monitor log files for errors and important events
  - `demo_validator_monitoring.sh`: Demonstration of validator monitoring (non-production)

- **utilities/**: General utility functions and tools
  - `analyze_output.sh`: Unified output analysis (replaces multiple output scripts)
  - Original scripts (now consolidated): `filter_ansible_output.sh`, `analyze_ansible_output.sh`, `diagnose_output.sh`
  - `generate_documentation.sh`: Generate documentation

- **maintenance/**: Cleanup, fixes, and maintenance scripts
  - `codebase_maintenance.sh`: Unified maintenance script (replaces multiple maintenance scripts)
  - Original scripts (now consolidated): `fix_shell_scripts.sh`, `fix_sc2155_warnings.sh`, `check-yaml-extensions.sh`, etc.
  - `check_sync_status.sh`: Check synchronization status of validators
  - `check-unencrypted-secrets.sh`: Detect unencrypted secrets in codebase
  - `add_version_strings.sh`: Add version strings to script files

- **backup/**: Backup and restoration scripts
  - `restore_validator_keys.sh`: Restore validator keys from backup

- **deployment/**: Scripts for deploying components
  - `apply_genesis_sync.sh`: Apply genesis state for validator synchronization

- **migration/**: Temporary migration scripts
  - `migrate_to_roles.sh`: Migrate playbooks to use role-based structure
  - `cleanup_legacy.sh`: Clean up legacy files and directories
  - `identify_legacy_files.sh`: Identify obsolete files for cleanup

- **testing/**: Testing and validation scripts
  - `run-tests.sh`: Run automated tests

- **lib/**: Shared libraries and functions
  - `common.sh`: Common functions used across scripts

- **archived/**: Scripts no longer actively used but kept for reference

## Backward Compatibility

For seamless transition, some symlinks have been created to maintain backward compatibility with existing workflows:

- `scripts/install-collections.sh` → `scripts/core/install-collections.sh`
- `scripts/check-yaml-extensions.sh` → `scripts/maintenance/check-yaml-extensions.sh`
- `scripts/check-unencrypted-secrets.sh` → `scripts/maintenance/check-unencrypted-secrets.sh`
- `scripts/tools/validate_versions.sh` → Original script (circular symlink for CI tooling)

These symlinks ensure that CI/CD pipelines, pre-commit hooks, and other automation continue to work while the transition to the new structure is completed.

## Usage

Most scripts support the `--help` flag to show usage information. For example:

```bash
./core/run_ansible.sh --help
./monitoring/validator_dashboard.sh --help
./utilities/analyze_output.sh --help
./maintenance/codebase_maintenance.sh --help
```

## Common Operations

- **Start Validator Dashboard**: `./monitoring/validator_dashboard.sh start`
- **Run Ansible Playbooks**: `./core/run_ansible.sh`
- **Analyze Output**: `./utilities/analyze_output.sh full`
- **Run Maintenance Tasks**: `./maintenance/codebase_maintenance.sh all`
- **Check Validator Sync**: `./maintenance/check_sync_status.sh`
- **Restore Validator Keys**: `./backup/restore_validator_keys.sh`

## Integration

Scripts are designed to work together in a modular way. The general workflow is:

1. Set up your environment using `core/setup_local_env.sh`
2. Run deployments with `core/run_ansible.sh`
3. Monitor validators with `monitoring/validator_dashboard.sh`
4. Analyze output with `utilities/analyze_output.sh`
5. Perform maintenance with `maintenance/codebase_maintenance.sh`
