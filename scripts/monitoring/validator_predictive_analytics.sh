#!/bin/bash
#
# Validator Predictive Analytics Script
# This script implements the "Analytics and Recommendations" phase of the monitoring system,
# providing trend analysis, performance forecasting, and optimization recommendations.
#
# Usage: ./validator_predictive_analytics.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --forecast-days N      Number of days to forecast (default: 7)
#   --analysis-type TYPE   Type of analysis: basic, advanced, comprehensive (default: advanced)
#   --output FORMAT        Output format: json, csv, html (default: json)
#   --config-file FILE     Configuration file path
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
for cmd in jq bc awk; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Default values
BASE_DIR="/opt/ephemery"
DATA_DIR="/var/lib/validator/data"
METRICS_DIR="/var/lib/validator/metrics"
FORECAST_DAYS=7
ANALYSIS_TYPE="advanced"
OUTPUT_FORMAT="json"
CONFIG_FILE="${SCRIPT_DIR}/config/predictive_analytics.json"
OUTPUT_FILE=""
VERBOSE=false

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
        --forecast-days)
            FORECAST_DAYS="$2"
            shift 2
            ;;
        --analysis-type)
            ANALYSIS_TYPE="$2"
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
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Validator Predictive Analytics Script"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --base-dir DIR         Base directory (default: $BASE_DIR)"
            echo "  --data-dir DIR         Data directory (default: $DATA_DIR)"
            echo "  --metrics-dir DIR      Metrics directory (default: $METRICS_DIR)"
            echo "  --forecast-days N      Number of days to forecast (default: $FORECAST_DAYS)"
            echo "  --analysis-type TYPE   Type of analysis: basic, advanced, comprehensive (default: $ANALYSIS_TYPE)"
            echo "  --output FORMAT        Output format: json, csv, html (default: $OUTPUT_FORMAT)"
            echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
            echo "  --config-file FILE     Configuration file path (default: $CONFIG_FILE)"
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

# Ensure data directory exists
mkdir -p "$DATA_DIR" 2>/dev/null || {
    log_error "Failed to create data directory: $DATA_DIR"
    exit 1
}

