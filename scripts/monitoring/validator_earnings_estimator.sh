#!/bin/bash
# Version: 1.0.0
#
# Validator Earnings Estimator Script
# ===================================
# This script estimates validator earnings based on performance metrics,
# calculates expected vs actual rewards, and provides earnings forecasts.

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
EARNINGS_DIR="${METRICS_DIR}/earnings"
VALIDATOR_KEYS_DIR="${BASE_DIR}/secrets/validator/keys"
BEACON_NODE_ENDPOINT=${BEACON_NODE_ENDPOINT:-"http://localhost:5052"}
EARNINGS_OUTPUT="${EARNINGS_DIR}/validator_earnings.json"
EARNINGS_HISTORY="${EARNINGS_DIR}/history/validator_earnings_$(date +%Y%m%d_%H%M%S).json"
VALIDATOR_METRICS="${METRICS_DIR}/validator_metrics.json"

# Network parameters - these would differ for different networks
EPOCHS_PER_DAY=225  # ~32 seconds per slot, 32 slots per epoch
BASE_REWARD_FACTOR=64  # Beacon chain parameter
EFFECTIVE_BALANCE=32000000000  # 32 ETH in gwei
SLOTS_PER_EPOCH=32
SECONDS_PER_SLOT=12

# Ensure directories exist
mkdir -p "${EARNINGS_DIR}" "${EARNINGS_DIR}/history" "${LOG_DIR}"

# Function to get the current network parameters
get_network_params() {
    # Attempt to get actual network parameters from the beacon node
    # Only for non-ephemery networks, as ephemery uses default values

    # For ephemery, we'll use default values for simplicity
    # In a production environment, these would be queried from the beacon node
    local network_json=$(cat <<EOF
{
  "base_reward_factor": ${BASE_REWARD_FACTOR},
  "effective_balance": ${EFFECTIVE_BALANCE},
  "slots_per_epoch": ${SLOTS_PER_EPOCH},
  "seconds_per_slot": ${SECONDS_PER_SLOT}
}
EOF
    )

    echo "${network_json}"
}

