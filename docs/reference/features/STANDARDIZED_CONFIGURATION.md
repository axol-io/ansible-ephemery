# Ephemery Standardized Configuration

## Overview

Ephemery uses a standardized configuration approach to ensure consistent path definitions across all components of the system. This document outlines the configuration standardization, explains the core configuration file, and provides guidelines for implementing it in scripts and playbooks.

## Core Configuration File

The standardized configuration is defined in a central location:

```
/opt/ephemery/config/ephemery_paths.conf
```

This file defines all path variables used throughout the Ephemery system, including:

- Base directories
- Data directories
- Configuration directories
- Log directories
- JWT secrets
- API endpoints

## Configuration Variables

The following standardized variables are available:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `EPHEMERY_BASE_DIR` | Base directory for all Ephemery data | `/opt/ephemery` |
| `EPHEMERY_SCRIPTS_DIR` | Directory for Ephemery scripts | `${EPHEMERY_BASE_DIR}/scripts` |
| `EPHEMERY_DATA_DIR` | Directory for Ephemery data | `${EPHEMERY_BASE_DIR}/data` |
| `EPHEMERY_LOGS_DIR` | Directory for Ephemery logs | `${EPHEMERY_BASE_DIR}/logs` |
| `EPHEMERY_CONFIG_DIR` | Directory for Ephemery configuration | `${EPHEMERY_BASE_DIR}/config` |
| `EPHEMERY_JWT_SECRET` | JWT secret path | `${EPHEMERY_CONFIG_DIR}/jwt.hex` |
| `EPHEMERY_VALIDATOR_KEYS` | Validator keys directory | `${EPHEMERY_DATA_DIR}/validator_keys` |
| `EPHEMERY_METRICS_DIR` | Metrics directory | `${EPHEMERY_DATA_DIR}/metrics` |
| `LIGHTHOUSE_API_ENDPOINT` | Lighthouse API endpoint | `http://localhost:5052` |
| `GETH_API_ENDPOINT` | Geth API endpoint | `http://localhost:8545` |
| `VALIDATOR_API_ENDPOINT` | Validator API endpoint | `http://localhost:5062` |

## Implementation Guidelines

### For Shell Scripts

All shell scripts should source the configuration file at the beginning:

```bash
# Load configuration file if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "Configuration file not found, using default paths"
    # Define fallback paths here
    EPHEMERY_BASE_DIR="/path/to/fallback"
    # ...
fi
```

### For Ansible Playbooks

Ansible playbooks should include the standardized variables:

```yaml
vars:
  ephemery_base_dir: "{{ ephemery_dir | default('/opt/ephemery') }}"
  ephemery_config_dir: "{{ ephemery_base_dir }}/config"
  ephemery_scripts_dir: "{{ ephemery_base_dir }}/scripts"
  ephemery_data_dir: "{{ ephemery_base_dir }}/data"
  ephemery_logs_dir: "{{ ephemery_base_dir }}/logs"
```

### For Configuration Templates

Configuration templates should reference these standardized paths:

```
base_dir: {{ ephemery_base_dir }}
data_dir: {{ ephemery_data_dir }}
```

## Validation

A validation script is available to check if all components are using the standardized paths:

```bash
./scripts/utilities/validate_paths.sh
```

This script will:

1. Check if the configuration file exists
2. Scan all scripts for proper configuration loading
3. Scan all playbooks for proper variable usage
4. Report which files are compliant and which need to be updated

## Benefits of Standardized Configuration

1. **Consistency**: All components use the same paths and variables
2. **Maintainability**: Path changes can be made in a single location
3. **Flexibility**: Easier to deploy to different locations
4. **Validation**: Automated checking ensures compliance
5. **Documentation**: Clear standards for developers

## Migration Guide

To migrate existing scripts to use the standardized configuration:

1. Replace hardcoded paths with variables from the configuration file
2. Add the configuration file loading code at the beginning of the script
3. Use the validation script to verify compliance
4. Update documentation to reference the standardized configuration

## Conclusion

The standardized configuration approach ensures that Ephemery components maintain consistent path definitions, improving maintainability and flexibility of the system. All new components should follow these guidelines, and existing components should be migrated to use the standardized configuration.
