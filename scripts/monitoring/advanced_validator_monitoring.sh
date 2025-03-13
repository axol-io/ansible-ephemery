#!/bin/bash
#
# Advanced Validator Performance Monitoring Script for Ephemery
# This script provides comprehensive validator monitoring and reporting for Ephemery nodes

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

# Default values
VALIDATOR_API="http://localhost:5064"
BEACON_API="http://localhost:5052"
OUTPUT_DIR="${REPO_ROOT}/validator_metrics"
REPORT_FILE="${OUTPUT_DIR}/validator_report.json"
CONFIG_FILE="${OUTPUT_DIR}/validator_monitor_config.json"
HISTORY_LIMIT=1000
VERBOSE=false
DASHBOARD=false
CHECK_ONLY=false
GENERATE_ALERTS=false
ALERT_THRESHOLD=90

# Help function
function show_help {
  echo -e "${BLUE}Advanced Validator Performance Monitoring for Ephemery${NC}"
  echo ""
  echo "This script provides comprehensive validator monitoring and reporting."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -o, --output DIR       Output directory for metrics (default: ${OUTPUT_DIR})"
  echo "  -v, --validator-api URL Validator API URL (default: ${VALIDATOR_API})"
  echo "  -b, --beacon-api URL   Beacon API URL (default: ${BEACON_API})"
  echo "  -a, --alerts           Generate alerts for underperforming validators"
  echo "  -t, --threshold NUM    Alert threshold percentage (default: ${ALERT_THRESHOLD})"
  echo "  -c, --check            Only check current validator status"
  echo "  -d, --dashboard        Display live dashboard (requires watch command)"
  echo "  --verbose              Enable verbose output"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --dashboard --alerts --threshold 85"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUTPUT_DIR="$2"
      REPORT_FILE="${OUTPUT_DIR}/validator_report.json"
      CONFIG_FILE="${OUTPUT_DIR}/validator_monitor_config.json"
      shift 2
      ;;
    -v|--validator-api)
      VALIDATOR_API="$2"
      shift 2
      ;;
    -b|--beacon-api)
      BEACON_API="$2"
      shift 2
      ;;
    -a|--alerts)
      GENERATE_ALERTS=true
      shift
      ;;
    -t|--threshold)
      ALERT_THRESHOLD="$2"
      shift 2
      ;;
    -c|--check)
      CHECK_ONLY=true
      shift
      ;;
    -d|--dashboard)
      DASHBOARD=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local color="$NC"
  
  case "$level" in
    "INFO") color="$GREEN" ;;
    "WARN") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    "DEBUG") 
      color="$BLUE"
      if [[ "$VERBOSE" != "true" ]]; then
        return
      fi
      ;;
  esac
  
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check dependencies
check_dependencies() {
  log "DEBUG" "Checking dependencies..."
  
  if ! command -v jq &> /dev/null; then
    log "ERROR" "jq is required but not installed. Please install jq to continue."
    exit 1
  fi
  
  if [[ "$DASHBOARD" == "true" ]] && ! command -v watch &> /dev/null; then
    log "ERROR" "watch is required for dashboard mode but not installed."
    exit 1
  fi
  
  if ! command -v curl &> /dev/null; then
    log "ERROR" "curl is required but not installed."
    exit 1
  fi
  
  log "DEBUG" "All dependencies are installed."
}

