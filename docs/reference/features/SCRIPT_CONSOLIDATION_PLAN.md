# Script Consolidation Plan

This document outlines the comprehensive plan for reorganizing and consolidating the scripts directory in the Ephemery Node project.

## Table of Contents

1. [Background](#background)
2. [Current State Analysis](#current-state-analysis)
3. [Consolidation Goals](#consolidation-goals)
4. [New Directory Structure](#new-directory-structure)
5. [Implementation Strategy](#implementation-strategy)
6. [Script Standardization](#script-standardization)
7. [Documentation Updates](#documentation-updates)
8. [Testing Strategy](#testing-strategy)
9. [Timeline and Milestones](#timeline-and-milestones)

## Background

The Ephemery Node project's scripts directory has grown organically as new features have been added. This has resulted in a collection of scripts with varied naming conventions, inconsistent structure, potential duplication, and scattered documentation. To improve maintainability and usability, a consolidated and standardized approach to script organization is needed.

## Current State Analysis

### Current Script Inventory

The scripts directory currently contains over 40 shell scripts with various purposes:

1. **Setup and Deployment Scripts**: Scripts for setting up Ephemery nodes locally or remotely
2. **Monitoring Scripts**: Scripts for checking status and health of nodes
3. **Maintenance Scripts**: Scripts for data retention and system maintenance
4. **Utility Scripts**: Helper scripts for various tasks
5. **Development Scripts**: Scripts for development and testing environments
6. **YAML and Linting Scripts**: Scripts for standardizing YAML files and fixing linting issues

### Issues with Current Structure

1. **Inconsistent Naming**: Script names don't follow a consistent pattern, making it difficult to identify their purpose
2. **Scattered Implementation**: Related functionality is spread across multiple scripts
3. **Documentation Gaps**: Many scripts lack comprehensive documentation
4. **Code Duplication**: Common functions are replicated across scripts
5. **Minimal Directory Structure**: Most scripts are in the root scripts directory with minimal organization
6. **Testing Deficiencies**: Limited automated testing for critical scripts

## Consolidation Goals

1. **Improve Discoverability**: Make it easier to find scripts by implementing a logical directory structure
2. **Reduce Duplication**: Centralize common functions in shared library files
3. **Standardize Implementation**: Establish consistent patterns for configuration, logging, and error handling
4. **Enhance Documentation**: Create comprehensive documentation for all scripts
5. **Improve Reliability**: Implement testing for critical scripts

## New Directory Structure

The scripts directory will be reorganized into the following structure:

```
scripts/
├── core/                   # Core ephemery functionality
│   ├── ephemery_retention.sh
│   ├── setup_ephemery.sh
│   └── reset_ephemery.sh
├── deployment/             # Deployment scripts
│   ├── local/              # Local deployment
│   │   └── run-ephemery-local.sh
│   ├── remote/             # Remote deployment
│   │   └── run-ephemery-remote.sh
│   └── common/             # Shared deployment utilities
├── monitoring/             # Monitoring and alerting
│   ├── check_sync_status.sh
│   ├── check_ephemery_status.sh
│   ├── validator_performance_monitor.sh
│   └── checkpoint_sync_alert.sh
├── maintenance/            # Maintenance tasks
│   ├── fix_checkpoint_sync.sh
│   ├── restore_validator_keys.sh
│   └── ephemery_retention.sh
├── utilities/              # Helper utilities and shared functions
│   ├── common.sh           # Common functions library
│   ├── logging.sh          # Logging functions
│   ├── config.sh           # Configuration management
│   └── validation.sh       # Input validation
├── development/            # Development environment tools
│   ├── dev-env-manager.sh
│   ├── setup-dev-env.sh
│   └── repo-standards.sh
└── tools/                  # Miscellaneous tools
    ├── linting/            # YAML and code linting
    │   ├── fix-yaml-extensions.sh
    │   ├── fix-yaml-quotes.sh
    │   └── fix-yaml-lint.sh
    └── testing/            # Testing tools
        ├── test_checkpoint_sync.sh
        └── benchmark_sync.sh
```

## Implementation Strategy

The consolidation will be implemented in phases:

### Phase 1: Inventory and Analysis

1. Create a complete inventory of all scripts
2. Document dependencies between scripts
3. Identify common functions that can be centralized
4. Define script categories based on functionality

### Phase 2: Directory Structure Implementation

1. Create the new directory structure
2. Move scripts to appropriate directories
3. Implement symbolic links for backward compatibility

### Phase 3: Script Standardization

1. Implement common functions library
2. Standardize script headers and documentation
3. Refactor scripts to use common libraries
4. Implement consistent error handling and logging

### Phase 4: Documentation and Testing

1. Update documentation to reflect new structure
2. Create comprehensive script reference
3. Implement testing for critical scripts
4. Validate functionality across various environments

## Script Standardization

All scripts will be standardized with the following elements:

### Standard Header

```bash
#!/usr/bin/env bash
#
# Script Name: script_name.sh
# Description: Brief description of the script
# Author: Author Name
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD
#
# Usage: ./script_name.sh [options]
#
# Dependencies:
#   - List of dependencies
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Specific error condition
```

### Common Script Structure

1. Source common libraries
2. Define constants and configuration
3. Define functions
4. Process command-line arguments
5. Validate inputs
6. Main execution
7. Cleanup and exit

### Error Handling

All scripts will implement standardized error handling with:
- Clear error messages
- Appropriate exit codes
- Error logging

### Configuration Management

Scripts will use a consistent approach to configuration:
- Environment variables with sensible defaults
- Configuration file support where appropriate
- Command-line overrides

## Documentation Updates

Documentation will be updated to reflect the new organization:

1. Update `EPHEMERY_SCRIPT_REFERENCE.md` to include all scripts by category
2. Create detailed documentation for each script
3. Update cross-references in other documentation
4. Create a script index with search functionality

## Testing Strategy

Testing will be implemented to ensure reliability:

1. Implement unit tests for common functions
2. Create integration tests for critical scripts
3. Implement continuous integration testing
4. Document test cases and expected results

## Timeline and Milestones

1. **Week 1-2**: Inventory and analysis
2. **Week 3-4**: Directory structure implementation
3. **Week 5-7**: Script standardization
4. **Week 8-10**: Documentation and testing
5. **Week 11-12**: Final validation and release

## Success Criteria

The consolidation will be considered successful when:

1. All scripts are organized according to the new directory structure
2. Common functions are centralized in shared libraries
3. Scripts follow standardized implementation patterns
4. Documentation is comprehensive and up-to-date
5. Critical scripts have automated tests
6. Users can easily find and use the scripts they need

## Implementation Progress

### Phase 1: Directory Structure and Shared Libraries (May 15, 2023)

The following progress has been made in implementing the script consolidation plan:

1. **Created New Directory Structure**:
   - Created the new directory structure according to the plan
   - Created README files for each directory explaining its purpose

2. **Implemented Shared Libraries**:
   - Created `common.sh` with common utility functions
   - Created `logging.sh` for standardized logging
   - Created `config.sh` for configuration management
   - Created `validation.sh` for input validation

3. **Moved and Updated Core Scripts**:
   - Moved `setup-ephemery.sh` to `core/setup_ephemery.sh` with updated structure
   - Moved `ephemery_retention.sh` to `core/ephemery_retention.sh` with updated structure
   - Moved `check_sync_status.sh` to `monitoring/check_sync_status.sh` with updated structure

4. **Documentation Updates**:
   - Created main README for the scripts directory
   - Created README files for each category
   - Updated script headers and usage documentation

### Next Steps

The following steps are planned next:

1. **Continue Script Migration**:
   - Move remaining scripts to their appropriate directories
   - Update scripts to use the shared libraries
   - Standardize naming conventions

2. **Implement Backward Compatibility**:
   - Create symbolic links for frequently used scripts
   - Add deprecation warnings to old script locations

3. **Testing and Validation**:
   - Test updated scripts for functionality
   - Implement unit tests for critical functions