# Load configuration
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
        if [[ -n "$(jq -r '.forecast_days // empty' "$CONFIG_FILE")" ]]; then
            FORECAST_DAYS=$(jq -r '.forecast_days' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.analysis_type // empty' "$CONFIG_FILE")" ]]; then
            ANALYSIS_TYPE=$(jq -r '.analysis_type' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.output_format // empty' "$CONFIG_FILE")" ]]; then
            OUTPUT_FORMAT=$(jq -r '.output_format' "$CONFIG_FILE")
        fi
        if [[ -n "$(jq -r '.validators // empty' "$CONFIG_FILE")" ]]; then
            VALIDATORS=$(jq -r '.validators[]' "$CONFIG_FILE")
        else
            log_error "No validators found in configuration file"
            exit 1
        fi
    else
        log_error "Unsupported config file format: $CONFIG_FILE"
        exit 1
    fi
else
    log_warning "Configuration file not found: $CONFIG_FILE"
    log_info "Using default configuration"
    
    # Check if validators list is available in metrics directory
    if [[ -d "$METRICS_DIR" ]]; then
        VALIDATORS=$(find "$METRICS_DIR" -name "*.json" -type f | sed 's|.*/||;s|\.json$||')
        if [[ -z "$VALIDATORS" ]]; then
            log_error "No validator metrics found in $METRICS_DIR"
            exit 1
        fi
    else
        log_error "Metrics directory not found: $METRICS_DIR"
        exit 1
    fi
fi

# Function to collect historical data for a validator
collect_historical_data() {
    local VALIDATOR_ID="$1"
    local HISTORY_FILE="${DATA_DIR}/history_${VALIDATOR_ID}.json"
    
    log_debug "Collecting historical data for validator $VALIDATOR_ID"
    
    # Check if history file exists
    if [[ ! -f "$HISTORY_FILE" ]]; then
        log_warning "No historical data found for validator $VALIDATOR_ID"
        return 1
    fi
    
    cat "$HISTORY_FILE"
    return 0
}

# Function to analyze attestation performance trend
analyze_attestation_trend() {
    local HISTORICAL_DATA="$1"
    local DAYS="$2"
    
    # Extract recent attestation data
    local RECENT_DATA=$(echo "$HISTORICAL_DATA" | jq -r "[.data[] | select(.timestamp >= (now - ${DAYS}*86400))]")
    
    # Calculate attestation success rate over time
    local ATTESTATION_TREND=$(echo "$RECENT_DATA" | jq -r '
        [.[] | {
            timestamp: .timestamp,
            date: (.timestamp | strftime("%Y-%m-%d")),
            success_rate: ((.successful_attestations / (.successful_attestations + .missed_attestations)) * 100)
        }] | group_by(.date) | map({
            date: .[0].date,
            success_rate: (map(.success_rate) | add / length)
        })'
    )
    
    # Detect trend direction
    local FIRST_DAY=$(echo "$ATTESTATION_TREND" | jq -r 'first.success_rate')
    local LAST_DAY=$(echo "$ATTESTATION_TREND" | jq -r 'last.success_rate')
    local TREND_DIRECTION="stable"
    
    if (( $(echo "$LAST_DAY - $FIRST_DAY > 1" | bc -l) )); then
        TREND_DIRECTION="improving"
    elif (( $(echo "$FIRST_DAY - $LAST_DAY > 1" | bc -l) )); then
        TREND_DIRECTION="declining"
    fi
    
    # Build result
    echo "{
        \"data\": $ATTESTATION_TREND,
        \"first_day\": $FIRST_DAY,
        \"last_day\": $LAST_DAY,
        \"trend\": \"$TREND_DIRECTION\"
    }"
}

# Function to predict future performance
predict_future_performance() {
    local HISTORICAL_DATA="$1"
    local FORECAST_DAYS="$2"
    
    # Extract recent performance data
    local PERFORMANCE_DATA=$(echo "$HISTORICAL_DATA" | jq -r '
        [.data[] | {
            day: (.timestamp | strftime("%j") | tonumber),
            attestation_rate: ((.successful_attestations / (.successful_attestations + .missed_attestations)) * 100),
            balance: .balance,
            inclusion_distance: .inclusion_distance
        }]'
    )
    
    # Simple linear regression for forecasting
    # This is a simplified approach - in a real system, more sophisticated
    # algorithms would be used for time-series forecasting
    local FORECAST=$(echo "$PERFORMANCE_DATA" | jq -r "
        # Calculate linear regression parameters
        . as \$data |
        (\$data | length) as \$n |
        (\$data | map(.day) | add) as \$sum_x |
        (\$data | map(.attestation_rate) | add) as \$sum_y |
        (\$data | map(.day * .attestation_rate) | add) as \$sum_xy |
        (\$data | map(.day * .day) | add) as \$sum_xx |
        
        # Calculate slope and intercept
        ((\$n * \$sum_xy) - (\$sum_x * \$sum_y)) / ((\$n * \$sum_xx) - (\$sum_x * \$sum_x)) as \$slope |
        (\$sum_y - (\$slope * \$sum_x)) / \$n as \$intercept |
        
        # Get the latest day number
        (\$data | max_by(.day).day) as \$last_day |
        
        # Generate forecast for next days
        [range(1; ${FORECAST_DAYS} + 1)] | map({
            day: (\$last_day + .),
            attestation_rate: (\$intercept + \$slope * (\$last_day + .))
        })
    ")
    
    echo "{\"forecast\": $FORECAST}"
}

# Function to generate optimization recommendations
generate_recommendations() {
    local VALIDATOR_ID="$1"
    local HISTORICAL_DATA="$2"
    local ANALYSIS_TYPE="$3"
    
    log_debug "Generating recommendations for validator $VALIDATOR_ID (analysis type: $ANALYSIS_TYPE)"
    
    # Extract recent performance metrics
    local RECENT_METRICS=$(echo "$HISTORICAL_DATA" | jq -r '.data | sort_by(.timestamp) | reverse | .[0:30]')
    
    # Initialize recommendations array
    local RECOMMENDATIONS="[]"
    
    # Check attestation performance
    local AVG_MISSED_ATTESTATIONS=$(echo "$RECENT_METRICS" | jq -r '[.[].missed_attestations] | add / length')
    if (( $(echo "$AVG_MISSED_ATTESTATIONS > 0.5" | bc -l) )); then
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
            "type": "attestation_performance",
            "severity": "medium",
            "description": "Attestation performance can be improved. Consider checking your network connectivity and sync status.",
            "action": "Ensure beacon node is fully synced and has low latency connections to peers."
        }]')
    fi
    
    # Check inclusion distance
    local AVG_INCLUSION_DISTANCE=$(echo "$RECENT_METRICS" | jq -r '[.[].inclusion_distance] | add / length')
    if (( $(echo "$AVG_INCLUSION_DISTANCE > 2" | bc -l) )); then
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
            "type": "inclusion_distance",
            "severity": "medium",
            "description": "Inclusion distance is higher than optimal. This may affect rewards.",
            "action": "Check network connectivity and ensure low latency to majority of peers."
        }]')
    fi
    
    # Check balance trend
    local FIRST_BALANCE=$(echo "$RECENT_METRICS" | jq -r 'last.balance')
    local LAST_BALANCE=$(echo "$RECENT_METRICS" | jq -r 'first.balance')
    local BALANCE_CHANGE=$(echo "scale=6; ($LAST_BALANCE - $FIRST_BALANCE) / $FIRST_BALANCE * 100" | bc)
    
    if (( $(echo "$BALANCE_CHANGE < -1" | bc -l) )); then
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
            "type": "balance_decreasing",
            "severity": "high",
            "description": "Validator balance is decreasing. This indicates penalties or missed rewards.",
            "action": "Perform a thorough check of validator performance, network connectivity, and system resources."
        }]')
    elif (( $(echo "$BALANCE_CHANGE < 0" | bc -l) )); then
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
            "type": "balance_stagnant",
            "severity": "low",
            "description": "Validator balance is not growing as expected.",
            "action": "Monitor validator performance more closely and check for missed attestations."
        }]')
    fi
    
    # Additional recommendations for advanced and comprehensive analysis
    if [[ "$ANALYSIS_TYPE" != "basic" ]]; then
        # Check for optimal gas settings (comprehensive analysis would include more detailed checks)
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
            "type": "resource_optimization",
            "severity": "info",
            "description": "Regular resource usage optimization can improve validator performance.",
            "action": "Consider tuning CPU and memory allocations based on peak usage patterns."
        }]')
        
        # Additional recommendations for comprehensive analysis
        if [[ "$ANALYSIS_TYPE" == "comprehensive" ]]; then
            RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq -r '. + [{
                "type": "hardware_upgrade",
                "severity": "info",
                "description": "Predictive analysis suggests hardware capacity may become a limiting factor in future.",
                "action": "Monitor system resources during peak loads and consider hardware upgrades if consistently near capacity."
            }]')
        fi
    fi
    
    echo "{\"recommendations\": $RECOMMENDATIONS}"
}

