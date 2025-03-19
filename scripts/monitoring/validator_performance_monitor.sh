#!/bin/bash
# Version: 1.0.0
#
# Validator Performance Monitoring Script
# =======================================
# This script collects performance metrics from validator clients,
# analyzes attestation and proposal effectiveness, and exports the data
# for use in dashboards and alerting systems.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
BASE_DIR=${BASE_DIR:-"/root/ephemery"}
CONFIG_DIR="${BASE_DIR}/config"
DATA_DIR="${BASE_DIR}/data"
LOG_DIR="${BASE_DIR}/logs"
METRICS_DIR="${DATA_DIR}/metrics"
HISTORY_DIR="${METRICS_DIR}/history"
VALIDATOR_DIR="${DATA_DIR}/validator"
VALIDATOR_KEYS_DIR="${BASE_DIR}/secrets/validator/keys"
BEACON_NODE_ENDPOINT=${BEACON_NODE_ENDPOINT:-"http://localhost:5052"}
VALIDATOR_ENDPOINT=${VALIDATOR_ENDPOINT:-"http://localhost:5062"}
METRICS_OUTPUT="${METRICS_DIR}/validator_metrics.json"
METRICS_HISTORY="${HISTORY_DIR}/validator_metrics_$(date +%Y%m%d_%H%M%S).json"
ALERT_LOG="${LOG_DIR}/validator_alerts.log"
CLIENT_TYPE=${CLIENT_TYPE:-"lighthouse"} # Options: lighthouse, teku, nimbus, prysm
VALIDATOR_METRICS_PORT=${VALIDATOR_METRICS_PORT:-"8009"}

# Ensure directories exist
mkdir -p "${METRICS_DIR}" "${HISTORY_DIR}" "${LOG_DIR}"

# Detect client type if not specified
detect_client_type() {
  if [[ -z "${CLIENT_TYPE}" ]]; then
    if docker ps | grep -q ephemery-lighthouse-validator; then
      CLIENT_TYPE="lighthouse"
      VALIDATOR_METRICS_PORT="8009"
    elif docker ps | grep -q ephemery-teku-validator; then
      CLIENT_TYPE="teku"
      VALIDATOR_METRICS_PORT="8008"
    elif docker ps | grep -q ephemery-prysm-validator; then
      CLIENT_TYPE="prysm"
      VALIDATOR_METRICS_PORT="8081"
    elif docker ps | grep -q ephemery-nimbus-validator; then
      CLIENT_TYPE="nimbus"
      VALIDATOR_METRICS_PORT="8008"
    elif docker ps | grep -q ephemery-lodestar-validator; then
      CLIENT_TYPE="lodestar"
      VALIDATOR_METRICS_PORT="8008"
    else
      echo "Unable to detect validator client type. Using default (lighthouse)."
      CLIENT_TYPE="lighthouse"
    fi
  fi
  echo "Detected validator client: ${CLIENT_TYPE}"
}

# Get validator public keys
get_validator_pubkeys() {
  local key_count=0
  local pubkeys=()

  for keyfile in "${VALIDATOR_KEYS_DIR}"/keystore-*.json; do
    if [[ -f "${keyfile}" ]]; then
      # Extract pubkey from filename or file content
      local pubkey
      if [[ "${keyfile}" =~ keystore-([0-9a-f]+)\.json ]]; then
        pubkey="${BASH_REMATCH[1]}"
      else
        pubkey=$(grep -o '"pubkey":[[:space:]]*"[^"]*"' "${keyfile}" | cut -d'"' -f4 || echo "")
      fi

      if [[ -n "${pubkey}" ]]; then
        pubkeys+=("${pubkey}")
        ((key_count++))
      fi
    fi
  done

  echo "Found ${key_count} validator keys"
  echo "${pubkeys[@]}"
}

# Get validator status from beacon node
get_validator_status() {
  local pubkey="$1"
  local status_json

  status_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
    -H "Accept: application/json" || echo '{"data":{"status":"unknown"}}')

  local status=$(echo "${status_json}" | grep -o '"status":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  echo "${status}"
}

# Get validator balance
get_validator_balance() {
  local pubkey="$1"
  local balance_json

  balance_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
    -H "Accept: application/json" || echo '{"data":{"balance":"0"}}')

  local balance=$(echo "${balance_json}" | grep -o '"balance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
  echo "${balance}"
}

