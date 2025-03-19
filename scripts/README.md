# Ephemery Scripts

This directory contains scripts used for deploying, maintaining, and monitoring Ephemery nodes.

## Directory Structure

The scripts are organized into the following directories:

- `deployment/`: Scripts for deployment operations
- `maintenance/`: Scripts for maintenance tasks
- `monitoring/`: Scripts for monitoring and alerting
- `utilities/`: Helper scripts and tools
- `testing/`: Scripts for testing deployments

## Script Standards

All scripts in this repository follow these standards:

1. **Naming Convention**: All scripts use `snake_case` naming
2. **Standard Header**: Each script includes a header with:
   - Purpose
   - Usage instructions
   - Parameter descriptions
   - Author information

3. **Error Handling**: Proper error handling and validation
4. **Common Utilities**: Shared utility functions from `utilities/` directory

## Common Operations

### Deployment

```bash
# Deploy a new Ephemery node
./scripts/deployment/deploy_node.sh

# Apply genesis configuration
./scripts/deployment/apply_genesis.sh
```

### Maintenance

```bash
# Check node sync status
./scripts/maintenance/check_sync_status.sh

# Monitor logs
./scripts/maintenance/monitor_logs.sh
```

### Monitoring

```bash
# Deploy monitoring dashboard
./scripts/monitoring/deploy_dashboard.sh

# Check validator status
./scripts/monitoring/check_validator_status.sh
```

## Contributing

When adding new scripts:

1. Place them in the appropriate directory
2. Follow the naming convention
3. Include the standard header
4. Use the common utility functions where applicable
5. Add appropriate error handling
6. Update documentation if necessary

## Integration with Ansible Roles

Scripts are designed to work with the role-based structure:

- They reference standardized variable names
- They work with the consolidated playbooks
- They support all client combinations
