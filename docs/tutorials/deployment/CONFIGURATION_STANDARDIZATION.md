# Configuration Standardization

This document details the configuration standardization implementation for the Ephemery Node system, providing a comprehensive overview of the changes made to ensure consistent configuration across all components.

## Background

Prior to standardization, the Ephemery system had several inconsistencies in its configuration approach:

1. **Inconsistent Path Definitions**: Different scripts used different base directories (`/root/ephemery` vs `/opt/ephemery`) and had hardcoded paths.
2. **Inconsistent Prometheus Configuration**: Multiple Prometheus configuration files with different settings and naming conventions.
3. **Inconsistent Environment Variables**: Different scripts used different environment variable names for the same paths.
4. **Lack of Configuration Documentation**: No documentation on how to configure the system.
5. **Inconsistent Directory Structure**: Different scripts assumed different directory structures.
6. **Hardcoded API Endpoints**: API endpoints were hardcoded in multiple places.
7. **Inconsistent Configuration Loading**: Different approaches to loading configuration in different scripts.

## Implementation Overview

The standardization effort involved the following key components:

1. **Central Configuration File**: Created a standardized configuration file (`/opt/ephemery/config/ephemery_paths.conf`) that defines all paths and endpoints in one place.
2. **Consistent Directory Structure**: Defined a standard directory structure across all components.
3. **Standardized Configuration Loading**: Implemented consistent loading mechanisms for all types of scripts (shell, Python) and services.
4. **Consistent Prometheus Configuration**: Standardized monitoring configuration across all components.
5. **Documentation**: Added comprehensive documentation for the configuration system.

## Central Configuration File

The central configuration file (`ephemery_paths.conf`) serves as the single source of truth for all paths and endpoints in the Ephemery system. It uses shell-compatible variable declarations that can be sourced by shell scripts and parsed by other languages.

### Example of the standardized configuration file:

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

## Ansible Integration

The standardized configuration is created and managed by the Ansible playbooks, ensuring consistent deployment across all environments:

```yaml
- name: Create configuration file
  copy:
    content: |
      # Ephemery Paths Configuration
      # ...configuration content...
    dest: "{{ ephemery_config_dir }}/ephemery_paths.conf"
    mode: '0644'
```

## Script Updates

### Shell Script Example

All shell scripts have been updated to use the standardized configuration:

```bash
# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
  echo -e "${BLUE}Loading configuration from $CONFIG_FILE${NC}"
  source "$CONFIG_FILE"
else
  echo -e "${YELLOW}Configuration file not found, using default paths${NC}"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi
```

### Python Script Example

Python scripts now use a standardized configuration loading function:

```python
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
    # ...additional defaults...

    return config
```

## Service Files

Systemd service files have been updated to use the standardized configuration path:

```
[Service]
Environment="EPHEMERY_CONFIG_PATH=/opt/ephemery/config/ephemery_paths.conf"
```

## Prometheus Configuration Standardization

Prometheus configuration has been standardized to ensure consistent monitoring:

1. **Consistent Job Names**: Standardized job names across all configurations
2. **Consistent Target Definitions**: Standardized the format of target definitions
3. **Consistent File Extensions**: Standardized on `.yaml` file extension

## Benefits of Standardization

The configuration standardization provides several key benefits:

1. **Reduced Errors**: Eliminates errors from inconsistent paths and configurations
2. **Simplified Maintenance**: Single location to update paths and endpoints
3. **Improved Deployment**: Consistent deployment across all environments
4. **Better Documentation**: Clear documentation of all configuration parameters
5. **Enhanced Security**: Standardized approach to sensitive information (e.g., JWT tokens)
6. **Easier Troubleshooting**: Standardized paths make troubleshooting more straightforward

## Validation and Testing

The standardized configuration has been tested in the following scenarios:

1. **Fresh Installation**: Verified that new installations correctly use the standardized paths
2. **Upgrades**: Tested the compatibility with existing installations
3. **Error Handling**: Verified graceful degradation when the configuration file is not available
4. **Cross-Component Integration**: Tested integration between different components using the standardized configuration

## Future Enhancements

Planned enhancements to the configuration system include:

1. **Configuration Validation**: Automated validation of configuration parameters
2. **Default Override Management**: Enhanced management of default overrides
3. **Configuration Versioning**: Version tracking for configuration changes
4. **UI-Based Configuration**: Web interface for configuration management
5. **Enhanced Secret Management**: Improved handling of sensitive configuration

## Related Documents

- [Configuration](./CONFIGURATION.md)
- [Deployment Overview](./DEPLOYMENT.md)
- [Variable Management](./VARIABLE_MANAGEMENT.md)

## Implementation Progress

The configuration standardization effort is ongoing, with the following progress:

### Completed:
- Created central configuration file (`ephemery_paths.conf`) with standardized paths and endpoints
- Updated main troubleshooting script (`troubleshoot_ephemery.sh`) to use standardized configuration
- Updated production troubleshooting script (`scripts/maintenance/troubleshoot-ephemery-production.sh`) to use standardized configuration
- Updated remote deployment script (`scripts/remote/run-ephemery-remote.sh`) to create and use standardized configuration
- Standardized Prometheus configuration by consolidating to a single file (`prometheus.yml`)
- Created comprehensive documentation for the configuration system

### In Progress:
- Updating remaining scripts to use the standardized configuration file
- Standardizing path references across all Ansible playbooks
- Ensuring consistent JWT token path usage

### Pending:
- Update core run scripts (`run-ephemery-local.sh`, `run-ephemery-demo.sh`)
- Update utility and maintenance scripts
- Update monitoring configuration to use standardized paths
- Update documentation to reflect standardized configuration

## Next Steps

The next phase of standardization will focus on:

1. **Core Scripts Update**: Update remaining core scripts to use the standardized configuration
2. **Playbook Updates**: Ensure all Ansible playbooks reference the standardized configuration
3. **Validation**: Create automated validation to ensure all components use the standardized configuration
4. **Documentation Enhancement**: Update all documentation to reference the standardized paths

## Validation

To validate that scripts are correctly using the standardized configuration, the following checks should be performed:

1. Scripts should load configuration from `/opt/ephemery/config/ephemery_paths.conf`
2. Scripts should provide fallback defaults if the configuration file is not found
3. Scripts should use the loaded configuration variables rather than hardcoded paths
4. New scripts should follow the standardized configuration loading pattern

## Example of Standardized Script Header

All shell scripts should include the following standardized header:

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
fi

# Script logic follows...
```