# Get validator effectiveness metrics from client
get_validator_effectiveness() {
  local metrics_json="{}"

  case "${CLIENT_TYPE}" in
    lighthouse)
      # Extract metrics from Lighthouse's Prometheus endpoint
      if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" >/tmp/lighthouse_metrics.txt; then
        local attestation_hits=$(grep 'validator_attestation_hits' /tmp/lighthouse_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_misses=$(grep 'validator_attestation_misses' /tmp/lighthouse_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_total=$((attestation_hits + attestation_misses))
        local attestation_rate=0
        if ((attestation_total > 0)); then
          attestation_rate=$(echo "scale=4; ${attestation_hits}/${attestation_total}" | bc)
        fi

        local proposals_hit=$(grep 'validator_proposal_hits' /tmp/lighthouse_metrics.txt | awk '{print $2}' || echo "0")
        local proposals_miss=$(grep 'validator_proposal_misses' /tmp/lighthouse_metrics.txt | awk '{print $2}' || echo "0")
        local proposals_total=$((proposals_hit + proposals_miss))
        local proposal_rate=0
        if ((proposals_total > 0)); then
          proposal_rate=$(echo "scale=4; ${proposals_hit}/${proposals_total}" | bc)
        fi

        metrics_json=$(
          cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestation_hits},
    "misses": ${attestation_misses},
    "total": ${attestation_total},
    "rate": ${attestation_rate}
  },
  "proposal_effectiveness": {
    "hits": ${proposals_hit},
    "misses": ${proposals_miss},
    "total": ${proposals_total},
    "rate": ${proposal_rate}
  }
}
EOF
        )
      fi
      ;;

    teku)
      # Extract metrics from Teku's Prometheus endpoint
      if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" >/tmp/teku_metrics.txt; then
        local attestation_published=$(grep 'beacon_attestation_published_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_failed=$(grep 'beacon_attestation_failed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_total=$((attestation_published + attestation_failed))
        local attestation_rate=0
        if ((attestation_total > 0)); then
          attestation_rate=$(echo "scale=4; ${attestation_published}/${attestation_total}" | bc)
        fi

        local blocks_proposed=$(grep 'beacon_blocks_proposed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_failed=$(grep 'beacon_blocks_proposed_failed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_total=$((blocks_proposed + blocks_failed))
        local proposal_rate=0
        if ((blocks_total > 0)); then
          proposal_rate=$(echo "scale=4; ${blocks_proposed}/${blocks_total}" | bc)
        fi

        metrics_json=$(
          cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestation_published},
    "misses": ${attestation_failed},
    "total": ${attestation_total},
    "rate": ${attestation_rate}
  },
  "proposal_effectiveness": {
    "hits": ${blocks_proposed},
    "misses": ${blocks_failed},
    "total": ${blocks_total},
    "rate": ${proposal_rate}
  }
}
EOF
        )
      fi
      ;;

    prysm)
      # Extract metrics from Prysm's Prometheus endpoint
      if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" >/tmp/prysm_metrics.txt; then
        local attestation_sent=$(grep 'validator_attestation_sent_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
        local attestation_missed=$(grep 'validator_attestation_missed_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
        local attestation_total=$((attestation_sent + attestation_missed))
        local attestation_rate=0
        if ((attestation_total > 0)); then
          attestation_rate=$(echo "scale=4; ${attestation_sent}/${attestation_total}" | bc)
        fi

        local blocks_proposed=$(grep 'validator_proposal_sent_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
        local blocks_missed=$(grep 'validator_proposal_missed_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
        local blocks_total=$((blocks_proposed + blocks_missed))
        local proposal_rate=0
        if ((blocks_total > 0)); then
          proposal_rate=$(echo "scale=4; ${blocks_proposed}/${blocks_total}" | bc)
        fi

        metrics_json=$(
          cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestation_sent},
    "misses": ${attestation_missed},
    "total": ${attestation_total},
    "rate": ${attestation_rate}
  },
  "proposal_effectiveness": {
    "hits": ${blocks_proposed},
    "misses": ${blocks_missed},
    "total": ${blocks_total},
    "rate": ${proposal_rate}
  }
}
EOF
        )
      fi
      ;;

    nimbus)
      # Extract metrics from Nimbus's Prometheus endpoint
      if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" >/tmp/nimbus_metrics.txt; then
        local attestations_sent=$(grep 'validator_attestations_sent_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
        local attestations_failed=$(grep 'validator_attestations_failed_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_total=$((attestations_sent + attestations_failed))
        local attestation_rate=0
        if ((attestation_total > 0)); then
          attestation_rate=$(echo "scale=4; ${attestations_sent}/${attestation_total}" | bc)
        fi

        local blocks_sent=$(grep 'validator_blocks_sent_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_failed=$(grep 'validator_blocks_failed_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_total=$((blocks_sent + blocks_failed))
        local proposal_rate=0
        if ((blocks_total > 0)); then
          proposal_rate=$(echo "scale=4; ${blocks_sent}/${blocks_total}" | bc)
        fi

        metrics_json=$(
          cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestations_sent},
    "misses": ${attestations_failed},
    "total": ${attestation_total},
    "rate": ${attestation_rate}
  },
  "proposal_effectiveness": {
    "hits": ${blocks_sent},
    "misses": ${blocks_failed},
    "total": ${blocks_total},
    "rate": ${proposal_rate}
  }
}
EOF
        )
      fi
      ;;

    lodestar)
      # Extract metrics from Lodestar's Prometheus endpoint
      if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" >/tmp/lodestar_metrics.txt; then
        local attestations_published=$(grep 'lodestar_validator_published_attestations_total' /tmp/lodestar_metrics.txt | awk '{print $2}' || echo "0")
        local attestations_missed=$(grep 'lodestar_validator_missed_attestations_total' /tmp/lodestar_metrics.txt | awk '{print $2}' || echo "0")
        local attestation_total=$((attestations_published + attestations_missed))
        local attestation_rate=0
        if ((attestation_total > 0)); then
          attestation_rate=$(echo "scale=4; ${attestations_published}/${attestation_total}" | bc)
        fi

        local blocks_published=$(grep 'lodestar_validator_published_blocks_total' /tmp/lodestar_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_missed=$(grep 'lodestar_validator_missed_blocks_total' /tmp/lodestar_metrics.txt | awk '{print $2}' || echo "0")
        local blocks_total=$((blocks_published + blocks_missed))
        local proposal_rate=0
        if ((blocks_total > 0)); then
          proposal_rate=$(echo "scale=4; ${blocks_published}/${blocks_total}" | bc)
        fi

        metrics_json=$(
          cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestations_published},
    "misses": ${attestations_missed},
    "total": ${attestation_total},
    "rate": ${attestation_rate}
  },
  "proposal_effectiveness": {
    "hits": ${blocks_published},
    "misses": ${blocks_missed},
    "total": ${blocks_total},
    "rate": ${proposal_rate}
  }
}
EOF
        )
      fi
      ;;

    *)
      echo "Unsupported client type: ${CLIENT_TYPE}"
      metrics_json="{\"error\": \"unsupported_client\"}"
      ;;
  esac

  echo "${metrics_json}"
}

