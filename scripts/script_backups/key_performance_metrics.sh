#!/bin/bash
#
# Key Performance Metrics Script
# ==============================
# This script collects and analyzes performance metrics for validator keys,
# focusing on attestation effectiveness, proposal success, and rewards.
# It provides detailed per-key metrics for monitoring and optimization.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=${BASE_DIR:-"/root/ephemery"}
CONFIG_DIR="${BASE_DIR}/config"
DATA_DIR="${BASE_DIR}/data"
LOG_DIR="${BASE_DIR}/logs"
METRICS_DIR="${DATA_DIR}/metrics"
KEY_METRICS_DIR="${METRICS_DIR}/key_metrics"
HISTORY_DIR="${KEY_METRICS_DIR}/history"
VALIDATOR_DIR="${DATA_DIR}/validator"
VALIDATOR_KEYS_DIR="${BASE_DIR}/secrets/validator/keys"
BEACON_NODE_ENDPOINT=${BEACON_NODE_ENDPOINT:-"http://localhost:5052"}
VALIDATOR_ENDPOINT=${VALIDATOR_ENDPOINT:-"http://localhost:5062"}
METRICS_OUTPUT="${KEY_METRICS_DIR}/key_metrics.json"
METRICS_SUMMARY="${KEY_METRICS_DIR}/key_metrics_summary.json"
METRICS_HISTORY="${HISTORY_DIR}/key_metrics_$(date +%Y%m%d_%H%M%S).json"
ALERT_LOG="${LOG_DIR}/key_metrics_alerts.log"
CLIENT_TYPE=${CLIENT_TYPE:-"lighthouse"} # Options: lighthouse, teku, nimbus, prysm
VALIDATOR_METRICS_PORT=${VALIDATOR_METRICS_PORT:-"8009"}
RETENTION_DAYS=${RETENTION_DAYS:-7}

# Performance thresholds for alerts
ATTESTATION_THRESHOLD=${ATTESTATION_THRESHOLD:-0.90} # Alert if below 90%
PROPOSAL_THRESHOLD=${PROPOSAL_THRESHOLD:-0.95} # Alert if below 95%
BALANCE_DECREASE_THRESHOLD=${BALANCE_DECREASE_THRESHOLD:-0.01} # 1% drop

# Ensure directories exist
mkdir -p "${KEY_METRICS_DIR}" "${HISTORY_DIR}" "${LOG_DIR}"

# Log with timestamp
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message"
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo "[$timestamp] [$level] $message" >> "${ALERT_LOG}"
    fi
}

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
            log "WARN" "Unable to detect validator client type. Using default (lighthouse)."
            CLIENT_TYPE="lighthouse"
        fi
    fi
    log "INFO" "Detected validator client: ${CLIENT_TYPE}"
}

# Get validator public keys
get_validator_pubkeys() {
    local key_count=0
    local pubkeys=()

    for keyfile in "${VALIDATOR_KEYS_DIR}"/keystore-*.json; do
        if [[ -f "$keyfile" ]]; then
            # Extract pubkey from filename or file content
            local pubkey
            if [[ "$keyfile" =~ keystore-([0-9a-f]+)\.json ]]; then
                pubkey="${BASH_REMATCH[1]}"
            else
                pubkey=$(grep -o '"pubkey":[[:space:]]*"[^"]*"' "$keyfile" | cut -d'"' -f4 || echo "")
            fi

            if [[ -n "$pubkey" ]]; then
                pubkeys+=("$pubkey")
                ((key_count++))
            fi
        fi
    done

    log "INFO" "Found ${key_count} validator keys"
    echo "${pubkeys[@]}"
}

# Get validator status from beacon node
get_validator_status() {
    local pubkey="$1"
    local status_json

    status_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
        -H "Accept: application/json" || echo '{"data":{"status":"unknown"}}')

    local status=$(echo "$status_json" | grep -o '"status":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "$status"
}

