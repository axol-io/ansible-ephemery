# Script Management

This document describes the utility scripts available in the repository.

As part of a consolidation effort, several standalone scripts were combined into more powerful unified scripts. This simplifies usage and maintenance while providing consistent interfaces.

## Consolidated Scripts

### yaml-lint-fixer.sh

**Purpose:** Check and fix YAML linting issues according to project standards.

**Usage:**

```bash
./scripts/yaml-lint-fixer.sh [options]
```

**Options:**

- `--check` - Check YAML files for linting issues without making changes
- `--fix` - Fix YAML linting issues automatically where possible
- `--files FILE1 [FILE2...]` - Apply to specific files instead of all YAML files
- `--help` - Show help information

**Replaces:**

- `yamllint-check.sh`
- `yamllint-fix.sh`

---

### molecule-manager.sh

**Purpose:** Unified interface for managing Molecule tests, scenarios, and configurations.

**Usage:**

```bash
./scripts/molecule-manager.sh <command> [options]
```

**Commands:**

- `run` - Run Molecule commands on specified scenarios
- `test-all` - Test all available Molecule scenarios
- `update-configs` - Update Molecule configuration files

**Common Options:**

- `--scenario NAME` - Specify Molecule scenario (for run command)
- `--command CMD` - Molecule command to run (default: test)
- `--platform` - Specify platform (default: auto-detected)
- `--dry-run` - Show what would be done without making changes
- `--help` - Show help information

**Replaces:**

- `update-all-molecule-configs.sh`
- `update-molecule-configs.sh`
- `run-molecule.sh`
- `run-molecule-tests-macos.sh`
- `test-all-scenarios.sh`

---

### yaml-extension-manager.sh

**Purpose:** Manage YAML file extensions to enforce project conventions (.yaml outside molecule/, .yml inside molecule/).

**Usage:**

```bash
./scripts/yaml-extension-manager.sh [options]
```

**Options:**

- `--check` - Check for inconsistent YAML file extensions
- `--fix` - Convert .yml files to .yaml outside the molecule/ directory
- `--reverse` - Convert .yaml files to .yml inside the molecule/ directory
- `--dry-run` - Show what would be changed without making actual changes
- `--help` - Show help information

**Replaces:**

- `fix-yaml-extensions.sh`
- `check-yaml-extensions.sh`

---

### dev-env-manager.sh

**Purpose:** Set up and manage the development environment, including virtual environments and Ansible collections.

**Usage:**

```bash
./scripts/dev-env-manager.sh <command> [options]
```

**Commands:**

- `setup` - Set up the development environment
- `install-collections` - Install Ansible collections
- `test-collections` - Test if required collections are installed
- `help` - Show help information

**Common Options:**

- `--no-venv` - Skip virtual environment creation (setup command)
- `--no-collections` - Skip collection installation (setup command)
- `--no-packages` - Skip package installation (setup command)
- `--force` - Force reinstallation (install-collections command)
- `--check` - Check if already installed (install-collections command)
- `--help` - Show command-specific help

**Replaces:**

- `setup-dev-env.sh`
- `install-collections.sh`
- `test-collections.sh`

---

### repo-standards.sh

**Purpose:** Maintain repository structure and standards.

**Usage:**

```bash
./scripts/repo-standards.sh <command> [options]
```

**Commands:**

- `structure` - Generate or verify repository structure documentation
- `normalize-tasks` - Normalize task names to follow standards
- `standardize-molecule` - Standardize Molecule directory extensions
- `standardize-all` - Run all standardization tasks
- `help` - Show help information

**Common Options:**

- Each command has specific options (use `--help` with each command)
- Most commands support `--dry-run` to preview changes

**Replaces:**

- `repository_structure.sh`
- `normalize_task_names.sh`
- `standardize_repository.sh`
- `standardize_molecule_extensions.sh`

---

### validator.sh

**Purpose:** Validate various aspects of the repository.

**Usage:**

```bash
./scripts/validator.sh <command> [options]
```

**Commands:**

- `docs` - Validate documentation completeness and correctness
- `vars` - Validate variable definitions and usage
- `conditionals` - Verify Ansible conditional statements
- `all` - Run all validation checks
- `help` - Show help information

**Common Options:**

- `--fix` - Attempt to fix issues (where supported)
- `--verbose` - Show detailed validation results
- Command-specific options available with `--help`

**Replaces:**

- `validate_docs.sh`
- `validate_variables.sh`
- `verify-ansible-conditionals.sh`

---

### manage-validator.sh

**Purpose:** Unified interface for managing Ephemery validator operations.

**Usage:**

```bash
./scripts/manage-validator.sh <command> [options]
```

**Commands:**

- `keys` - Manage validator keys (generate, import, list, backup, restore)
- `monitor` - Monitor validator status and performance
- `test` - Test validator configuration
- `help` - Show help information

**Common Options:**

- Each command has specific options (use `--help` with each command)

**Replaces:**

- Individual validator management scripts

---

### ephemery_reset_handler.sh

**Purpose:** Handles Ephemery network resets automatically.

**Usage:**

```bash
./scripts/core/ephemery_reset_handler.sh [options]
```

**Options:**

- `--verbose` - Show detailed output
- `--force` - Force reset handling even if not detected
- `--dry-run` - Show what would be done without making changes
- `--no-keys` - Skip key restoration
- `--no-restart` - Skip container restart
- `--help` - Show help information

**Replaces:**

- Manual reset handling scripts

## Script Usage in CI/CD

These consolidated scripts are integrated into the CI/CD pipeline. If you're updating the pipeline configuration, use the new script names and appropriate options.

## Best Practices

1. Always use the `--help` option if unsure about script usage
2. Use the `--dry-run` option (where available) to preview changes
3. Run validation scripts before submitting pull requests
4. Use wrapper scripts instead of directly calling individual scripts
5. Follow the standardized paths defined in `ephemery_paths.conf`

## Script Development Guidelines

When modifying existing scripts or creating new ones:

1. Follow the established pattern of command/subcommand structure
2. Include comprehensive help text
3. Provide dry-run functionality where appropriate
4. Add proper error handling and user feedback
5. Document the script in this file
6. Use the standardized path configuration from `ephemery_paths.conf`
7. Create wrapper scripts for related functionality
