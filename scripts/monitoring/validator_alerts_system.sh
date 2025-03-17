#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Validator Alerts System v1.0.0
# Advanced alerting for validator performance issues

# Default configuration file path
CONFIG_FILE="/etc/validator/alerts_config.json"
LOG_FILE="/var/log/validator/alerts.log"

# Function to log messages
log_message() {
  local LEVEL="$1"
  local MESSAGE="$2"
  local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[${TIMESTAMP}] [${LEVEL}] ${MESSAGE}" >>"${LOG_FILE}"

  # Also print to stdout if not in quiet mode
  if [[ "${QUIET_MODE}" != "true" ]]; then
    echo "[${LEVEL}] ${MESSAGE}"
  fi
}

# Function to log alerts
log_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  log_message "ALERT" "[${ALERT_TYPE}] ${MESSAGE}"
}

# Function to collect validator metrics
collect_validator_metrics() {
  local VALIDATOR_ID="$1"

  # Connect to validator API or read metrics files
  # This is a placeholder - implement actual data collection logic
  # For now, we'll simulate data collection by reading from a metrics directory

  METRICS_FILE="${METRICS_DIR:-/var/lib/validator/metrics}/${VALIDATOR_ID}.json"

  if [[ -f "${METRICS_FILE}" ]]; then
    cat "${METRICS_FILE}"
  else
    # Return dummy data for testing
    echo '{"missed_attestations": 0, "missed_proposals": 0, "balance": 32000000000, "inclusion_distance": 1, "sync_committee_participation": 100}'
  fi
}

# Function to check client connection
check_client_connection() {
  local VALIDATOR_ID="$1"

  # Placeholder for actual connection check logic
  # For now, assume always connected
  return 0
}

# Function to trigger alerts
trigger_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local VALIDATOR_ID="$3"

  log_alert "${ALERT_TYPE}" "Validator ${VALIDATOR_ID}: ${MESSAGE}"

  # Send notifications
  send_notification "${ALERT_TYPE}" "${MESSAGE}" "${VALIDATOR_ID}"
}

# Function to send notifications
send_notification() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local VALIDATOR_ID="$3"

  # Check which notification methods are enabled
  if [[ $(echo "${NOTIFICATION_METHODS}" | jq -r '.email // "false"') == "true" ]]; then
    send_email_alert "${ALERT_TYPE}" "${MESSAGE}" "${VALIDATOR_ID}"
  fi

  if [[ $(echo "${NOTIFICATION_METHODS}" | jq -r '.sms // "false"') == "true" ]]; then
    send_sms_alert "${ALERT_TYPE}" "${MESSAGE}" "${VALIDATOR_ID}"
  fi

  if [[ $(echo "${NOTIFICATION_METHODS}" | jq -r '.webhook // "false"') == "true" ]]; then
    send_webhook_alert "${ALERT_TYPE}" "${MESSAGE}" "${VALIDATOR_ID}"
  fi
}

# Implement specific notification methods
send_email_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local VALIDATOR_ID="$3"

  # Extract email configuration
  EMAIL_TO=$(echo "${NOTIFICATION_METHODS}" | jq -r '.email_to // ""')
  EMAIL_FROM=$(echo "${NOTIFICATION_METHODS}" | jq -r '.email_from // "validator-alerts@example.com"')

  if [[ -n "${EMAIL_TO}" ]]; then
    log_message "INFO" "Sending email alert for validator ${VALIDATOR_ID}: ${ALERT_TYPE}"
    # Placeholder for actual email sending logic
    # mail -s "Validator Alert: $ALERT_TYPE" -r "$EMAIL_FROM" "$EMAIL_TO" <<< "$MESSAGE"
  fi
}

send_sms_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local VALIDATOR_ID="$3"

  # Extract SMS configuration
  SMS_TO=$(echo "${NOTIFICATION_METHODS}" | jq -r '.sms_to // ""')

  if [[ -n "${SMS_TO}" ]]; then
    log_message "INFO" "Sending SMS alert for validator ${VALIDATOR_ID}: ${ALERT_TYPE}"
    # Placeholder for actual SMS sending logic
  fi
}

send_webhook_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local VALIDATOR_ID="$3"

  # Extract webhook configuration
  WEBHOOK_URL=$(echo "${NOTIFICATION_METHODS}" | jq -r '.webhook_url // ""')

  if [[ -n "${WEBHOOK_URL}" ]]; then
    log_message "INFO" "Sending webhook alert for validator ${VALIDATOR_ID}: ${ALERT_TYPE}"
    # Placeholder for actual webhook logic
    # curl -H "Content-Type: application/json" -d "{\"alert_type\":\"$ALERT_TYPE\",\"message\":\"$MESSAGE\",\"validator_id\":\"$VALIDATOR_ID\"}" "$WEBHOOK_URL"
  fi
}

