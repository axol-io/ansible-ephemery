# Ephemery Variable Structure

This directory contains the centralized variable management system for the ansible-ephemery role.

## Directory Structure

- `ephemery_variables.yaml`: Core variables for Ephemery deployment
- `resource_management.yaml`: Resource allocation configuration
- `clients/`: Client-specific configurations
  - `execution/`: Execution client configurations
  - `consensus/`: Consensus client configurations
- `networks/`: Network-specific configurations
- `environments/`: Environment-specific configurations (dev, prod, etc.)

## How Variables Are Loaded

Variables are loaded through the `vars_management.yaml` file in the parent directory. It follows this hierarchy:

1. Core variables
2. Resource management
3. Network-specific variables
4. Client-specific variables
5. Environment-specific variables
6. Host-specific variables

Later definitions override earlier ones, allowing for flexible configuration.

## Adding New Variables

When adding new variables:

1. Place them in the most appropriate file based on their purpose
2. Document them with clear comments
3. Use consistent naming conventions
4. Update documentation in `docs/VARIABLE_MANAGEMENT.md` if necessary

## Configuration Examples

### Client-Specific Configuration

Each client has its own configuration file. For example, Geth's configuration is in `clients/execution/geth.yaml`:

```yaml
geth:
  name: 'Geth'
  options:
    cache: 4096
    # ... other options
```

### Environment-Specific Configuration

Environment configurations are in `environments/`. For example, production settings are in `environments/production.yaml`:

```yaml
features:
  monitoring:
    enabled: true
    # ... other settings
```

## Recommended Usage

Use this variable system by including the `vars_management.yaml` file in your playbooks:

```yaml
- name: Import variables
  include_tasks: ../vars_management.yaml
```

For more detailed information, see the [Variable Management Documentation](../../docs/VARIABLE_MANAGEMENT.md).
