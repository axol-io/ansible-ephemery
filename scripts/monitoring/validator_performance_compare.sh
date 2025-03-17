#!/bin/bash
# Version: 1.0.0
#
# Validator Performance Comparison Script
# =======================================
# This script compares validator performance against network averages
# and other validators to identify performance trends and outliers.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=${BASE_DIR:-"/root/ephemery"}
CONFIG_DIR="${BASE_DIR}/config"
DATA_DIR="${BASE_DIR}/data"
LOG_DIR="${BASE_DIR}/logs"
METRICS_DIR="${DATA_DIR}/metrics"
HISTORY_DIR="${METRICS_DIR}/history"
COMPARISON_DIR="${METRICS_DIR}/comparisons"
VALIDATOR_METRICS="${METRICS_DIR}/validator_metrics.json"
EARNINGS_DATA="${METRICS_DIR}/earnings/validator_earnings.json"
COMPARISON_OUTPUT="${COMPARISON_DIR}/validator_comparison.json"
COMPARISON_HISTORY="${COMPARISON_DIR}/history/validator_comparison_$(date +%Y%m%d_%H%M%S).json"
BEACON_NODE_ENDPOINT=${BEACON_NODE_ENDPOINT:-"http://localhost:5052"}
NETWORK_DATA_API=${NETWORK_DATA_API:-"https://beaconcha.in/api/v1/epoch/latest"}

# Ensure directories exist
mkdir -p "${COMPARISON_DIR}/history" "${LOG_DIR}"

