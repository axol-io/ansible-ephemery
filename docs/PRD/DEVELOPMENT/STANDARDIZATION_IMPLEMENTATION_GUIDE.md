# Standardization Implementation Guide

## Overview

This guide provides instructions for implementing standardization across the Ephemery codebase to address inconsistencies in configuration paths, container naming, and other elements.

## Issues to Address

The following issues have been identified in the codebase that need standardization:

1. **Inconsistent validator key path references**
   - Various scripts use different paths for validator keys
   - Some paths are hardcoded while others use variables

2. **Checkpoint sync URL inconsistency**
   - Checkpoint sync configuration is defined in different ways throughout the codebase
   - Some components use configuration files while others use hardcoded values

3. **Inconsistent container naming**
   - Container naming varies between scripts and playbooks
   - Both `ephemery-validator-lighthouse` and `{{ network }}-validator-{{ cl }}` are used in different places

## Implementation Steps

### 1. Standardize Configuration Path Variables

All configuration paths should be defined in a central configuration file (`/opt/ephemery/config/ephemery_paths.conf`) and referenced consistently throughout the codebase.

```bash
# Example path variable definitions
EPHEMERY_BASE_DIR="/opt/ephemery"
EPHEMERY_VALIDATOR_KEYS_DIR="${EPHEMERY_BASE_DIR}/data/validator_keys"
EPHEMERY_CHECKPOINT_SYNC_URL_FILE="${EPHEMERY_BASE_DIR}/config/checkpoint_sync_url.txt"
```

### 2. Standardize Container Naming

Establish a consistent naming convention for containers:

```bash
# Container naming convention
EPHEMERY_GETH_CONTAINER="${NETWORK_NAME:-ephemery}-geth"
EPHEMERY_LIGHTHOUSE_CONTAINER="${NETWORK_NAME:-ephemery}-lighthouse"
EPHEMERY_VALIDATOR_CONTAINER="${NETWORK_NAME:-ephemery}-validator"
```

### 3. Standardize Checkpoint Sync Configuration

Create a standardized approach for checkpoint sync configuration:

```bash
# Checkpoint sync configuration
EPHEMERY_CHECKPOINT_SYNC_ENABLED=true
EPHEMERY_CHECKPOINT_SYNC_URL_FILE="${EPHEMERY_CONFIG_DIR}/checkpoint_sync_url.txt"
EPHEMERY_DEFAULT_CHECKPOINT_URLS=(
  "https://checkpoint-sync.ephemery.dev"
  "https://checkpoint-sync.ephemery.ethpandaops.io"
  "https://checkpoint.ephemery.eth.limo"
)
```

## Implementation Checklist

- [ ] Update `config/ephemery_paths.conf` with standardized path definitions
- [ ] Update `scripts/core/ephemery_config.sh` with standardized container naming and configuration variables
- [ ] Modify all scripts to use standardized variables from configuration files
- [ ] Update Ansible playbooks to use consistent variable names
- [ ] Add validation checks to ensure configuration consistency
- [ ] Update documentation to reflect standardized approach

## Testing Approach

To validate the standardization implementation:

1. **Path Consistency Testing**
   - Run environment validation script to check for consistent path usage

2. **Container Naming Testing**
   - Verify containers are named consistently across deployments

3. **Configuration Loading Testing**
   - Ensure all scripts correctly load and use standardized configuration

## Additional Considerations

- Backward compatibility with existing deployments
- Clear documentation of the new standardized approach
- Migration path for existing scripts and playbooks