# Get validator public keys and their indices
get_validator_indices() {
    local pubkeys=()
    local indices=()
    local combined_result="[]"

    # Get list of validator keyfiles
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

                # Get validator index from beacon node
                local index_json
                index_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${pubkey}" \
                    -H "Accept: application/json" || echo '{"data":{"index":"unknown"}}')

                local index=$(echo "${index_json}" | grep -o '"index":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
                indices+=("${index}")
            fi
        fi
    done

    # Build combined JSON array
    if [[ ${#pubkeys[@]} -gt 0 ]]; then
        combined_result="["
        for i in "${!pubkeys[@]}"; do
            combined_result+="{\"pubkey\":\"${pubkeys[${i}]}\",\"index\":\"${indices[${i}}\"}"
            if [[ ${i} -lt $((${#pubkeys[@]} - 1)) ]]; then
                combined_result+=", "
            fi
        done
        combined_result+="]"
    fi

    echo "${combined_result}"
}

# Get historical balance data for validators
get_historical_balances() {
    local validators_json="$1"
    local balances_json="[]"

    # Extract validator indices
    local indices=()
    while IFS= read -r line; do
        indices+=("${line}")
    done < <(echo "${validators_json}" | grep -o '"index":"[^"]*"' | cut -d'"' -f4)

    # Get current and historical balance data
    if [[ ${#indices[@]} -gt 0 ]]; then
        balances_json="["
        for i in "${!indices[@]}"; do
            local index="${indices[${i}]}"

            # Get current balance
            local current_balance_json
            current_balance_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head/validators/${index}" \
                -H "Accept: application/json" || echo '{"data":{"balance":"0"}}')

            local current_balance=$(echo "${current_balance_json}" | grep -o '"balance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")

            # Get historical balances from saved metrics
            local historical_balances=()
            local historical_balances_json="[]"

            # Find the 5 most recent validator metrics files
            mapfile -t history_files < <(find "${HISTORY_DIR}" -name "validator_metrics_*.json" -type f -printf "%T@ %p\n" | sort -nr | head -n 5 | cut -d' ' -f2-)

            if [[ ${#history_files[@]} -gt 0 ]]; then
                historical_balances_json="["
                for j in "${!history_files[@]}"; do
                    local history_file="${history_files[${j}]}"
                    if [[ -f "${history_file}" ]]; then
                        # Extract timestamp and balance from historical file
                        local timestamp=$(grep -o '"timestamp":[[:space:]]*"[^"]*"' "${history_file}" | cut -d'"' -f4 || echo "unknown")

                        # Extract balance for this validator
                        local balance=0
                        if grep -q "\"pubkey\":\"${indices[${i}]}\"" "${history_file}"; then
                            balance=$(grep -A 3 "\"pubkey\":\"${indices[${i}]}\"" "${history_file}" | grep -o '"balance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
                        fi

                        historical_balances_json+="{\"timestamp\":\"${timestamp}\",\"balance\":\"${balance}\"}"
                        if [[ ${j} -lt $((${#history_files[@]} - 1)) ]]; then
                            historical_balances_json+=", "
                        fi
                    fi
                done
                historical_balances_json+="]"
            fi

            balances_json+="{\"index\":\"${index}\",\"current_balance\":\"${current_balance}\",\"historical_balances\":${historical_balances_json}}"
            if [[ ${i} -lt $((${#indices[@]} - 1)) ]]; then
                balances_json+=", "
            fi
        done
        balances_json+="]"
    fi

    echo "${balances_json}"
}

# Calculate expected rewards based on network parameters and validator effectiveness
calculate_expected_rewards() {
    local validator_metrics_json="$1"
    local network_params_json="$2"

    # Extract validator effectiveness metrics
    local attestation_rate=$(echo "${validator_metrics_json}" | grep -o '"attestation_effectiveness":[^}]*' | grep -o '"rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local proposal_rate=$(echo "${validator_metrics_json}" | grep -o '"proposal_effectiveness":[^}]*' | grep -o '"rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Extract network parameters
    local base_reward_factor=$(echo "${network_params_json}" | grep -o '"base_reward_factor":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${BASE_REWARD_FACTOR}")
    local effective_balance=$(echo "${network_params_json}" | grep -o '"effective_balance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${EFFECTIVE_BALANCE}")

    # Calculate base reward per epoch
    # Base reward = effective_balance * base_reward_factor / sqrt(total_active_balance) / BASE_REWARDS_PER_EPOCH
    # For simplicity, we'll use an approximation based on current network conditions
    local base_reward=32000000  # ~32000 gwei per epoch - simplified for estimation

    # Calculate expected rewards based on performance
    local daily_epochs=${EPOCHS_PER_DAY}

    # Attestation rewards (simplified model)
    # Perfect attestation = ~97% of total rewards
    local perfect_attestation_reward=$((base_reward * 31 / 32))  # ~97% of base reward
    local expected_attestation_reward=$(echo "scale=0; ${perfect_attestation_reward} * ${attestation_rate}" | bc)
    local daily_attestation_reward=$((expected_attestation_reward * daily_epochs))

    # Proposal rewards (simplified model)
    # Proposals are rare but valuable, ~1 proposal every ~8 days for each validator
    # Perfect proposal = ~3% of total rewards when they occur
    local proposal_chance=$(echo "scale=10; 1 / (${daily_epochs} * 8)" | bc)  # Chance of proposal per epoch
    local perfect_proposal_reward=$((base_reward * 1 / 32))  # ~3% of base reward
    local expected_proposal_reward=$(echo "scale=0; ${perfect_proposal_reward} * ${proposal_rate} * ${proposal_chance} * ${daily_epochs}" | bc)

    # Total daily expected reward in gwei
    local daily_expected_reward=$((daily_attestation_reward + expected_proposal_reward))

    # Convert to ETH for readability
    local daily_expected_reward_eth=$(echo "scale=6; ${daily_expected_reward} / 1000000000" | bc)
    local monthly_expected_reward_eth=$(echo "scale=6; ${daily_expected_reward_eth} * 30" | bc)
    local annual_expected_reward_eth=$(echo "scale=6; ${daily_expected_reward_eth} * 365" | bc)

    # Calculate APR
    local apr=$(echo "scale=2; (${annual_expected_reward_eth} / 32) * 100" | bc)

    # Format results as JSON
    local rewards_json=$(cat <<EOF
{
  "daily_reward_gwei": ${daily_expected_reward},
  "daily_reward_eth": ${daily_expected_reward_eth},
  "monthly_reward_eth": ${monthly_expected_reward_eth},
  "annual_reward_eth": ${annual_expected_reward_eth},
  "estimated_apr": ${apr},
  "parameters": {
    "attestation_rate": ${attestation_rate},
    "proposal_rate": ${proposal_rate},
    "base_reward_gwei": ${base_reward},
    "daily_epochs": ${daily_epochs}
  }
}
EOF
    )

    echo "${rewards_json}"
}

# Compare expected vs actual rewards
compare_rewards() {
    local expected_rewards_json="$1"
    local balances_json="$2"

    local expected_daily_gwei=$(echo "${expected_rewards_json}" | grep -o '"daily_reward_gwei":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Calculate actual rewards from historical balances
    local actual_rewards_json="[]"

    # Extract balances array
    local balances_array=$(echo "${balances_json}" | grep -o '\[.*\]' || echo "[]")

    if [[ "${balances_array}" != "[]" ]]; then
        # Get counts of validators to calculate average
        local validator_count=$(echo "${balances_json}" | grep -o '"index"' | wc -l)

        # Look at first validator's historical balances for timestamps
        local historical_timestamps=$(echo "${balances_json}" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || echo "")

        # Parse timestamps and calculate daily change
        local prev_date=""
        local prev_total_balance=0

        actual_rewards_json="["

        # Process each validator's balances and calculate daily changes
        local first_entry=true
        while IFS= read -r timestamp; do
            if [[ -n "${timestamp}" ]]; then
                local date=$(echo "${timestamp}" | cut -d'T' -f1)

                if [[ "${date}" != "${prev_date}" && -n "${prev_date}" ]]; then
                    # Calculate total balance for this date
                    local total_balance=0
                    while IFS= read -r balance; do
                        total_balance=$((total_balance + balance))
                    done < <(grep -A 5 "\"timestamp\":\"${timestamp}\"" "${balances_json}" | grep -o '"balance":"[^"]*"' | cut -d'"' -f4)

                    # Calculate daily change
                    local daily_change=$((total_balance - prev_total_balance))

                    # Calculate average change per validator in gwei
                    local avg_daily_change=0
                    if [[ ${validator_count} -gt 0 ]]; then
                        avg_daily_change=$((daily_change / validator_count))
                    fi

                    # Convert to ETH
                    local avg_daily_change_eth=$(echo "scale=6; ${avg_daily_change} / 1000000000" | bc)

                    # Add to JSON array
                    if [[ "${first_entry}" == "false" ]]; then
                        actual_rewards_json+=", "
                    fi
                    first_entry=false

                    actual_rewards_json+="{\"date\":\"${date}\",\"avg_reward_gwei\":${avg_daily_change},\"avg_reward_eth\":${avg_daily_change_eth}}"

                    # Update for next iteration
                    prev_total_balance=${total_balance}
                fi

                # Update previous date
                if [[ -z "${prev_date}" ]]; then
                    # Initialize prev_total_balance for first entry
                    while IFS= read -r balance; do
                        prev_total_balance=$((prev_total_balance + balance))
                    done < <(grep -A 5 "\"timestamp\":\"${timestamp}\"" "${balances_json}" | grep -o '"balance":"[^"]*"' | cut -d'"' -f4)
                fi
                prev_date=${date}
            fi
        done < <(echo "${historical_timestamps}")

        actual_rewards_json+="]"
    fi

    # Calculate average actual daily reward if enough data points
    local avg_actual_daily_gwei=0
    local avg_actual_daily_eth=0
    local comparison_percent=0

    local actual_count=$(echo "${actual_rewards_json}" | grep -o '"avg_reward_gwei"' | wc -l)

    if [[ ${actual_count} -gt 0 ]]; then
        local total_actual_gwei=0
        while IFS= read -r reward; do
            total_actual_gwei=$((total_actual_gwei + reward))
        done < <(echo "${actual_rewards_json}" | grep -o '"avg_reward_gwei":[[:space:]]*[0-9-]*' | cut -d':' -f2 | tr -d ' ')

        avg_actual_daily_gwei=$((total_actual_gwei / actual_count))
        avg_actual_daily_eth=$(echo "scale=6; ${avg_actual_daily_gwei} / 1000000000" | bc)

        # Compare expected vs actual
        if [[ ${expected_daily_gwei} -gt 0 ]]; then
            comparison_percent=$(echo "scale=2; (${avg_actual_daily_gwei} / ${expected_daily_gwei}) * 100" | bc)
        fi
    fi

    # Format comparison JSON
    local comparison_json=$(cat <<EOF
{
  "expected_daily_gwei": ${expected_daily_gwei},
  "avg_actual_daily_gwei": ${avg_actual_daily_gwei},
  "avg_actual_daily_eth": ${avg_actual_daily_eth},
  "comparison_percent": ${comparison_percent},
  "data_points": ${actual_count},
  "daily_history": ${actual_rewards_json}
}
EOF
    )

    echo "${comparison_json}"
}

# Create earnings forecast for different performance scenarios
create_forecast() {
    local expected_rewards_json="$1"
    local comparison_json="$2"

    # Extract base values from expected rewards
    local base_daily_reward_eth=$(echo "${expected_rewards_json}" | grep -o '"daily_reward_eth":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local base_annual_reward_eth=$(echo "${expected_rewards_json}" | grep -o '"annual_reward_eth":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local base_apr=$(echo "${expected_rewards_json}" | grep -o '"estimated_apr":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")

    # Create scenarios (optimal, expected, current, degraded)
    local optimal_effectiveness=0.99
    local expected_effectiveness=0.95
    local current_effectiveness=$(echo "${expected_rewards_json}" | grep -o '"attestation_rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local degraded_effectiveness=0.8

    # Calculate rewards for each scenario
    local optimal_daily=$(echo "scale=6; ${base_daily_reward_eth} * (${optimal_effectiveness} / ${current_effectiveness})" | bc)
    local optimal_annual=$(echo "scale=6; ${optimal_daily} * 365" | bc)
    local optimal_apr=$(echo "scale=2; (${optimal_annual} / 32) * 100" | bc)

    local expected_daily=$(echo "scale=6; ${base_daily_reward_eth} * (${expected_effectiveness} / ${current_effectiveness})" | bc)
    local expected_annual=$(echo "scale=6; ${expected_daily} * 365" | bc)
    local expected_apr=$(echo "scale=2; (${expected_annual} / 32) * 100" | bc)

    local current_daily=${base_daily_reward_eth}
    local current_annual=${base_annual_reward_eth}
    local current_apr=${base_apr}

    local degraded_daily=$(echo "scale=6; ${base_daily_reward_eth} * (${degraded_effectiveness} / ${current_effectiveness})" | bc)
    local degraded_annual=$(echo "scale=6; ${degraded_daily} * 365" | bc)
    local degraded_apr=$(echo "scale=2; (${degraded_annual} / 32) * 100" | bc)

    # Format forecast JSON
    local forecast_json=$(cat <<EOF
{
  "scenarios": {
    "optimal": {
      "effectiveness": ${optimal_effectiveness},
      "daily_reward_eth": ${optimal_daily},
      "annual_reward_eth": ${optimal_annual},
      "estimated_apr": ${optimal_apr}
    },
    "expected": {
      "effectiveness": ${expected_effectiveness},
      "daily_reward_eth": ${expected_daily},
      "annual_reward_eth": ${expected_annual},
      "estimated_apr": ${expected_apr}
    },
    "current": {
      "effectiveness": ${current_effectiveness},
      "daily_reward_eth": ${current_daily},
      "annual_reward_eth": ${current_annual},
      "estimated_apr": ${current_apr}
    },
    "degraded": {
      "effectiveness": ${degraded_effectiveness},
      "daily_reward_eth": ${degraded_daily},
      "annual_reward_eth": ${degraded_annual},
      "estimated_apr": ${degraded_apr}
    }
  },
  "time_to_roi_days": {
    "optimal": $(echo "scale=0; 32 / ${optimal_daily}" | bc),
    "expected": $(echo "scale=0; 32 / ${expected_daily}" | bc),
    "current": $(echo "scale=0; 32 / ${current_daily}" | bc),
    "degraded": $(echo "scale=0; 32 / ${degraded_daily}" | bc)
  }
}
EOF
    )

    echo "${forecast_json}"
}

# Main function to collect and analyze earnings data
main() {
    echo "Starting validator earnings estimation at $(date)"

    # Get network parameters
    local network_params=$(get_network_params)

    # Get validator indices
    local validators=$(get_validator_indices)

    # Get validator historical balances
    local balances=$(get_historical_balances "${validators}")

    # Check if validator metrics file exists
    if [[ ! -f "${VALIDATOR_METRICS}" ]]; then
        echo "Validator metrics file not found at ${VALIDATOR_METRICS}"
        echo "Please run the validator_performance_monitor.sh script first"
        exit 1
    fi

    # Read validator metrics
    local validator_metrics=$(cat "${VALIDATOR_METRICS}")

    # Calculate expected rewards
    local expected_rewards=$(calculate_expected_rewards "${validator_metrics}" "${network_params}")

    # Compare expected vs actual rewards
    local comparison=$(compare_rewards "${expected_rewards}" "${balances}")

    # Create earnings forecast
    local forecast=$(create_forecast "${expected_rewards}" "${comparison}")

    # Combine all data into one JSON object
    local combined_json=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network_params": ${network_params},
  "expected_rewards": ${expected_rewards},
  "actual_vs_expected": ${comparison},
  "forecast": ${forecast}
}
EOF
    )

    # Save to files
    echo "${combined_json}" > "${EARNINGS_OUTPUT}"
    echo "${combined_json}" > "${EARNINGS_HISTORY}"

    # Print summary
    echo "Validator earnings estimation completed at $(date)"
    echo "Results saved to ${EARNINGS_OUTPUT}"

    # Output a brief summary to the console
    local daily_eth=$(echo "${expected_rewards}" | grep -o '"daily_reward_eth":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')
    local annual_eth=$(echo "${expected_rewards}" | grep -o '"annual_reward_eth":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')
    local apr=$(echo "${expected_rewards}" | grep -o '"estimated_apr":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')

    echo "--------------------------------------------------"
    echo "Validator Earnings Summary"
    echo "--------------------------------------------------"
    echo "Estimated daily reward: ${daily_eth} ETH"
    echo "Estimated annual reward: ${annual_eth} ETH"
    echo "Estimated APR: ${apr}%"
    echo "--------------------------------------------------"
}

# Run the main function
main
