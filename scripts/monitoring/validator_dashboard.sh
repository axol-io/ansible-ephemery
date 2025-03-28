#!/bin/bash
# Version: 1.0.0
#
# Enhanced Validator Status Dashboard for Ephemery
# ================================================
# This script provides a comprehensive dashboard for monitoring validator performance,
# visualizing metrics, and displaying advanced analytics for Ephemery validators.
# It integrates with the advanced_validator_monitoring.sh script for data collection.

set -e

# Color definitions
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
GRAY="\033[90m"
WHITE="\033[97m"
BG_BLUE="\033[44m"
BG_GREEN="\033[42m"
BG_RED="\033[41m"
BG_YELLOW="\033[43m"

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common functions if available
COMMON_SCRIPT="${REPO_ROOT}/scripts/core/common.sh"
if [[ -f "$COMMON_SCRIPT" ]]; then
    source "$COMMON_SCRIPT"
fi

# Default configuration
BASE_DIR=${BASE_DIR:-"${REPO_ROOT}"}
CONFIG_DIR="${BASE_DIR}/config"
DATA_DIR="${BASE_DIR}/data"
METRICS_DIR="${DATA_DIR}/metrics"
OUTPUT_DIR="${REPO_ROOT}/validator_metrics"
REPORT_FILE="${OUTPUT_DIR}/validator_report.json"
CONFIG_FILE="${OUTPUT_DIR}/validator_monitor_config.json"
BEACON_API="http://localhost:5052"
VALIDATOR_API="http://localhost:5064"
REFRESH_INTERVAL=10
SHOW_ALERTS=true
SHOW_HISTORY=true
SHOW_ANALYTICS=true
DETAILED_VIEW=false
COMPACT_VIEW=false
FULL_VIEW=false
ALERT_THRESHOLD=90
ADVANCED_MONITOR_SCRIPT="${SCRIPT_DIR}/advanced_validator_monitoring.sh"
ANALYSIS_SCRIPT="${SCRIPT_DIR}/validator_performance_analysis.sh"

