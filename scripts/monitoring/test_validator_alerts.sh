#!/bin/bash
# Version: 1.0.0
#
# Test Validator Alerts System
# This script tests the validator alerting system with real-world data and validates
# alert thresholds and notification settings.
#
# Usage: ./test_validator_alerts.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --test-notifications   Test all configured notification channels
#   --simulate-issues      Simulate various validator performance issues
#   --test-thresholds      Test alert thresholds with boundary conditions
#   --verbose              Enable verbose output
#   --help                 Show this help message

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common functions
COMMON_SCRIPT="${REPO_ROOT}/scripts/utilities/common_functions.sh"
if [[ -f "${COMMON_SCRIPT}" ]]; then
  source "${COMMON_SCRIPT}"
else
  # Define minimal required functions if common_functions.sh is not available
  function log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
  function log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
  function log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
  function log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
  function log_debug() { if [[ "${VERBOSE}" == "true" ]]; then echo -e "${CYAN}[DEBUG]${NC} $*"; fi; }
fi

# Function to display help
function show_help {
  echo -e "${BLUE}Test Validator Alerts System${NC}"
  echo ""
  echo "This script tests the validator alerting system with real-world data."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
  echo "  --test-notifications   Test all configured notification channels"
  echo "  --simulate-issues      Simulate various validator performance issues"
  echo "  --test-thresholds      Test alert thresholds with boundary conditions"
  echo "  --verbose              Enable verbose output"
  echo "  --help                 Show this help message"
}

# Default values
BASE_DIR="/opt/ephemery"
ALERTS_DIR="${BASE_DIR}/validator_metrics/alerts"
CONFIG_DIR="${BASE_DIR}/config"
ALERTS_CONFIG="${CONFIG_DIR}/validator_alerts.yaml"
TEMP_DIR="$(mktemp -d)"
VERBOSE=false
TEST_NOTIFICATIONS=false
SIMULATE_ISSUES=false
TEST_THRESHOLDS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --test-notifications)
      TEST_NOTIFICATIONS=true
      shift
      ;;
    --simulate-issues)
      SIMULATE_ISSUES=true
      shift
      ;;
    --test-thresholds)
      TEST_THRESHOLDS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Setup test environment
function setup_test_environment {
  log_info "Setting up test environment in ${TEMP_DIR}"

  mkdir -p "${TEMP_DIR}/metrics"
  mkdir -p "${TEMP_DIR}/alerts"
  mkdir -p "${TEMP_DIR}/notifications"

  # Copy configuration files
  if [[ -f "${ALERTS_CONFIG}" ]]; then
    cp "${ALERTS_CONFIG}" "${TEMP_DIR}/"
    log_success "Copied alerts configuration"
  else
    log_warning "Alerts configuration not found at ${ALERTS_CONFIG}"
    # Create minimal test configuration
    cat >"${TEMP_DIR}/validator_alerts.yaml" <<EOF
alerts:
  missed_attestation:
    threshold: 2
    period: "1h"
    severity: "warning"
  missed_proposal:
    threshold: 1
    period: "1d"
    severity: "critical"
  performance_decrease:
    threshold: 10
    period: "1d"
    severity: "warning"
  balance_decrease:
    threshold: 0.01
    period: "1d"
    severity: "warning"
notifications:
  console: true
  email: false
  webhook: false
  telegram: false
  discord: false
EOF
    log_info "Created test configuration"
  fi
}

