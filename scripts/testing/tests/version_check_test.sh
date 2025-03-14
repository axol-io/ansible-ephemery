#!/bin/bash

# Sample unit test for version checking functionality
# Tests the version_greater_equal function in version_management.sh

# Set up
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." &> /dev/null && pwd)"
VERSION_MANAGEMENT="${PROJECT_ROOT}/scripts/core/version_management.sh"

# Ensure version_management.sh exists
if [ ! -f "$VERSION_MANAGEMENT" ]; then
  echo "ERROR: version_management.sh not found at $VERSION_MANAGEMENT"
  exit 1
fi

# Source version_management.sh to get the functions
source "$VERSION_MANAGEMENT"

# Test function
test_version_greater_equal() {
  local test_name="$1"
  local version1="$2"
  local version2="$3"
  local expected="$4"
  
  version_greater_equal "$version1" "$version2"
  local result=$?
  
  if [[ "$result" -eq 0 && "$expected" == "true" ]] || [[ "$result" -ne 0 && "$expected" == "false" ]]; then
    echo "✅ PASS: $test_name"
    return 0
  else
    echo "❌ FAIL: $test_name"
    echo "  Expected: $expected"
    echo "  Got: $([ "$result" -eq 0 ] && echo "true" || echo "false")"
    echo "  version_greater_equal '$version1' '$version2'"
    return 1
  fi
}

# Run tests
echo "Running version comparison tests..."
failures=0

# Basic tests
test_version_greater_equal "Equal versions" "1.0.0" "1.0.0" "true" || ((failures++))
test_version_greater_equal "Greater major version" "2.0.0" "1.0.0" "true" || ((failures++))
test_version_greater_equal "Lesser major version" "1.0.0" "2.0.0" "false" || ((failures++))
test_version_greater_equal "Greater minor version" "1.1.0" "1.0.0" "true" || ((failures++))
test_version_greater_equal "Lesser minor version" "1.0.0" "1.1.0" "false" || ((failures++))
test_version_greater_equal "Greater patch version" "1.0.1" "1.0.0" "true" || ((failures++))
test_version_greater_equal "Lesser patch version" "1.0.0" "1.0.1" "false" || ((failures++))

# Edge cases
test_version_greater_equal "Single digit vs double digit" "1.10.0" "1.2.0" "true" || ((failures++))
test_version_greater_equal "Double digit vs single digit" "1.2.0" "1.10.0" "false" || ((failures++))
test_version_greater_equal "Complex versions" "1.22.3" "1.22.0" "true" || ((failures++))
test_version_greater_equal "Complex equal versions" "10.20.30" "10.20.30" "true" || ((failures++))

# Summary
echo 
echo "Test summary:"
echo "Total tests: 11"
echo "Failures: $failures"

if [ $failures -eq 0 ]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi 