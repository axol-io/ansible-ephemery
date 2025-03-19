# Library Migration Guide

## Overview

As part of the Ephemery codebase consolidation efforts, we have created a unified shell script library (`scripts/lib/common_consolidated.sh`) that replaces several older, fragmented libraries. This document provides guidance on how to migrate scripts from the old libraries to the new consolidated library.

## Status Update

**MIGRATION COMPLETED**: All scripts across the codebase have been successfully migrated to use the consolidated library. Any new scripts should follow the patterns established in this document.

## Deprecated Libraries

The following libraries are now deprecated and should no longer be used:

* `scripts/utils/common.sh`
* `scripts/utils/common_functions.sh`
* `scripts/utilities/common.sh`
* `scripts/utilities/common_functions.sh`
* `scripts/core/common.sh`

All functionality from these libraries is now available in `scripts/lib/common_consolidated.sh`.

## Migration Process

If you need to create a new script or update an existing one, follow these guidelines:

1. **Use the consolidated library**:
   ```bash
   # Define base directory
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
   PROJECT_ROOT="$(cd "${SCRIPT_DIR}/relative/path/to/root" && pwd)"

   # Source the consolidated library
   source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"
   ```

2. **Error handling** (if needed):
   ```bash
   # With error handling if the library might not be found
   source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" 2>/dev/null || echo "Warning: common_consolidated.sh not found"
   ```

3. **Function availability**: Check that any functions you use from the old libraries are available in the consolidated library. Most functions have been preserved with the same names and parameters.

## Potential Issues

When migrating to the consolidated library, be aware of these potential issues:

1. **Path references**: The consolidated library uses `PROJECT_ROOT` as the base path variable. If your script was using a different variable (e.g., `REPO_ROOT`), you'll need to update all path references.

2. **Function name conflicts**: Some function names might have changed in the consolidated library. Check the library documentation for any renamed functions.

3. **Environment variables**: The consolidated library sets several standard environment variables. Make sure these don't conflict with any custom variables in your script.

4. **Function parameter changes**: Some functions might have slightly different parameter requirements. Review the function documentation in the consolidated library before use.

## Tools

We've created several tools to assist with the migration process:

1. **Library usage checker** - `scripts/maintenance/standardize_library_usage.sh`:
   - Identifies scripts that still use deprecated libraries
   - Can automatically update library references with the `--force` option

Example usage:
```bash
# Check for scripts using deprecated libraries (dry run)
./scripts/maintenance/standardize_library_usage.sh --dry-run

# Update all scripts to use the consolidated library
./scripts/maintenance/standardize_library_usage.sh --force
```

## Need Help?

If you encounter issues with the migration process, refer to the example scripts in the `scripts/examples` directory or the Ephemery documentation. 