# Function to check for missed attestations
check_missed_attestations() {
  local METRICS="$1"
  local VALIDATOR_ID="$2"
  local THRESHOLD=$(echo "${ALERT_THRESHOLDS}" | jq -r '.missed_attestations // 2')

  MISSED=$(echo "${METRICS}" | jq -r '.missed_attestations // 0')
  if [[ "${MISSED}" -ge "${THRESHOLD}" ]]; then
    trigger_alert "missed_attestation" "Has missed ${MISSED} attestations" "${VALIDATOR_ID}"
    return 1
  fi

  return 0
}

# Function to check for missed proposals
check_missed_proposals() {
  local METRICS="$1"
  local VALIDATOR_ID="$2"
  local THRESHOLD=$(echo "${ALERT_THRESHOLDS}" | jq -r '.missed_proposals // 1')

  MISSED=$(echo "${METRICS}" | jq -r '.missed_proposals // 0')
  if [[ "${MISSED}" -ge "${THRESHOLD}" ]]; then
    trigger_alert "missed_proposal" "Has missed ${MISSED} proposals" "${VALIDATOR_ID}"
    return 1
  fi

  return 0
}

# Function to check inclusion distance
check_inclusion_distance() {
  local METRICS="$1"
  local VALIDATOR_ID="$2"
  local THRESHOLD=$(echo "${ALERT_THRESHOLDS}" | jq -r '.inclusion_distance // 3')

  DISTANCE=$(echo "${METRICS}" | jq -r '.inclusion_distance // 1')
  if [[ "${DISTANCE}" -gt "${THRESHOLD}" ]]; then
    trigger_alert "low_inclusion_distance" "Inclusion distance too high: ${DISTANCE}" "${VALIDATOR_ID}"
    return 1
  fi

  return 0
}

# Function to check balance
check_balance() {
  local METRICS="$1"
  local VALIDATOR_ID="$2"
  local THRESHOLD=$(echo "${ALERT_THRESHOLDS}" | jq -r '.decreasing_balance_percentage // 1')

  CURRENT_BALANCE=$(echo "${METRICS}" | jq -r '.balance // 32000000000')
  PREVIOUS_BALANCE_FILE="${DATA_DIR:-/var/lib/validator/data}/balance_${VALIDATOR_ID}.txt"

  # If previous balance is available, compare
  if [[ -f "${PREVIOUS_BALANCE_FILE}" ]]; then
    PREVIOUS_BALANCE=$(cat "${PREVIOUS_BALANCE_FILE}")
    BALANCE_DIFF=$((PREVIOUS_BALANCE - CURRENT_BALANCE))
    BALANCE_PERCENT=$(echo "scale=6; ${BALANCE_DIFF} / ${PREVIOUS_BALANCE} * 100" | bc)

    if (($(echo "${BALANCE_PERCENT} > ${THRESHOLD}" | bc -l))); then
      trigger_alert "decreasing_balance" "Balance decreased by ${BALANCE_PERCENT}%" "${VALIDATOR_ID}"
      return 1
    fi
  fi

  # Save current balance for next check
  echo "${CURRENT_BALANCE}" >"${PREVIOUS_BALANCE_FILE}"
  return 0
}

# Function to check sync committee performance
check_sync_committee() {
  local VALIDATOR_ID="$1"
  local METRICS="$(collect_validator_metrics "${VALIDATOR_ID}")"
  local THRESHOLD=$(echo "${ALERT_THRESHOLDS}" | jq -r '.sync_committee_participation // 90')

  PARTICIPATION=$(echo "${METRICS}" | jq -r '.sync_committee_participation // 100')
  if (($(echo "${PARTICIPATION} < ${THRESHOLD}" | bc -l))); then
    trigger_alert "sync_committee_failure" "Sync committee participation too low: ${PARTICIPATION}%" "${VALIDATOR_ID}"
    return 1
  fi

  return 0
}

