# Script Organization and Common Configuration

This document describes the script organization system and common configuration approach implemented for Ephemery nodes.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
  - [Root-Level Scripts](#root-level-scripts)
  - [Scripts Directory](#scripts-directory)
- [Common Configuration](#common-configuration)
  - [Configuration File](#configuration-file)
  - [Directory Standardization](#directory-standardization)
  - [Implementation](#implementation)
- [Script Development Guidelines](#script-development-guidelines)
  - [Coding Standards](#coding-standards)
  - [Documentation](#documentation)
  - [Error Handling](#error-handling)
- [Related Documentation](#related-documentation)

## Overview

The Ephemery script organization system provides a structured approach to managing the various scripts used for node setup, monitoring, maintenance, and operations. The system aims to improve maintainability, discoverability, and consistency across all scripts.

A key component of this system is the common configuration approach, which centralizes configuration settings in a single file that can be sourced by all scripts. This ensures consistent settings across the entire system and simplifies configuration management.

## Directory Structure

The script organization follows a hierarchical structure to group related scripts together.

### Root-Level Scripts

Core scripts used for primary operations are located at the repository root for easy access:

| Script | Description |
|--------|-------------|
| `setup_ephemery.sh` | Sets up the Ephemery node |
| `setup_ephemery_validator.sh` | Sets up the validator client |
| `monitor_ephemery.sh` | Provides monitoring capabilities |
| `health_check_ephemery.sh` | Performs health checks |
| `prune_ephemery_data.sh` | Manages disk space |
| `backup_restore_validators.sh` | Handles validator key backup/restore |

### Scripts Directory

The `scripts` directory contains specialized scripts organized into functional categories:

- `core/`: Core functionality and common libraries
  - `ephemery_config.sh`: Common configuration file
  - `functions.sh`: Shared utility functions

- `deployment/`: Scripts for deploying and configuring Ephemery nodes
  - `deploy-ephemery.sh`: Deployment script
  - `setup-ephemery.sh`: Alternative setup script
  - `setup_ephemery_cron.sh`: Sets up scheduled tasks

- `validator/`: Scripts for validator management
  - `manage-validator.sh`: Validator operations
  - `start-validator-dashboard.sh`: Starts monitoring dashboard

- `monitoring/`: Monitoring and alerting scripts
  - `monitor_sync.sh`: Monitors synchronization progress
  - `check_validator_balance.sh`: Monitors validator balances

- `maintenance/`: Scripts for routine maintenance
  - `prune_data.sh`: Older data pruning script
  - `backup_keys.sh`: Older key backup script

- `utilities/`: Utility scripts for common operations
  - `convert_keys.sh`: Converts key formats
  - `generate_jwtsecret.sh`: Generates JWT secrets

- `development/`: Scripts for development and testing
  - `run-tests.sh`: Runs test suite
  - `check-yaml-extensions.sh`: Validates YAML files

## Common Configuration

The common configuration approach centralizes configuration settings in a single file that is sourced by all scripts. This ensures consistent settings and simplifies configuration management.

### Configuration File

The common configuration is implemented in `scripts/core/ephemery_config.sh`, which defines:

1. **Directory Paths**:
   - Base directory (`EPHEMERY_BASE_DIR`)
   - Data directories for both clients
   - Configuration directories
   - Log directories

2. **Docker Settings**:
   - Container names
   - Network name
   - Image names and versions

3. **Client Settings**:
   - RPC endpoints
   - Port mappings
   - Performance settings

4. **Validator Settings**:
   - Key locations
   - Password handling
   - Fee recipient addresses

5. **Visual Formatting**:
   - Color codes for console output
   - Formatting functions

### Directory Standardization

The configuration establishes standardized directory locations:

```
${EPHEMERY_BASE_DIR}/
├── data/                    # Client data
│   ├── geth/                # Execution client data
│   ├── lighthouse/          # Consensus client data
│   └── lighthouse-validator/  # Validator client data
├── config/                  # Configuration files
├── logs/                    # Log files
└── secrets/                 # Sensitive files (JWT, keys)
    └── validator-passwords/ # Validator passwords
```

This standardization ensures that all scripts reference the same locations.

### Implementation

The common configuration is implemented with these features:

1. **Default Values**: Provides sensible defaults for all settings
2. **Override Capability**: Allows settings to be overridden through environment variables
3. **Existence Checks**: Scripts check for the configuration file and fall back to defaults if not found
4. **Validation**: Validates critical settings before use
5. **Documentation**: Each setting is documented with comments

Example of script integration:

```bash
# Source common configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/scripts/core/ephemery_config.sh" ]; then
  source "$SCRIPT_DIR/scripts/core/ephemery_config.sh"
else
  # Fallback to local definitions if common config not found
  EPHEMERY_BASE_DIR=~/ephemery
  # ... other defaults
fi
```

## Script Development Guidelines

The script organization system includes guidelines for script development to ensure consistency and maintainability.

### Coding Standards

Scripts should follow these coding standards:

1. **POSIX Compatibility**: Ensure scripts work in most POSIX-compliant shells
2. **Error Handling**: Include proper error handling and exit codes
3. **Help Messages**: Provide comprehensive help messages with examples
4. **Common Configuration**: Source the common configuration file
5. **Modularity**: Break down functionality into functions

### Documentation

Scripts should include clear documentation:

1. **Header**: Include a descriptive header explaining purpose
2. **Usage Examples**: Provide examples of common use cases
3. **Parameter Documentation**: Document all command-line parameters
4. **Function Documentation**: Document the purpose of each function
5. **Exit Codes**: Document the meaning of exit codes

### Error Handling

Scripts should implement robust error handling:

1. **Exit on Errors**: Use `set -e` or explicit error checking
2. **Descriptive Messages**: Provide clear error messages
3. **Cleanup on Exit**: Clean up temporary files on exit
4. **Dependency Checking**: Verify required tools before execution
5. **Graceful Degradation**: Provide fallback behavior when possible

## Related Documentation

- [Script Directory Structure](./SCRIPT_DIRECTORY_STRUCTURE.md)
- [Ephemery Script Reference](./EPHEMERY_SCRIPT_REFERENCE.md)
- [Development Guidelines](../DEVELOPMENT/DEVELOPMENT_SETUP.md)
- [Contributing](../DEVELOPMENT/CONTRIBUTING.md)