# Initialize or load configuration
init_config() {
  log "DEBUG" "Initializing configuration..."
  
  if [[ -f "$CONFIG_FILE" ]]; then
    log "INFO" "Loading existing configuration from $CONFIG_FILE"
    local config=$(cat "$CONFIG_FILE")
    # Extract values from config if needed
  else
    log "INFO" "Creating new configuration file"
    cat > "$CONFIG_FILE" << EOF
{
  "validator_api": "${VALIDATOR_API}",
  "beacon_api": "${BEACON_API}",
  "history_limit": ${HISTORY_LIMIT},
  "alert_threshold": ${ALERT_THRESHOLD},
  "alert_destinations": [
    {
      "type": "file",
      "path": "${OUTPUT_DIR}/validator_alerts.log"
    }
  ],
  "metrics_enabled": true,
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
  fi
}

# Function to get validator metrics
get_validator_metrics() {
  log "INFO" "Fetching validator metrics..."
  
  # Get validator statuses
  local validator_status
  validator_status=$(curl -s "${VALIDATOR_API}/lighthouse/validators" 2>/dev/null)
  
  if [[ -z "$validator_status" ]]; then
    log "ERROR" "Failed to get validator status from ${VALIDATOR_API}"
    return 1
  fi
  
  log "DEBUG" "Successfully fetched validator status"
  
  # Get beacon metrics for additional information
  local beacon_metrics
  beacon_metrics=$(curl -s "${BEACON_API}/eth/v1/beacon/states/head/validators" 2>/dev/null)
  
  if [[ -z "$beacon_metrics" ]]; then
    log "WARN" "Failed to get beacon metrics from ${BEACON_API}"
  else
    log "DEBUG" "Successfully fetched beacon metrics"
  fi
  
  # Process validator status and metrics
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local active_validators=$(echo "$validator_status" | jq -r 'length')
  
  log "INFO" "Found $active_validators active validators"
  
  # Create metrics report
  local report="{
    \"timestamp\": \"$timestamp\",
    \"active_validators\": $active_validators,
    \"validators\": $validator_status"
  
  if [[ -n "$beacon_metrics" ]]; then
    report+=",
    \"beacon_data\": $beacon_metrics"
  fi
  
  report+="
  }"
  
  # Save report to file
  echo "$report" > "$REPORT_FILE"
  log "INFO" "Validator metrics saved to $REPORT_FILE"
  
  # Update historical data
  update_history "$report"
  
  return 0
}

# Function to update historical metrics
update_history() {
  local report="$1"
  local history_file="${OUTPUT_DIR}/validator_history.json"
  
  log "DEBUG" "Updating historical data..."
  
  # Create or load history file
  if [[ ! -f "$history_file" ]]; then
    echo "[]" > "$history_file"
  fi
  
  # Read existing history
  local history=$(cat "$history_file")
  
  # Add new data point
  local timestamp=$(echo "$report" | jq -r '.timestamp')
  local active_count=$(echo "$report" | jq -r '.active_validators')
  
  # Calculate performance metrics
  local performance=$(echo "$report" | jq -r '.validators | map(select(.balance != null)) | map(.balance) | add / length')
  
  # Create history entry
  local entry="{
    \"timestamp\": \"$timestamp\",
    \"active_validators\": $active_count,
    \"average_balance\": $performance
  }"
  
  # Append to history and limit size
  local updated_history=$(echo "$history" | jq --argjson entry "$entry" '. + [$entry] | sort_by(.timestamp) | .[-'"$HISTORY_LIMIT"':]')
  echo "$updated_history" > "$history_file"
  
  log "DEBUG" "Historical data updated"
}

# Function to analyze validator performance
analyze_performance() {
  log "INFO" "Analyzing validator performance..."
  
  if [[ ! -f "$REPORT_FILE" ]]; then
    log "ERROR" "Report file not found: $REPORT_FILE"
    return 1
  fi
  
  local report=$(cat "$REPORT_FILE")
  local validators=$(echo "$report" | jq -r '.validators')
  
  # Calculate average balance
  local avg_balance=$(echo "$validators" | jq -r 'map(select(.balance != null)) | map(.balance) | add / length')
  log "INFO" "Average validator balance: $avg_balance ETH"
  
  # Find underperforming validators
  if [[ "$GENERATE_ALERTS" == "true" ]]; then
    log "INFO" "Checking for underperforming validators (threshold: ${ALERT_THRESHOLD}%)..."
    
    # Create alerts directory
    local alerts_dir="${OUTPUT_DIR}/alerts"
    mkdir -p "$alerts_dir"
    
    # Calculate performance threshold
    local threshold=$(echo "$avg_balance * $ALERT_THRESHOLD / 100" | bc -l)
    log "DEBUG" "Performance threshold: $threshold ETH"
    
    # Find validators below threshold
    local underperforming=$(echo "$validators" | jq --arg threshold "$threshold" 'map(select(.balance != null and (.balance | tonumber) < ($threshold | tonumber)))')
    local count=$(echo "$underperforming" | jq -r 'length')
    
    if [[ "$count" -gt 0 ]]; then
      log "WARN" "Found $count underperforming validators"
      
      # Generate alert
      local alert_file="${alerts_dir}/alert_$(date +%Y%m%d%H%M%S).json"
      cat > "$alert_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "alert_type": "underperforming_validators",
  "threshold": $threshold,
  "average_balance": $avg_balance,
  "affected_validators": $underperforming
}
EOF
      log "INFO" "Alert generated: $alert_file"
    else
      log "INFO" "No underperforming validators found"
    fi
  fi
  
  return 0
}

