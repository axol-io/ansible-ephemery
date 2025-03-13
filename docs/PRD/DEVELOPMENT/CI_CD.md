# CI/CD Pipeline

This document outlines the Continuous Integration and Continuous Deployment pipeline for ansible-ephemery.

## Overview

The CI/CD pipeline ensures code quality, validates functionality, and automates the release process for the Ephemery Node project. The pipeline is implemented using GitHub Actions and includes several stages from code validation to release.

## Pipeline Stages

| Stage | Purpose | Tools |
|-------|---------|-------|
| **Lint** | Validate syntax and style | ansible-lint, yamllint |
| **Test** | Verify functionality | Molecule, Docker |
| **Security Scan** | Check for vulnerabilities | Ansible Vault check, trivy |
| **Release** | Package and publish | GitHub releases |

## GitHub Actions Workflows

### Main Workflow

The primary CI pipeline runs on all branches and PRs:

```yaml
---
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  lint:
    # Runs ansible-lint and yamllint

  molecule-test:
    # Runs basic Molecule tests

  security-scan:
    # Checks for unencrypted secrets and vulnerabilities
```

### Molecule Testing

Our Molecule testing infrastructure supports multiple drivers:

1. **Docker Driver (Default)**: Used in CI/CD pipelines and for local testing where Docker is available
2. **Delegated Driver**: Used for environments where Docker isn't available or for local testing without containers

#### CI Configuration for Molecule Tests

In GitHub Actions, we use the Docker driver with a standardized Docker socket path:

```yaml
- name: Update Molecule configuration for GitHub Actions
  run: |
    for file in $(find molecule -name "molecule.yml"); do
      # Use default Docker socket path for GitHub Actions
      sed -i 's|/Users/.*/\.docker/run/docker\.sock|/var/run/docker.sock|g' $file
      # Other configuration adjustments...
    done
```

#### Local Testing

For local development and testing, you can use either driver:

```bash
# Run tests with Docker driver (default)
./molecule/run-tests.sh

# Run tests with delegated driver (no Docker required)
MOLECULE_DRIVER=delegated ./molecule/run-tests.sh
```

See the [Testing Guide](./TESTING_GUIDE.md) for more details on local testing.

### Release Workflow

Triggered when a new tag is pushed:

```yaml
---
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    # Creates GitHub release
```

## Test Matrix

The CI pipeline tests combinations of:

- Python versions (3.11, 3.12)
- Client combinations (Execution + Consensus)
- OS distributions (Ubuntu, Debian, CentOS)

## Local CI Execution

Run the CI checks locally before pushing:

```bash
# Run linting checks
ansible-lint
yamllint .

# Run quick test with Docker driver
molecule test -s default

# Run quick test with delegated driver (no Docker required)
MOLECULE_DRIVER=delegated molecule test -s default

# Run security checks
./scripts/check_unencrypted_secrets.sh
```

## Release Process

1. Update version in appropriate files
2. Create and push a new tag: `git tag v1.0.0 && git push --tags`
3. CI automatically creates GitHub release
4. Release notes are generated from commit history

## Pipeline Configuration

For the complete CI/CD configuration, see:

- `.github/workflows/` directory

## Related Documentation

- [Coding Standards](./CODING_STANDARDS.md)
- [Linting](./LINTING.md)
- [Testing Guide](./TESTING_GUIDE.md)
- [Contributing](./CONTRIBUTING.md) 