# Main execution function
main() {
    log_info "Starting validator predictive analytics"
    log_info "Analysis type: $ANALYSIS_TYPE"
    log_info "Forecast days: $FORECAST_DAYS"
    
    # Initialize results array
    RESULTS="[]"
    
    # Process each validator
    for VALIDATOR_ID in $VALIDATORS; do
        log_info "Analyzing validator: $VALIDATOR_ID"
        
        # Collect historical data
        HISTORICAL_DATA=$(collect_historical_data "$VALIDATOR_ID")
        if [[ $? -ne 0 ]]; then
            log_warning "Skipping validator $VALIDATOR_ID due to missing historical data"
            continue
        fi
        
        # Analyze performance trends
        log_debug "Analyzing performance trends for validator $VALIDATOR_ID"
        ATTESTATION_TREND=$(analyze_attestation_trend "$HISTORICAL_DATA" 30)
        
        # Predict future performance
        log_debug "Predicting future performance for validator $VALIDATOR_ID"
        PERFORMANCE_FORECAST=$(predict_future_performance "$HISTORICAL_DATA" "$FORECAST_DAYS")
        
        # Generate optimization recommendations
        log_debug "Generating optimization recommendations for validator $VALIDATOR_ID"
        RECOMMENDATIONS=$(generate_recommendations "$VALIDATOR_ID" "$HISTORICAL_DATA" "$ANALYSIS_TYPE")
        
        # Combine results
        VALIDATOR_RESULTS=$(echo "{
            \"validator_id\": \"$VALIDATOR_ID\",
            \"analysis_timestamp\": $(date +%s),
            \"attestation_trend\": $ATTESTATION_TREND,
            \"performance_forecast\": $PERFORMANCE_FORECAST,
            \"recommendations\": $(echo "$RECOMMENDATIONS" | jq -r '.recommendations')
        }")
        
        # Add to results array
        RESULTS=$(echo "$RESULTS" | jq -r ". + [$VALIDATOR_RESULTS]")
    done
    
    # Build final output
    FINAL_OUTPUT=$(echo "{
        \"analysis_type\": \"$ANALYSIS_TYPE\",
        \"forecast_days\": $FORECAST_DAYS,
        \"timestamp\": $(date +%s),
        \"validators\": $RESULTS
    }")
    
    # Format and output results
    case "$OUTPUT_FORMAT" in
        json)
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo "$FINAL_OUTPUT" | jq '.' > "$OUTPUT_FILE"
                log_success "Results saved to $OUTPUT_FILE"
            else
                echo "$FINAL_OUTPUT" | jq '.'
            fi
            ;;
        csv)
            # Convert JSON to CSV format
            CSV_OUTPUT="validator_id,analysis_timestamp,trend,forecast_success_rate,recommendation_count\n"
            CSV_OUTPUT+=$(echo "$FINAL_OUTPUT" | jq -r '.validators[] | [
                .validator_id,
                .analysis_timestamp,
                .attestation_trend.trend,
                (.performance_forecast.forecast | last.attestation_rate),
                (.recommendations | length)
            ] | join(",")')
            
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo -e "$CSV_OUTPUT" > "$OUTPUT_FILE"
                log_success "Results saved to $OUTPUT_FILE"
            else
                echo -e "$CSV_OUTPUT"
            fi
            ;;
        html)
            # Generate a basic HTML report
            HTML_OUTPUT="<!DOCTYPE html>
