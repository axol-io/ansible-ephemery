# Test Templates

This directory contains templates for creating new tests for the Ephemery project.

## Files

- `test_template.sh`: A template script for creating new tests
- `init_test_env.sh`: A template for the `init_test_env` function that can be included in tests

## Using the Test Template

To create a new test:

1. Copy `test_template.sh` to your test directory with an appropriate name
2. Modify the script to implement your test logic
3. Make sure to keep the command-line argument parsing and init_test_env function

## Using the init_test_env Function

The `init_test_env` function initializes the test environment with:

- Test report directory
- Mock environment (if enabled)
- Temporary directory for test artifacts
- Fixture directory

You can include the function in your test in two ways:

### Option 1: Source the template file

```bash
source "${PROJECT_ROOT}/scripts/testing/tests/template/init_test_env.sh"
```

### Option 2: Copy the function into your test script

Copy the function from `init_test_env.sh` into your test script.

## Mock Mode

When running tests in mock mode (`--mock`), the `init_test_env` function:

1. Initializes the mock framework
2. Registers default mock behavior for common tools
3. Sets shorter intervals for performance tests

## Example Usage

```bash
#!/bin/bash
# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source common libraries
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/test_config.sh"
source "${PROJECT_ROOT}/scripts/lib/test_mock.sh"

# Parse command line arguments
MOCK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)
      MOCK_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      export MOCK_VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--mock] [--verbose]"
      exit 1
      ;;
  esac
done

# Initialize test environment
export TEST_MOCK_MODE="${MOCK_MODE}"
export TEST_VERBOSE="${VERBOSE}"

# Load configuration
load_config

# Source the init_test_env function
source "${PROJECT_ROOT}/scripts/testing/tests/template/init_test_env.sh"

# Initialize test environment
init_test_env

# Your test code here...

# Cleanup mock environment if used
if [[ "${TEST_MOCK_MODE}" == "true" ]]; then
  restore_commands
fi
