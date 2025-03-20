# DEPRECATED: Utils Directory

**IMPORTANT: This directory is deprecated and will be removed in a future release.**

The contents of this directory have been reorganized according to the plan in `../REORGANIZATION.md`.

## New Structure

- **For inventory-related functionality**: Use `../core/inventory_manager.sh` instead
- **For other utility scripts**: Use `../utilities/` directory
- **For library functions**: Use `../lib/common_consolidated.sh`

## Redirections

The following symlinks are maintained for backward compatibility only:

- `generate_inventory.sh` → `../utilities/generate_inventory.sh`
- `cleanup.sh` → `../utilities/cleanup.sh`
- `manage_inventories.sh` → `../utilities/manage_inventories.sh`
- `guided_config.sh` → `../utilities/guided_config.sh`
- `verify_deployment.sh` → `../utilities/verify_deployment.sh`
- `parse_inventory.sh` → `../utilities/parse_inventory.sh`
- `validate_inventory.sh` → `../utilities/validate_inventory.sh`

These symlinks will be removed in a future release. Please update your scripts to use the new paths.

## Consolidated Scripts

As part of the consolidation effort, several scripts have been combined into more powerful tools:

1. `../core/inventory_manager.sh` - Combines all inventory-related functionality
2. `../core/install_dependencies.sh` - Handles all dependency installation
3. `../lib/common_consolidated.sh` - Combined library of common functions

Please refer to the documentation in each of these files for more information.
