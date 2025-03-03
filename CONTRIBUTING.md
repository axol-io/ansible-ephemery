# Contributing to ansible-ephemery

Thank you for your interest in contributing to the ansible-ephemery project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming community.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up the development environment
4. Create a new branch for your changes

## Development Environment Setup

```bash
# Clone your fork
git clone https://github.com/your-username/ansible-ephemery.git
cd ansible-ephemery

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt
ansible-galaxy collection install -r requirements.yaml

# Set up pre-commit hooks
pre-commit install
```

## Making Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes

3. Follow the coding standards and best practices:
   - Use `.yaml` extension for YAML files, not `.yml`
   - Follow Ansible best practices
   - Use snake_case for variable names
   - Include meaningful task names
   - Keep line length to a reasonable limit (preferably under 100 characters)

4. Run tests to ensure your changes work correctly:
   ```bash
   # For quick testing with automatic cleanup
   molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

   # For more comprehensive testing
   molecule test -s default
   ```

5. Commit your changes:
   ```bash
   git commit -m "Add feature X" -m "Detailed description of changes"
   ```

## Testing

We use Molecule for testing. Please ensure your changes pass all tests before submitting a pull request. For detailed testing information, see [docs/TESTING.md](docs/TESTING.md).

```bash
# Run a quick demo test
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Test a specific scenario
molecule test -s geth-lighthouse
```

## Pull Requests

1. Push your changes to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create a pull request from your fork to the main repository

3. In your pull request, provide:
   - A clear description of the changes
   - Any relevant issue numbers
   - Information about testing you've performed

4. Respond to any feedback or requested changes

## Coding Standards

### Ansible Standards

- Follow [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- Use Ansible Vault for sensitive information
- Use tags appropriately
- Keep tasks idempotent

### YAML Standards

- Use `.yaml` extension, not `.yml`
- Use 2-space indentation
- Keep lines under 100 characters
- Use snake_case for keys

### Naming Conventions

- Tasks: Use descriptive names that explain what the task does
- Variables: Use snake_case and descriptive names
- Files: Use kebab-case (hyphen-separated) for filenames

## Documentation

Please update documentation as needed:

- Add or update docstrings and comments in code
- Update relevant documentation in the `docs/` directory
- Update the main README.md if necessary

## Creating New Features

### New Client Support

If adding support for a new Ethereum client:

1. Create client-specific tasks in `tasks/clients/`
2. Add verification tests in `molecule/shared/templates/verify/`
3. Test the client with the testing framework
4. Update the client matrix in documentation

### New Scenario Types

If adding a new scenario type to the testing framework:

1. Add templates to `molecule/shared/templates/`
2. Update `generate_scenario.sh` to support the new type
3. Document the new scenario type in `docs/TESTING.md`

## Release Process

The maintainers will handle releases, but contributors should:

1. Follow semantic versioning principles
2. Document significant changes
3. Ensure backward compatibility or provide upgrade paths

## Getting Help

If you need help with your contribution:

1. Check the documentation in the `docs/` directory
2. Open an issue with questions
3. Reach out on our communication channels

Thank you for contributing to ansible-ephemery!
