# Ansible-Ephemery Repository Cleanup Scripts

This directory contains scripts for cleaning up and optimizing the Ansible-Ephemery repository.

## Scripts

| Script | Description |
|--------|-------------|
| `remove_backup_files.sh` | Removes `.bak` files from the repository |
| `remove_script_backups.sh` | Analyzes and removes the `script_backups` directory |
| `consolidate_common_libraries.sh` | Consolidates utility libraries into a common location |
| `merge_utils_directories.sh` | Merges `utils` directories into a standardized `utilities` directory |
| `consolidate_standardization_scripts.sh` | Consolidates standardization scripts |
| `consolidate_validator_wrappers.sh` | Consolidates validator wrapper scripts |
| `standardize_configuration_files.sh` | Standardizes configuration files |
| `standardize_documentation.sh` | Standardizes documentation and README files |
| `analyze_ansible_collections.sh` | Analyzes and optimizes Ansible collections (largest storage savings) |
| `run_all_cleanup.sh` | Master script to run all cleanup scripts in sequence |

## Usage

### Individual Scripts

Each script can be run independently. They follow a standard pattern:

1. Create a backup of affected files
2. Analyze the current situation
3. Make changes with user confirmation
4. Report results

Example usage:

```bash
./scripts/cleanup/remove_backup_files.sh
```

### Complete Cleanup Process

To run the entire cleanup process in the optimal order, use the master script:

```bash
./scripts/cleanup/run_all_cleanup.sh
```

This will:

1. Create a complete repository backup
2. Run each cleanup script in sequence with confirmation
3. Generate logs and a summary report

## Expected Storage Savings

| Script | Expected Savings |
|--------|------------------|
| `remove_backup_files.sh` | ~0.5MB |
| `remove_script_backups.sh` | ~1MB |
| `analyze_ansible_collections.sh` | ~20MB |
| Other scripts | ~0.5MB |
| **Total** | **~22MB** |

## Implementation Notes

1. All scripts create backups before making changes
2. User confirmation is required before changes are applied
3. Logs are generated for all operations
4. The `run_all_cleanup.sh` script handles the entire process

## Execution Plan

1. Make sure all scripts are executable:
   ```bash
   chmod +x scripts/cleanup/*.sh
   ```

2. Create a branch for the cleanup:
   ```bash
   git checkout -b repository-cleanup
   ```

3. Run the master cleanup script:
   ```bash
   ./scripts/cleanup/run_all_cleanup.sh
   ```

4. Review the changes and test the repository

5. Commit the changes:
   ```bash
   git add .
   git commit -m "Repository cleanup and optimization"
   ```

6. Create a pull request for review 