# Get validator balance
get_validator_balance() {
    local pubkey="$1"
    local balance_json

    balance_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
        -H "Accept: application/json" || echo '{"data":{"balance":"0"}}')

    local balance=$(echo "$balance_json" | grep -o '"balance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
    echo "$balance"
}

# Get validator index
get_validator_index() {
    local pubkey="$1"
    local index_json

    index_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
        -H "Accept: application/json" || echo '{"data":{"index":"0"}}')

    local index=$(echo "$index_json" | grep -o '"index":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
    echo "$index"
}

# Get validator effectiveness metrics from client
get_validator_effectiveness() {
    local validator_index="$1"
    local metrics_json="{}"

    case "${CLIENT_TYPE}" in
        lighthouse)
            # Get validator-specific metrics from Lighthouse API
            local validator_data=$(curl -s "${VALIDATOR_ENDPOINT}/lighthouse/validators/info/${validator_index}" || echo '{}')

            # Extract attestation performance
            local attestation_hits=$(echo "$validator_data" | jq -r '.attestation_hits // 0')
            local attestation_misses=$(echo "$validator_data" | jq -r '.attestation_misses // 0')
            local attestation_total=$((attestation_hits + attestation_misses))
            local attestation_rate=0
            if (( attestation_total > 0 )); then
                attestation_rate=$(echo "scale=4; ${attestation_hits}/${attestation_total}" | bc)
            fi

            # Extract proposal performance
            local proposals_hit=$(echo "$validator_data" | jq -r '.proposal_hits // 0')
            local proposals_miss=$(echo "$validator_data" | jq -r '.proposal_misses // 0')
            local proposals_total=$((proposals_hit + proposals_miss))
            local proposal_rate=0
            if (( proposals_total > 0 )); then
                proposal_rate=$(echo "scale=4; ${proposals_hit}/${proposals_total}" | bc)
            fi

            metrics_json=$(cat <<EOF
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
            ;;

        teku)
            # For Teku, we'll use the global metrics and prorate them for each validator
            # This is a simplification as Teku doesn't expose per-validator metrics directly
            local total_validators=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators" | \
                                 jq '.data | length' || echo "1")

            if [[ "$total_validators" -lt 1 ]]; then
                total_validators=1
            fi

            if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" > /tmp/teku_metrics.txt; then
                local attestation_published=$(grep 'beacon_attestation_published_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
                local attestation_failed=$(grep 'beacon_attestation_failed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
                local attestation_total=$((attestation_published + attestation_failed))
                local attestation_rate=0
                if (( attestation_total > 0 )); then
                    attestation_rate=$(echo "scale=4; ${attestation_published}/${attestation_total}" | bc)
                fi

                local blocks_proposed=$(grep 'beacon_blocks_proposed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
                local blocks_failed=$(grep 'beacon_blocks_proposed_failed_total' /tmp/teku_metrics.txt | awk '{print $2}' || echo "0")
                local blocks_total=$((blocks_proposed + blocks_failed))
                local proposal_rate=0
                if (( blocks_total > 0 )); then
                    proposal_rate=$(echo "scale=4; ${blocks_proposed}/${blocks_total}" | bc)
                fi

                # Prorate the metrics based on validator count
                attestation_published=$(echo "scale=4; ${attestation_published}/${total_validators}" | bc)
                attestation_failed=$(echo "scale=4; ${attestation_failed}/${total_validators}" | bc)
                attestation_total=$(echo "scale=4; ${attestation_total}/${total_validators}" | bc)
                blocks_proposed=$(echo "scale=4; ${blocks_proposed}/${total_validators}" | bc)
                blocks_failed=$(echo "scale=4; ${blocks_failed}/${total_validators}" | bc)
                blocks_total=$(echo "scale=4; ${blocks_total}/${total_validators}" | bc)

                metrics_json=$(cat <<EOF
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
            # For Prysm, try to get validator-specific metrics via the validator index
            if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" > /tmp/prysm_metrics.txt; then
                # Look for metrics with index label matching our validator
                local index_filter="index=\"${validator_index}\""
                local attestation_sent=$(grep "validator_attestation_sent_total.*${index_filter}" /tmp/prysm_metrics.txt | awk '{print $2}' || echo "0")
                local attestation_missed=$(grep "validator_attestation_missed_total.*${index_filter}" /tmp/prysm_metrics.txt | awk '{print $2}' || echo "0")

                # If no specific validator metrics found, use aggregate and prorate
                if [[ -z "$attestation_sent" || -z "$attestation_missed" ]]; then
                    local total_validators=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators" | \
                                         jq '.data | length' || echo "1")
                    if [[ "$total_validators" -lt 1 ]]; then
                        total_validators=1
                    fi

                    attestation_sent=$(grep 'validator_attestation_sent_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
                    attestation_sent=$(echo "scale=4; ${attestation_sent}/${total_validators}" | bc)

                    attestation_missed=$(grep 'validator_attestation_missed_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
                    attestation_missed=$(echo "scale=4; ${attestation_missed}/${total_validators}" | bc)
                fi

                local attestation_total=$(echo "${attestation_sent} + ${attestation_missed}" | bc)
                local attestation_rate=0
                if (( $(echo "$attestation_total > 0" | bc -l) )); then
                    attestation_rate=$(echo "scale=4; ${attestation_sent}/${attestation_total}" | bc)
                fi

                # Similar approach for proposal metrics
                local proposals_hit=$(grep "validator_proposal_sent_total.*${index_filter}" /tmp/prysm_metrics.txt | awk '{print $2}' || echo "0")
                local proposals_miss=$(grep "validator_proposal_missed_total.*${index_filter}" /tmp/prysm_metrics.txt | awk '{print $2}' || echo "0")

                if [[ -z "$proposals_hit" || -z "$proposals_miss" ]]; then
                    local total_validators=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators" | \
                                         jq '.data | length' || echo "1")
                    if [[ "$total_validators" -lt 1 ]]; then
                        total_validators=1
                    fi

                    proposals_hit=$(grep 'validator_proposal_sent_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
                    proposals_hit=$(echo "scale=4; ${proposals_hit}/${total_validators}" | bc)

                    proposals_miss=$(grep 'validator_proposal_missed_total' /tmp/prysm_metrics.txt | awk '{sum+=$2} END {print sum}' || echo "0")
                    proposals_miss=$(echo "scale=4; ${proposals_miss}/${total_validators}" | bc)
                fi

                local proposals_total=$(echo "${proposals_hit} + ${proposals_miss}" | bc)
                local proposal_rate=0
                if (( $(echo "$proposals_total > 0" | bc -l) )); then
                    proposal_rate=$(echo "scale=4; ${proposals_hit}/${proposals_total}" | bc)
                fi

                metrics_json=$(cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestation_sent},
    "misses": ${attestation_missed},
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

        nimbus)
            # For Nimbus, we'll use the global metrics and prorate them for each validator
            if curl -s "http://localhost:${VALIDATOR_METRICS_PORT}/metrics" > /tmp/nimbus_metrics.txt; then
                local total_validators=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators" | \
                                     jq '.data | length' || echo "1")
                if [[ "$total_validators" -lt 1 ]]; then
                    total_validators=1
                fi

                local attestation_published=$(grep 'validator_attestations_sent_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
                local attestation_failed=$(grep 'validator_attestations_missed_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
                local attestation_total=$((attestation_published + attestation_failed))
                local attestation_rate=0
                if (( attestation_total > 0 )); then
                    attestation_rate=$(echo "scale=4; ${attestation_published}/${attestation_total}" | bc)
                fi

                local blocks_proposed=$(grep 'validator_proposals_sent_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
                local blocks_missed=$(grep 'validator_proposals_missed_total' /tmp/nimbus_metrics.txt | awk '{print $2}' || echo "0")
                local blocks_total=$((blocks_proposed + blocks_missed))
                local proposal_rate=0
                if (( blocks_total > 0 )); then
                    proposal_rate=$(echo "scale=4; ${blocks_proposed}/${blocks_total}" | bc)
                fi

                # Prorate the metrics based on validator count
                attestation_published=$(echo "scale=4; ${attestation_published}/${total_validators}" | bc)
                attestation_failed=$(echo "scale=4; ${attestation_failed}/${total_validators}" | bc)
                attestation_total=$(echo "scale=4; ${attestation_total}/${total_validators}" | bc)
                blocks_proposed=$(echo "scale=4; ${blocks_proposed}/${total_validators}" | bc)
                blocks_missed=$(echo "scale=4; ${blocks_missed}/${total_validators}" | bc)
                blocks_total=$(echo "scale=4; ${blocks_total}/${total_validators}" | bc)

                metrics_json=$(cat <<EOF
{
  "attestation_effectiveness": {
    "hits": ${attestation_published},
    "misses": ${attestation_failed},
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

        *)
            log "WARN" "Unsupported client type: ${CLIENT_TYPE}. Unable to collect validator effectiveness metrics."
            metrics_json="{}"
            ;;
    esac

    echo "$metrics_json"
}

# Get rewards for a validator
get_validator_rewards() {
    local pubkey="$1"
    local rewards_json="{}"

    # Try to get rewards from beacon API
    local rewards_data=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/validators/${pubkey}/rewards" || echo '{}')

    # If API doesn't support rewards endpoint, calculate from balance change
    if [[ "$(echo "$rewards_data" | jq -r 'has("data")')" != "true" ]]; then
        local previous_metrics_file="${KEY_METRICS_DIR}/history/$(ls -t "${KEY_METRICS_DIR}/history" | head -n 1)"

        if [[ -f "$previous_metrics_file" ]]; then
            local previous_balance=$(jq -r ".validators.\"${pubkey}\".balance // 0" "$previous_metrics_file")
            local current_balance=$(get_validator_balance "$pubkey")
            local balance_change=$((current_balance - previous_balance))

            rewards_json=$(cat <<EOF
{
  "balance_change": ${balance_change},
  "total_rewards": null,
  "attestation_rewards": null,
  "proposal_rewards": null,
  "sync_committee_rewards": null
}
EOF
            )
        else
            rewards_json=$(cat <<EOF
{
  "balance_change": 0,
  "total_rewards": null,
  "attestation_rewards": null,
  "proposal_rewards": null,
  "sync_committee_rewards": null
}
EOF
            )
        fi
    else
        # Parse the rewards data from the API response
        local total_rewards=$(echo "$rewards_data" | jq -r '.data.total_rewards // 0')
        local attestation_rewards=$(echo "$rewards_data" | jq -r '.data.attestation_rewards // 0')
        local proposal_rewards=$(echo "$rewards_data" | jq -r '.data.proposal_rewards // 0')
        local sync_committee_rewards=$(echo "$rewards_data" | jq -r '.data.sync_committee_rewards // 0')

        rewards_json=$(cat <<EOF
{
  "balance_change": ${total_rewards},
  "total_rewards": ${total_rewards},
  "attestation_rewards": ${attestation_rewards},
  "proposal_rewards": ${proposal_rewards},
  "sync_committee_rewards": ${sync_committee_rewards}
}
EOF
        )
    fi

    echo "$rewards_json"
}

# Analyze validator performance
analyze_validator_performance() {
    local pubkey="$1"
    local status="$2"
    local balance="$3"
    local effectiveness_data="$4"
    local rewards_data="$5"
    local validator_index="$6"
    local analysis_json

    # Extract effectiveness metrics
    local attestation_rate=$(echo "$effectiveness_data" | jq -r '.attestation_effectiveness.rate // 0')
    local proposal_rate=$(echo "$effectiveness_data" | jq -r '.proposal_effectiveness.rate // 0')

    # Extract rewards metrics
    local balance_change=$(echo "$rewards_data" | jq -r '.balance_change // 0')

    # Performance scoring (0-100)
    local attestation_score=$(echo "scale=2; ${attestation_rate} * 100" | bc)
    local proposal_score=$(echo "scale=2; ${proposal_rate} * 100" | bc)

    # Overall performance score (weighted average)
    local overall_score=$(echo "scale=2; (${attestation_score} * 0.7) + (${proposal_score} * 0.3)" | bc)

    # Performance status
    local performance_status="unknown"
    if (( $(echo "$overall_score >= 95" | bc -l) )); then
        performance_status="excellent"
    elif (( $(echo "$overall_score >= 90" | bc -l) )); then
        performance_status="good"
    elif (( $(echo "$overall_score >= 80" | bc -l) )); then
        performance_status="average"
    elif (( $(echo "$overall_score >= 70" | bc -l) )); then
        performance_status="poor"
    else
        performance_status="critical"
    fi

    # Check for alerts
    local alerts=()
    if (( $(echo "$attestation_rate < $ATTESTATION_THRESHOLD" | bc -l) )); then
        alerts+=("Low attestation effectiveness: $(echo "scale=2; ${attestation_rate} * 100" | bc)%")
        log "WARN" "Validator ${pubkey} has low attestation effectiveness: $(echo "scale=2; ${attestation_rate} * 100" | bc)%"
    fi

    if (( $(echo "$proposal_rate < $PROPOSAL_THRESHOLD" | bc -l) )); then
        alerts+=("Low proposal effectiveness: $(echo "scale=2; ${proposal_rate} * 100" | bc)%")
        log "WARN" "Validator ${pubkey} has low proposal effectiveness: $(echo "scale=2; ${proposal_rate} * 100" | bc)%"
    fi

    if (( balance_change < 0 )) && (( $(echo "scale=4; (-1 * ${balance_change}) / ${balance} > ${BALANCE_DECREASE_THRESHOLD}" | bc -l) )); then
        alerts+=("Significant balance decrease: ${balance_change}")
        log "WARN" "Validator ${pubkey} has significant balance decrease: ${balance_change}"
    fi

    analysis_json=$(cat <<EOF
{
  "performance_scores": {
    "attestation_score": ${attestation_score},
    "proposal_score": ${proposal_score},
    "overall_score": ${overall_score}
  },
  "performance_status": "${performance_status}",
  "alerts": $(jq -n --argjson alerts "$(echo "${alerts[@]}" | jq -R -s -c 'split("\n")[:-1]')" '$alerts')
}
EOF
    )

    echo "$analysis_json"
}

# Main function to collect and analyze metrics
collect_metrics() {
    detect_client_type

    local pubkeys=($(get_validator_pubkeys))
    local all_metrics="{}"
    local summary_metrics="{}"

    # Initialize the validators object
    all_metrics=$(echo '{"validators": {}, "summary": {"total_count": 0, "active_count": 0, "total_balance": 0, "performance_status": {}}}' | jq .)

    log "INFO" "Collecting metrics for ${#pubkeys[@]} validators"

    # Performance status counters
    local excellent_count=0
    local good_count=0
    local average_count=0
    local poor_count=0
    local critical_count=0
    local unknown_count=0
    local total_attestation_score=0
    local total_proposal_score=0
    local total_overall_score=0
    local active_count=0
    local total_balance=0

    # Process each validator key
    for pubkey in "${pubkeys[@]}"; do
        log "INFO" "Processing validator ${pubkey}"

        # Get basic validator info
        local status=$(get_validator_status "$pubkey")
        local balance=$(get_validator_balance "$pubkey")
        local validator_index=$(get_validator_index "$pubkey")

        # Get performance metrics
        local effectiveness_data=$(get_validator_effectiveness "$validator_index")
        local rewards_data=$(get_validator_rewards "$pubkey")

        # Analyze performance
        local analysis_data=$(analyze_validator_performance "$pubkey" "$status" "$balance" "$effectiveness_data" "$rewards_data" "$validator_index")

        # Update counters for summary
        if [[ "$status" == "active" || "$status" == "active_ongoing" || "$status" == "active_exiting" ]]; then
            ((active_count++))
            total_balance=$((total_balance + balance))

            # Extract scores for calculating averages
            local attestation_score=$(echo "$analysis_data" | jq -r '.performance_scores.attestation_score')
            local proposal_score=$(echo "$analysis_data" | jq -r '.performance_scores.proposal_score')
            local overall_score=$(echo "$analysis_data" | jq -r '.performance_scores.overall_score')
            local performance_status=$(echo "$analysis_data" | jq -r '.performance_status')

            total_attestation_score=$(echo "${total_attestation_score} + ${attestation_score}" | bc)
            total_proposal_score=$(echo "${total_proposal_score} + ${proposal_score}" | bc)
            total_overall_score=$(echo "${total_overall_score} + ${overall_score}" | bc)

            # Increment the appropriate counter
            case "$performance_status" in
                "excellent") ((excellent_count++)) ;;
                "good") ((good_count++)) ;;
                "average") ((average_count++)) ;;
                "poor") ((poor_count++)) ;;
                "critical") ((critical_count++)) ;;
                *) ((unknown_count++)) ;;
            esac
        fi

        # Create the validator metrics JSON
        local validator_json=$(cat <<EOF
{
  "pubkey": "${pubkey}",
  "index": "${validator_index}",
  "status": "${status}",
  "balance": ${balance},
  "effectiveness": ${effectiveness_data},
  "rewards": ${rewards_data},
  "analysis": ${analysis_data},
  "last_updated": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF
        )

        # Add to the all_metrics object
        all_metrics=$(echo "$all_metrics" | jq --arg pubkey "$pubkey" --argjson validator "$validator_json" '.validators[$pubkey] = $validator')
    done

    # Calculate averages
    local avg_attestation_score=0
    local avg_proposal_score=0
    local avg_overall_score=0

    if [[ $active_count -gt 0 ]]; then
        avg_attestation_score=$(echo "scale=2; ${total_attestation_score} / ${active_count}" | bc)
        avg_proposal_score=$(echo "scale=2; ${total_proposal_score} / ${active_count}" | bc)
        avg_overall_score=$(echo "scale=2; ${total_overall_score} / ${active_count}" | bc)
    fi

    # Create the summary JSON
    local summary_json=$(cat <<EOF
{
  "total_count": ${#pubkeys[@]},
  "active_count": ${active_count},
  "total_balance": ${total_balance},
  "avg_balance": $(if [[ $active_count -gt 0 ]]; then echo "scale=2; ${total_balance} / ${active_count}" | bc; else echo 0; fi),
  "performance_status": {
    "excellent": ${excellent_count},
    "good": ${good_count},
    "average": ${average_count},
    "poor": ${poor_count},
    "critical": ${critical_count},
    "unknown": ${unknown_count}
  },
  "avg_scores": {
    "attestation_score": ${avg_attestation_score},
    "proposal_score": ${avg_proposal_score},
    "overall_score": ${avg_overall_score}
  },
  "last_updated": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF
    )

    # Update the summary section
    all_metrics=$(echo "$all_metrics" | jq --argjson summary "$summary_json" '.summary = $summary')

    # Write metrics to file
    echo "$all_metrics" > "${METRICS_OUTPUT}"
    echo "$summary_json" > "${METRICS_SUMMARY}"
    cp "${METRICS_OUTPUT}" "${METRICS_HISTORY}"

    # Clean up old history files (keep only the last X days)
    find "${HISTORY_DIR}" -type f -name "key_metrics_*.json" -mtime +${RETENTION_DAYS} -delete

    log "INFO" "Metrics collection completed successfully"

    # Output summary to stdout
    echo "$summary_json" | jq .
}

# Export metrics to Prometheus format
export_to_prometheus() {
    if [[ ! -f "${METRICS_OUTPUT}" ]]; then
        log "ERROR" "Metrics file not found: ${METRICS_OUTPUT}"
        return 1
    fi

    local prom_dir="${METRICS_DIR}/prometheus"
    mkdir -p "${prom_dir}"
    local prom_file="${prom_dir}/key_metrics.prom"

    log "INFO" "Exporting metrics to Prometheus format at ${prom_file}"

    # Create the Prometheus file
    cat > "${prom_file}" <<EOF
# HELP validator_key_count Total number of validator keys
# TYPE validator_key_count gauge
validator_key_count $(jq -r '.summary.total_count' "${METRICS_OUTPUT}")

# HELP validator_active_count Number of active validator keys
# TYPE validator_active_count gauge
validator_active_count $(jq -r '.summary.active_count' "${METRICS_OUTPUT}")

# HELP validator_total_balance Total balance of all active validators (in Gwei)
# TYPE validator_total_balance gauge
validator_total_balance $(jq -r '.summary.total_balance' "${METRICS_OUTPUT}")

# HELP validator_avg_balance Average balance per active validator (in Gwei)
# TYPE validator_avg_balance gauge
validator_avg_balance $(jq -r '.summary.avg_balance' "${METRICS_OUTPUT}")

# HELP validator_avg_attestation_score Average attestation score across all validators (0-100)
# TYPE validator_avg_attestation_score gauge
validator_avg_attestation_score $(jq -r '.summary.avg_scores.attestation_score' "${METRICS_OUTPUT}")

# HELP validator_avg_proposal_score Average proposal score across all validators (0-100)
# TYPE validator_avg_proposal_score gauge
validator_avg_proposal_score $(jq -r '.summary.avg_scores.proposal_score' "${METRICS_OUTPUT}")

# HELP validator_avg_overall_score Average overall performance score across all validators (0-100)
# TYPE validator_avg_overall_score gauge
validator_avg_overall_score $(jq -r '.summary.avg_scores.overall_score' "${METRICS_OUTPUT}")

# HELP validator_performance_status Number of validators in each performance status category
# TYPE validator_performance_status gauge
validator_performance_status{status="excellent"} $(jq -r '.summary.performance_status.excellent' "${METRICS_OUTPUT}")
validator_performance_status{status="good"} $(jq -r '.summary.performance_status.good' "${METRICS_OUTPUT}")
validator_performance_status{status="average"} $(jq -r '.summary.performance_status.average' "${METRICS_OUTPUT}")
validator_performance_status{status="poor"} $(jq -r '.summary.performance_status.poor' "${METRICS_OUTPUT}")
validator_performance_status{status="critical"} $(jq -r '.summary.performance_status.critical' "${METRICS_OUTPUT}")
validator_performance_status{status="unknown"} $(jq -r '.summary.performance_status.unknown' "${METRICS_OUTPUT}")

# Individual validator metrics
EOF

    # Add individual validator metrics
    jq -r '.validators | to_entries[] | @text "#HELP validator_balance_\(.key) Balance for validator \(.key) (in Gwei)\n#TYPE validator_balance_\(.key) gauge\nvalidator_balance{pubkey=\"\(.key)\"} \(.value.balance)\n\n#HELP validator_attestation_score_\(.key) Attestation score for validator \(.key) (0-100)\n#TYPE validator_attestation_score_\(.key) gauge\nvalidator_attestation_score{pubkey=\"\(.key)\"} \(.value.analysis.performance_scores.attestation_score)\n\n#HELP validator_proposal_score_\(.key) Proposal score for validator \(.key) (0-100)\n#TYPE validator_proposal_score_\(.key) gauge\nvalidator_proposal_score{pubkey=\"\(.key)\"} \(.value.analysis.performance_scores.proposal_score)\n\n#HELP validator_overall_score_\(.key) Overall performance score for validator \(.key) (0-100)\n#TYPE validator_overall_score_\(.key) gauge\nvalidator_overall_score{pubkey=\"\(.key)\"} \(.value.analysis.performance_scores.overall_score)"' "${METRICS_OUTPUT}" >> "${prom_file}"

    log "INFO" "Exported metrics to Prometheus format successfully"
}

# Run the main functions
collect_metrics
export_to_prometheus

log "INFO" "Key performance metrics collection completed"
echo "Metrics available at: ${METRICS_OUTPUT}"
echo "Summary available at: ${METRICS_SUMMARY}"
echo "Prometheus metrics available at: ${METRICS_DIR}/prometheus/key_metrics.prom"
