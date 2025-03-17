#!/bin/bash
# Version: 1.0.0
# run_all_tests.sh - Main test runner for Ephemery test suite
# This script runs all the test categories and generates a comprehensive report

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Source core utilities
source "${PROJECT_ROOT}/scripts/core/path_config.sh"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
source "${PROJECT_ROOT}/scripts/core/common.sh"

# Setup error handling
setup_error_handling

# Test configuration
TESTS_DIR="${PROJECT_ROOT}/scripts/testing/tests"
REPORTS_DIR="${PROJECT_ROOT}/scripts/testing/reports"
SUMMARY_REPORT="${REPORTS_DIR}/test_summary_$(date +%Y%m%d-%H%M%S).log"

# Create reports directory
mkdir -p "${REPORTS_DIR}"

# Create summary report header
{
  echo "Ephemery Test Suite Summary Report"
  echo "=================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "--------------------------------------------------------"
  echo ""
} > "${SUMMARY_REPORT}"

# Define test categories
TEST_CATEGORIES=(
  "client_combinations"
  "reset_integration"
  "performance_benchmark"
  "chaos_testing"
  "genesis_validator"
)

# Function to run tests in a category
run_test_category() {
  local category=$1
  local category_dir="${TESTS_DIR}/${category}"
  
  echo -e "${BLUE}Running ${category} tests${NC}"
  echo "Running ${category} tests..." >> "${SUMMARY_REPORT}"
  
  # Check if category directory exists
  if [ ! -d "${category_dir}" ]; then
    echo -e "${YELLOW}⚠️ Test category directory not found: ${category_dir}${NC}"
    echo "⚠️ Test category directory not found: ${category_dir}" >> "${SUMMARY_REPORT}"
    return 0
  fi
  
  # Find test scripts in the category
  test_scripts=()
  while IFS= read -r line; do
    test_scripts+=("$line")
  done < <(find "${category_dir}" -name "test_*.sh" -type f)
  
  if [ ${#test_scripts[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No test scripts found in ${category}${NC}"
    echo "⚠️ No test scripts found in ${category}" >> "${SUMMARY_REPORT}"
    return 0
  fi
  
  echo "Found ${#test_scripts[@]} test scripts in ${category}" >> "${SUMMARY_REPORT}"
  
  # Run each test script
  local category_passed=0
  local category_failed=0
  
  for script in "${test_scripts[@]}"; do
    local script_name=$(basename "${script}")
    echo -e "${BLUE}Running test: ${script_name}${NC}"
    echo "Running test: ${script_name}" >> "${SUMMARY_REPORT}"
    
    # Make script executable
    chmod +x "${script}"
    
    # Run the test script
    if "${script}"; then
      echo -e "${GREEN}✓ Test passed: ${script_name}${NC}"
      echo "✓ Test passed: ${script_name}" >> "${SUMMARY_REPORT}"
      category_passed=$((category_passed + 1))
    else
      echo -e "${RED}✗ Test failed: ${script_name}${NC}"
      echo "✗ Test failed: ${script_name}" >> "${SUMMARY_REPORT}"
      category_failed=$((category_failed + 1))
    fi
    
    echo "" >> "${SUMMARY_REPORT}"
  done
  
  # Category summary
  {
    echo "Category Summary: ${category}"
    echo "------------------------"
    echo "Tests passed: ${category_passed}"
    echo "Tests failed: ${category_failed}"
    echo "Total tests: $((category_passed + category_failed))"
    echo ""
  } >> "${SUMMARY_REPORT}"
  
  # Return failure if any tests failed
  if [ ${category_failed} -gt 0 ]; then
    return 1
  fi
  
  return 0
}

# Function to run all test categories
run_all_tests() {
  echo -e "${BLUE}Starting Ephemery test suite${NC}"
  echo "Starting Ephemery test suite at $(date)" >> "${SUMMARY_REPORT}"
  
  local total_passed=0
  local total_failed=0
  local categories_passed=0
  local categories_failed=0
  
  # Run each test category
  for category in "${TEST_CATEGORIES[@]}"; do
    if run_test_category "${category}"; then
      categories_passed=$((categories_passed + 1))
    else
      categories_failed=$((categories_failed + 1))
    fi
    
    echo "" >> "${SUMMARY_REPORT}"
  done
  
  # Count total passed and failed tests from the report
  total_passed=$(grep -c "✓ Test passed:" "${SUMMARY_REPORT}")
  total_failed=$(grep -c "✗ Test failed:" "${SUMMARY_REPORT}")
  
  # Generate final summary
  {
    echo "Final Test Suite Summary"
    echo "======================="
    echo "Categories passed: ${categories_passed}"
    echo "Categories failed: ${categories_failed}"
    echo "Total categories: ${#TEST_CATEGORIES[@]}"
    echo ""
    echo "Tests passed: ${total_passed}"
    echo "Tests failed: ${total_failed}"
    echo "Total tests: $((total_passed + total_failed))"
    echo ""
    if [ ${total_failed} -eq 0 ]; then
      echo "OVERALL RESULT: PASSED"
    else
      echo "OVERALL RESULT: FAILED"
    fi
    echo ""
    echo "Test completed at: $(date)"
  } | tee -a "${SUMMARY_REPORT}"
  
  echo -e "${GREEN}Test suite completed. Full report available at:${NC}"
  echo "${SUMMARY_REPORT}"
  
  # Return non-zero exit code if any tests failed
  if [ ${total_failed} -gt 0 ]; then
    return 1
  fi
  
  return 0
}

# Parse command line arguments
SELECTED_CATEGORY=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -c|--category)
      SELECTED_CATEGORY="$2"
      shift
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  -c, --category CATEGORY  Run tests only for the specified category"
      echo "  -h, --help               Show this help message"
      echo ""
      echo "Available categories:"
      for category in "${TEST_CATEGORIES[@]}"; do
        echo "  - ${category}"
      done
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Run tests
if [ -n "${SELECTED_CATEGORY}" ]; then
  # Check if the selected category is valid
  if [[ ! " ${TEST_CATEGORIES[*]} " =~ " ${SELECTED_CATEGORY} " ]]; then
    echo -e "${RED}Error: Invalid category '${SELECTED_CATEGORY}'${NC}"
    echo "Available categories:"
    for category in "${TEST_CATEGORIES[@]}"; do
      echo "  - ${category}"
    done
    exit 1
  fi
  
  # Run only the selected category
  echo -e "${BLUE}Running tests for category: ${SELECTED_CATEGORY}${NC}"
  run_test_category "${SELECTED_CATEGORY}"
  exit $?
else
  # Run all test categories
  run_all_tests
  exit $?
fi 