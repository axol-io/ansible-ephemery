# YAML Linting Guidelines

This document provides guidance on addressing YAML linting issues in the Ansible Ephemery repository.

## Common Linting Issues

The repository uses pre-commit hooks and yamllint to enforce code quality. Common issues include:

1. **Line Length**: Lines exceeding 80 characters
2. **Truthy Values**: Using `yes`/`no` instead of `true`/`false`
3. **Document Start Markers**: Missing `---` at the beginning of YAML files
4. **Comment Spacing**: Insufficient spaces before comments
5. **Trailing Whitespace**: Extra spaces at the end of lines
6. **End of File**: Missing newline at end of file
7. **Indentation**: Incorrect spacing for indentation

## Automated Fixes

Two scripts are provided to automatically fix common issues:

```bash
# Fix document start markers, truthy values, and trailing whitespace
./scripts/fix_yaml_lint.sh

# Fix long lines in defaults/main.yaml
./scripts/fix_line_length.sh
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
long_expression: "{{ (ansible_memory_mb.real.total * 0.90 * some_percentage) | round | int }}M"
```

Can be changed to:
```yaml
long_expression: |-
  "{{ (ansible_memory_mb.real.total * 0.90 * some_percentage) | round | int }}M"
```

## Bypassing Linting for Exceptional Cases

If you need to bypass linting for a specific commit:

```bash
git commit -m "your message" --no-verify
```

For specific lines in a file that cannot be reformatted:

```yaml
# yamllint disable-line rule:line-length
this_line_is_too_long_but_we_need_to_keep_it_this_way: "long value here"
```

To disable checks for a section:

```yaml
# yamllint disable
these_lines: will_not_be_checked
for_any_lint: issues
# yamllint enable
```

## Pre-commit Configuration

The pre-commit configuration is in `.pre-commit-config.yaml`. To temporarily skip checks:

```bash
# Skip all pre-commit hooks
SKIP=all git commit -m "message"

# Skip specific hooks
SKIP=yamllint git commit -m "message"
```

## Linting During Development

Run linting checks without committing:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run yamllint --all-files
``` 