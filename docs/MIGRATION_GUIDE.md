# Migration Guide: Legacy to Role-Based Structure

This document provides a step-by-step guide for migrating from the legacy configuration to the new role-based architecture in the Ephemery Ansible repository.

## Prerequisites

Before starting the migration process, ensure you have:

1. Backed up your current configurations
2. Reviewed the new role-based architecture
3. Tested the playbooks in a development environment

## Migration Process Overview

The migration process consists of the following steps:

1. Test the new role-based structure
2. Migrate from legacy to new structure
3. Clean up obsolete files

## Detailed Migration Steps

### 1. Test the New Role-Based Structure

The test playbook verifies that the new role-based structure can replace legacy configurations:

```bash
ansible-playbook playbooks/test_role_migration.yml
```

This playbook does the following:
- Creates backups of your current configuration
- Tests all roles (common, execution_client, consensus_client, validator)
- Verifies service configurations
- Checks directory structure and file permissions
- Restores from backup if tests fail

### 2. Migrate from Legacy to New Structure

After successful testing, run the migration script:

```bash
./scripts/migrate_to_roles.sh
```

This script:
- Creates backups of legacy directories
- Verifies the new role structure exists
- Runs the test playbook again to ensure compatibility
- Removes legacy directories after confirmation
- Updates inventory files to use the new role-based structure

### 3. Clean Up Obsolete Files

After verifying that everything works with the new structure, run the cleanup script:

```bash
./scripts/cleanup_legacy.sh
```

This script:
- Verifies that migration was successful
- Identifies obsolete files
- Creates backups before removing anything
- Removes obsolete files after confirmation
- Cleans up empty directories

## Rollback Procedure

If you encounter issues after migration, you can restore from the backups:

1. Check the backup directories created during migration:
   ```bash
   ls -la backups/
   ```

2. Restore from the appropriate backup:
   ```bash
   cp -r backups/TIMESTAMP/ansible/clients ansible/
   cp -r backups/TIMESTAMP/ansible/tasks ansible/
   cp -r backups/TIMESTAMP/ansible/playbooks ansible/
   ```

## Common Issues and Solutions

### Service Fails to Start After Migration

**Issue**: Services fail to start after migration to the new role-based structure.

**Solution**: Check the service configurations in the following locations:
- `/etc/ethereum/config.yaml` for execution clients
- `/etc/consensus/config.yaml` for consensus clients
- `/etc/validator/config.yaml` for validators

### Configuration Files Missing

**Issue**: Required configuration files are missing after migration.

**Solution**: Regenerate the configuration files:
```bash
ansible-playbook playbooks/fix_ephemery_node.yaml
```

### Inventory Changes Not Applied

**Issue**: Inventory changes not being applied after migration.

**Solution**: Update your inventory file manually:
```bash
sed -i 's/\[clients\]/[execution_nodes]/' ansible/inventory.ini
sed -i 's/\[validators\]/[consensus_nodes]/' ansible/inventory.ini
```

## Post-Migration Verification

After completing the migration, verify that:

1. All services are running correctly:
   ```bash
   ansible-playbook playbooks/status_check.yml
   ```

2. Monitoring is functioning:
   ```bash
   ansible-playbook playbooks/setup_monitoring.yml
   ```

3. Validator operations are working:
   ```bash
   ansible-playbook playbooks/setup_validator.yml
   ```

## Support and Feedback

If you encounter any issues during migration, please:
1. Check the logs at `/var/log/ansible/`
2. Review the backup files in `backups/`
3. Open an issue on the GitHub repository with details about the problem

## Last Updated

March 19, 2024
