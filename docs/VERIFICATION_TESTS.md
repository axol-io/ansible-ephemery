# Verification Tests

This document provides an overview of the verification tests used in the ansible-ephemery project and how they integrate with the validator.sh script.

## Overview

Verification tests in Molecule are run during the `verify` phase after the playbook has been applied. They validate that the deployment is functioning correctly and all components are properly configured and running.

The `validator.sh` script in the `scripts/` directory can be used to validate aspects of the codebase, including verification test implementation.

## Common Verification Tests

These tests are performed across most scenarios:

### 1. Service Health Checks

- **Docker Containers**: Verifies that all required Docker containers are running
- **Service Health**: Checks that services respond correctly to health checks
- **Log Files**: Examines log files for errors or warnings

### 2. Network Connectivity

- **Port Availability**: Verifies that required ports are open
- **Inter-service Communication**: Checks that services can communicate with each other
- **External Connectivity**: Validates external network connectivity where applicable

### 3. Configuration Validation

- **Configuration Files**: Verifies that configuration files are created with correct content
- **Permissions**: Checks that files and directories have appropriate permissions
- **Environment Variables**: Validates that environment variables are set correctly

### 4. Resource Usage

- **Memory Limits**: Verifies that memory limits are respected
- **CPU Usage**: Checks CPU utilization
- **Disk Space**: Validates adequate disk space

## Client-Specific Tests

Each client combination has specific tests:

### Execution Clients

#### Geth

- Verifies Geth API is accessible
- Checks sync status
- Validates JWT authentication

#### Nethermind

- Verifies Nethermind API is accessible
- Checks JSON-RPC endpoints
- Validates metrics endpoint

#### Besu

- Verifies Besu API is accessible
- Checks P2P connectivity
- Validates GraphQL endpoint

#### Reth

- Verifies Reth API is accessible
- Checks database integrity
- Validates RPC module availability

#### Erigon

- Verifies Erigon API is accessible
- Checks state availability
- Validates snapshot synchronization

### Consensus Clients

#### Lighthouse

- Verifies Beacon API is accessible
- Checks validator connectivity
- Validates metrics endpoint

#### Prysm

- Verifies Prysm API is accessible
- Checks gRPC endpoints
- Validates validator connection

#### Teku

- Verifies Teku API is accessible
- Checks REST API endpoints
- Validates metrics collection

#### Lodestar

- Verifies Lodestar API is accessible
- Checks consensus parameters
- Validates API endpoints

## Feature-Specific Tests

### Backup Tests

- Verifies backup script execution
- Checks backup file creation
- Validates backup integrity
- Tests restoration process

### Monitoring Tests

- Verifies Prometheus endpoints
- Checks Grafana dashboard availability
- Validates metric collection
- Tests alert configurations

### Security Tests

- Verifies firewall configurations
- Checks JWT secret management
- Validates secure communication
- Tests access controls

### Validator Tests

- Verifies validator setup
- Checks key management
- Validates attestation process
- Tests validator metrics

### Resource Limits Tests

- Verifies memory constraints
- Checks CPU limitations
- Validates disk quotas
- Tests performance under constraints

## Test Implementation

Verification tests are implemented in Ansible playbooks within each scenario:

- `verify.yml`: Main verification playbook for the scenario
- Shared verification tasks in `molecule/shared/templates/verify/`

## Running Verification Tests

### Using Molecule Directly

You can run only the verification tests without re-deploying the entire stack:

```bash
molecule verify -s scenario_name
```

### Using the validator.sh Script

The `validator.sh` script can validate verification tests implementation:

```bash
# Check all verification tests for compliance with standards
./scripts/validator.sh conditionals --only-verify

# Check specific scenario verification tests
./scripts/validator.sh conditionals --only-verify --scenario default
```

## Writing New Verification Tests

When adding new verification tests:

1. Make tests idempotent and repeatable
2. Add meaningful assertions
3. Include clear task names
4. Group related tests logically
5. Provide useful error messages

Example verification task structure:

```yaml
---
- name: "Verify that container X is running"
  ansible.builtin.command: "docker ps -q -f name=container-x"
  register: container_result
  changed_when: false
  failed_when: container_result.stdout == ""

- name: "Verify that service X API is accessible"
  ansible.builtin.uri:
    url: "http://localhost:8080/api/status"
    return_content: yes
  register: api_result
  failed_when: api_result.status != 200
```

## Handling Test Failures

When tests fail:

1. Check the test output for specific error messages
2. Examine logs for the involved services
3. Use `molecule login -s scenario_name` to access the test instance
4. Run individual verification tasks manually

## Future Test Enhancements

Planned improvements to verification tests:

1. **Comprehensive API Coverage**: Expanding API endpoint testing
2. **Performance Testing**: Adding performance benchmarks
3. **Fault Injection**: Testing behavior under failure conditions
4. **Security Scanning**: Integrating vulnerability scanning

## Integration with CI/CD

Verification tests are run as part of the CI/CD pipeline. For more information, see [CI_CD.md](CI_CD.md).