# Function to display dashboard
display_dashboard() {
  log "INFO" "Preparing dashboard display..."
  
  if [[ ! -f "$REPORT_FILE" ]]; then
    log "ERROR" "Report file not found: $REPORT_FILE"
    return 1
  fi
  
  local report=$(cat "$REPORT_FILE")
  local validators=$(echo "$report" | jq -r '.validators')
  local timestamp=$(echo "$report" | jq -r '.timestamp')
  local active_count=$(echo "$report" | jq -r '.active_validators')
  
  # Clear screen
  clear
  
  # Print header
  echo -e "${CYAN}===========================================${NC}"
  echo -e "${CYAN}  EPHEMERY VALIDATOR PERFORMANCE MONITOR  ${NC}"
  echo -e "${CYAN}===========================================${NC}"
  echo ""
  echo -e "${GREEN}Time: $(date --date="$timestamp" '+%Y-%m-%d %H:%M:%S UTC')${NC}"
  echo -e "${GREEN}Active Validators: $active_count${NC}"
  echo ""
  
  # Print validator summary
  echo -e "${YELLOW}VALIDATOR SUMMARY${NC}"
  echo -e "${YELLOW}----------------${NC}"
  
  # Calculate average balance
  local avg_balance=$(echo "$validators" | jq -r 'map(select(.balance != null)) | map(.balance) | add / length')
  echo -e "Average Balance: ${CYAN}$avg_balance ETH${NC}"
  
  # Get history file for trend
  local history_file="${OUTPUT_DIR}/validator_history.json"
  if [[ -f "$history_file" ]]; then
    local history=$(cat "$history_file")
    local history_count=$(echo "$history" | jq -r 'length')
    
    if [[ "$history_count" -gt 1 ]]; then
      local prev_avg=$(echo "$history" | jq -r '.[-2].average_balance')
      local change=$(echo "$avg_balance - $prev_avg" | bc -l)
      
      if (( $(echo "$change > 0" | bc -l) )); then
        echo -e "Balance Trend: ${GREEN}↑ +$change ETH${NC}"
      elif (( $(echo "$change < 0" | bc -l) )); then
        echo -e "Balance Trend: ${RED}↓ $change ETH${NC}"
      else
        echo -e "Balance Trend: ${YELLOW}→ No change${NC}"
      fi
    fi
  fi
  
  echo ""
  
  # Print validator status distribution
  echo -e "${YELLOW}VALIDATOR STATUS DISTRIBUTION${NC}"
  echo -e "${YELLOW}----------------------------${NC}"
  
  local active=$(echo "$validators" | jq -r 'map(select(.state == "active")) | length')
  local pending=$(echo "$validators" | jq -r 'map(select(.state == "pending")) | length')
  local exiting=$(echo "$validators" | jq -r 'map(select(.state == "exiting")) | length')
  local slashed=$(echo "$validators" | jq -r 'map(select(.state == "slashed")) | length')
  
  echo -e "Active:  ${GREEN}$active${NC}"
  echo -e "Pending: ${YELLOW}$pending${NC}"
  echo -e "Exiting: ${BLUE}$exiting${NC}"
  echo -e "Slashed: ${RED}$slashed${NC}"
  
  echo ""
  
  # Print performance indicators
  echo -e "${YELLOW}PERFORMANCE INDICATORS${NC}"
  echo -e "${YELLOW}----------------------${NC}"
  
  # Calculate metrics from history if available
  if [[ -f "$history_file" && $(echo "$history" | jq -r 'length') -gt 0 ]]; then
    # Calculate attestation effectiveness (if available)
    if echo "$validators" | jq -e '.[0].attestation_hits' > /dev/null 2>&1; then
      local total_hits=$(echo "$validators" | jq -r 'map(.attestation_hits) | add')
      local total_misses=$(echo "$validators" | jq -r 'map(.attestation_misses) | add')
      local effectiveness=$(echo "scale=2; $total_hits * 100 / ($total_hits + $total_misses)" | bc -l)
      
      echo -e "Attestation Effectiveness: ${CYAN}${effectiveness}%${NC}"
    fi
    
    # Calculate balance gain over time
    local oldest_point=$(echo "$history" | jq -r '.[0]')
    local newest_point=$(echo "$history" | jq -r '.[-1]')
    
    local oldest_balance=$(echo "$oldest_point" | jq -r '.average_balance')
    local newest_balance=$(echo "$newest_point" | jq -r '.average_balance')
    
    local oldest_time=$(echo "$oldest_point" | jq -r '.timestamp')
    local newest_time=$(echo "$newest_point" | jq -r '.timestamp')
    
    local balance_change=$(echo "$newest_balance - $oldest_balance" | bc -l)
    
    # Convert timestamps to seconds
    local oldest_seconds=$(date --date="$oldest_time" +%s)
    local newest_seconds=$(date --date="$newest_time" +%s)
    
    # Calculate time difference in hours
    local hours_diff=$(echo "($newest_seconds - $oldest_seconds) / 3600" | bc)
    
    if [[ "$hours_diff" -gt 0 ]]; then
      local hourly_gain=$(echo "scale=6; $balance_change / $hours_diff" | bc -l)
      
      if (( $(echo "$balance_change > 0" | bc -l) )); then
        echo -e "Balance change: ${GREEN}+$balance_change ETH${NC} over $hours_diff hours"
        echo -e "Hourly average: ${GREEN}+$hourly_gain ETH/h${NC}"
      else
        echo -e "Balance change: ${RED}$balance_change ETH${NC} over $hours_diff hours"
        echo -e "Hourly average: ${RED}$hourly_gain ETH/h${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}Insufficient history data for performance analysis${NC}"
  fi
  
  echo ""
  echo -e "${CYAN}===========================================${NC}"
  echo -e "${YELLOW}Press Ctrl+C to exit dashboard view${NC}"
}