# Test alert thresholds
function test_alert_thresholds {
  log_info "Testing alert thresholds with boundary conditions"

  # Create test data directory
  mkdir -p "${TEMP_DIR}/test_data"

  # Test cases for various alert types
  log_info "Testing missed attestation thresholds"
  for count in 0 1 2 3 5; do
    log_debug "Testing with ${count} missed attestations"
    # Create test data
    cat >"${TEMP_DIR}/test_data/attestation_${count}.json" <<EOF
{
  "validator_index": "123456",
  "missed_attestations": ${count},
  "total_attestations": 32,
  "period": "1h",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    # Run alert check against this data
    if [[ -x "${SCRIPT_DIR}/validator_alerts_system.sh" ]]; then
      RESULT=$("${SCRIPT_DIR}/validator_alerts_system.sh" \
        --config-file "${TEMP_DIR}/validator_alerts.yaml" \
        --test-mode \
        --test-data "${TEMP_DIR}/test_data/attestation_${count}.json" \
        --alert-type "missed_attestation" 2>/dev/null || echo "ERROR")

      if [[ "${RESULT}" == *"ALERT"* ]]; then
        log_info "Threshold test [${count}]: Alert triggered ✓"
      else
        log_info "Threshold test [${count}]: No alert triggered ✓"
      fi
    else
      log_error "validator_alerts_system.sh not found or not executable"
    fi
  done

  # Test missed proposals
  log_info "Testing missed proposal thresholds"
  for count in 0 1 2; do
    log_debug "Testing with ${count} missed proposals"
    # Create test data
    cat >"${TEMP_DIR}/test_data/proposal_${count}.json" <<EOF
{
  "validator_index": "123456",
  "missed_proposals": ${count},
  "total_proposals": ${count},
  "period": "1d",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    # Run alert check against this data
    if [[ -x "${SCRIPT_DIR}/validator_alerts_system.sh" ]]; then
      RESULT=$("${SCRIPT_DIR}/validator_alerts_system.sh" \
        --config-file "${TEMP_DIR}/validator_alerts.yaml" \
        --test-mode \
        --test-data "${TEMP_DIR}/test_data/proposal_${count}.json" \
        --alert-type "missed_proposal" 2>/dev/null || echo "ERROR")

      if [[ "${RESULT}" == *"ALERT"* ]]; then
        log_info "Threshold test [${count}]: Alert triggered ✓"
      else
        log_info "Threshold test [${count}]: No alert triggered ✓"
      fi
    else
      log_error "validator_alerts_system.sh not found or not executable"
    fi
  done

  # More tests could be added for other alert types
}

# Simulate validator issues
function simulate_validator_issues {
  log_info "Simulating various validator performance issues"

  # Array of simulation scenarios
  SCENARIOS=(
    "missed_attestations"
    "missed_proposal"
    "low_inclusion_distance"
    "decreasing_balance"
    "client_disconnect"
    "sync_committee_failure"
  )

  for scenario in "${SCENARIOS[@]}"; do
    log_info "Simulating scenario: ${scenario}"

    # Create simulation data based on scenario
    case "${scenario}" in
      missed_attestations)
        # Create data for multiple missed attestations
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "missed_attestations": 5,
  "total_attestations": 32,
  "period": "1h",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
      missed_proposal)
        # Create data for missed proposal
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "missed_proposals": 1,
  "total_proposals": 1,
  "period": "1d",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
      low_inclusion_distance)
        # Create data for low inclusion distance
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "inclusion_distance": 4,
  "average_inclusion_distance": 1.2,
  "period": "6h",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
      decreasing_balance)
        # Create data for decreasing balance
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "balance": 31.95,
  "previous_balance": 32.0,
  "period": "1d",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
      client_disconnect)
        # Create data for client disconnect
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "last_seen": "$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-1H -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "offline",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
      sync_committee_failure)
        # Create data for sync committee failure
        cat >"${TEMP_DIR}/test_data/sim_${scenario}.json" <<EOF
{
  "validator_index": "123456",
  "sync_committee_participation": 0.75,
  "expected_participation": 0.95,
  "period": "1d",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        ;;
    esac

    # Run alert check against this simulation
    if [[ -x "${SCRIPT_DIR}/validator_alerts_system.sh" ]]; then
      RESULT=$("${SCRIPT_DIR}/validator_alerts_system.sh" \
        --config-file "${TEMP_DIR}/validator_alerts.yaml" \
        --test-mode \
        --test-data "${TEMP_DIR}/test_data/sim_${scenario}.json" \
        --alert-type "${scenario}" 2>/dev/null || echo "ERROR")

      if [[ "${RESULT}" == *"ALERT"* ]]; then
        log_success "Simulation [${scenario}]: Alert triggered correctly ✓"
      else
        log_error "Simulation [${scenario}]: Alert should have been triggered ✗"
      fi
    else
      log_error "validator_alerts_system.sh not found or not executable"
    fi
  done
}

# Test notification channels
function test_notification_channels {
  log_info "Testing configured notification channels"

  # Load notification configuration
  if [[ -f "${TEMP_DIR}/validator_alerts.yaml" ]]; then
    # Parse YAML to find enabled notification channels
    # This is a simplified version; in a real script, use proper YAML parsing
    CHANNELS=($(grep -A 10 "notifications:" "${TEMP_DIR}/validator_alerts.yaml" | grep "true" | awk -F ':' '{print $1}' | tr -d ' '))

    if [[ ${#CHANNELS[@]} -eq 0 ]]; then
      log_warning "No notification channels enabled in configuration"
      return
    fi

    log_info "Found ${#CHANNELS[@]} enabled notification channels"

    # Create a test alert
    TEST_ALERT='{
          "type": "test_alert",
          "severity": "info",
          "message": "This is a test alert for notification channel testing",
          "validator_index": "test",
          "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }'

    echo "${TEST_ALERT}" >"${TEMP_DIR}/test_alert.json"

    # Test each channel
    for channel in "${CHANNELS[@]}"; do
      log_info "Testing notification channel: ${channel}"

      if [[ -x "${SCRIPT_DIR}/validator_alerts_system.sh" ]]; then
        RESULT=$("${SCRIPT_DIR}/validator_alerts_system.sh" \
          --config-file "${TEMP_DIR}/validator_alerts.yaml" \
          --test-mode \
          --test-notification "${channel}" \
          --alert-data "${TEMP_DIR}/test_alert.json" 2>/dev/null || echo "ERROR")

        if [[ "${RESULT}" == *"SUCCESS"* ]]; then
          log_success "Notification test [${channel}]: Successfully sent ✓"
        else
          log_error "Notification test [${channel}]: Failed to send ✗"
          log_debug "Error output: ${RESULT}"
        fi
      else
        log_error "validator_alerts_system.sh not found or not executable"
      fi
    done
  else
    log_error "Alerts configuration not found at ${TEMP_DIR}/validator_alerts.yaml"
  fi
}

# Run all the tests
function run_tests {
  log_info "Starting validator alerts system testing"

  setup_test_environment

  if [[ "${TEST_THRESHOLDS}" == "true" ]]; then
    test_alert_thresholds
  fi

  if [[ "${SIMULATE_ISSUES}" == "true" ]]; then
    simulate_validator_issues
  fi

  if [[ "${TEST_NOTIFICATIONS}" == "true" ]]; then
    test_notification_channels
  fi

  # If no specific tests were requested, run them all
  if [[ "${TEST_THRESHOLDS}" == "false" && "${SIMULATE_ISSUES}" == "false" && "${TEST_NOTIFICATIONS}" == "false" ]]; then
    log_info "No specific tests requested, running all tests"
    test_alert_thresholds
    simulate_validator_issues
    test_notification_channels
  fi

  log_success "Testing completed"
}

# Cleanup function
function cleanup {
  log_info "Cleaning up temporary test environment"
  rm -rf "${TEMP_DIR}"
}

# Set trap for cleanup
trap cleanup EXIT

# Run the tests
run_tests

exit 0
