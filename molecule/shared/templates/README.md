# Molecule Scenario Templates

This directory contains templates for generating Molecule test scenarios for the ansible-ephemery role.

## Template Files

- `scenario_molecule.yml.j2` - General template for molecule.yml files
- `client_molecule.yml.j2` - Specialized template for client combination tests
- `resource_limits_molecule.yml.j2` - Specialized template for resource limits tests
- `converge.yml.j2` - Template for converge.yml playbooks
- `prepare.yml.j2` - Template for prepare.yml playbooks
- `verify.yml.j2` - Template for verify.yml playbooks

## Using Templates

Use the scripts in the `../scripts/` directory to generate new scenarios:

1. For client combination tests:
   ```bash
   ../scripts/generate_client_scenario.sh nethermind lodestar
   ```

2. For general scenarios:
   ```bash
   ../scripts/generate_scenario.sh resource-limits high-memory el_memory=8192M cl_memory=8192M
   ```

## Template Variables

### Common Variables

- `scenario_name` - Name of the scenario (default: 'Custom')
- `node_name` - Name of the test instance (default: 'ethereum-node')
- `custom_vars` - Dictionary of custom variables to set in host_vars
- `custom_platform` - Dictionary of platform-specific settings
- `scenario_config` - Dictionary of scenario-specific configuration sections

### Client-Specific Variables

- `el_client` - Execution layer client (default: 'geth')
- `cl_client` - Consensus layer client (default: 'lighthouse')
- `el_memory` - Memory limit for execution client (default: '3072M')
- `cl_memory` - Memory limit for consensus client (default: '3072M')

### Resource Limits Variables

- `el_memory` - Memory limit for execution client (default: '2048M')
- `cl_memory` - Memory limit for consensus client (default: '2048M')
- `el_cpu` - CPU limit for execution client (default: '1.0')
- `cl_cpu` - CPU limit for consensus client (default: '1.0')
- `additional_limits` - Dictionary of additional resource limits

## Template Inheritance

Templates use the following inheritance mechanisms:

1. Base configuration included from `../../shared/base_molecule.yml`
2. YAML anchors (`<<: *base_provisioner`) for reusing blocks
3. Default values with Jinja2 filters (`{{ variable | default('default_value') }}`)
4. Conditional inclusion of variables (`{% if variable is defined %}`)

## Adding New Templates

When adding new templates:

1. Create a new `.j2` file in this directory
2. Update this README to document the template
3. Update the generation scripts if necessary
