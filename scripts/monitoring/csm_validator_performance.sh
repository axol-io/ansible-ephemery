#!/bin/bash
#
# CSM Validator Performance Monitoring Script
# This script provides comprehensive monitoring and analytics for Lido CSM validators,
# integrating with existing analytics tools and providing CSM-specific metrics.
#
# Usage: ./csm_validator_performance.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --data-dir DIR         Data directory (default: /var/lib/validator/data)
#   --metrics-dir DIR      Metrics directory (default: /var/lib/validator/metrics)
#   --config-file FILE     Configuration file path
#   --output FORMAT        Output format: json, csv, html, terminal (default: terminal)
#   --output-file FILE     Output file path (defaults to stdout if not specified)
#   --monitoring-interval N Number of minutes between monitoring runs (default: 60)
#   --alert-threshold N    Alert threshold for performance deviation (default: 10)
#   --compare-network      Compare with network averages (requires API)
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

# Source common functions if available
COMMON_SCRIPT="${REPO_ROOT}/scripts/utilities/common_functions.sh"
if [[ -f "$COMMON_SCRIPT" ]]; then
    source "$COMMON_SCRIPT"
else
    # Define minimal required functions if common_functions.sh is not available
    function log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
    function log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
    function log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
    function log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
    function log_debug() { if [[ "$VERBOSE" == "true" ]]; then echo -e "${CYAN}[DEBUG]${NC} $*"; fi; }
fi

# Check for required tools
for cmd in jq bc awk curl; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Default values
BASE_DIR="/opt/ephemery"
DATA_DIR="/var/lib/validator/data"
METRICS_DIR="/var/lib/validator/metrics"
CONFIG_FILE="${SCRIPT_DIR}/config/csm_validator_performance.json"
OUTPUT_FORMAT="terminal"
OUTPUT_FILE=""
MONITORING_INTERVAL=60
ALERT_THRESHOLD=10
COMPARE_NETWORK=false
VERBOSE=false
BEACON_API_ENDPOINT="http://localhost:5052"
CSM_API_ENDPOINT="http://localhost:9000"
NETWORK_API_ENDPOINT="https://beaconcha.in/api/v1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --metrics-dir)
            METRICS_DIR="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --monitoring-interval)
            MONITORING_INTERVAL="$2"
            shift 2
            ;;
        --alert-threshold)
            ALERT_THRESHOLD="$2"
            shift 2
            ;;
        --compare-network)
            COMPARE_NETWORK=true
            shift
            ;;
        --beacon-api)
            BEACON_API_ENDPOINT="$2"
            shift 2
            ;;
        --csm-api)
            CSM_API_ENDPOINT="$2"
            shift 2
            ;;
        --network-api)
            NETWORK_API_ENDPOINT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "CSM Validator Performance Monitoring Script"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --base-dir DIR         Base directory (default: $BASE_DIR)"
            echo "  --data-dir DIR         Data directory (default: $DATA_DIR)"
            echo "  --metrics-dir DIR      Metrics directory (default: $METRICS_DIR)"
            echo "  --config-file FILE     Configuration file path (default: $CONFIG_FILE)"
            echo "  --output FORMAT        Output format: json, csv, html, terminal (default: $OUTPUT_FORMAT)"
            echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
            echo "  --monitoring-interval N Number of minutes between monitoring runs (default: $MONITORING_INTERVAL)"
            echo "  --alert-threshold N    Alert threshold for performance deviation (default: $ALERT_THRESHOLD)"
            echo "  --compare-network      Compare with network averages (requires API)"
            echo "  --beacon-api URL       Beacon API endpoint (default: $BEACON_API_ENDPOINT)"
            echo "  --csm-api URL          CSM API endpoint (default: $CSM_API_ENDPOINT)"
            echo "  --network-api URL      Network API endpoint (default: $NETWORK_API_ENDPOINT)"
            echo "  --verbose              Enable verbose output"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure directories exist
mkdir -p "$DATA_DIR" "$METRICS_DIR" 2>/dev/null || {
    log_error "Failed to create required directories"
    exit 1
}

