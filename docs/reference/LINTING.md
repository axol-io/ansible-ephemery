# Linting in ansible-ephemery

This document describes the linting tools and configuration used in the ansible-ephemery project.

## YAML Linting

We use [yamllint](https://yamllint.readthedocs.io/) to enforce consistent formatting in YAML files.

### Installation

yamllint is included in the project's development dependencies. Install it with:

```bash
pip install -r requirements-dev.txt
```

### Configuration

The yamllint configuration is defined in `.yamllint` at the root of the project. Key rules include:

- Line length: maximum 80 characters (warning only)
- Comments: must have at least 2 spaces before the text
- Truthy values: must use `true` and `false` (not `yes`, `no`, `on`, `off`)
- Indentation: 2 spaces

### Running yamllint

You can run yamllint manually with:

```bash
# Check a single file
yamllint -c .yamllint path/to/file.yaml

# Check all YAML files in a directory
yamllint -c .yamllint ansible/

# Check all YAML files in the project
yamllint -c .yamllint .
```

### Integration with pre-commit

yamllint is run automatically as part of pre-commit hooks. The pre-commit hook is configured to fail only on errors, not on warnings, to avoid being too strict about line length.

To install pre-commit hooks:

```bash
pre-commit install
```

### IDE Integration

#### VS Code

For VS Code, install the [YAML extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml) and configure it to use the project's yamllint configuration:

1. Install the extension
2. Add to your settings.json:

```json
{
  "yaml.validate": true,
  "yaml.customTags": [],
  "yaml.format.enable": true,
  "yaml.linting.enable": true,
  "yaml.linting.yamllint.enable": true,
  "yaml.linting.yamllint.configPath": ".yamllint"
}
```

#### JetBrains IDEs (PyCharm, IntelliJ)

1. Go to Settings → Tools → File Watchers
2. Click + and select "custom"
3. Configure:
   - Name: yamllint
   - File type: YAML
   - Program: yamllint
   - Arguments: -c $ProjectFileDir$/.yamllint $FilePath$
   - Working directory: $ProjectFileDir$

## Other Linting Tools

The project also uses:

- ansible-lint: for Ansible-specific linting
- flake8, black, isort: for Python code formatting
- shellcheck: for shell script linting

See the `.pre-commit-config.yaml` file for details on how these are configured.
