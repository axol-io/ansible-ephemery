# Ephemery Node Testing Framework Documentation

## Overview

The Ephemery Node project includes a comprehensive testing framework for ensuring code quality, reliability, and maintainability. The framework consists of multiple components that work together to validate different aspects of the codebase, with a particular focus on shell scripts.

This documentation provides detailed information about the testing framework, including its components, how to use it, how to add new tests, and best practices for testing.

## Testing Framework Components

The Ephemery testing framework consists of the following components:

1. **Shell Script Linting**
   - ShellCheck for static analysis
   - shfmt for consistent formatting

2. **Version Management**
   - Validation of script version strings
   - Dependency version tracking and validation

3. **Unit Tests**
   - Traditional shell test scripts
   - BATS (Bash Automated Testing System) support

4. **Integration Tests**
   - Framework for testing component interactions
   - Standardized test naming and organization

5. **Pre-commit Hooks**
   - Automated validation before commits
   - Code formatting and validation checks

## Directory Structure

The testing framework uses the following directory structure:

```
scripts/
├── core/
│   └── version_management.sh   # Centralized version management
├── testing/
│   ├── run_tests.sh            # Main test runner script
│   ├── tests/                  # Unit tests
│   │   ├── *_test.sh           # Regular shell tests
│   │   ├── test_*.sh           # Alternative naming convention
│   │   ├── *.bats              # BATS tests
│   │   └── integration/        # Integration tests
│   │       ├── *_integration.sh
│   │       └── integration_*.sh
│   ├── fixtures/               # Test data and fixtures
│   └── reports/                # Generated test reports
└── tools/
    └── validate_versions.sh    # Script version validator
```

## Running Tests

The testing framework provides a unified script (`scripts/testing/run_tests.sh`) for running different types of tests.

### Basic Usage

```bash
# Run all tests (except integration tests)
./scripts/testing/run_tests.sh

# Run only shell script unit tests
./scripts/testing/run_tests.sh --shell-only

# Run only linting tests
./scripts/testing/run_tests.sh --lint-only

# Run all tests including integration tests
./scripts/testing/run_tests.sh --integration

# Enable verbose output
./scripts/testing/run_tests.sh --verbose
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-s, --shell-only` | Run only shell script unit tests |
| `-l, --lint-only` | Run only linting tests |
| `-i, --integration` | Also run integration tests (may take longer) |
| `-v, --verbose` | Enable verbose output |
| `-h, --help` | Show help message |

### Test Reports

The testing framework generates detailed reports for each test run. These reports are stored in the `scripts/testing/reports/` directory with timestamped filenames:

- `shellcheck-report-YYYYMMDD-HHMMSS.txt` - ShellCheck linting results
- `shfmt-report-YYYYMMDD-HHMMSS.txt` - Formatting check results

## Shell Script Linting

### ShellCheck

ShellCheck is a static analysis tool for shell scripts that provides warnings and suggestions for improved code.

The configuration for ShellCheck is maintained in `.shellcheckrc`:

```
# Exclude some warnings that are too strict for this project
disable=SC1090,SC1091,SC2034

# Enable some optional warnings
enable=require-variable-braces
enable=deprecate-which
enable=avoid-nullary-conditions

# External sources
external-sources=true

# Shell type/dialect
shell=bash
```

### shfmt

shfmt is used to enforce consistent formatting across all shell scripts. The configuration is maintained in the pre-commit hooks:

```
args: [-w, -i, "2", -ci, -bn]
```

This configuration:
- Uses 2-space indentation
- Enables case indentation
- Aligns binary operators

## Writing Tests

### Unit Tests

Unit tests can be written in two formats:

1. **Regular Shell Tests**

   Create a new file in `scripts/testing/tests/` with a name matching `*_test.sh` or `test_*.sh`:

   ```bash
   #!/bin/bash

   # Set up
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

   # Tests
   test_some_functionality() {
     # Test code here
     if [ some_condition ]; then
       echo "✅ PASS: Test description"
       return 0
     else
       echo "❌ FAIL: Test description"
       return 1
     fi
   }

   # Run tests
   failures=0
   test_some_functionality || ((failures++))

   # Return non-zero exit code if any test failed
   exit $failures
   ```

2. **BATS Tests**

   Create a new file in `scripts/testing/tests/` with a `.bats` extension:

   ```bash
   #!/usr/bin/env bats

   @test "Description of test" {
     result=$(some_command)
     [ "$result" = "expected output" ]
   }
   ```

### Integration Tests

Integration tests follow a similar pattern but focus on testing interactions between components:

1. Create a new file in `scripts/testing/tests/integration/` with a name matching `*_integration.sh` or `integration_*.sh`
2. Structure the test similarly to unit tests, but with a focus on component interactions

Example:

```bash
#!/bin/bash

# Integration test for script interactions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

# Test the interaction between script A and script B
test_script_interaction() {
  script_a_output=$(bash "${PROJECT_ROOT}/path/to/script_a.sh")
  script_b_result=$(echo "$script_a_output" | bash "${PROJECT_ROOT}/path/to/script_b.sh")

  if [ "$script_b_result" = "expected result" ]; then
    echo "✅ PASS: Script interaction works correctly"
    return 0
  else
    echo "❌ FAIL: Script interaction failed"
    echo "  Expected: expected result"
    echo "  Got: $script_b_result"
    return 1
  fi
}

# Run tests
failures=0
test_script_interaction || ((failures++))

exit $failures
```

## Version Management

The framework includes a version management system to ensure consistent versioning across scripts.

### Script Versioning

All shell scripts should include a version string near the beginning of the file:

```bash
#!/bin/bash

# Script Name
# Description of what the script does
# Version: 1.2.3
```

This version string is validated by the `scripts/tools/validate_versions.sh` script, which is also integrated into the pre-commit hooks.

### Dependency Versioning

The `scripts/core/version_management.sh` provides centralized dependency version definitions:

```bash
declare -A EPHEMERY_DEPENDENCY_VERSIONS=(
  [DOCKER]="24.0.0"
  [GETH]="1.13.14"
  # Other dependencies...
)
```

This ensures consistent version requirements across all scripts and provides utility functions for version checking:

```bash
# Check if a tool meets the minimum version requirement
check_version "docker" "${EPHEMERY_DEPENDENCY_VERSIONS[DOCKER]}"

# Compare two versions
version_greater_equal "1.2.3" "1.2.0"
```

## Pre-commit Hooks

The project includes pre-commit hooks for automated validation before commits. These hooks are configured in `.pre-commit-config.yaml`:

```yaml
# Shell script linting
- repo: https://github.com/shellcheck-py/shellcheck-py
  hooks:
    - id: shellcheck
      args: [--severity=warning, --color=always]

# Shell script formatting
- repo: https://github.com/scop/pre-commit-shfmt
  hooks:
    - id: shfmt
      args: [-w, -i, "2", -ci, -bn]

# Version check for shell scripts
- repo: local
  hooks:
    - id: validate-shell-script-versions
      name: Validate shell script versions
      entry: ./scripts/tools/validate_versions.sh
```

### Setting Up Pre-commit Hooks

To use the pre-commit hooks:

1. Install pre-commit:
   ```bash
   pip install pre-commit
   ```

2. Install the hooks:
   ```bash
   pre-commit install
   ```

3. Run manually if desired:
   ```bash
   pre-commit run --all-files
   ```

## Best Practices

1. **Test Structure**
   - Keep tests small and focused on a single functionality
   - Use descriptive test names that explain what is being tested
   - Keep fixture data separate from test logic

2. **Test Coverage**
   - Aim to test all critical functions in each script
   - Include both happy path and error cases
   - Test edge cases and boundary conditions

3. **Test Maintenance**
   - Update tests when modifying or adding functionality
   - Periodically review and refactor tests as needed
   - Keep test dependencies minimal

4. **Continuous Integration**
   - Integrate testing with CI/CD pipelines
   - Ensure tests run on all pushes and pull requests
   - Enforce passing tests before merging

## Troubleshooting

### Common Issues

1. **Tests failing due to ShellCheck warnings**
   - Fix the identified issues in your scripts
   - If the warning is a false positive, update `.shellcheckrc` to exclude specific warnings

2. **Formatting issues with shfmt**
   - Run `shfmt -w -i 2 -ci -bn path/to/script.sh` to automatically format the script

3. **Version validation failures**
   - Add or update the version string in scripts following the format `# Version: X.Y.Z`

4. **BATS tests not running**
   - Ensure BATS is installed: `apt-get install bats` or equivalent for your system

## Future Improvements

The testing framework is designed to evolve with the project. Planned improvements include:

1. Expanded code coverage metrics for shell scripts
2. Automated performance testing
3. Enhanced integration with CI/CD pipelines
4. Support for parallel test execution
5. Mock frameworks for external dependencies

## References

- [ShellCheck Documentation](https://www.shellcheck.net/wiki/)
- [shfmt Documentation](https://github.com/mvdan/sh)
- [BATS Documentation](https://github.com/bats-core/bats-core)
- [pre-commit Documentation](https://pre-commit.com/)

---

This documentation will be maintained alongside the testing framework code. For questions or suggestions, please open an issue on the project repository.
