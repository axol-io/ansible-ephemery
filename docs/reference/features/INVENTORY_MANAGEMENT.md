# Inventory Management System

This document outlines the standardized inventory management system for the Ephemery Node project, including file naming conventions, security considerations, and management tools.

## Overview

The Ephemery Node project uses a standardized approach to generating and managing inventory files, ensuring consistency, traceability, and security. Inventory files contain configuration details for deployments, which may include sensitive information that should not be committed to the repository.

## Standardized Naming Convention

All generated inventory files follow this naming convention:

```
<name>-inventory-YYYY-MM-DD-HH-MM.yaml
```

Where:

- `<name>` is a descriptive identifier (e.g., server name, environment)
- `YYYY-MM-DD` is the date of generation
- `HH-MM` is the time of generation

Examples:

- `local-ephemery-inventory-2024-03-13-14-30.yaml`
- `prod-server-inventory-2024-03-13-14-35.yaml`
- `staging-ephemery-inventory-2024-03-13-14-40.yaml`

## Security Considerations

The standardized naming convention provides several security benefits:

1. **Git Exclusion**: All inventory files with the standardized naming convention are automatically excluded from git via the `.gitignore` file, preventing accidental commits of sensitive information
2. **Clear Identification**: Easy visual identification of inventory files helps prevent mistaken actions
3. **Versioning**: The timestamp in the filename allows for tracking different versions without requiring version control
4. **Backup Support**: The standardized naming makes it easy to automate backups and preservation of sensitive configuration data

## Inventory Generation

### Command-line Usage

The `generate_inventory.sh` script provides a flexible way to create inventory files:

```bash
./scripts/core/inventory_manager.sh generate [OPTIONS]
```

Options:

- `--type TYPE`: Template type (local or remote)
- `--name NAME`: Base name for inventory file
- `--output FILE`: Custom output file path (optional, otherwise uses naming convention)
- `--base-dir DIR`: Base directory for Ephemery
- `--data-dir DIR`: Data directory
- `--logs-dir DIR`: Logs directory
- `--geth-image IMAGE`: Geth Docker image
- `--geth-cache SIZE`: Geth cache size in MB
- `--geth-max-peers NUM`: Geth max peers
- `--lighthouse-image IMG`: Lighthouse Docker image
- `--lighthouse-peers NUM`: Lighthouse target peers
- `--remote-host HOST`: Remote host (required for remote type)
- `--remote-user USER`: Remote user (required for remote type)
- `--remote-port PORT`: Remote SSH port
- `--enable-validator`: Enable validator support
- `--enable-monitoring`: Enable sync monitoring
- `--enable-dashboard`: Enable web dashboard

### Examples

```bash
# Generate a local inventory file with default settings
./scripts/core/inventory_manager.sh generate --type local --name mylocal

# Generate a remote inventory file with custom settings
./scripts/core/inventory_manager.sh generate --type remote --name prod-server \
  --remote-host prod.example.com --remote-user admin \
  --geth-cache 8192 --enable-validator --enable-monitoring

# Generate a file with a custom output path (not using naming convention)
./scripts/core/inventory_manager.sh generate --type local --output /tmp/custom-inventory.yaml
```

## Inventory Management

The `manage_inventories.sh` script provides tools for managing inventory files:

```bash
./scripts/core/inventory_manager.sh [OPTIONS]
```

Options:

- `--list`: List all generated inventory files (default action)
- `--clean`: Clean up old inventory files
- `--backup`: Backup all inventory files
- `--days DAYS`: Days to keep when cleaning (default: 30)
- `--backup-dir DIR`: Backup directory (default: ./inventory_backups)

### Examples

```bash
# List all inventory files
./scripts/core/inventory_manager.sh --list

# Clean up inventory files older than 7 days
./scripts/core/inventory_manager.sh --clean --days 7

# Backup all inventory files to a custom location
./scripts/core/inventory_manager.sh --backup --backup-dir /path/to/backups
```

## Integration with Deployment

The inventory files can be used with the deployment script:

```bash
# Deploy with a generated inventory file
./scripts/deploy-ephemery.sh --inventory /path/to/prod-server-inventory-2024-03-13-14-35.yaml
```

## Best Practices

1. **Always Use Generated Files**: Use the provided scripts to generate inventory files rather than creating them manually
2. **Maintain Backups**: Regularly backup inventory files, especially for production environments
3. **Clean Old Files**: Periodically clean up old inventory files to avoid confusion
4. **Descriptive Names**: Use descriptive names that identify the environment, server, or purpose
5. **Check Before Commit**: Always verify that no inventory files with sensitive data are included in git commits

## Common Issues and Solutions

### Inventory Files Not Found

If deployment scripts can't find inventory files, ensure:

- The file path is correct and absolute
- File permissions allow the current user to read the file

### Git Accidentally Tracking Inventory Files

If inventory files are being tracked by git:

- Ensure they follow the naming convention
- Update the `.gitignore` file if needed
- Use `git rm --cached <filename>` to remove from tracking without deleting

### Managing Multiple Environments

For managing multiple environments:

- Use clear environment indicators in the name portion of inventory files
- Consider creating separate backup directories for different environments
- Use tagging or metadata to track which inventory files go with which environments
