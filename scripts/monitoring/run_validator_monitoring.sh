#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Run Validator Performance Monitoring
# ====================================
# This script will run the validator performance monitoring script once
# and display the results.

set -e

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo "Loading configuration from ${CONFIG_FILE}"
  source "${CONFIG_FILE}"
else
  echo "Configuration file not found, using default paths"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
  EPHEMERY_METRICS_DIR="${EPHEMERY_DATA_DIR}/metrics"
fi

# Configuration with standardized paths
SCRIPT_PATH="${EPHEMERY_SCRIPTS_DIR}/validator_performance_monitor.sh"
METRICS_PATH="${EPHEMERY_METRICS_DIR}/validator_metrics.json"

# Check if the monitoring script exists
if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "Validator performance monitoring script not found at ${SCRIPT_PATH}"
  echo "Please run the deployment playbook first:"
  echo "  ansible-playbook playbooks/deploy_validator_monitoring.yml -i inventory.yaml"
  exit 1
fi

# Run the monitoring script
echo "Running validator performance monitoring..."
bash "${SCRIPT_PATH}"

# Check if metrics were generated
if [[ -f "${METRICS_PATH}" ]]; then
  echo "Metrics generated successfully!"
  echo "Metrics file: ${METRICS_PATH}"
  echo
  echo "Validator Summary:"
  # Extract validator count and effectiveness rates
  VALIDATOR_COUNT=$(grep -o '"validator_count":[[:space:]]*[0-9]*' "${METRICS_PATH}" | cut -d':' -f2 | tr -d ' ' || echo "Unknown")
  ATTESTATION_RATE=$(grep -o '"rate":[[:space:]]*[0-9.]*' "${METRICS_PATH}" | head -1 | cut -d':' -f2 | tr -d ' ' || echo "Unknown")
  PROPOSAL_RATE=$(grep -o '"rate":[[:space:]]*[0-9.]*' "${METRICS_PATH}" | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "Unknown")

  echo "- Validator Count: ${VALIDATOR_COUNT}"
  echo "- Attestation Effectiveness: $(printf "%.2f%%" "$(echo "${ATTESTATION_RATE} * 100" | bc -l)")"
  echo "- Proposal Effectiveness: $(printf "%.2f%%" "$(echo "${PROPOSAL_RATE} * 100" | bc -l)")"

  # Extract alerts
  ALERTS=$(grep -o '"alerts":[[:space:]]*\[.*\]' "${METRICS_PATH}" | sed 's/"alerts":[[:space:]]*\[\(.*\)\]/\1/' | tr -d '[]' || echo "")
  if [[ -n "${ALERTS}" && "${ALERTS}" != '""' ]]; then
    echo
    echo "Alerts:"
    echo "${ALERTS}" | tr ',' '\n' | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//'
  else
    echo
    echo "No alerts detected. Validator performance is good!"
  fi

  echo
  echo "To view the full metrics, run:"
  echo "  cat ${METRICS_PATH} | jq"
  echo
  echo "To view the Grafana dashboard, go to:"
  echo "  http://$(hostname -I | awk '{print $1}'):3000/d/validator-performance"
else
  echo "Error: Metrics file not generated at ${METRICS_PATH}"
  exit 1
fi
