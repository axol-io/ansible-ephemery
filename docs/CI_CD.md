# CI/CD Pipeline

This document outlines the Continuous Integration and Continuous Deployment pipeline for ansible-ephemery.

## Pipeline Overview

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

# Run quick test
molecule test -s default

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