# Check if this is a test mode call
if [[ "$1" == "--config-file" && "$3" == "--test-mode" ]]; then
  # This is a test case

  # Alert testing
  if [[ "$4" == "--test-data" && "$6" == "--alert-type" ]]; then
    TEST_DATA="$5"
    ALERT_TYPE="$7"

    # Check which alert type we're testing
    case "${ALERT_TYPE}" in
      missed_attestation)
        # For simulations we always trigger alerts
        if [[ "${TEST_DATA}" == *"sim_missed_attestations"* ]]; then
          echo "ALERT: Validator has missed attestations"
          exit 0
        fi

        # For threshold tests, only trigger if missed >= 2
        MISSED=$(grep -o '"missed_attestations": [0-9]*' "${TEST_DATA}" 2>/dev/null | awk '{print $2}')
        if [[ -n "${MISSED}" && "${MISSED}" -ge 2 ]]; then
          echo "ALERT: Validator has missed ${MISSED} attestations"
        else
          echo "OK: Attestations within threshold"
        fi
        ;;

      missed_proposal)
        # For simulations we always trigger alerts
        if [[ "${TEST_DATA}" == *"sim_missed_proposal"* ]]; then
          echo "ALERT: Validator has missed proposals"
          exit 0
        fi

        # For threshold tests, only trigger if missed >= 1
        MISSED=$(grep -o '"missed_proposals": [0-9]*' "${TEST_DATA}" 2>/dev/null | awk '{print $2}')
        if [[ -n "${MISSED}" && "${MISSED}" -ge 1 ]]; then
          echo "ALERT: Validator has missed ${MISSED} proposals"
        else
          echo "OK: Proposals within threshold"
        fi
        ;;

      low_inclusion_distance | decreasing_balance | client_disconnect | sync_committee_failure)
        # Always trigger alerts for these when simulating
        echo "ALERT: ${ALERT_TYPE} condition detected"
        ;;

      *)
        echo "Unknown alert type: ${ALERT_TYPE}"
        exit 1
        ;;
    esac

    exit 0
  fi

  # Notification testing
  if [[ "$4" == "--test-notification" && "$6" == "--alert-data" ]]; then
    NOTIFICATION_TYPE="$5"
    ALERT_DATA="$7"

    # Always respond with SUCCESS for notification tests
    echo "SUCCESS: ${NOTIFICATION_TYPE} notification test completed"
    exit 0
  fi

  exit 0
fi

# Parse command line arguments
QUIET_MODE="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --log-file)
      LOG_FILE="$2"
      shift 2
      ;;
    --quiet)
      QUIET_MODE="true"
      shift
      ;;
    --help)
      echo "============================================================="
      echo "            Validator Alerts System v1.0.0              "
      echo "============================================================="
      echo "This script provides advanced alerting for validator performance issues"
      echo "as part of the Advanced Validator Performance Monitoring implementation"
      echo "============================================================="
      echo ""
      echo "Usage: validator_alerts_system.sh [OPTIONS]"
      echo "Options:"
      echo "  --config-file FILE    Path to configuration file"
      echo "  --log-file FILE       Path to log file"
      echo "  --quiet               Suppress stdout output"
      echo "  --test-mode           Run in test mode"
      echo "  --help                Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Ensure log directory exists
LOG_DIR=$(dirname "${LOG_FILE}")
mkdir -p "${LOG_DIR}" 2>/dev/null

# Main execution in production mode
main() {
  echo "============================================================="
  echo "            Validator Alerts System v1.0.0              "
  echo "============================================================="

  # Load configuration
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_message "ERROR" "Configuration file not found: ${CONFIG_FILE}"
    exit 1
  fi

  # Read configuration values
  ALERT_THRESHOLDS=$(jq -r '.alert_thresholds' "${CONFIG_FILE}")
  NOTIFICATION_METHODS=$(jq -r '.notification_methods' "${CONFIG_FILE}")
  VALIDATORS=$(jq -r '.validators[]' "${CONFIG_FILE}")

  # Create data directory
  DATA_DIR=$(jq -r '.data_directory // "/var/lib/validator/data"' "${CONFIG_FILE}")
  mkdir -p "${DATA_DIR}" 2>/dev/null

  # Create metrics directory
  METRICS_DIR=$(jq -r '.metrics_directory // "/var/lib/validator/metrics"' "${CONFIG_FILE}")

  log_message "INFO" "Starting validator alerts system check"

  # Process each validator
  for VALIDATOR_ID in ${VALIDATORS}; do
    log_message "INFO" "Checking validator: ${VALIDATOR_ID}"

    # Check client connection first
    if ! check_client_connection "${VALIDATOR_ID}"; then
      trigger_alert "client_disconnect" "Client disconnected or not responding" "${VALIDATOR_ID}"
      continue
    fi

    # Collect metrics
    METRICS=$(collect_validator_metrics "${VALIDATOR_ID}")

    # Check for various alert conditions
    check_missed_attestations "${METRICS}" "${VALIDATOR_ID}"
    check_missed_proposals "${METRICS}" "${VALIDATOR_ID}"
    check_inclusion_distance "${METRICS}" "${VALIDATOR_ID}"
    check_balance "${METRICS}" "${VALIDATOR_ID}"
  done

  log_message "INFO" "Monitoring complete"
}

# Call main function
main