<html>
<head>
    <title>Validator Predictive Analytics Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .validator { border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
        .trend-improving { color: green; }
        .trend-stable { color: blue; }
        .trend-declining { color: red; }
        .recommendation { margin: 10px 0; padding: 10px; border-left: 4px solid #ddd; }
        .severity-high { border-left-color: red; }
        .severity-medium { border-left-color: orange; }
        .severity-low { border-left-color: yellow; }
        .severity-info { border-left-color: blue; }
    </style>
</head>
<body>
    <h1>Validator Predictive Analytics Report</h1>
    <p>Analysis Type: $ANALYSIS_TYPE | Forecast Days: $FORECAST_DAYS | Date: $(date)</p>
    <div id='validators'>"
            
            # Add each validator's data
            for VALIDATOR_DATA in $(echo "$FINAL_OUTPUT" | jq -r '.validators[] | @base64'); do
                VALIDATOR_JSON=$(echo "$VALIDATOR_DATA" | base64 --decode)
                VALIDATOR_ID=$(echo "$VALIDATOR_JSON" | jq -r '.validator_id')
                TREND=$(echo "$VALIDATOR_JSON" | jq -r '.attestation_trend.trend')
                FORECAST_RATE=$(echo "$VALIDATOR_JSON" | jq -r '.performance_forecast.forecast | last.attestation_rate')
                
                HTML_OUTPUT+="
        <div class='validator'>
            <h2>Validator: $VALIDATOR_ID</h2>
            <p>Performance Trend: <span class='trend-$TREND'>$TREND</span></p>
            <p>Forecasted Success Rate (in $FORECAST_DAYS days): $(printf "%.2f" "$FORECAST_RATE")%</p>
            
            <h3>Recommendations:</h3>"
                
                # Add recommendations
                RECOMMENDATIONS=$(echo "$VALIDATOR_JSON" | jq -r '.recommendations[]')
                if [[ -n "$RECOMMENDATIONS" ]]; then
                    for REC in $(echo "$VALIDATOR_JSON" | jq -r '.recommendations[] | @base64'); do
                        REC_JSON=$(echo "$REC" | base64 --decode)
                        REC_TYPE=$(echo "$REC_JSON" | jq -r '.type')
                        REC_SEVERITY=$(echo "$REC_JSON" | jq -r '.severity')
                        REC_DESC=$(echo "$REC_JSON" | jq -r '.description')
                        REC_ACTION=$(echo "$REC_JSON" | jq -r '.action')
                        
                        HTML_OUTPUT+="
                <div class='recommendation severity-$REC_SEVERITY'>
                    <p><strong>$REC_TYPE</strong> (Severity: $REC_SEVERITY)</p>
                    <p>$REC_DESC</p>
                    <p><em>Recommended Action:</em> $REC_ACTION</p>
                </div>"
                    done
                else
                    HTML_OUTPUT+="
                <p>No recommendations at this time.</p>"
                fi
                
                HTML_OUTPUT+="
        </div>"
            done
            
            HTML_OUTPUT+="
    </div>
</body>
</html>"
            
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo -e "$HTML_OUTPUT" > "$OUTPUT_FILE"
                log_success "Results saved to $OUTPUT_FILE"
            else
                echo -e "$HTML_OUTPUT"
            fi
            ;;
        *)
            log_error "Unsupported output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    log_success "Validator predictive analytics completed successfully"
}

# Call main function
main

exit 0 