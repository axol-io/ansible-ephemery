# Ephemery Configuration

This directory contains configuration files for the Ephemery system.

## Files

- `ephemery_paths.conf`: Defines standard paths used across all Ephemery scripts and services. This ensures consistency in directory structures and file locations across the entire system.

## Usage

The configuration files in this directory are loaded by various components of the Ephemery system:

1. **Shell Scripts**: Source the configuration file at the beginning of the script:
   ```bash
   source /opt/ephemery/config/ephemery_paths.conf
   ```

2. **Python Scripts**: Load the configuration file using the provided helper functions:
   ```python
   # The configuration loading function is included in each API script
   config = load_config()
   
   # Access configuration values
   base_dir = config['EPHEMERY_BASE_DIR']
   ```

3. **Service Files**: Reference the configuration file in the environment variables:
   ```
   Environment="EPHEMERY_CONFIG_PATH=/opt/ephemery/config/ephemery_paths.conf"
   ```

## Extending

To add new configuration parameters:

1. Add the parameter to `ephemery_paths.conf`
2. Update the relevant scripts to use the new parameter

## Default Installation

By default, Ephemery is installed in `/opt/ephemery` with the following structure:

- `/opt/ephemery/config`: Configuration files
- `/opt/ephemery/data`: Data files (validator keys, metrics, etc.)
- `/opt/ephemery/logs`: Log files
- `/opt/ephemery/scripts`: Scripts for deployment, maintenance, etc. 