# Function to get the current network statistics
get_network_stats() {
    local network_stats
    
    # Try to get data from external API
    if network_stats=$(curl -s "${NETWORK_DATA_API}" 2>/dev/null); then
        echo "Retrieved network statistics from external API"
    else
        # Fallback to local estimation
        local network_state
        network_state=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/beacon/states/head" -H "Accept: application/json" 2>/dev/null)
        if [[ -z "${network_state}" ]]; then
            echo "Error: Failed to retrieve network statistics. Using default values."
            network_stats=$(cat <<EOF
{
  "data": {
    "validatorscount": 0,
    "averagevalidatorbalance": 32000000000,
    "averagevalidatoreffectiveness": 0.95,
    "participation_rate": 0.95
  }
}
EOF
            )
        else
            # Extract validator count from state
            local validator_count=$(echo "${network_state}" | grep -o '"validator_count":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
            
            # Use conservative estimates for other values
            network_stats=$(cat <<EOF
{
  "data": {
    "validatorscount": ${validator_count:-0},
    "averagevalidatorbalance": 32000000000,
    "averagevalidatoreffectiveness": 0.95,
    "participation_rate": 0.95
  }
}
EOF
            )
        fi
    fi
    
    echo "${network_stats}"
}

# Function to get local validator performance data
get_local_validator_performance() {
    local validator_metrics_json
    local earnings_json
    
    # Get validator metrics
    if [[ -f "${VALIDATOR_METRICS}" ]]; then
        validator_metrics_json=$(cat "${VALIDATOR_METRICS}")
    else
        echo "Error: Validator metrics file not found at ${VALIDATOR_METRICS}"
        validator_metrics_json="{}"
    fi
    
    # Get earnings data
    if [[ -f "${EARNINGS_DATA}" ]]; then
        earnings_json=$(cat "${EARNINGS_DATA}")
    else
        echo "Warning: Earnings data file not found at ${EARNINGS_DATA}"
        earnings_json="{}"
    fi
    
    # Extract key metrics
    local attestation_rate=$(echo "${validator_metrics_json}" | grep -o '"attestation_effectiveness":[^}]*' | grep -o '"rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local proposal_rate=$(echo "${validator_metrics_json}" | grep -o '"proposal_effectiveness":[^}]*' | grep -o '"rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local validator_count=$(echo "${validator_metrics_json}" | grep -o '"validator_count":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    
    # Extract validators data
    local validators_array=$(echo "${validator_metrics_json}" | grep -o '"validators":[[:space:]]*\[.*\]' | sed 's/"validators":[[:space:]]*\(.*\)/\1/' || echo "[]")
    
    # Calculate average balance from validators array
    local total_balance=0
    local balance_count=0
    
    while IFS= read -r balance; do
        if [[ -n "${balance}" ]]; then
            total_balance=$((total_balance + balance))
            ((balance_count++))
        fi
    done < <(echo "${validators_array}" | grep -o '"balance":"[^"]*"' | cut -d'"' -f4)
    
    local avg_balance=0
    if [[ ${balance_count} -gt 0 ]]; then
        avg_balance=$((total_balance / balance_count))
    fi
    
    # Extract APR from earnings data
    local estimated_apr=$(echo "${earnings_json}" | grep -o '"estimated_apr":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    
    # Format local performance data
    local performance_json=$(cat <<EOF
{
  "validator_count": ${validator_count},
  "attestation_rate": ${attestation_rate},
  "proposal_rate": ${proposal_rate},
  "average_balance": ${avg_balance},
  "estimated_apr": ${estimated_apr}
}
EOF
    )
    
    echo "${performance_json}"
}

# Compare local performance with network averages
compare_with_network() {
    local local_performance="$1"
    local network_stats="$2"
    
    # Extract local metrics
    local local_attestation_rate=$(echo "${local_performance}" | grep -o '"attestation_rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local local_proposal_rate=$(echo "${local_performance}" | grep -o '"proposal_rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local local_avg_balance=$(echo "${local_performance}" | grep -o '"average_balance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    local local_estimated_apr=$(echo "${local_performance}" | grep -o '"estimated_apr":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    
    # Extract network metrics
    local network_avg_balance=$(echo "${network_stats}" | grep -o '"averagevalidatorbalance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "32000000000")
    local network_effectiveness=$(echo "${network_stats}" | grep -o '"averagevalidatoreffectiveness":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0.95")
    local network_participation=$(echo "${network_stats}" | grep -o '"participation_rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0.95")
    
    # Convert to percentages for easier comparison
    local local_attestation_percent=$(echo "scale=2; ${local_attestation_rate} * 100" | bc)
    local local_proposal_percent=$(echo "scale=2; ${local_proposal_rate} * 100" | bc)
    local network_effectiveness_percent=$(echo "scale=2; ${network_effectiveness} * 100" | bc)
    local network_participation_percent=$(echo "scale=2; ${network_participation} * 100" | bc)
    
    # Calculate balance ratio (local vs. network)
    local balance_ratio=0
    if [[ ${network_avg_balance} -gt 0 ]]; then
        balance_ratio=$(echo "scale=4; ${local_avg_balance} / ${network_avg_balance}" | bc)
    fi
    local balance_percent=$(echo "scale=2; ${balance_ratio} * 100" | bc)
    
    # Calculate effectiveness difference (local vs. network)
    local attestation_diff=$(echo "scale=2; ${local_attestation_percent} - ${network_effectiveness_percent}" | bc)
    local participation_diff=$(echo "scale=2; ${local_attestation_percent} - ${network_participation_percent}" | bc)
    
    # Generate comparison metrics
    local comparison_json=$(cat <<EOF
{
  "attestation": {
    "local_rate": ${local_attestation_rate},
    "local_percent": ${local_attestation_percent},
    "network_rate": ${network_effectiveness},
    "network_percent": ${network_effectiveness_percent},
    "difference": ${attestation_diff},
    "performance_category": $(if (( $(echo "${attestation_diff} > 0" | bc -l) )); then echo "\"above_average\""; elif (( $(echo "${attestation_diff} < -2" | bc -l) )); then echo "\"needs_improvement\""; else echo "\"average\""; fi)
  },
  "participation": {
    "local_rate": ${local_attestation_rate},
    "local_percent": ${local_attestation_percent},
    "network_rate": ${network_participation},
    "network_percent": ${network_participation_percent},
    "difference": ${participation_diff},
    "performance_category": $(if (( $(echo "${participation_diff} > 0" | bc -l) )); then echo "\"above_average\""; elif (( $(echo "${participation_diff} < -2" | bc -l) )); then echo "\"needs_improvement\""; else echo "\"average\""; fi)
  },
  "balance": {
    "local_balance": ${local_avg_balance},
    "network_balance": ${network_avg_balance},
    "ratio": ${balance_ratio},
    "percent_of_network": ${balance_percent},
    "performance_category": $(if (( $(echo "${balance_ratio} > 1.02" | bc -l) )); then echo "\"above_average\""; elif (( $(echo "${balance_ratio} < 0.98" | bc -l) )); then echo "\"needs_improvement\""; else echo "\"average\""; fi)
  },
  "apr": {
    "local_apr": ${local_estimated_apr},
    "network_apr": $(echo "scale=2; (0.06 * 100)" | bc),
    "performance_category": $(if (( $(echo "${local_estimated_apr} > 6" | bc -l) )); then echo "\"above_average\""; elif (( $(echo "${local_estimated_apr} < 5" | bc -l) )); then echo "\"needs_improvement\""; else echo "\"average\""; fi)
  }
}
EOF
    )
    
    echo "${comparison_json}"
}

# Analyze historical performance trends
analyze_trends() {
    local trend_analysis="{}"
    
    # Find historical comparison files
    mapfile -t history_files < <(find "${COMPARISON_DIR}/history" -name "validator_comparison_*.json" -type f -printf "%T@ %p\n" | sort -nr | head -n 10 | cut -d' ' -f2-)
    
    if [[ ${#history_files[@]} -gt 2 ]]; then
        # Extract attestation rates over time
        local timestamps=()
        local attestation_rates=()
        local balance_values=()
        
        for history_file in "${history_files[@]}"; do
            if [[ -f "${history_file}" ]]; then
                # Extract timestamp from filename
                local file_timestamp=$(basename "${history_file}" | sed -E 's/validator_comparison_([0-9]{8})_([0-9]{6})\.json/\1\2/')
                timestamps+=("${file_timestamp}")
                
                # Extract attestation rate
                local att_rate=$(grep -o '"attestation":[^}]*"local_rate":[[:space:]]*[0-9.]*' "${history_file}" | grep -o '"local_rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
                attestation_rates+=("${att_rate}")
                
                # Extract balance
                local balance=$(grep -o '"balance":[^}]*"local_balance":[[:space:]]*[0-9]*' "${history_file}" | grep -o '"local_balance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
                balance_values+=("${balance}")
            fi
        done
        
        # Calculate trends
        local attestation_trend="stable"
        local balance_trend="stable"
        
        # Simple trend detection - compare first and last values
        if [[ ${#attestation_rates[@]} -gt 1 ]]; then
            local first_rate=${attestation_rates[-1]}
            local last_rate=${attestation_rates[0]}
            
            if (( $(echo "${last_rate} > (${first_rate} + 0.02)" | bc -l) )); then
                attestation_trend="improving"
            elif (( $(echo "${last_rate} < (${first_rate} - 0.02)" | bc -l) )); then
                attestation_trend="declining"
            fi
        fi
        
        if [[ ${#balance_values[@]} -gt 1 ]]; then
            local first_balance=${balance_values[-1]}
            local last_balance=${balance_values[0]}
            local balance_change=$((last_balance - first_balance))
            
            if (( balance_change > 10000000 )); then  # More than 0.01 ETH increase
                balance_trend="increasing"
            elif (( balance_change < -10000000 )); then  # More than 0.01 ETH decrease
                balance_trend="decreasing"
            fi
        fi
        
        # Format trend analysis as JSON
        trend_analysis=$(cat <<EOF
{
  "attestation_trend": "${attestation_trend}",
  "balance_trend": "${balance_trend}",
  "data_points": ${#history_files[@]},
  "time_period_days": $(echo "scale=1; ${#history_files[@]} / 24" | bc)
}
EOF
        )
    else
        trend_analysis=$(cat <<EOF
{
  "attestation_trend": "insufficient_data",
  "balance_trend": "insufficient_data",
  "data_points": ${#history_files[@]},
  "time_period_days": $(echo "scale=1; ${#history_files[@]} / 24" | bc)
}
EOF
        )
    fi
    
    echo "${trend_analysis}"
}

# Generate recommendations based on performance
generate_recommendations() {
    local comparison_data="$1"
    local trend_data="$2"
    
    # Extract performance categories
    local attestation_category=$(echo "${comparison_data}" | grep -o '"attestation":[^}]*"performance_category":[[:space:]]*"[^"]*"' | grep -o '"performance_category":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "average")
    local balance_category=$(echo "${comparison_data}" | grep -o '"balance":[^}]*"performance_category":[[:space:]]*"[^"]*"' | grep -o '"performance_category":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "average")
    
    # Extract trends
    local attestation_trend=$(echo "${trend_data}" | grep -o '"attestation_trend":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "stable")
    local balance_trend=$(echo "${trend_data}" | grep -o '"balance_trend":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "stable")
    
    # Generate recommendations based on performance and trends
    local recommendations=()
    
    # Attestation recommendations
    if [[ "${attestation_category}" == "needs_improvement" ]]; then
        if [[ "${attestation_trend}" == "declining" ]]; then
            recommendations+=("Urgent: Your attestation effectiveness is declining and below network average. Check your validator's network connectivity and system resources.")
        else
            recommendations+=("Your attestation effectiveness is below network average. Ensure your validator has stable network connectivity and sufficient system resources.")
        fi
    elif [[ "${attestation_category}" == "average" && "${attestation_trend}" == "declining" ]]; then
        recommendations+=("Monitor your attestation effectiveness as it shows a declining trend. Check for any changes in network conditions or system performance.")
    fi
    
    # Balance recommendations
    if [[ "${balance_category}" == "needs_improvement" ]]; then
        if [[ "${balance_trend}" == "decreasing" ]]; then
            recommendations+=("Alert: Your validator balance is decreasing and below average. Check for missed duties or potential penalties.")
        else
            recommendations+=("Your validator balance is below network average. Optimize your setup to improve effectiveness and earnings.")
        fi
    elif [[ "${balance_category}" == "average" && "${balance_trend}" == "decreasing" ]]; then
        recommendations+=("Your validator balance shows a decreasing trend. Monitor for missed attestations or proposals.")
    fi
    
    # General recommendations
    if [[ "${attestation_category}" == "above_average" && "${balance_category}" == "above_average" ]]; then
        recommendations+=("Your validator is performing excellently. Maintain your current setup and monitoring practices.")
    elif [[ "${attestation_category}" == "needs_improvement" || "${balance_category}" == "needs_improvement" ]]; then
        recommendations+=("Consider reviewing your validator client version and configuration for optimal performance.")
        recommendations+=("Ensure your system clock is accurately synchronized with NTP.")
        recommendations+=("Check that your system has sufficient CPU, memory, and network bandwidth for validator operations.")
    fi
    
    # Format recommendations as JSON array
    local recommendations_json="[]"
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        recommendations_json="["
        for i in "${!recommendations[@]}"; do
            recommendations_json+="\"${recommendations[${i}]}\""
            if [[ ${i} -lt $((${#recommendations[@]} - 1)) ]]; then
                recommendations_json+=", "
            fi
        done
        recommendations_json+="]"
    fi
    
    echo "${recommendations_json}"
}

# Main function
main() {
    echo "Starting validator performance comparison at $(date)"
    
    # Get network statistics
    local network_stats=$(get_network_stats)
    
    # Get local validator performance
    local local_performance=$(get_local_validator_performance)
    
    # Compare with network averages
    local comparison_data=$(compare_with_network "${local_performance}" "${network_stats}")
    
    # Analyze historical trends
    local trend_analysis=$(analyze_trends)
    
    # Generate recommendations
    local recommendations=$(generate_recommendations "${comparison_data}" "${trend_analysis}")
    
    # Compile full comparison report
    local comparison_report=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "local_performance": ${local_performance},
  "comparison_with_network": ${comparison_data},
  "trend_analysis": ${trend_analysis},
  "recommendations": ${recommendations}
}
EOF
    )
    
    # Save the comparison report
    echo "${comparison_report}" > "${COMPARISON_OUTPUT}"
    echo "${comparison_report}" > "${COMPARISON_HISTORY}"
    
    # Print summary
    echo "Validator performance comparison completed at $(date)"
    echo "Results saved to ${COMPARISON_OUTPUT}"
    
    # Output a brief summary to the console
    local attestation_diff=$(echo "${comparison_data}" | grep -o '"attestation":[^}]*"difference":[[:space:]]*[0-9.-]*' | grep -o '"difference":[[:space:]]*[0-9.-]*' | cut -d':' -f2 | tr -d ' ')
    local balance_percent=$(echo "${comparison_data}" | grep -o '"balance":[^}]*"percent_of_network":[[:space:]]*[0-9.]*' | grep -o '"percent_of_network":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')
    
    echo "--------------------------------------------------"
    echo "Validator Performance Comparison Summary"
    echo "--------------------------------------------------"
    echo "Attestation effectiveness vs network: ${attestation_diff}%"
    echo "Validator balance vs network average: ${balance_percent}%"
    echo "Attestation trend: $(echo "${trend_analysis}" | grep -o '"attestation_trend":[[:space:]]*"[^"]*"' | cut -d'"' -f4)"
    echo "Balance trend: $(echo "${trend_analysis}" | grep -o '"balance_trend":[[:space:]]*"[^"]*"' | cut -d'"' -f4)"
    echo "--------------------------------------------------"
    echo "Recommendations:"
    
    # Extract and display recommendations
    if echo "${recommendations}" | grep -q '"'; then
        echo "${recommendations}" | grep -o '"[^"]*"' | sed 's/"//g' | while read -r line; do
            echo "- ${line}"
        done
    else
        echo "- No specific recommendations at this time."
    fi
    echo "--------------------------------------------------"
}

# Run the main function
main 