# Validator Scripts

This directory contains scripts for managing and operating Ephemery validators.

## Available Scripts

### Setup and Configuration
- `setup_ephemery_validator.sh` - Sets up a new validator node with Lighthouse client
- `restore_validator_keys.sh` - Restores validator keys from backup

### Monitoring and Management
- `manage-validator.sh` - Provides utilities for managing running validators
- `demo_validator_monitoring.sh` - Demonstrates validator monitoring capabilities

## Usage

Most scripts support the following common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-d, --dry-run` - Show what would be done without making changes

## Best Practices

1. Always backup validator keys before making changes
2. Test scripts in a development environment first
3. Monitor logs after running validator operations
4. Keep validator keys secure and never share them
5. Regularly check validator performance and health

## Security Considerations

- Store validator keys securely
- Use strong passwords for validator keystores
- Regularly rotate passwords
- Monitor for slashing conditions
- Keep validator client software updated

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag.