# Print header function
print_header() {
    local title="$1"
    local width=$(tput cols)
    local header="${BG_BLUE}${WHITE}${BOLD} $title ${RESET}"
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local extra_space=$(( (width - ${#title} - 2) % 2 ))

    printf "%s%s%s%s%s\n" \
        "${BG_BLUE}${WHITE}" \
        "$(printf ' %.0s' $(seq 1 $padding))" \
        "$title" \
        "$(printf ' %.0s' $(seq 1 $(( padding + extra_space ))))" \
        "${RESET}"
fi

# Print section header
print_section() {
    local section="$1"
    echo -e "${BOLD}${BLUE}=== $section ===${RESET}"
fi

# Print status with color
print_status() {
    local status="$1"
    local details="$2"

    case "$status" in
        "active")
            echo -e "${GREEN}${BOLD}$status${RESET} $details"
            ;;
        "pending")
            echo -e "${YELLOW}${BOLD}$status${RESET} $details"
            ;;
        "error"|"slashed"|"critical")
            echo -e "${RED}${BOLD}$status${RESET} $details"
            ;;
        "warning")
            echo -e "${YELLOW}${BOLD}$status${RESET} $details"
            ;;
        *)
            echo -e "${BOLD}$status${RESET} $details"
            ;;
    esac
fi

# Print progress bar
print_progress_bar() {
    local value=$1
    local max=$2
    local length=$3
    local title=$4

    local percent=$((value * 100 / max))
    local filled=$((value * length / max))
    local empty=$((length - filled))

    printf "${BOLD}%-15s${RESET} [" "$title"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%3d%%${RESET}\n" "$percent"
fi

# Draw horizontal line
draw_line() {
    local width=$(tput cols)
    printf "%${width}s\n" | tr ' ' '─'
fi

# Check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${RESET}"
        echo "Please install jq to use this dashboard:"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  Red Hat/CentOS: sudo yum install jq"
        echo "  macOS: brew install jq"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed.${RESET}"
        exit 1
    fi
fi

# Fetch validator data
fetch_validator_data() {
    # Ensure metrics directory exists
    mkdir -p "$OUTPUT_DIR"

    # Run the advanced validator monitoring script if it exists
    if [[ -f "$ADVANCED_MONITOR_SCRIPT" ]]; then
        bash "$ADVANCED_MONITOR_SCRIPT" --output "$OUTPUT_DIR" \
            --validator-api "$VALIDATOR_API" \
            --beacon-api "$BEACON_API" \
            --alerts --threshold "$ALERT_THRESHOLD" \
            --check
    else
        echo -e "${YELLOW}Warning: Advanced validator monitoring script not found at $ADVANCED_MONITOR_SCRIPT${RESET}"
        # Try to fetch data directly if script not available
        fetch_validators_directly
    fi
fi

# Fetch validators directly from beacon API if monitoring script not available
fetch_validators_directly() {
    local temp_file="${OUTPUT_DIR}/validators_temp.json"
    curl -s "${BEACON_API}/eth/v1/beacon/states/head/validators" > "$temp_file"

    if [[ -f "$temp_file" ]]; then
        jq '.data' "$temp_file" > "${REPORT_FILE}"
        rm "$temp_file"
    else
        echo -e "${RED}Error: Failed to fetch validator data${RESET}"
        touch "${REPORT_FILE}"
        echo "[]" > "${REPORT_FILE}"
    fi
fi

# Show validator summary
show_validator_summary() {
    if [[ ! -f "$REPORT_FILE" ]]; then
        echo -e "${RED}No validator data found. Please run the monitoring script first.${RESET}"
        return
    fi

    local active=$(jq '[.validators[] | select(.status == "active")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local pending=$(jq '[.validators[] | select(.status == "pending")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local exiting=$(jq '[.validators[] | select(.status == "exiting")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local slashed=$(jq '[.validators[] | select(.status == "slashed")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local total=$(jq '.validators | length' "$REPORT_FILE" 2>/dev/null || echo "0")

    print_section "Validator Summary"
    echo -e "${BOLD}Total Validators:${RESET} $total"
    echo -e "${GREEN}${BOLD}Active:${RESET} $active"
    echo -e "${YELLOW}${BOLD}Pending:${RESET} $pending"
    echo -e "${YELLOW}${BOLD}Exiting:${RESET} $exiting"
    echo -e "${RED}${BOLD}Slashed:${RESET} $slashed"

    # Show balance information if available
    local avg_balance=$(jq '.average_balance // 0' "$REPORT_FILE" 2>/dev/null || echo "0")
    local avg_balance_eth=$(echo "scale=4; $avg_balance / 1000000000" | bc)

    if [[ "$avg_balance" != "0" ]]; then
        echo -e "\n${BOLD}Average Balance:${RESET} ${avg_balance_eth} ETH"
    fi

    # Show effectiveness if available
    local avg_effectiveness=$(jq '.average_effectiveness // 0' "$REPORT_FILE" 2>/dev/null || echo "0")
    if [[ "$avg_effectiveness" != "0" ]]; then
        echo -e "${BOLD}Attestation Effectiveness:${RESET} ${avg_effectiveness}%"
    fi
fi

# Show detailed validator information
show_validator_details() {
    if [[ ! -f "$REPORT_FILE" ]]; then
        echo -e "${RED}No validator data found. Please run the monitoring script first.${RESET}"
        return
    }

    print_section "Validator Details"

    # Get validators, limit to first 10 for readability
    local validators=$(jq -r '.validators[:10] | .[] | "\(.index) \(.balance) \(.status)"' "$REPORT_FILE" 2>/dev/null)

    if [[ -z "$validators" ]]; then
        echo -e "${YELLOW}No validator details available${RESET}"
        return
    }

    printf "${BOLD}%-10s %-15s %-10s${RESET}\n" "Index" "Balance (ETH)" "Status"
    draw_line

    while read -r index balance status; do
        local balance_eth=$(echo "scale=4; $balance / 1000000000" | bc)
        printf "%-10s %-15s " "$index" "$balance_eth"
        print_status "$status" ""
    done <<< "$validators"

    local total=$(jq '.validators | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    if [[ $total -gt 10 ]]; then
        echo -e "\n${GRAY}(Showing 10 of $total validators)${RESET}"
    fi
fi

# Show recent alerts
show_alerts() {
    local alerts_file="${OUTPUT_DIR}/validator_alerts.json"

    if [[ ! -f "$alerts_file" ]]; then
        echo -e "${YELLOW}No alerts file found.${RESET}"
        return
    }

    print_section "Recent Alerts"

    local alerts=$(jq -r '.alerts[:5] | .[] | "\(.timestamp) \(.severity) \(.message)"' "$alerts_file" 2>/dev/null)

    if [[ -z "$alerts" ]]; then
        echo -e "${GREEN}No recent alerts${RESET}"
        return
    }

    while read -r timestamp severity message; do
        echo -e "${GRAY}$timestamp${RESET} - $(print_status "$severity" "$message")"
    done <<< "$alerts"
fi

# Show performance analytics
show_performance_analytics() {
    if [[ ! -f "$REPORT_FILE" ]]; then
        echo -e "${RED}No validator data found. Please run the monitoring script first.${RESET}"
        return
    }

    print_section "Performance Analytics"

    # Extract metrics if available
    local attestation_rate=$(jq '.attestation_rate // 0' "$REPORT_FILE" 2>/dev/null || echo "0")
    local proposal_rate=$(jq '.proposal_rate // 0' "$REPORT_FILE" 2>/dev/null || echo "0")
    local sync_participation=$(jq '.sync_participation // 0' "$REPORT_FILE" 2>/dev/null || echo "0")

    if [[ "$attestation_rate" != "0" ]]; then
        print_progress_bar "$attestation_rate" 100 20 "Attestations"
    else
        echo -e "${GRAY}Attestation data not available${RESET}"
    fi

    if [[ "$proposal_rate" != "0" ]]; then
        print_progress_bar "$proposal_rate" 100 20 "Proposals"
    else
        echo -e "${GRAY}Proposal data not available${RESET}"
    fi

    if [[ "$sync_participation" != "0" ]]; then
        print_progress_bar "$sync_participation" 100 20 "Sync Committee"
    else
        echo -e "${GRAY}Sync committee data not available${RESET}"
    fi

    # Show estimated rewards if available
    local estimated_daily=$(jq '.estimated_daily_rewards // 0' "$REPORT_FILE" 2>/dev/null || echo "0")
    if [[ "$estimated_daily" != "0" ]]; then
        echo -e "\n${BOLD}Estimated Daily Rewards:${RESET} ${estimated_daily} ETH"
    fi
fi

# Print help function
function show_help {
    echo -e "${BLUE}Enhanced Validator Status Dashboard for Ephemery${NC}"
    echo ""
    echo "This script provides a comprehensive dashboard for monitoring validator performance."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -b, --beacon URL      Beacon node API URL (default: ${BEACON_API})"
    echo "  -v, --validator URL   Validator API URL (default: ${VALIDATOR_API})"
    echo "  -r, --refresh N       Refresh interval in seconds (default: ${REFRESH_INTERVAL})"
    echo "  -c, --compact         Use compact view (summary only)"
    echo "  -d, --detailed        Use detailed view (includes validator details)"
    echo "  -f, --full            Use full view with all information"
    echo "  -a, --analyze         Generate historical performance analysis report"
    echo "  --period PERIOD       Analysis period (1d, 7d, 30d, 90d, all) for historical analysis"
    echo "  --charts              Generate performance charts (requires gnuplot)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start dashboard with default settings"
    echo "  $0 --detailed         # Start dashboard with detailed view"
    echo "  $0 --analyze --period 30d --charts # Generate performance analysis for last 30 days with charts"
fi

# Parse command-line arguments
parse_args() {
    GENERATE_ANALYSIS=false
    ANALYSIS_PERIOD="7d"
    GENERATE_CHARTS=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--beacon)
                BEACON_API="$2"
                shift 2
                ;;
            -v|--validator)
                VALIDATOR_API="$2"
                shift 2
                ;;
            -r|--refresh)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -c|--compact)
                COMPACT_VIEW=true
                DETAILED_VIEW=false
                FULL_VIEW=false
                shift
                ;;
            -d|--detailed)
                DETAILED_VIEW=true
                COMPACT_VIEW=false
                FULL_VIEW=false
                shift
                ;;
            -f|--full)
                FULL_VIEW=true
                DETAILED_VIEW=false
                COMPACT_VIEW=false
                shift
                ;;
            -a|--analyze)
                GENERATE_ANALYSIS=true
                shift
                ;;
            --period)
                ANALYSIS_PERIOD="$2"
                shift 2
                ;;
            --charts)
                GENERATE_CHARTS=true
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

    # Set default view if none specified
    if [[ "$COMPACT_VIEW" == "false" && "$DETAILED_VIEW" == "false" && "$FULL_VIEW" == "false" ]]; then
        FULL_VIEW=true
    fi
fi

# Display the dashboard once
display_dashboard_once() {
    clear
    print_header "Ephemery Validator Dashboard"
    echo -e "Beacon API: ${CYAN}${BEACON_API}${RESET} | Validator API: ${CYAN}${VALIDATOR_API}${RESET}"
    echo -e "Last Updated: ${GRAY}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    draw_line

    fetch_validator_data

    show_validator_summary

    if [[ "$DETAILED_VIEW" == "true" || "$FULL_VIEW" == "true" ]]; then
        echo
        show_validator_details
    fi

    if [[ "$SHOW_ALERTS" == "true" ]]; then
        echo
        show_alerts
    fi

    if [[ "$SHOW_ANALYTICS" == "true" ]]; then
        echo
        show_performance_analytics
    fi

    if [[ "$FULL_VIEW" == "true" && -f "$ADVANCED_MONITOR_SCRIPT" ]]; then
        echo
        print_section "Advanced Options"
        echo -e "For detailed monitoring, run: ${CYAN}${ADVANCED_MONITOR_SCRIPT} --dashboard${RESET}"
    fi

    # Show footer
    echo
    draw_line
    echo -e "Press ${BOLD}Ctrl+C${RESET} to exit | Refresh: ${REFRESH_INTERVAL}s | Alert Threshold: ${ALERT_THRESHOLD}%"
fi

# Run the dashboard with continuous updates
run_dashboard() {
    check_dependencies

    if [[ "$REFRESH_INTERVAL" -eq 0 ]]; then
        display_dashboard_once
    else
        while true; do
            display_dashboard_once
            sleep "$REFRESH_INTERVAL"
        done
    fi
fi

# Main function
main() {
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE} Ephemery Enhanced Validator Dashboard${NC}"
    echo -e "${BLUE}=============================================${NC}"

    # Parse command line arguments
    parse_args "$@"

    # Check if we should generate historical analysis
    if [[ "$GENERATE_ANALYSIS" == "true" ]]; then
        echo -e "${BLUE}Generating historical performance analysis...${NC}"

        ANALYSIS_CMD="$ANALYSIS_SCRIPT --period $ANALYSIS_PERIOD"

        if [[ "$GENERATE_CHARTS" == "true" ]]; then
            ANALYSIS_CMD="$ANALYSIS_CMD --charts"
        fi

        echo "Running: $ANALYSIS_CMD"
        eval "$ANALYSIS_CMD"

        # Exit after analysis is complete
        exit 0
    fi

    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"

    # Run the dashboard
    run_dashboard
fi

# Execute main function
main "$@"
