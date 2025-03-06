# YAML Linting Guidelines

This document provides guidance on addressing YAML linting issues in the Ansible Ephemery repository.

## Common Linting Issues

The repository uses pre-commit hooks and ansible-lint to enforce code quality. Common issues include:

1. **Line Length**: Lines exceeding 80 characters
2. **Truthy Values**: Using `yes`/`no` instead of `true`/`false`
3. **Document Start Markers**: Missing `---` at the beginning of YAML files
4. **Comment Spacing**: Insufficient spaces before comments
5. **Trailing Whitespace**: Extra spaces at the end of lines
6. **End of File**: Missing newline at end of file
7. **Indentation**: Incorrect spacing for indentation

## Automated Fixes

A consolidated script is provided to automatically fix common issues:

```bash
# Check for linting issues
./scripts/yaml-lint-fixer.sh --check

# Fix all YAML linting issues (document start markers, truthy values, line length, quotes)
./scripts/yaml-lint-fixer.sh --fix-all

# Fix specific issues
./scripts/yaml-lint-fixer.sh --fix-truthy    # Fix only truthy values
./scripts/yaml-lint-fixer.sh --fix-line-length  # Fix line length issues
```

## Manually Fixing Line Length Issues

For molecule test files and task files with long lines, manually break up lines:

Before:

```yaml
- name: This is a very long task name that exceeds the 80 character limit and needs to be reformatted
```

After:

```yaml
- name: >-
    This is a very long task name that exceeds the 80 character limit
    and needs to be reformatted
```

For Ansible expressions:

```yaml
long_expression: '{{ (ansible_memory_mb.real.total * 0.90 * some_percentage) | round | int }}M"
```

Can be changed to:

```yaml
long_expression: |-
  '{{ (ansible_memory_mb.real.total * 0.90 * some_percentage) | round | int }}M"
```

## Bypassing Linting for Exceptional Cases

If you need to bypass linting for a specific commit:

```bash
git commit -m "your message" --no-verify
```

For specific lines in a file that cannot be reformatted:

```yaml
# Comment indicating the reason for bypassing the linter
this_line_is_too_long_but_we_need_to_keep_it_this_way: "long value here"
```

## Pre-commit Configuration

The pre-commit configuration is in `.pre-commit-config.yaml`. To temporarily skip checks:

```bash
# Skip all pre-commit hooks
SKIP=all git commit -m "message"

# Skip specific hooks
SKIP=ansible-lint git commit -m "message"
```

## Linting During Development

Run linting checks without committing:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run ansible-lint --all-files
```
