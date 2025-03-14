# Ephemery Core Scripts

This directory contains the core utility scripts that provide standardized functionality for the Ephemery project.

## Overview

The core scripts provide a foundation for all other scripts in the Ephemery project, ensuring consistency, reliability, and maintainability across the codebase. They handle common tasks such as:

- Path standardization
- Error handling
- Logging
- Configuration management
- Validation

## Core Script Files

### path_config.sh

Provides standardized path management for all Ephemery scripts. This ensures consistent directory structures and file locations across all components.

**Usage:**

```bash
# Source in your script
source "$(dirname "$0")/scripts/core/path_config.sh"

# Use standardized paths
echo "Base directory: $EPHEMERY_BASE_DIR"
mkdir -p "$EPHEMERY_CONFIG_DIR"

# Get a path by name
data_dir=$(get_path "data")

# Ensure all standard directories exist
ensure_directories
```

### error_handling.sh

Provides robust, standardized error handling for all Ephemery scripts. Ensures consistent error reporting, logging, and recovery mechanisms.

**Usage:**

```bash
# Source in your script
source "$(dirname "$0")/scripts/core/error_handling.sh"

# Set up error handling
setup_error_handling

# Handle errors manually
if [ ! -f "$config_file" ]; then
  handle_error "ERROR" "Configuration file not found: $config_file" 2
fi

# Run a command with error handling
run_with_error_handling "Create data directory" mkdir -p "$data_dir"
```

### common.sh

Provides common utility functions used across all Ephemery scripts. This includes logging, validation, and other helper functions.

**Usage:**

```bash
# Source in your script
source "$(dirname "$0")/scripts/core/common.sh"

# Use logging functions
log_info "Starting process"
log_debug "Debug information"
log_warning "Something might be wrong"
log_error "An error occurred"

# Check if Docker is available
check_docker || exit 1

# Check if a container is running
if is_container_running "ephemery-geth"; then
  log_info "Geth container is running"
fi
```

### ephemery_config.sh

Contains default configuration values and settings for the Ephemery node. Used when specific configuration is not provided.

## Usage Patterns

### Basic Script Template

```bash
#!/bin/bash

# Script name and description
# Version: 1.0.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Error: Path configuration not found"
  exit 1
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  setup_error_handling
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
fi

# Script-specific code here
log_info "Starting script"
ensure_ephemery_directories

# Run commands with error handling
run_with_error_handling "Create data directory" mkdir -p "$(get_path data)/myapp"

log_info "Script completed successfully"
```

### Error Handling Best Practices

- Always source `error_handling.sh` and call `setup_error_handling` at the beginning of your script
- Use `run_with_error_handling` for critical operations
- Use `handle_error` for custom error conditions
- Set appropriate error levels based on severity

### Path Management Best Practices

- Always source `path_config.sh` at the beginning of your script
- Use the exported path variables (e.g., `$EPHEMERY_CONFIG_DIR`) instead of hardcoding paths
- Use `get_path` for dynamic path resolution
- Use `ensure_ephemery_directories` to create standard directories

## Contributing

When adding new functionality to the core scripts:

1. Follow the established patterns and naming conventions
2. Add comprehensive documentation in the script header
3. Export any functions that should be available to other scripts
4. Update this README.md with information about new scripts or functions
5. Ensure backwards compatibility where possible
