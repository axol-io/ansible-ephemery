# Ephemery Scripts

This directory contains scripts for setting up, managing, and maintaining Ephemery environments.

## Directory Structure

The scripts have been reorganized into a more logical structure:

- `scripts/lib/` - Contains the common library
- `scripts/core/` - Core functionality scripts 
- `scripts/deployment/` - Deployment scripts
- `scripts/maintenance/` - Maintenance scripts
- `scripts/monitoring/` - Monitoring scripts
- `scripts/testing/` - Testing scripts
- `scripts/development/templates/` - Script templates
- `scripts/examples/` - Example scripts
- `scripts/tools/` - Tools for managing and working with scripts

> **Note**: The old directory structure (`utils/`, `tools/`, `validator/`, `remote/`, `local/`, `setup/`) is being phased out. All scripts have been migrated to the new structure, though some legacy directories remain temporarily for backward compatibility.

## Migration Status

The script reorganization has been completed. The following steps were taken:

1. ✅ Created a new directory structure with dedicated categories
2. ✅ Implemented a consolidated common library in `scripts/lib/common.sh`
3. ✅ Created a script template in `scripts/development/templates/`
4. ✅ Added README files documenting the new structure
5. ✅ Developed working example scripts 
6. ✅ Created tools for migration and auditing
7. ✅ Migrated scripts to the new structure

## Audit Results

The `script_audit.sh` tool identified the following issues that still need to be addressed:

1. Many scripts (174 out of 205) don't yet use the common library
2. Many scripts have their own color definitions instead of using the standard ones from the common library
3. Several scripts define functions that are already available in the common library

These issues should be fixed systematically, starting with the most frequently used scripts.

## Next Steps

To complete the script reorganization and standardization, the following steps should be taken:

1. Run the `fix_common_issues.sh` tool to address common issues in scripts:
   ```bash
   ./scripts/tools/fix_common_issues.sh --script path/to/script.sh
   ```
   
   Or to process all scripts in a directory:
   ```bash
   ./scripts/tools/fix_common_issues.sh --directory scripts/monitoring
   ```

2. Test all scripts after modification to ensure they work correctly
3. Remove redundant directories once all scripts have been migrated and tested
4. Update documentation to reflect the new structure

## Using the Common Library

To use the common library in your scripts, add the following code to the top of your script:

```bash
#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
```

This will give you access to common utility functions such as:

- `log_info`, `log_warn`, `log_error`, `log_debug`, `log_success` - Standardized logging functions
- `print_banner` - Print a formatted banner
- `confirm_action` - Ask for user confirmation
- `is_command_available` - Check if a command is available
- `check_dependencies` - Check if required dependencies are installed
- `get_script_name` - Get the name of the current script
- `get_absolute_path` - Convert a relative path to an absolute path
- `is_ephemery_environment` - Check if running in an Ephemery environment
- `check_ansible` - Check if ansible is installed
- `get_inventory_value` - Read a configuration value from inventory.yaml

## Script Categories

Scripts are organized by their functionality:

### Core Scripts (`core/`)

Scripts providing core functionality for the Ephemery system, including:
- Basic setup and configuration
- Path and environment management
- Validator handling
- Version management
- Retention policies

### Deployment Scripts (`deployment/`)

Scripts for deploying Ephemery environments, including:
- Ansible playbook runners
- Environment provisioning
- Collection installation
- Environment setup

### Maintenance Scripts (`maintenance/`)

Scripts for maintaining Ephemery environments, including:
- Updates and upgrades
- Backup and restore operations
- Cleaning and fixing issues
- Secret management
- Reset handling

### Monitoring Scripts (`monitoring/`)

Scripts for monitoring Ephemery environments, including:
- Log monitoring
- Status checking
- Dashboards
- Diagnostic tools
- Output analysis

### Testing Scripts (`testing/`)

Scripts for testing and validation, including:
- Unit/integration tests
- Validation scripts
- Verification tools
- Auditing tools
- Linting and pre-commit hooks

### Examples (`examples/`)

Example scripts demonstrating proper usage of the common library and other Ephemery features.

### Development Templates (`development/templates/`)

Templates for creating new scripts that follow Ephemery conventions.

## Script Development Guidelines

When developing scripts for Ephemery, please follow these guidelines:

1. Use the common library for consistent functionality
2. Follow the script template structure
3. Place scripts in the appropriate category directory
4. Use strict mode (`set -euo pipefail`)
5. Implement proper error handling
6. Document usage with header comments
7. Follow shellcheck recommendations

## Tools

- `reorganize_scripts.sh` - Identifies and migrates scripts to the new directory structure
- `script_audit.sh` - Audits scripts for common patterns and duplication

## Examples

See the `examples/` directory for example scripts demonstrating proper usage of the common library.

```bash
# Example of running the hello_ephemery.sh example
./scripts/examples/hello_ephemery.sh
```

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

# Scripts Directory Organization

## Current Issues

The scripts directory currently has several organizational problems:

- Duplication of utility functions across multiple scripts and libraries
- Similar or redundant directories (`utils/`, `utilities/`, `tools/`)
- Inconsistent script naming and organization
- Lack of standardized script templates and common libraries

## Proposed Directory Structure

```
scripts/
├── README.md                # This file
├── core/                    # Core functionality scripts specific to Ephemery
│   └── ...
├── deployment/              # Scripts for deploying nodes and validators
│   └── ...
├── maintenance/             # Scripts for maintaining and fixing nodes
│   └── ...
├── monitoring/              # Monitoring and analytics scripts
│   └── ...
├── testing/                 # Testing scripts and frameworks
│   └── ...
├── development/             # Development utilities and templates
│   ├── templates/           # Script templates
│   └── ...
├── lib/                     # Shared libraries (replacing utilities/lib)
│   ├── common.sh            # Common utility functions
│   ├── logging.sh           # Logging functions
│   ├── validation.sh        # Input validation functions
│   ├── config.sh            # Configuration handling
│   └── README.md            # Documentation
└── examples/                # Example scripts and usage
    └── ...
```

## Implementation Plan

1. **Consolidate Utility Libraries**
   - Move all common functions to `scripts/lib/`
   - Create modular libraries: `common.sh`, `logging.sh`, `validation.sh`, etc.
   - Update all scripts to source from the new location

2. **Standardize Script Headers**
   - Version information
   - Description
   - Usage instructions
   - Author and date information

3. **Organize Scripts by Category**
   - Move scripts to appropriate directories based on their purpose
   - Rename scripts for consistency
   - Remove duplicate scripts

4. **Create Script Templates**
   - Standard templates in `development/templates/`
   - Enforce consistent style and structure

5. **Update Documentation**
   - Add README files to each directory
   - Document common libraries and functions

## Coding Standards

1. **Naming Conventions**
   - Use lowercase with hyphens for script names: `deploy-validator.sh`
   - Use snake_case for functions: `validate_config()`
   - Use UPPER_CASE for constants: `DEFAULT_PORT=8545`

2. **Script Structure**
   - Begin with proper shebang: `#!/usr/bin/env bash`
   - Include version and metadata
   - Source common libraries
   - Define functions before using them
   - Use a main() function at the end

3. **Error Handling**
   - Use `set -euo pipefail` for strict error handling
   - Implement proper error messages and exit codes
   - Use logging functions consistently
