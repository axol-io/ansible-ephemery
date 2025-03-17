# Utility Scripts

This directory contains common utility functions and helper scripts used across the Ephemery project.

## Available Scripts

### Common Utilities
- `analyze_ansible_output.sh` - Analyzes and formats Ansible output
- `filter_ansible_output.sh` - Filters Ansible output for relevant information
- `ephemery_output.sh` - Formats Ephemery-specific output

### Helper Functions
- `run_ansible.sh` - Common functions for running Ansible playbooks
- `monitor_logs.sh` - Shared log monitoring utilities

## Usage

Most utility scripts are designed to be sourced by other scripts:

```bash
source scripts/utilities/common_functions.sh
```

When used directly, they support these common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-d, --dry-run` - Show what would be done without making changes

## Features

- Common function libraries
- Shared utilities
- Output formatting
- Error handling
- Logging functions
- Configuration helpers

## Best Practices

1. Keep utilities modular and focused
2. Document function parameters
3. Include usage examples
4. Handle errors gracefully
5. Follow consistent naming conventions

## Development Guidelines

- Write reusable functions
- Include proper error handling
- Document dependencies
- Use consistent formatting
- Add usage examples in comments

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag.
