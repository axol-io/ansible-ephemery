# Dependency Management Plan

## Overview

This document outlines the standardized approach to dependency management in the Ephemery Node project. Consistent dependency management practices are essential for ensuring reproducible builds, minimizing version conflicts, and maintaining security across the project.

## Current Status

An analysis of the current dependency management practices has revealed the following:

1. Multiple `requirements.txt` and `requirements.yaml` files exist across the project
2. Inconsistent version pinning formats are used (e.g., `>=`, `~=`, no version constraints)
3. Lack of centralized dependency management standards
4. No automated validation for dependency consistency

## Standardization Goals

1. Establish consistent version pinning practices across all dependency files
2. Implement dependency validation tools to enforce standards
3. Document dependency management procedures for contributors
4. Create a centralized dependency update workflow

## Version Pinning Standards

### Python Dependencies (`requirements.txt`)

All Python dependencies in `requirements.txt` files should follow these standards:

1. **Core Dependencies**: Use exact version pinning with `==` to ensure reproducible builds
   ```
   # Example
   ansible==2.9.13
   certifi==2023.11.17
   ```

2. **Development Dependencies**: Use compatible release operator `~=` to allow for minor updates while ensuring API compatibility
   ```
   # Example
   pytest~=7.3.1
   black~=23.3.0
   ```

3. **Comments**: All dependencies should include a comment indicating their purpose/category
   ```
   # Monitoring tools
   prometheus-client==1.0.0
   grafana-api==1.0.3
   ```

4. **Organization**: Dependencies should be grouped by category with clear headers

### Ansible Collections (`requirements.yaml`)

All Ansible collections in `requirements.yaml` files should follow these standards:

1. **Core Collections**: Use exact version pinning
   ```yaml
   collections:
     - name: ansible.netcommon
       version: "==2.5.0"
   ```

2. **Less Critical Collections**: Use minimum version with compatible minor updates
   ```yaml
   collections:
     - name: community.general
       version: ">=4.0.0,<5.0.0"
   ```

3. **Organization**: Collections should be alphabetically ordered by name

## Implementation Plan

### Phase 1: Inventory and Analysis (Week 1)

1. **Complete inventory of all dependency files**
   - Identify all `requirements.txt` and `requirements.yaml` files
   - Document current version constraints used
   - Note any inconsistencies or potential conflicts

2. **Create dependency graph**
   - Map dependencies and their relationships
   - Identify potential dependency conflicts
   - Document minimum required versions

### Phase 2: Standardization (Week 2)

1. **Update `requirements.txt` files**
   - Apply standardized version pinning to all dependencies
   - Organize dependencies by category
   - Add appropriate comments

2. **Update `requirements.yaml` files**
   - Apply standardized version pinning to all collections
   - Organize collections alphabetically
   - Ensure consistency across all files

3. **Create centralized dependency documentation**
   - Document all major dependencies and their purpose
   - Include update procedures and compatibility notes
   - Add security considerations

### Phase 3: Validation and Enforcement (Week 3)

1. **Create dependency validation script**
   - Implement tool to check for consistency across all dependency files
   - Verify version pinning follows standards
   - Check for inconsistent versions of the same dependency

2. **Set up pre-commit hooks**
   - Add dependency validation to pre-commit process
   - Prevent commits with non-standard version constraints
   - Add helpful error messages for easy resolution

3. **Integrate with CI/CD pipeline**
   - Run dependency validation on pull requests
   - Ensure all dependency updates pass validation
   - Generate dependency reports as part of CI process

## Dependency Update Workflow

To ensure controlled and secure dependency updates, the following workflow should be followed:

1. **Regular security scans**
   - Run weekly scans for security vulnerabilities
   - Prioritize security updates for immediate action

2. **Quarterly dependency reviews**
   - Review all dependencies for available updates
   - Test compatibility of new versions
   - Update version pins as appropriate

3. **Update process**
   - Create dedicated branch for dependency updates
   - Update version pins according to standards
   - Run validation script to ensure consistency
   - Run all tests to verify compatibility
   - Update documentation as needed

## Responsibilities

- **DevOps Lead**: Maintain dependency validation tools
- **Security Engineer**: Regular security scans of dependencies
- **Lead Developer**: Approve dependency updates
- **All Contributors**: Follow dependency management standards

## Success Criteria

The dependency management standardization will be considered successful when:

1. All dependency files follow consistent version pinning standards
2. Automated validation tools are in place and integrated with CI/CD
3. Dependency documentation is complete and up-to-date
4. Regular dependency review process is established

## Appendix: Dependency File Locations

The following dependency files have been identified in the project:

```
./.config/requirements/requirements.yaml
./.config/requirements/requirements.txt
./requirements.yaml
./requirements.txt
./dashboard/app/requirements.txt
./collections/ansible_collections/ansible/posix/requirements.txt
./collections/ansible_collections/ansible/posix/tests/unit/requirements.txt
./collections/ansible_collections/ansible/netcommon/requirements.txt
./collections/ansible_collections/ansible/netcommon/tests/unit/requirements.txt
./collections/ansible_collections/ansible/utils/requirements.txt
./collections/ansible_collections/ansible/utils/tests/unit/requirements.txt
./collections/ansible_collections/ansible/utils/tests/integration/requirements.txt
./collections/ansible_collections/community/docker/tests/unit/requirements.txt
./collections/ansible_collections/community/general/tests/unit/requirements.txt
./collections/ansible_collections/community/library_inventory_filtering_v1/tests/unit/requirements.txt
``` 