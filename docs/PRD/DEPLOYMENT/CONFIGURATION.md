# Configuration

This document outlines the configuration practices and patterns used in the Ephemery Node deployment system. Proper configuration management ensures that nodes are deployed consistently with the correct parameters.

## Overview

The configuration system in our deployment architecture provides a structured way to define and manage the settings for different node types, environments, and services. This approach enables both standardization and customization.

## Configuration Standardization

### Path Configuration

We have implemented a standardized configuration approach that ensures consistent directory structures and file locations across all components of the Ephemery system. This is achieved through a central configuration file:

- **Location**: `/opt/ephemery/config/ephemery_paths.conf`
- **Purpose**: Defines standard paths used across all Ephemery scripts and services
- **Implementation**: Created during deployment by the `deploy_ephemery_retention.yml` playbook

### Standard Directory Structure

The following standard directory structure is used across all Ephemery deployments:

```
/opt/ephemery/
├── config/           # Configuration files including paths.conf
├── data/             # Data files (validator keys, metrics, etc.)
│   ├── metrics/      # Performance and monitoring metrics
│   └── validator_keys/ # Validator key storage
├── logs/             # Log files
└── scripts/          # Scripts for deployment, maintenance, etc.
```

### Configuration Loading

All components of the Ephemery system load configuration in a standardized way:

1. **Shell Scripts**: Source the configuration file at the beginning of the script:
   ```bash
   # Load configuration if available
   CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
   if [ -f "$CONFIG_FILE" ]; then
     source "$CONFIG_FILE"
   else
     # Default fallback paths
     EPHEMERY_BASE_DIR="/opt/ephemery"
     # ... other defaults
   fi
   ```

2. **Python Scripts**: Use a standardized configuration loading function:
   ```python
   def load_config():
       config = {}
       config_path = os.environ.get('EPHEMERY_CONFIG_PATH', 
                                   '/opt/ephemery/config/ephemery_paths.conf')
       
       if os.path.exists(config_path):
           logger.info(f"Loading configuration from {config_path}")
           with open(config_path, 'r') as f:
               for line in f:
                   # Configuration file parsing logic
                   # ...
       return config
   ```

3. **Service Files**: Reference the configuration file in environment variables:
   ```
   Environment="EPHEMERY_CONFIG_PATH=/opt/ephemery/config/ephemery_paths.conf"
   ```

## Configuration Parameters

The standard configuration file includes the following parameters:

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| EPHEMERY_BASE_DIR | Base installation directory | /opt/ephemery |
| EPHEMERY_SCRIPTS_DIR | Scripts directory | ${EPHEMERY_BASE_DIR}/scripts |
| EPHEMERY_DATA_DIR | Data storage directory | ${EPHEMERY_BASE_DIR}/data |
| EPHEMERY_LOGS_DIR | Log files directory | ${EPHEMERY_BASE_DIR}/logs |
| EPHEMERY_CONFIG_DIR | Configuration directory | ${EPHEMERY_BASE_DIR}/config |
| EPHEMERY_JWT_SECRET | JWT secret file path | ${EPHEMERY_CONFIG_DIR}/jwt.hex |
| EPHEMERY_VALIDATOR_KEYS | Validator keys directory | ${EPHEMERY_DATA_DIR}/validator_keys |
| EPHEMERY_METRICS_DIR | Metrics storage directory | ${EPHEMERY_DATA_DIR}/metrics |
| LIGHTHOUSE_API_ENDPOINT | Lighthouse API endpoint | http://localhost:5052 |
| GETH_API_ENDPOINT | Geth API endpoint | http://localhost:8545 |
| VALIDATOR_API_ENDPOINT | Validator API endpoint | http://localhost:5062 |

## Monitoring Configuration

Prometheus monitoring has been standardized with consistent configuration across all components:

- **Prometheus Configuration**: Uses a standardized configuration file with consistent job names and target definitions
- **Metrics Collection**: Standardized metrics collection from all components (Geth, Lighthouse, node exporter, validator)
- **Dashboard Integration**: Configuration ensures proper integration with Grafana dashboards

## Related Documents

- [Deployment Overview](./DEPLOYMENT.md)
- [Remote Deployment](./REMOTE_DEPLOYMENT.md)
- [Local Deployment](./LOCAL_DEPLOYMENT.md)
- [Inventory Management](./INVENTORY_MANAGEMENT.md)
- [Variable Management](./VARIABLE_MANAGEMENT.md)
- [Configuration Standardization](./CONFIGURATION_STANDARDIZATION.md)

*Note: This document is a placeholder based on the existing configuration.md file and will be fully migrated with comprehensive content in a future update.*
