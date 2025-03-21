# Codebase Improvements: Action Items

This document provides concrete action items for implementing the codebase improvements outlined in the [Codebase Improvements Initiative](./CODEBASE_IMPROVEMENTS.md).

## Action Items by Priority

### High Priority (Week 1-2)

#### 1. Path Standardization

- [x] **Task 1.1**: Create `scripts/core/path_config.sh` utility script for standardized path handling
  - **Owner**: TBD
  - **Deadline**: Week 1, Day 3
  - **Criteria**: Script provides consistent path definitions, works on all supported platforms, handles edge cases
  - **Status**: Completed. The script has been created and provides standardized path handling.

- [ ] **Task 1.2**: Update top-level shell scripts to use the path utility
  - **Owner**: TBD
  - **Deadline**: Week 1, Day 5
  - **Criteria**: All root directory scripts consistently use the path utility

- [x] **Task 1.3**: Create Ansible variable mapping in `ansible/vars/paths.yaml`
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 1
  - **Criteria**: All path references are defined in a single location
  - **Status**: Completed. The paths.yaml file defines all standardized paths for Ansible playbooks.

- [ ] **Task 1.4**: Update Ansible playbooks to use standardized path variables
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 3
  - **Criteria**: All Ansible playbooks use the standardized path variables

#### 2. Container Naming Standardization

- [x] **Task 2.1**: Update `scripts/core/path_config.sh` with standardized container naming
  - **Owner**: TBD
  - **Deadline**: Week 1, Day 4
  - **Criteria**: Container names follow standard pattern of {network}-{role}-{client}
  - **Status**: Completed. Updated path_config.sh with standardized container naming.

- [x] **Task 2.2**: Update `ansible/vars/paths.yaml` with standardized container naming
  - **Owner**: TBD
  - **Deadline**: Week 1, Day 5
  - **Criteria**: Ansible variable mapping uses the same container naming convention
  - **Status**: Completed. Updated paths.yaml with standardized container naming.

- [x] **Task 2.3**: Create validation script to check for container naming inconsistencies
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 1
  - **Criteria**: Script identifies inconsistent container naming across the codebase
  - **Status**: Completed. Created `scripts/utilities/validate_container_names.sh`.

- [ ] **Task 2.4**: Update scripts to use standardized container naming variables
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 5
  - **Criteria**: All scripts use the standardized container name variables

- [ ] **Task 2.5**: Update Ansible playbooks to use standardized container naming variables
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 1
  - **Criteria**: All Ansible playbooks use the standardized container name variables

#### 3. Shell Script Library

- [x] **Task 3.1**: Create `scripts/core/common.sh` with shared utility functions
  - **Owner**: TBD
  - **Deadline**: Week 1, Day 4
  - **Criteria**: Functions for colors, logging, error handling, argument parsing
  - **Status**: Completed. The common.sh script has been created with utility functions.

- [ ] **Task 3.2**: Update `setup_ephemery.sh` to use the common library
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 1
  - **Criteria**: Script refactored to use common functions, reduced code duplication

- [ ] **Task 3.3**: Update remaining top-level scripts to use the common library
  - **Owner**: TBD
  - **Deadline**: Week 2, Day 4
  - **Criteria**: All top-level scripts use the common library

### Medium Priority (Week 3)

#### 4. Dependency Management

- [ ] **Task 4.1**: Standardize version pinning in `requirements.txt`
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 1
  - **Criteria**: All dependencies have consistent version pinning

- [ ] **Task 4.2**: Standardize version pinning in `requirements.yaml`
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 1
  - **Criteria**: All Ansible collections have consistent version pinning

- [ ] **Task 4.3**: Create automated dependency validation checks
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 3
  - **Criteria**: CI job verifies dependency consistency

#### 5. Code Quality Tools

- [ ] **Task 5.1**: Enable shellcheck in pre-commit
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 1
  - **Criteria**: Pre-commit configuration updated, shellcheck enabled

- [ ] **Task 5.2**: Fix critical shellcheck issues in top-level scripts
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 3
  - **Criteria**: All top-level scripts pass shellcheck

- [ ] **Task 5.3**: Fix shellcheck issues in helper scripts
  - **Owner**: TBD
  - **Deadline**: Week 3, Day 4
  - **Criteria**: All helper scripts pass shellcheck

### Lower Priority (Week 4-5)

#### 6. Error Handling

- [ ] **Task 6.1**: Create error handling templates in `scripts/core/error_handling.sh`
  - **Owner**: TBD
  - **Deadline**: Week 4, Day 1
  - **Criteria**: Script provides functions for error trapping, reporting, and recovery

- [ ] **Task 6.2**: Implement error handling in critical scripts
  - **Owner**: TBD
  - **Deadline**: Week 4, Day 3
  - **Criteria**: Top-level scripts implement robust error handling

#### 7. Directory Structure Optimization

- [ ] **Task 7.1**: Document current directory structure
  - **Owner**: TBD
  - **Deadline**: Week 4, Day 2
  - **Criteria**: Comprehensive documentation of current directory structure

- [ ] **Task 7.2**: Design optimized directory structure
  - **Owner**: TBD
  - **Deadline**: Week 4, Day 3
  - **Criteria**: Clear structure with non-overlapping purposes

- [ ] **Task 7.3**: Implement directory reorganization
  - **Owner**: TBD
  - **Deadline**: Week 4, Day 5
  - **Criteria**: All scripts moved to appropriate locations, references updated

#### 8. Testing

- [ ] **Task 8.1**: Create test matrix for key functionality
  - **Owner**: TBD
  - **Deadline**: Week 5, Day 1
  - **Criteria**: Comprehensive test scenarios defined

- [ ] **Task 8.2**: Implement key test scenarios
  - **Owner**: TBD
  - **Deadline**: Week 5, Day 3
  - **Criteria**: Automated tests for core functionality

- [ ] **Task 8.3**: Implement CI integration for tests
  - **Owner**: TBD
  - **Deadline**: Week 5, Day 4
  - **Criteria**: Tests run automatically on CI

## Tracking Progress

- Weekly status meetings to review progress
- Task boards in GitHub Projects
- Regular commits with conventional commit messages

## Validation Strategy

1. **Unit Testing**: Each component tested in isolation
2. **Integration Testing**: Components tested together
3. **End-to-End Testing**: Full flow testing
4. **Manual Validation**: Key scenarios manually verified

## Documentation Updates

All changes should be documented in:
1. Code comments
2. Script headers
3. README.md updates
4. PRD documentation updates
5. CHANGELOG.md updates
