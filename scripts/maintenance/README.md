# Maintenance Scripts

This directory contains scripts for maintaining and troubleshooting Ephemery nodes.

## Available Scripts

### System Maintenance
- `fix_mainnet_deployment.sh` - Fixes common mainnet deployment issues
- `manage-validator.sh` - Manages validator operations and maintenance
- `complete_script_organization.sh` - Organizes and maintains script structure

### Data Management
- `organize_scripts.sh` - Organizes script files and directories
- `update_script_readmes.sh` - Updates documentation for scripts

## Usage

Most maintenance scripts support these common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-d, --dry-run` - Show what would be done without making changes
- `-f, --force` - Force operations without confirmation

## Features

- Automated maintenance tasks
- System health checks
- Data cleanup and organization
- Configuration validation
- Error recovery procedures
- Backup and restore capabilities

## Best Practices

1. Always run with --dry-run first
2. Backup data before major maintenance
3. Schedule regular maintenance windows
4. Monitor system during maintenance
5. Keep maintenance logs for reference

## Safety Considerations

- Always verify backups before maintenance
- Test maintenance scripts in development first
- Have a rollback plan ready
- Monitor system resources during maintenance
- Document all maintenance activities

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag.