# Get current epoch and slots
get_network_info() {
  local network_json

  network_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head" \
    -H "Accept: application/json" || echo '{"data":{"slot":"0"}}')

  local current_slot=$(echo "${network_json}" | grep -o '"slot":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
  local current_epoch=$((current_slot / 32))

  echo "{\"current_slot\": ${current_slot}, \"current_epoch\": ${current_epoch}}"
}

# Check for sync issues
check_sync_status() {
  local sync_json

  sync_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/node/syncing" \
    -H "Accept: application/json" || echo '{"data":{"is_syncing":true,"sync_distance":"unknown"}}')

  local is_syncing=$(echo "${sync_json}" | grep -o '"is_syncing":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' ' || echo "true")
  local sync_distance=$(echo "${sync_json}" | grep -o '"sync_distance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")

  echo "{\"is_syncing\": ${is_syncing}, \"sync_distance\": \"${sync_distance}\"}"
}

# Check for slashing protection issues
check_slashing_protection() {
  local slashing_protection_file="${VALIDATOR_DIR}/slashing_protection.json"
  local status="ok"
  local message=""

  if [[ -f "${slashing_protection_file}" ]]; then
    # Check file size to ensure it's not empty or corrupted
    local file_size=$(stat -c%s "${slashing_protection_file}" 2>/dev/null || stat -f%z "${slashing_protection_file}" 2>/dev/null)

    if [[ ${file_size} -lt 100 ]]; then
      status="warning"
      message="Slashing protection database appears to be very small (${file_size} bytes). May be corrupted or incomplete."
    fi
  else
    status="warning"
    message="Slashing protection database not found at ${slashing_protection_file}"
  fi

  echo "{\"status\": \"${status}\", \"message\": \"${message}\"}"
}

# Generate alerts based on metrics
generate_alerts() {
  local effectiveness_json="$1"
  local alerts=()

  # Parse effectiveness rates
  local attestation_rate=$(echo "${effectiveness_json}" | grep -o '"rate":[[:space:]]*[0-9.]*' | head -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
  local proposal_rate=$(echo "${effectiveness_json}" | grep -o '"rate":[[:space:]]*[0-9.]*' | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "0")

  # Alert thresholds
  local attestation_warning=0.95
  local attestation_critical=0.9
  local proposal_warning=0.95
  local proposal_critical=0.9

  # Check attestation effectiveness
  if (($(echo "${attestation_rate} < ${attestation_critical}" | bc -l))); then
    alerts+=("CRITICAL: Attestation effectiveness is critically low (${attestation_rate})")
    log_alert "CRITICAL" "Attestation effectiveness is critically low: ${attestation_rate}"
  elif (($(echo "${attestation_rate} < ${attestation_warning}" | bc -l))); then
    alerts+=("WARNING: Attestation effectiveness is below threshold (${attestation_rate})")
    log_alert "WARNING" "Attestation effectiveness is below threshold: ${attestation_rate}"
  fi

  # Check proposal effectiveness (if there have been any proposals)
  local proposal_total=$(echo "${effectiveness_json}" | grep -o '"total":[[:space:]]*[0-9]*' | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
  if [[ "${proposal_total}" != "0" ]]; then
    if (($(echo "${proposal_rate} < ${proposal_critical}" | bc -l))); then
      alerts+=("CRITICAL: Block proposal effectiveness is critically low (${proposal_rate})")
      log_alert "CRITICAL" "Block proposal effectiveness is critically low: ${proposal_rate}"
    elif (($(echo "${proposal_rate} < ${proposal_warning}" | bc -l))); then
      alerts+=("WARNING: Block proposal effectiveness is below threshold (${proposal_rate})")
      log_alert "WARNING" "Block proposal effectiveness is below threshold: ${proposal_rate}"
    fi
  fi

  # Format alerts as JSON
  local alerts_json="[]"
  if [[ ${#alerts[@]} -gt 0 ]]; then
    alerts_json="["
    for i in "${!alerts[@]}"; do
      alerts_json+="\"${alerts[${i}]}\""
      if [[ ${i} -lt $((${#alerts[@]} - 1)) ]]; then
        alerts_json+=", "
      fi
    done
    alerts_json+="]"
  fi

  echo "${alerts_json}"
}

# Log alerts to file
log_alert() {
  local level="$1"
  local message="$2"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "[${timestamp}] [${level}] ${message}" >>"${ALERT_LOG}"
}

# Main function to collect all metrics
collect_metrics() {
  local pubkeys
  read -r -a pubkeys <<<"$(get_validator_pubkeys)"

  # Initialize validators array
  local validators_json="[]"
  if [[ ${#pubkeys[@]} -gt 0 ]]; then
    validators_json="["
    for i in "${!pubkeys[@]}"; do
      local pubkey="${pubkeys[${i}]}"
      local status=$(get_validator_status "${pubkey}")
      local balance=$(get_validator_balance "${pubkey}")

      validators_json+="{\"pubkey\":\"${pubkey}\",\"status\":\"${status}\",\"balance\":\"${balance}\"}"
      if [[ ${i} -lt $((${#pubkeys[@]} - 1)) ]]; then
        validators_json+=", "
      fi
    done
    validators_json+="]"
  fi

  # Get effectiveness metrics
  local effectiveness_json=$(get_validator_effectiveness)

  # Get network info
  local network_json=$(get_network_info)

  # Get sync status
  local sync_json=$(check_sync_status)

  # Check slashing protection
  local slashing_protection_json=$(check_slashing_protection)

  # Generate alerts
  local alerts_json=$(generate_alerts "${effectiveness_json}")

  # Combine all metrics into one JSON object
  local combined_json=$(
    cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validator_client": "${CLIENT_TYPE}",
  "validator_count": ${#pubkeys[@]},
  "network_info": ${network_json},
  "sync_status": ${sync_json},
  "slashing_protection": ${slashing_protection_json},
  "effectiveness": ${effectiveness_json},
  "validators": ${validators_json},
  "alerts": ${alerts_json}
}
EOF
  )

  # Save metrics to files
  echo "${combined_json}" >"${METRICS_OUTPUT}"
  echo "${combined_json}" >"${METRICS_HISTORY}"

  # Output to stdout as well
  echo "${combined_json}"
}

# Export metrics to Prometheus format for scraping
export_prometheus_metrics() {
  local metrics_dir="${METRICS_DIR}/prometheus"
  mkdir -p "${metrics_dir}"
  local prom_file="${metrics_dir}/validator_metrics.prom"

  # Extract metrics from the JSON file
  if [[ -f "${METRICS_OUTPUT}" ]]; then
    local json_content=$(cat "${METRICS_OUTPUT}")

    # Validator count
    local validator_count=$(echo "${json_content}" | grep -o '"validator_count":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Attestation effectiveness
    local attestation_hits=$(echo "${json_content}" | grep -o '"hits":[[:space:]]*[0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
    local attestation_misses=$(echo "${json_content}" | grep -o '"misses":[[:space:]]*[0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
    local attestation_rate=$(echo "${json_content}" | grep -o '"rate":[[:space:]]*[0-9.]*' | head -1 | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Proposal effectiveness
    local proposal_hits=$(echo "${json_content}" | grep -o '"hits":[[:space:]]*[0-9]*' | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
    local proposal_misses=$(echo "${json_content}" | grep -o '"misses":[[:space:]]*[0-9]*' | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "0")
    local proposal_rate=$(echo "${json_content}" | grep -o '"rate":[[:space:]]*[0-9.]*' | tail -1 | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Alert count
    local alert_count=$(echo "${json_content}" | grep -o '"alerts":[[:space:]]*\[.*\]' | grep -o ',' | wc -l)
    ((alert_count++))
    if [[ "${alert_count}" == "1" && -n $(echo "${json_content}" | grep -o '"alerts":[[:space:]]*\[\]') ]]; then
      alert_count=0
    fi

    # Write Prometheus metrics
    cat >"${prom_file}" <<EOF
# HELP ephemery_validator_count Number of validators managed by this client
# TYPE ephemery_validator_count gauge
ephemery_validator_count ${validator_count}

# HELP ephemery_attestation_hits Number of attestations successfully published
# TYPE ephemery_attestation_hits counter
ephemery_attestation_hits ${attestation_hits}

# HELP ephemery_attestation_misses Number of attestations that failed or were missed
# TYPE ephemery_attestation_misses counter
ephemery_attestation_misses ${attestation_misses}

# HELP ephemery_attestation_rate Rate of successful attestations (0-1)
# TYPE ephemery_attestation_rate gauge
ephemery_attestation_rate ${attestation_rate}

# HELP ephemery_proposal_hits Number of blocks successfully proposed
# TYPE ephemery_proposal_hits counter
ephemery_proposal_hits ${proposal_hits}

# HELP ephemery_proposal_misses Number of block proposals that failed or were missed
# TYPE ephemery_proposal_misses counter
ephemery_proposal_misses ${proposal_misses}

# HELP ephemery_proposal_rate Rate of successful block proposals (0-1)
# TYPE ephemery_proposal_rate gauge
ephemery_proposal_rate ${proposal_rate}

# HELP ephemery_validator_alerts Number of active alerts for validator performance
# TYPE ephemery_validator_alerts gauge
ephemery_validator_alerts ${alert_count}
EOF

    echo "Exported metrics to Prometheus format at ${prom_file}"
  else
    echo "Metrics file ${METRICS_OUTPUT} not found, skipping Prometheus export"
  fi
}

# Run all functions in sequence
main() {
  echo "Starting validator performance monitoring at $(date)"

  detect_client_type
  local metrics_json=$(collect_metrics)
  export_prometheus_metrics

  echo "Completed validator performance monitoring at $(date)"
}

# Run the main function
main