# Load configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Loading configuration from $CONFIG_FILE"
    
    # Parse config file
    if [[ "$CONFIG_FILE" == *.json ]]; then
        if ! command -v jq &>/dev/null; then
            log_error "jq is required for parsing JSON config files"
            exit 1
        fi
        
        # Extract configuration values
        if [[ -n "$(jq -r '.data_directory // empty' "$CONFIG_FILE")" ]]; then
            DATA_DIR=$(jq -r '.data_directory' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.metrics_directory // empty' "$CONFIG_FILE")" ]]; then
            METRICS_DIR=$(jq -r '.metrics_directory' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.monitoring_interval // empty' "$CONFIG_FILE")" ]]; then
            MONITORING_INTERVAL=$(jq -r '.monitoring_interval' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.alert_threshold // empty' "$CONFIG_FILE")" ]]; then
            ALERT_THRESHOLD=$(jq -r '.alert_threshold' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.compare_network // empty' "$CONFIG_FILE")" ]]; then
            COMPARE_NETWORK=$(jq -r '.compare_network' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.beacon_api // empty' "$CONFIG_FILE")" ]]; then
            BEACON_API_ENDPOINT=$(jq -r '.beacon_api' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.csm_api // empty' "$CONFIG_FILE")" ]]; then
            CSM_API_ENDPOINT=$(jq -r '.csm_api' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.network_api // empty' "$CONFIG_FILE")" ]]; then
            NETWORK_API_ENDPOINT=$(jq -r '.network_api' "$CONFIG_FILE")
        fi
    else
        log_error "Unsupported config file format: $CONFIG_FILE"
        exit 1
    fi
else
    log_warning "Configuration file not found: $CONFIG_FILE"
    log_info "Using default configuration"
fi

# Function to fetch CSM validator indices
fetch_csm_validators() {
    log_debug "Fetching CSM validator indices"
    
    # In a real implementation, this would fetch from the CSM API
    # For now, simulate with sample data
    local csm_validators_file="${DATA_DIR}/csm_validators.json"
    
    # Check if the file exists
    if [[ -f "$csm_validators_file" ]]; then
        cat "$csm_validators_file"
        return 0
    fi
    
    # Create sample data if file doesn't exist
    local sample_data=$(cat <<EOF
{
    "validators": [
        {"index": 1000, "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000000", "status": "active"},
        {"index": 1001, "pubkey": "0x8100000000000000000000000000000000000000000000000000000000000000", "status": "active"},
        {"index": 1002, "pubkey": "0x8200000000000000000000000000000000000000000000000000000000000000", "status": "active"},
        {"index": 1003, "pubkey": "0x8300000000000000000000000000000000000000000000000000000000000000", "status": "active"},
        {"index": 1004, "pubkey": "0x8400000000000000000000000000000000000000000000000000000000000000", "status": "active"}
    ]
}
EOF
)
    echo "$sample_data" > "$csm_validators_file"
    echo "$sample_data"
    return 0
}

# Function to fetch validator performance from beacon chain
fetch_validator_performance() {
    local validator_index="$1"
    local url="${BEACON_API_ENDPOINT}/eth/v1/validator/${validator_index}/performance"
    
    log_debug "Fetching validator performance from: $url"
    
    # In a real implementation, this would make an API call
    # For now, generate sample data
    local current_time=$(date +%s)
    local random_effectiveness=$(( 90 + (RANDOM % 10) ))
    local random_balance=$(( 32000000000 + (RANDOM % 1000000000) ))
    
    cat <<EOF
{
    "data": {
        "current_effective_balance": "${random_balance}",
        "inclusion_slots": [1, 2, 3],
        "correctness_percentage": ${random_effectiveness},
        "last_attestation_slot": "$(( (current_time - 12) / 12 ))"
    }
}
EOF
}

# Function to fetch network average performance
fetch_network_average() {
    local url="${NETWORK_API_ENDPOINT}/validator/performance/average"
    
    log_debug "Fetching network average performance from: $url"
    
    # In a real implementation, this would make an API call
    # For now, generate sample data
    cat <<EOF
{
    "data": {
        "average_effectiveness": 95.2,
        "average_balance": 32500000000,
        "average_inclusion_distance": 1.2,
        "total_validators": 10000
    }
}
EOF
}

# Function to calculate performance rating (0-100)
calculate_performance_rating() {
    local effectiveness="$1"
    local inclusion_distance="$2"
    local balance_growth="$3"
    
    # Simple weighted formula
    # 70% effectiveness + 20% inclusion distance + 10% balance growth
    local inclusion_score=$(echo "scale=2; 100 - (($inclusion_distance - 1) * 10)" | bc)
    
    # Ensure inclusion score is between 0 and 100
    if (( $(echo "$inclusion_score > 100" | bc -l) )); then
        inclusion_score=100
    elif (( $(echo "$inclusion_score < 0" | bc -l) )); then
        inclusion_score=0
    fi
    
    # Calculate final rating
    local rating=$(echo "scale=2; ($effectiveness * 0.7) + ($inclusion_score * 0.2) + ($balance_growth * 0.1)" | bc)
    
    # Round to nearest integer
    printf "%.0f" "$rating"
}

# Function to detect performance anomalies
detect_anomalies() {
    local validator_data="$1"
    local network_average="$2"
    local alert_threshold="$3"
    
    local anomalies="[]"
    
    # Extract metrics
    local effectiveness=$(echo "$validator_data" | jq -r '.performance.correctness_percentage')
    local network_effectiveness=$(echo "$network_average" | jq -r '.data.average_effectiveness')
    
    # Calculate deviation
    local effectiveness_deviation=$(echo "scale=2; $network_effectiveness - $effectiveness" | bc)
    
    # Check for attestation effectiveness anomaly
    if (( $(echo "$effectiveness_deviation > $alert_threshold" | bc -l) )); then
        anomalies=$(echo "$anomalies" | jq -r '. + [{
            "type": "effectiveness",
            "severity": "high",
            "description": "Attestation effectiveness is significantly below network average",
            "data": {
                "validator": '${effectiveness}',
                "network": '${network_effectiveness}',
                "deviation": '${effectiveness_deviation}'
            }
        }]')
    fi
    
    # Additional anomaly checks could be added here
    
    echo "$anomalies"
}

# Function to generate alerts
generate_alerts() {
    local anomalies="$1"
    local alerts="[]"
    
    # Check if there are any anomalies
    local anomaly_count=$(echo "$anomalies" | jq -r 'length')
    
    if (( anomaly_count > 0 )); then
        # Convert anomalies to alerts
        alerts=$(echo "$anomalies" | jq -r 'map({
            "type": .type,
            "severity": .severity,
            "message": .description,
            "data": .data,
            "timestamp": '$(date +%s)'
        })')
        
        # In a real implementation, this would send alerts through configured channels
        log_warning "Generated $anomaly_count alerts"
    else
        log_debug "No alerts generated"
    fi
    
    echo "$alerts"
}

# Function to save performance history
save_performance_history() {
    local validator_index="$1"
    local performance_data="$2"
    local history_file="${DATA_DIR}/performance_history_${validator_index}.json"
    
    log_debug "Saving performance history for validator $validator_index"
    
    # Initialize history file if it doesn't exist
    if [[ ! -f "$history_file" ]]; then
        echo '{"data": []}' > "$history_file"
    fi
    
    # Read existing history
    local history=$(cat "$history_file")
    
    # Add new data point
    local updated_history=$(echo "$history" | jq -r '.data += ['${performance_data}']')
    
    # Limit history to last 30 days (720 entries with 1 hour interval)
    local trimmed_history=$(echo "$updated_history" | jq -r '.data = .data | sort_by(.timestamp) | reverse | .[0:720]')
    
    # Save updated history
    echo "$trimmed_history" > "$history_file"
}

# Function to run comprehensive validator analysis
run_comprehensive_analysis() {
    local validator_index="$1"
    
    log_debug "Running comprehensive analysis for validator $validator_index"
    
    # Path to the validator predictive analytics script
    local predictive_script="${SCRIPT_DIR}/validator_predictive_analytics.sh"
    
    if [[ ! -f "$predictive_script" ]]; then
        log_warning "Predictive analytics script not found: $predictive_script"
        return 1
    fi
    
    # Run predictive analytics
    "$predictive_script" --validator "$validator_index" --analysis-type comprehensive --output json
    return $?
}

# Main monitoring function
monitor_csm_validators() {
    log_info "Starting CSM validator performance monitoring"
    
    # Fetch CSM validators
    local csm_validators
    csm_validators=$(fetch_csm_validators)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch CSM validator information"
        exit 1
    fi
    
    # Extract validator indices
    local validator_indices=$(echo "$csm_validators" | jq -r '.validators[].index')
    
    # Fetch network average if comparison is enabled
    local network_average="{}"
    if [[ "$COMPARE_NETWORK" == "true" ]]; then
        network_average=$(fetch_network_average)
        if [[ $? -ne 0 ]]; then
            log_warning "Failed to fetch network average performance, disabling comparison"
            COMPARE_NETWORK=false
        fi
    fi
    
    # Process each validator
    local all_validators_data="[]"
    local all_alerts="[]"
    
    for validator_index in $validator_indices; do
        log_info "Monitoring validator $validator_index"
        
        # Fetch current performance
        local performance=$(fetch_validator_performance "$validator_index")
        if [[ $? -ne 0 ]]; then
            log_warning "Failed to fetch performance for validator $validator_index, skipping"
            continue
        fi
        
        # Extract metadata from CSM validators
        local validator_metadata=$(echo "$csm_validators" | jq -r '.validators[] | select(.index == '$validator_index')')
        
        # Create timestamp
        local timestamp=$(date +%s)
        
        # Calculate performance metrics
        local effectiveness=$(echo "$performance" | jq -r '.data.correctness_percentage')
        local balance=$(echo "$performance" | jq -r '.data.current_effective_balance')
        local inclusion_distance=1.2  # Simulated value
        local balance_growth=5.0      # Simulated value (%)
        
        # Calculate performance rating
        local rating=$(calculate_performance_rating "$effectiveness" "$inclusion_distance" "$balance_growth")
        
        # Create performance data point
        local performance_data=$(cat <<EOF
{
    "timestamp": ${timestamp},
    "validator_index": ${validator_index},
    "effectiveness": ${effectiveness},
    "balance": ${balance},
    "inclusion_distance": ${inclusion_distance},
    "balance_growth": ${balance_growth},
    "rating": ${rating}
}
EOF
)
        
        # Save performance history
        save_performance_history "$validator_index" "$performance_data"
        
        # Detect anomalies if network comparison is enabled
        local anomalies="[]"
        if [[ "$COMPARE_NETWORK" == "true" ]]; then
            # Create combined data for anomaly detection
            local combined_data=$(cat <<EOF
{
    "validator_index": ${validator_index},
    "performance": $(echo "$performance" | jq '.data'),
    "metadata": ${validator_metadata}
}
EOF
)
            
            anomalies=$(detect_anomalies "$combined_data" "$network_average" "$ALERT_THRESHOLD")
            
            # Generate alerts if anomalies detected
            if [[ "$(echo "$anomalies" | jq 'length')" -gt 0 ]]; then
                local alerts=$(generate_alerts "$anomalies")
                all_alerts=$(echo "$all_alerts" | jq -r '. + '"$alerts"'')
            fi
        fi
        
        # Create validator data object
        local validator_data=$(cat <<EOF
{
    "validator_index": ${validator_index},
    "pubkey": $(echo "$validator_metadata" | jq '.pubkey'),
    "status": $(echo "$validator_metadata" | jq '.status'),
    "performance": {
        "timestamp": ${timestamp},
        "effectiveness": ${effectiveness},
        "balance": ${balance},
        "inclusion_distance": ${inclusion_distance},
        "balance_growth": ${balance_growth},
        "rating": ${rating}
    },
    "anomalies": ${anomalies}
}
EOF
)
        
        # Add to all validators data
        all_validators_data=$(echo "$all_validators_data" | jq -r '. + ['"$validator_data"']')
        
        # Run comprehensive analysis periodically (e.g., once a day)
        if [[ $(( timestamp % 86400 )) -lt $((MONITORING_INTERVAL * 60)) ]]; then
            log_info "Running comprehensive analysis for validator $validator_index"
            run_comprehensive_analysis "$validator_index" > "${METRICS_DIR}/analysis_${validator_index}.json"
        fi
    done
    
    # Create final result
    local result=$(cat <<EOF
{
    "timestamp": $(date +%s),
    "monitoring_interval": ${MONITORING_INTERVAL},
    "alert_threshold": ${ALERT_THRESHOLD},
    "compare_network": ${COMPARE_NETWORK},
    "validators": ${all_validators_data},
    "alerts": ${all_alerts},
    "network_average": $(echo "$network_average" | jq '.data')
}
EOF
)
    
    # Format and output results
    format_output "$result"
    
    log_success "CSM validator performance monitoring completed"
}

# Function to format output based on selected format
format_output() {
    local result="$1"
    
    case "$OUTPUT_FORMAT" in
        json)
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo "$result" | jq '.' > "$OUTPUT_FILE"
                log_success "Results saved to $OUTPUT_FILE"
            else
                echo "$result" | jq '.'
            fi
            ;;
        csv)
            # Convert JSON to CSV format
            local csv_header="timestamp,validator_index,effectiveness,balance,inclusion_distance,balance_growth,rating"
            local csv_data=$(echo "$result" | jq -r '.validators[] | [
                .performance.timestamp,
                .validator_index,
                .performance.effectiveness,
                .performance.balance,
                .performance.inclusion_distance,
                .performance.balance_growth,
                .performance.rating
            ] | join(",")')
            
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo "$csv_header" > "$OUTPUT_FILE"
                echo "$csv_data" >> "$OUTPUT_FILE"
                log_success "Results saved to $OUTPUT_FILE"
            else
                echo "$csv_header"
                echo "$csv_data"
            fi
            ;;
        html)
            generate_html_report "$result"
            ;;
        terminal)
            display_terminal_results "$result"
            ;;
        *)
            log_error "Unsupported output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
}

