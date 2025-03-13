# Maintenance Scripts

This directory contains scripts for maintaining the repository and ensuring code quality.

## Available Scripts

### `fix-repository-linting.sh`

A comprehensive script to fix common linting issues in the repository:

- **Trailing whitespace:** Removes trailing spaces from line endings
- **End-of-file newlines:** Ensures files end with a newline character
- **YAML file extensions:** Renames `.yml` files to use `.yaml` extension
- **Python formatting:** Applies isort and black formatting to Python files

#### Usage

```bash
# Run with all features
./fix-repository-linting.sh

# Skip Python formatting (if isort/black not installed)
./fix-repository-linting.sh --no-python-format

# Show help message
./fix-repository-linting.sh --help
```

#### Requirements

- Basic tools: `find`, `sed`, `git`
- For Python formatting: `isort`, `black` (optional)

#### Example

```bash
# Run from the repository root
cd /path/to/ansible-ephemery
./scripts/maintenance/fix-repository-linting.sh
```

### Other Maintenance Scripts

- `fix-yaml-extensions.sh`: Specifically targets YAML file extensions
- `fix-yaml-lint.sh`: Fixes YAML linting issues
- `fix-yaml-line-length.sh`: Addresses line length issues in YAML files
- `fix-yaml-quotes.sh`: Fixes quoting issues in YAML files
- `troubleshoot-ephemery.sh`: Helps troubleshoot Ephemery node issues
- `troubleshoot-ephemery-production.sh`: Production version of troubleshooting
- `enhance_checkpoint_sync.sh`: Enhances checkpoint synchronization
- `enhanced_checkpoint_sync.sh`: Improved checkpoint sync implementation
- `reset_ephemery.sh`: Resets Ephemery nodes to original state

## Usage

Please refer to the individual script comments or the main project documentation for usage information.
