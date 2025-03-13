# Ephemery Standardized Paths Guide

This guide provides comprehensive information about the standardized paths approach in the Ephemery project, including how to use, validate, and extend the configuration system.

## Overview

The Ephemery project uses a standardized configuration approach to ensure consistent path definitions across all components. This approach centers around a single configuration file (`/opt/ephemery/config/ephemery_paths.conf`) that defines all paths and endpoints used throughout the system.

## Benefits of Standardized Paths

- **Consistency**: All components use the same paths and configuration approach
- **Flexibility**: Easily change base directories or other configuration parameters in one place
- **Maintainability**: Simpler to update and maintain scripts when paths are standardized
- **Reduced Errors**: Eliminates errors from inconsistent paths and configurations
- **Improved Troubleshooting**: Standardized approach makes troubleshooting more straightforward

## Standard Configuration File

The standard configuration file is located at `/opt/ephemery/config/ephemery_paths.conf` and contains shell-compatible variable declarations. Here's an example:

```bash
# Ephemery Paths Configuration
# This file defines standard paths used across all Ephemery scripts and services

# Base directory for Ephemery installation
EPHEMERY_BASE_DIR="/opt/ephemery"

# Directory for Ephemery scripts
EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"

# Directory for Ephemery data
EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"

# Directory for Ephemery logs
EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"

# Directory for Ephemery configuration
EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"

# JWT secret path
EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"

# Validator keys directory
EPHEMERY_VALIDATOR_KEYS="${EPHEMERY_DATA_DIR}/validator_keys"

# Metrics directory
EPHEMERY_METRICS_DIR="${EPHEMERY_DATA_DIR}/metrics"

# Default endpoints
LIGHTHOUSE_API_ENDPOINT="http://localhost:5052"
GETH_API_ENDPOINT="http://localhost:8545"
VALIDATOR_API_ENDPOINT="http://localhost:5062"
```

## Using Standardized Paths

### In Shell Scripts

Shell scripts should load the configuration file at the beginning:

```bash
#!/bin/bash

# Script description
# This script [description of what the script does]

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading configuration from $CONFIG_FILE"
  source "$CONFIG_FILE"
else
  echo "Configuration file not found, using default paths"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
  EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
  # Add other necessary defaults
fi

# Then use the variables in your script
echo "Using data directory: $EPHEMERY_DATA_DIR"
```

### In Python Scripts

Python scripts should use a standardized configuration loading function:

```python
import os
import logging

logger = logging.getLogger(__name__)

def load_config():
    config = {}
    config_path = os.environ.get('EPHEMERY_CONFIG_PATH', '/opt/ephemery/config/ephemery_paths.conf')
    
    if os.path.exists(config_path):
        logger.info(f"Loading configuration from {config_path}")
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes if present
                    value = value.strip('"\'')
                    # Expand variables in the value
                    if '$' in value:
                        for k, v in config.items():
                            value = value.replace(f"${{{k}}}", v)
                    config[key] = value
    else:
        logger.warning(f"Configuration file {config_path} not found, using environment variables")
    
    # Set defaults from environment or use defaults
    config['EPHEMERY_BASE_DIR'] = os.environ.get('EPHEMERY_BASE_DIR', config.get('EPHEMERY_BASE_DIR', '/opt/ephemery'))
    config['EPHEMERY_CONFIG_DIR'] = os.environ.get('EPHEMERY_CONFIG_DIR', config.get('EPHEMERY_CONFIG_DIR', 
                                                  f"{config['EPHEMERY_BASE_DIR']}/config"))
    # Add other necessary defaults
    
    return config

# Usage example
config = load_config()
data_dir = config.get('EPHEMERY_DATA_DIR')
```

### In Ansible Playbooks

Ansible playbooks should use standardized variable names and the configuration file:

```yaml
- name: Deploy Ephemery components
  hosts: all
  vars:
    ephemery_base_dir: "/opt/ephemery"
    ephemery_config_dir: "{{ ephemery_base_dir }}/config"
    ephemery_data_dir: "{{ ephemery_base_dir }}/data"
    ephemery_logs_dir: "{{ ephemery_base_dir }}/logs"
    
  tasks:
    - name: Create configuration file
      copy:
        content: |
          # Ephemery Paths Configuration
          EPHEMERY_BASE_DIR="{{ ephemery_base_dir }}"
          EPHEMERY_CONFIG_DIR="{{ ephemery_config_dir }}"
          EPHEMERY_DATA_DIR="{{ ephemery_data_dir }}"
          EPHEMERY_LOGS_DIR="{{ ephemery_logs_dir }}"
          # Add other paths as needed
        dest: "{{ ephemery_config_dir }}/ephemery_paths.conf"
        mode: '0644'
```