# Function to generate HTML report
generate_html_report() {
    local result="$1"
    
    # Create HTML header
    local html_output="<!DOCTYPE html>
<html>
<head>
    <title>CSM Validator Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .validator { border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
        .rating-high { color: green; }
        .rating-medium { color: orange; }
        .rating-low { color: red; }
        .alert { background-color: #ffeeee; border-left: 4px solid red; padding: 10px; margin: 10px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>CSM Validator Performance Report</h1>
    <p>Generated on: $(date)</p>
    <p>Monitoring Interval: ${MONITORING_INTERVAL} minutes</p>"
    
    # Add network average if available
    if [[ "$COMPARE_NETWORK" == "true" ]]; then
        local network_effectiveness=$(echo "$result" | jq -r '.network_average.average_effectiveness')
        local network_balance=$(echo "$result" | jq -r '.network_average.average_balance')
        local network_inclusion=$(echo "$result" | jq -r '.network_average.average_inclusion_distance')
        
        html_output+="
    <h2>Network Averages</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Value</th>
        </tr>
        <tr>
            <td>Average Effectiveness</td>
            <td>${network_effectiveness}%</td>
        </tr>
        <tr>
            <td>Average Balance</td>
            <td>${network_balance} gwei</td>
        </tr>
        <tr>
            <td>Average Inclusion Distance</td>
            <td>${network_inclusion}</td>
        </tr>
    </table>"
    fi
    
    # Add alerts section if any
    local alerts_count=$(echo "$result" | jq -r '.alerts | length')
    if [[ "$alerts_count" -gt 0 ]]; then
        html_output+="
    <h2>Alerts (${alerts_count})</h2>"
        
        # Process each alert
        for alert_json in $(echo "$result" | jq -r '.alerts[] | @base64'); do
            local alert=$(echo "$alert_json" | base64 --decode)
            local alert_type=$(echo "$alert" | jq -r '.type')
            local alert_severity=$(echo "$alert" | jq -r '.severity')
            local alert_message=$(echo "$alert" | jq -r '.message')
            
            html_output+="
    <div class='alert'>
        <strong>[${alert_severity}] ${alert_type}:</strong> ${alert_message}
    </div>"
        done
    fi
    
    # Add validator section
    html_output+="
    <h2>Validators</h2>"
    
    # Process each validator
    for validator_json in $(echo "$result" | jq -r '.validators[] | @base64'); do
        local validator=$(echo "$validator_json" | base64 --decode)
        local index=$(echo "$validator" | jq -r '.validator_index')
        local pubkey=$(echo "$validator" | jq -r '.pubkey')
        local status=$(echo "$validator" | jq -r '.status')
        local effectiveness=$(echo "$validator" | jq -r '.performance.effectiveness')
        local balance=$(echo "$validator" | jq -r '.performance.balance')
        local rating=$(echo "$validator" | jq -r '.performance.rating')
        
        # Determine rating class
        local rating_class="rating-medium"
        if (( rating >= 90 )); then
            rating_class="rating-high"
        elif (( rating < 70 )); then
            rating_class="rating-low"
        fi
        
        html_output+="
    <div class='validator'>
        <h3>Validator ${index}</h3>
        <p>Public Key: ${pubkey}</p>
        <p>Status: ${status}</p>
        <p>Performance Rating: <span class='${rating_class}'>${rating}%</span></p>
        
        <h4>Performance Metrics</h4>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Effectiveness</td>
                <td>${effectiveness}%</td>
            </tr>
            <tr>
                <td>Balance</td>
                <td>${balance} gwei</td>
            </tr>
        </table>"
        
        # Add anomalies if any
        local anomalies_count=$(echo "$validator" | jq -r '.anomalies | length')
        if [[ "$anomalies_count" -gt 0 ]]; then
            html_output+="
        <h4>Detected Anomalies</h4>
        <ul>"
            
            for anomaly_json in $(echo "$validator" | jq -r '.anomalies[] | @base64'); do
                local anomaly=$(echo "$anomaly_json" | base64 --decode)
                local anomaly_type=$(echo "$anomaly" | jq -r '.type')
                local anomaly_description=$(echo "$anomaly" | jq -r '.description')
                
                html_output+="
            <li><strong>${anomaly_type}:</strong> ${anomaly_description}</li>"
            done
            
            html_output+="
        </ul>"
        fi
        
        html_output+="
    </div>"
    done
    
    # Close HTML
    html_output+="
</body>
</html>"
    
    # Save or output HTML
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$html_output" > "$OUTPUT_FILE"
        log_success "HTML report saved to $OUTPUT_FILE"
    else
        echo "$html_output"
    fi
}

# Function to display terminal-formatted results
display_terminal_results() {
    local result="$1"
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}CSM Validator Performance Report${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "Generated on: $(date)"
    echo -e "Monitoring Interval: ${CYAN}${MONITORING_INTERVAL}${NC} minutes"
    echo ""
    
    # Display network average if available
    if [[ "$COMPARE_NETWORK" == "true" ]]; then
        local network_effectiveness=$(echo "$result" | jq -r '.network_average.average_effectiveness')
        local network_balance=$(echo "$result" | jq -r '.network_average.average_balance')
        local network_inclusion=$(echo "$result" | jq -r '.network_average.average_inclusion_distance')
        
        echo -e "${BLUE}Network Averages:${NC}"
        echo -e "  Effectiveness: ${CYAN}${network_effectiveness}%${NC}"
        echo -e "  Balance: ${CYAN}${network_balance} gwei${NC}"
        echo -e "  Inclusion Distance: ${CYAN}${network_inclusion}${NC}"
        echo ""
    fi
    
    # Display alerts if any
    local alerts_count=$(echo "$result" | jq -r '.alerts | length')
    if [[ "$alerts_count" -gt 0 ]]; then
        echo -e "${RED}Alerts (${alerts_count}):${NC}"
        
        # Process each alert
        for alert_json in $(echo "$result" | jq -r '.alerts[] | @base64'); do
            local alert=$(echo "$alert_json" | base64 --decode)
            local alert_type=$(echo "$alert" | jq -r '.type')
            local alert_severity=$(echo "$alert" | jq -r '.severity')
            local alert_message=$(echo "$alert" | jq -r '.message')
            
            # Determine severity color
            local severity_color="$YELLOW"
            if [[ "$alert_severity" == "high" ]]; then
                severity_color="$RED"
            elif [[ "$alert_severity" == "low" ]]; then
                severity_color="$BLUE"
            fi
            
            echo -e "  [${severity_color}${alert_severity}${NC}] ${PURPLE}${alert_type}${NC}: ${alert_message}"
        done
        echo ""
    fi
    
    # Display validator information
    echo -e "${BLUE}Validators:${NC}"
    echo ""
    
    # Process each validator
    for validator_json in $(echo "$result" | jq -r '.validators[] | @base64'); do
        local validator=$(echo "$validator_json" | base64 --decode)
        local index=$(echo "$validator" | jq -r '.validator_index')
        local pubkey=$(echo "$validator" | jq -r '.pubkey')
        local status=$(echo "$validator" | jq -r '.status')
        local effectiveness=$(echo "$validator" | jq -r '.performance.effectiveness')
        local balance=$(echo "$validator" | jq -r '.performance.balance')
        local rating=$(echo "$validator" | jq -r '.performance.rating')
        
        # Determine rating color
        local rating_color="$YELLOW"
        if (( rating >= 90 )); then
            rating_color="$GREEN"
        elif (( rating < 70 )); then
            rating_color="$RED"
        fi
        
        echo -e "${CYAN}Validator ${index}${NC} (${status})"
        echo -e "  Public Key: ${pubkey}"
        echo -e "  Performance Rating: ${rating_color}${rating}%${NC}"
        echo -e "  Effectiveness: ${effectiveness}%"
        echo -e "  Balance: ${balance} gwei"
        
        # Display anomalies if any
        local anomalies_count=$(echo "$validator" | jq -r '.anomalies | length')
        if [[ "$anomalies_count" -gt 0 ]]; then
            echo -e "  ${YELLOW}Detected Anomalies:${NC}"
            
            for anomaly_json in $(echo "$validator" | jq -r '.anomalies[] | @base64'); do
                local anomaly=$(echo "$anomaly_json" | base64 --decode)
                local anomaly_type=$(echo "$anomaly" | jq -r '.type')
                local anomaly_description=$(echo "$anomaly" | jq -r '.description')
                
                echo -e "    - ${PURPLE}${anomaly_type}${NC}: ${anomaly_description}"
            done
        fi
        
        echo ""
    done
    
    # Save results to metrics directory
    local timestamp_str=$(date +"%Y%m%d_%H%M%S")
    local metrics_file="${METRICS_DIR}/csm_performance_${timestamp_str}.json"
    echo "$result" > "$metrics_file"
    log_success "Report saved to: $metrics_file"
}

# Main function
main() {
    # Initial monitoring run
    monitor_csm_validators
    
    # If monitoring interval is set, continue monitoring
    if [[ "$MONITORING_INTERVAL" -gt 0 ]]; then
        log_info "Continuous monitoring mode enabled, interval: $MONITORING_INTERVAL minutes"
        
        # Create pid file to prevent multiple instances
        local pid_file="/tmp/csm_monitor.pid"
        echo $$ > "$pid_file"
        
        # Set up trap to clean up pid file on exit
        trap "rm -f $pid_file; exit" INT TERM EXIT
        
        # Main monitoring loop
        while true; do
            log_info "Sleeping for $MONITORING_INTERVAL minutes until next monitoring run"
            sleep $(( MONITORING_INTERVAL * 60 ))
            monitor_csm_validators
        done
    fi
}

# Run main function
main

exit 0 