# Main execution
check_dependencies
init_config

if [[ "$CHECK_ONLY" == "true" ]]; then
  log "INFO" "Checking current validator status"
  if get_validator_metrics; then
    log "INFO" "Validator status check complete"
    analyze_performance
  fi
  exit $?
fi

if [[ "$DASHBOARD" == "true" ]]; then
  log "INFO" "Starting dashboard mode"
  
  # Create dashboard update function
  dashboard_update() {
    get_validator_metrics > /dev/null 2>&1
    analyze_performance > /dev/null 2>&1
    display_dashboard
  }
  
  # Export the function for watch
  export -f dashboard_update
  export -f display_dashboard
  export -f log
  export OUTPUT_DIR
  export REPORT_FILE
  
  # Run using watch for automatic updates
  watch -n 60 -c "dashboard_update"
  exit 0
fi

# Normal execution - collect metrics once
log "INFO" "Starting validator performance collection"
if get_validator_metrics; then
  log "INFO" "Validator metrics collection complete"
  analyze_performance
  
  # Display performance summary
  if [[ -f "$REPORT_FILE" ]]; then
    local report=$(cat "$REPORT_FILE")
    local validators=$(echo "$report" | jq -r '.validators')
    local active_count=$(echo "$report" | jq -r '.active_validators')
    
    log "INFO" "Active validators: $active_count"
    log "INFO" "Report saved to: $REPORT_FILE"
    log "INFO" "To view the dashboard, run with --dashboard option"
  fi
fi 