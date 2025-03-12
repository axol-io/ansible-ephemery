# Known Issues

This document lists known issues with the Ansible Ephemery project and their current status.

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
- [ ] **Checkpoint sync URL inconsistency**: `checkpoint_sync_url` defined in inventory but commented out in Lighthouse tasks
- [ ] **Inconsistent container naming**: Both `ephemery-validator-lighthouse` and `{{ network }}-validator-{{ cl }}` used in different places
- [ ] **Non-existing paths referenced in ansible/clients/geth-lighthouse/cl-lighthouse.yaml**: Template references for maintenance script are commented out
- [ ] **Undefined validator image in some task contexts**: Missing default fallback when `client_images.validator` isn't defined
- [ ] **Incomplete validator definition file handling**: Path checked but not fully validated or used in validator initialization
- [ ] **Password file permissions error**: Ansible user not consistently applied for file ownership
- [ ] **Duplicated validator configuration**: Same config defined in multiple inventory groups
- [ ] **Hard-coded "ephemery" password**: Default password used without secure generation option
- [ ] **Path inconsistencies between `ephemery_base_dir` and expanded paths**: Some paths use full specification when variable would work

### Execution Client Issues

- [ ] **Geth synchronization delay**: Synchronization taking longer than expected
- [ ] **Incomplete Geth performance tuning**: Performance tuning parameters not fully implemented in inventory
- [ ] **No automated recovery for Geth sync failures**: Missing automatic recovery procedures
- [ ] **Geth metrics port inconsistency**: Metrics port not consistently defined across configuration

### Consensus Client Issues

- [ ] **Lighthouse checkpoint sync disabled**: Checkpoint sync disabled without proper fallback strategy
- [ ] **Insufficient peer discovery**: Peer discovery mechanisms not optimized for fast sync

### Validation and Testing Issues

- [ ] **Missing validator key loading tests**: No automatic testing for validator key loading
- [ ] **Insufficient integration tests**: Missing integration tests between execution and consensus clients