## Validating Path Standardization

A validation script is provided to check that all components are using standardized paths:

```bash
./scripts/utilities/validate_paths.sh
```

This script checks all shell scripts and Ansible playbooks to ensure they:
1. Source the configuration file properly
2. Provide fallback defaults if the configuration file is not found
3. Use the loaded configuration variables rather than hardcoded paths

## Adding New Paths

When adding new paths to the configuration system:

1. Add the new path to the configuration file (`/opt/ephemery/config/ephemery_paths.conf`)
2. Update the default path declarations in scripts that need the new path
3. Ensure the path is referenced consistently across all components
4. Run the validation script to ensure proper integration

Example of adding a new path:

```bash
# In /opt/ephemery/config/ephemery_paths.conf
# Add new path
EPHEMERY_BACKUP_DIR="${EPHEMERY_DATA_DIR}/backups"

# In scripts that use the path, add the default
if [ ! -f "$CONFIG_FILE" ]; then
  # ... existing defaults ...
  EPHEMERY_BACKUP_DIR="${EPHEMERY_DATA_DIR}/backups"
fi
```

## Testing with Different Base Directories

The testing script (`scripts/utilities/test_standardized_paths.sh`) can be used to verify that all components work correctly with different base directories:

```bash
./scripts/utilities/test_standardized_paths.sh /tmp/ephemery_test
```

This script:
1. Creates a test configuration with a different base directory
2. Copies key scripts to the test directory
3. Runs the scripts with the test configuration
4. Verifies that the scripts work correctly with the test configuration

## Best Practices

1. **Always source the configuration file**: Begin scripts by sourcing the standardized configuration file
2. **Always provide defaults**: Include default paths in case the configuration file is not available
3. **Use consistent variable names**: Stick to the standardized variable names (e.g., `EPHEMERY_BASE_DIR`)
4. **Reference paths via variables**: Never hardcode paths; always use the variables
5. **Add descriptive comments**: Document what each path is used for
6. **Validate regularly**: Run the validation script regularly to ensure compliance

## Troubleshooting

### Common Issues

1. **Configuration file not found**: Ensure the configuration file exists at `/opt/ephemery/config/ephemery_paths.conf` or set the `EPHEMERY_CONFIG_PATH` environment variable to point to the correct location.

2. **Validation script reports non-compliant files**: Check the listed files and update them to use the standardized configuration approach.

3. **Path expansion not working**: Ensure variables are referenced correctly (e.g., `${EPHEMERY_BASE_DIR}` not `$EPHEMERY_BASE_DIR`) when they're part of another string.

4. **Inconsistent paths across environments**: Verify that all environments have the same configuration structure and that the configuration file is being properly loaded.

### Validation Script Output

The validation script outputs a summary of compliant and non-compliant files. Non-compliant files should be updated to use the standardized configuration approach.

```
=== Validation Summary ===
Compliant files (42):
- setup_ephemery.sh
- run-ephemery-demo.sh
...

Non-compliant files (3):
- legacy_script.sh
- old_deployment.sh
...

⚠ Some files need to be updated to use standardized paths
Please update the listed non-compliant files to source /opt/ephemery/config/ephemery_paths.conf
```

## Further Resources

- [Configuration Standardization PRD](./docs/PRD/DEPLOYMENT/CONFIGURATION_STANDARDIZATION.md)
- [Configuration Standardization Implementation](./docs/PRD/DEPLOYMENT/CONFIGURATION_STANDARDIZATION_IMPLEMENTATION.md)
- [Configuration](./docs/PRD/DEPLOYMENT/CONFIGURATION.md)

## Conclusion

Following the standardized paths approach ensures consistency, flexibility, and maintainability across all components of the Ephemery system. By adhering to the guidelines in this document, you can help maintain a robust and flexible codebase.
