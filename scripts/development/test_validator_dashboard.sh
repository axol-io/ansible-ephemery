#!/bin/bash
# Version: 1.0.0
#
# Comprehensive Test Script for Validator Dashboard
# This script tests the functionality of the validator dashboard with various configurations

set -e

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load common library if available
COMMON_LIB="${REPO_ROOT}/scripts/core/common.sh"
if [[ -f "${COMMON_LIB}" ]]; then
  source "${COMMON_LIB}"
else
  echo -e "${RED}Error: Common library not found at ${COMMON_LIB}${NC}"
  exit 1
fi

# Test configuration
DASHBOARD_SCRIPT="${REPO_ROOT}/scripts/validator-dashboard.sh"
MONITOR_SCRIPT="${REPO_ROOT}/scripts/monitoring/advanced_validator_monitoring.sh"
MOCK_DATA_DIR="${REPO_ROOT}/scripts/development/test_data/validator"
TEST_OUTPUT_DIR="${REPO_ROOT}/logs/tests/validator_dashboard"
TEST_CONFIGS=("compact" "detailed" "full" "analyze")

# Ensure mock data directory exists
mkdir -p "${MOCK_DATA_DIR}"
mkdir -p "${TEST_OUTPUT_DIR}"

# Print header
print_header() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}   Validator Dashboard Test Suite${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

# Generate mock data for testing
generate_mock_data() {
  echo -e "${YELLOW}Generating mock validator data for testing...${NC}"

  # Create mock validator status data
  cat >"${MOCK_DATA_DIR}/validator_status.json" <<EOF
{
  "data": [
    {
      "index": "1",
      "balance": "32000000000",
      "status": "active_ongoing",
      "validator": {
        "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000000"
      }
    },
    {
      "index": "2",
      "balance": "31950000000",
      "status": "active_ongoing",
      "validator": {
        "pubkey": "0x8100000000000000000000000000000000000000000000000000000000000000"
      }
    },
    {
      "index": "3",
      "balance": "32100000000",
      "status": "active_ongoing",
      "validator": {
        "pubkey": "0x8200000000000000000000000000000000000000000000000000000000000000"
      }
    },
    {
      "index": "4",
      "balance": "31000000000",
      "status": "active_slashed",
      "validator": {
        "pubkey": "0x8300000000000000000000000000000000000000000000000000000000000000"
      }
    },
    {
      "index": "5",
      "balance": "32000000000",
      "status": "pending_queued",
      "validator": {
        "pubkey": "0x8400000000000000000000000000000000000000000000000000000000000000"
      }
    }
  ]
}
EOF

  # Create mock validator performance data
  cat >"${MOCK_DATA_DIR}/validator_performance.json" <<EOF
{
  "attestation_effectiveness": {
    "0x8000000000000000000000000000000000000000000000000000000000000000": 100,
    "0x8100000000000000000000000000000000000000000000000000000000000000": 98.5,
    "0x8200000000000000000000000000000000000000000000000000000000000000": 100,
    "0x8300000000000000000000000000000000000000000000000000000000000000": 85.3,
    "0x8400000000000000000000000000000000000000000000000000000000000000": 0
  },
  "proposal_count": {
    "0x8000000000000000000000000000000000000000000000000000000000000000": 2,
    "0x8100000000000000000000000000000000000000000000000000000000000000": 1,
    "0x8200000000000000000000000000000000000000000000000000000000000000": 0,
    "0x8300000000000000000000000000000000000000000000000000000000000000": 0,
    "0x8400000000000000000000000000000000000000000000000000000000000000": 0
  },
  "missed_attestations": {
    "0x8000000000000000000000000000000000000000000000000000000000000000": 0,
    "0x8100000000000000000000000000000000000000000000000000000000000000": 2,
    "0x8200000000000000000000000000000000000000000000000000000000000000": 0,
    "0x8300000000000000000000000000000000000000000000000000000000000000": 15,
    "0x8400000000000000000000000000000000000000000000000000000000000000": 0
  },
  "last_attestation": {
    "0x8000000000000000000000000000000000000000000000000000000000000000": "2023-03-12T14:22:30Z",
    "0x8100000000000000000000000000000000000000000000000000000000000000": "2023-03-12T14:22:00Z",
    "0x8200000000000000000000000000000000000000000000000000000000000000": "2023-03-12T14:22:30Z",
    "0x8300000000000000000000000000000000000000000000000000000000000000": "2023-03-12T14:15:30Z",
    "0x8400000000000000000000000000000000000000000000000000000000000000": null
  }
}
EOF

  # Create mock historical data for analysis
  mkdir -p "${MOCK_DATA_DIR}/history"
  for day in {1..7}; do
    cat >"${MOCK_DATA_DIR}/history/validator_metrics_day_${day}.json" <<EOF
{
  "timestamp": "2023-03-${day}T12:00:00Z",
  "validators": {
    "0x8000000000000000000000000000000000000000000000000000000000000000": {
      "balance": $((32000000000 + ${RANDOM} % 100000000)),
      "effectiveness": $((95 + ${RANDOM} % 5)),
      "status": "active_ongoing"
    },
    "0x8100000000000000000000000000000000000000000000000000000000000000": {
      "balance": $((31900000000 + ${RANDOM} % 100000000)),
      "effectiveness": $((90 + ${RANDOM} % 10)),
      "status": "active_ongoing"
    },
    "0x8200000000000000000000000000000000000000000000000000000000000000": {
      "balance": $((32050000000 + ${RANDOM} % 100000000)),
      "effectiveness": $((95 + ${RANDOM} % 5)),
      "status": "active_ongoing"
    },
    "0x8300000000000000000000000000000000000000000000000000000000000000": {
      "balance": $((31000000000 + ${RANDOM} % 100000000)),
      "effectiveness": $((80 + ${RANDOM} % 10)),
      "status": "active_slashed"
    },
    "0x8400000000000000000000000000000000000000000000000000000000000000": {
      "balance": 32000000000,
      "effectiveness": 0,
      "status": "pending_queued"
    }
  }
}
EOF
  done

  echo -e "${GREEN}Mock data generation complete${NC}"
}

# Test dashboard with different configurations
test_dashboard() {
  local config=$1
  local output_file="${TEST_OUTPUT_DIR}/test_${config}.log"

  echo -e "${YELLOW}Testing dashboard with ${config} configuration...${NC}"

  case ${config} in
    compact)
      ${DASHBOARD_SCRIPT} --compact --test-mode --data-dir="${MOCK_DATA_DIR}" >"${output_file}" 2>&1
      ;;
    detailed)
      ${DASHBOARD_SCRIPT} --detailed --test-mode --data-dir="${MOCK_DATA_DIR}" >"${output_file}" 2>&1
      ;;
    full)
      ${DASHBOARD_SCRIPT} --full --test-mode --data-dir="${MOCK_DATA_DIR}" >"${output_file}" 2>&1
      ;;
    analyze)
      ${DASHBOARD_SCRIPT} --analyze --period 7d --test-mode --data-dir="${MOCK_DATA_DIR}" >"${output_file}" 2>&1
      ;;
    *)
      echo -e "${RED}Unknown configuration: ${config}${NC}"
      return 1
      ;;
  esac

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Test passed: ${config}${NC}"
    return 0
  else
    echo -e "${RED}✗ Test failed: ${config}${NC}"
    echo -e "${RED}See error log: ${output_file}${NC}"
    return 1
  fi
}

