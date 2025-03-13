# Known Issues

This document lists known issues with the Ansible Ephemery project and their current status.

## Table of Contents

- [Resolved Issues](#resolved-issues)
- [Current Issues](#current-issues)
  - [Code and Configuration Issues](#code-and-configuration-issues)
  - [Execution Client Issues](#execution-client-issues)
  - [Consensus Client Issues](#consensus-client-issues)
  - [Validation and Testing Issues](#validation-and-testing-issues)

## Resolved Issues

The following issues have been resolved in recent updates:

- [x] **Validator key count mismatch**: Expected 1000 keys but found 2000+ JSON files
  - Fixed with robust key count validation and reporting

- [x] **Non-atomic key extraction process**: If extraction fails midway, can leave keys directory in inconsistent state
  - Implemented staged extraction with atomic commit

- [x] **Missing key validation in ansible/tasks/custom-validator-setup.yaml**: Grep for pubkey field only removes invalid keys but doesn't alert on count mismatches
  - Added comprehensive key format validation with detailed reporting

- [x] **Lighthouse container restart lacks waiting period**: No delay between stop/start
  - Added appropriate delay between lighthouse container stop/start operations

- [x] **Unsecured tmp directory for key extraction**: Insufficient permissions
  - Temporary extraction directory now has secure permissions (0700)

- [x] **Missing validator metrics collection**: No performance data
  - Added detailed metrics collection for validators

## Current Issues

### Code and Configuration Issues

- [ ] **Inconsistent validator key path references**: `validator_keys_src` defined in inventory but also hardcoded in some playbooks
  - **Impact**: May cause key loading failures when paths are modified
  - **Workaround**: Ensure all reference paths match exactly

- [ ] **Checkpoint sync URL inconsistency**: `checkpoint_sync_url` defined in inventory but commented out in Lighthouse tasks
  - **Impact**: Checkpoint sync not functioning as expected
  - **Workaround**: Manually uncomment the checkpoint sync URL configuration

- [ ] **Inconsistent container naming**: Both `ephemery-validator-lighthouse` and `{{ network }}-validator-{{ cl }}` used in different places
  - **Impact**: Can cause confusion in scripts and monitoring
  - **Workaround**: Use full container names in manual commands

- [ ] **Non-existing paths referenced in ansible/clients/geth-lighthouse/cl-lighthouse.yaml**: Template references for maintenance script are commented out
  - **Impact**: Maintenance script not properly configured
  - **Workaround**: Create missing paths or update references

- [ ] **Undefined validator image in some task contexts**: Missing default fallback when `client_images.validator` isn't defined
  - **Impact**: Deployment may fail with unclear errors
  - **Workaround**: Always define validator image in inventory

- [ ] **Incomplete validator definition file handling**: Path checked but not fully validated or used in validator initialization
  - **Impact**: Custom validator configurations may not apply
  - **Workaround**: Verify validator definition files manually

- [ ] **Password file permissions error**: Ansible user not consistently applied for file ownership
  - **Impact**: Permission denied errors when accessing password files
  - **Workaround**: Manually fix permissions after deployment

- [ ] **Duplicated validator configuration**: Same config defined in multiple inventory groups
  - **Impact**: Configuration conflicts and unexpected behavior
  - **Workaround**: Ensure consistent configuration across inventory groups

- [ ] **Hard-coded "ephemery" password**: Default password used without secure generation option
  - **Impact**: Security risk in production environments
  - **Workaround**: Manually change password files after deployment

- [ ] **Path inconsistencies between `ephemery_base_dir` and expanded paths**: Some paths use full specification when variable would work
  - **Impact**: Path changes in inventory may not propagate to all components
  - **Workaround**: Check all path references when changing base directory

### Execution Client Issues

- [ ] **Geth synchronization delay**: Synchronization taking longer than expected
  - **Impact**: Extended wait times for a fully functional node
  - **Workaround**: Apply manual optimization flags or use checkpoint sync

- [ ] **Incomplete Geth performance tuning**: Performance tuning parameters not fully implemented in inventory
  - **Impact**: Suboptimal performance
  - **Workaround**: Manually add performance parameters to Geth configuration

- [ ] **No automated recovery for Geth sync failures**: Missing automatic recovery procedures
  - **Impact**: Manual intervention required for sync failures
  - **Workaround**: Monitor logs and restart containers as needed

- [ ] **Geth metrics port inconsistency**: Metrics port not consistently defined across configuration
  - **Impact**: Monitoring may not capture all metrics
  - **Workaround**: Verify metrics port in Prometheus configuration

### Consensus Client Issues

- [ ] **Lighthouse checkpoint sync disabled**: Checkpoint sync disabled without proper fallback strategy
  - **Impact**: Longer initial sync times
  - **Workaround**: Manually enable checkpoint sync in configuration

- [ ] **Insufficient peer discovery**: Peer discovery mechanisms not optimized for fast sync
  - **Impact**: Slower synchronization due to limited peers
  - **Workaround**: Manually specify additional bootstrap nodes

### Validation and Testing Issues

- [ ] **Missing validator key loading tests**: No automatic testing for validator key loading
  - **Impact**: Key loading issues may not be detected until runtime
  - **Workaround**: Manually verify key loading during deployment

- [ ] **Insufficient integration tests**: Missing integration tests between execution and consensus clients
  - **Impact**: Integration issues may not be detected during development
  - **Workaround**: Perform thorough manual testing before deployment

## Related Documentation

- [Project Roadmap](./ROADMAP.md)
- [Troubleshooting Guide](../DEVELOPMENT/TROUBLESHOOTING.md)
- [Validator Key Management](../FEATURES/VALIDATOR_KEY_MANAGEMENT.md)
