# Ephemery Ansible Repository Structure

This repository contains Ansible playbooks and configurations for deploying and managing Ephemery testnet nodes.

## Repository Organization

The repository is organized into the following key directories:

- **playbooks/**: Contains Ansible playbooks for different deployment scenarios
- **tasks/**: Contains reusable task files included by playbooks
- **templates/**: Contains Jinja2 templates used by tasks
- **vars/**: Contains variable definitions for different configurations
- **clients/**: Contains client-specific configurations and tasks

## Key Playbooks

- **playbooks/deploy.yaml**: Main deployment playbook
- **playbooks/update.yaml**: Updates existing deployments
- **playbooks/check_sync_status.yaml**: Checks node sync status
- **playbooks/fix_ephemery_node.yaml**: Consolidated fix playbook for common issues

## Common Issues and Fixes

The `fix_ephemery_node.yaml` playbook addresses several common issues:

1. **JWT Secret Inconsistencies**: Fixes JWT format and path issues
2. **Container Configuration Problems**: Corrects configuration issues in Docker containers
3. **Path and Permission Issues**: Ensures proper file permissions and directory structures
4. **Verification**: Confirms that fixes were applied correctly

## Consolidation Plan

### Phase 1: Task Consolidation (Completed)

- Combined separate fix playbooks into a unified `fix_ephemery_node.yaml`
- Standardized JWT handling across all client combinations
- Added proper validation and diagnostics to container management

### Phase 2: Directory Structure Cleanup (In Progress)

- Standardize client configuration directories
- Create a consistent naming convention for task files
- Organize templates by function rather than client

### Phase 3: Variable Consolidation (Planned)

- Reduce duplication in variable files
- Create a hierarchical variable structure
- Document all variables with clear descriptions

### Phase 4: Playbook Consolidation (Planned)

- Combine related playbooks with role-based flags
- Create a standardized interface for all deployment scenarios
- Implement validation for all user inputs

## Best Practices

### JWT Secret Handling

The JWT secret should:

- Be a 64-character hex string with no prefix
- Have 0600 permissions
- Be consistently located at the same path for both clients
- Be mounted correctly in container volumes

### Container Configuration

Containers should:

- Use the correct entrypoint for wrapper scripts
- Have consistent command formatting
- Mount volumes with appropriate permissions
- Use consistent network configurations

### Diagnostics

Always run diagnostics before applying fixes to:

- Verify Docker is running
- Check client container existence and status
- Verify disk space and resource availability
- Check connectivity between execution and consensus clients

## Contribution Guidelines

When contributing to this repository:

1. Follow the established directory structure
2. Reuse existing tasks where possible
3. Document all variables and parameters
4. Add validation for user inputs
5. Test changes thoroughly before submitting

## Troubleshooting Common Issues

### Client Connection Issues

If the consensus client cannot connect to the execution client:

- Verify the JWT secret is consistent between both clients
- Check that the execution client is exposing the correct API endpoints
- Ensure network settings allow the clients to communicate

### Container Startup Failures

If containers fail to start:

- Check the Docker logs for error messages
- Verify volume mounts and file permissions
- Ensure command parameters are formatted correctly

### Sync Issues

If nodes are not syncing:

- Check network connectivity and peer count
- Verify that both clients are running and communicating
- Examine client logs for error messages
- Consider using checkpoint sync for faster initial sync