# Test monitoring script
test_monitoring_script() {
  local output_file="${TEST_OUTPUT_DIR}/test_monitoring.log"

  echo -e "${YELLOW}Testing monitoring script...${NC}"

  ${MONITOR_SCRIPT} --beacon-node mock --validator-client mock --test-mode --output-dir="${MOCK_DATA_DIR}" >"${output_file}" 2>&1

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Test passed: monitoring script${NC}"
    return 0
  else
    echo -e "${RED}✗ Test failed: monitoring script${NC}"
    echo -e "${RED}See error log: ${output_file}${NC}"
    return 1
  fi
}

# Check if dashboard script is executable
check_script_executable() {
  if [[ ! -x "${DASHBOARD_SCRIPT}" ]]; then
    echo -e "${YELLOW}Making dashboard script executable...${NC}"
    chmod +x "${DASHBOARD_SCRIPT}"
  fi

  if [[ ! -x "${MONITOR_SCRIPT}" ]]; then
    echo -e "${YELLOW}Making monitoring script executable...${NC}"
    chmod +x "${MONITOR_SCRIPT}"
  fi
}

# Run all tests
run_all_tests() {
  local failures=0

  # Test monitoring script
  test_monitoring_script || ((failures++))

  # Test dashboard with different configurations
  for config in "${TEST_CONFIGS[@]}"; do
    test_dashboard "${config}" || ((failures++))
  done

  # Report results
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}   Test Results${NC}"
  echo -e "${BLUE}========================================${NC}"

  if [[ ${failures} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}${failures} test(s) failed.${NC}"
    echo -e "${YELLOW}See logs in ${TEST_OUTPUT_DIR} for details.${NC}"
    return 1
  fi
}

# Main function
main() {
  print_header
  check_script_executable
  generate_mock_data
  run_all_tests
  exit $?
}

# Execute main function
main
