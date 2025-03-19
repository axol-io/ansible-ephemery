#!/bin/bash

# Lido CSM Monitoring Script for Ephemery
# =======================================
#
# This script provides monitoring capabilities for the Lido CSM integration
# with Ephemery nodes. It can display status, performance metrics, and
# manage monitoring dashboards.
#
# Version: 0.1.0

set -e

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_DIR="${REPO_ROOT}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Warning: Path configuration not found. Using default settings."
  # Define default settings
  EPHEMERY_BASE_DIR="${HOME}/ephemery"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
fi

# Color definitions if not defined by common utilities
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
RED=${RED:-'\033[0;31m'}
BLUE=${BLUE:-'\033[0;34m'}
CYAN=${CYAN:-'\033[0;36m'}
PURPLE=${PURPLE:-'\033[0;35m'}
NC=${NC:-'\033[0m'}

# CSM-specific defaults
CSM_CONTAINER="ephemery-lido-csm"
CSM_DATA_DIR="${EPHEMERY_DATA_DIR}/lido-csm"
CSM_CONFIG_DIR="${EPHEMERY_CONFIG_DIR}/lido-csm"
CSM_LOGS_DIR="${EPHEMERY_LOGS_DIR}/lido-csm"
CSM_API_PORT=9000
CSM_METRICS_PORT=8888
CSM_API_ENDPOINT="http://localhost:${CSM_API_PORT}"
CSM_METRICS_ENDPOINT="http://localhost:${CSM_METRICS_PORT}/metrics"

# Script-specific defaults
DEBUG_MODE=false
VERBOSE=false
CONTINUOUS=false
INTERVAL=30
OPERATION="status"
DASHBOARD=false
GRAFANA_PORT=3000

# Help function
function show_help {
  echo -e "${BLUE}Lido CSM Monitoring for Ephemery${NC}"
  echo ""
  echo "This script provides monitoring capabilities for the Lido CSM integration."
  echo ""
  echo "Usage: $0 [operation] [options]"
  echo ""
  echo "Operations:"
  echo "  status        Show current CSM status (default)"
  echo "  performance   Show performance metrics"
  echo "  validators    Show CSM validators status"
  echo "  bond          Show bond status and health"
  echo "  queue         Show stake distribution queue status"
  echo "  ejector       Show ejector status and metrics"
  echo "  dashboard     Launch monitoring dashboard"
  echo ""
  echo "Options:"
  echo "  --api-endpoint URL     CSM API endpoint (default: ${CSM_API_ENDPOINT})"
  echo "  --metrics-endpoint URL CSM metrics endpoint (default: ${CSM_METRICS_ENDPOINT})"
  echo "  -c, --continuous       Enable continuous monitoring"
  echo "  -i, --interval SEC     Monitoring interval in seconds (default: ${INTERVAL})"
  echo "  --grafana-port PORT    Grafana port for dashboard (default: ${GRAFANA_PORT})"
  echo "  -v, --verbose          Enable verbose output"
  echo "  --debug                Enable debug output"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 status"
  echo "  $0 performance --continuous --interval 10"
  echo "  $0 validators --verbose"
  echo "  $0 dashboard"
}

# Parse command line arguments
if [[ $# -gt 0 ]]; then
  # First argument might be an operation
  case "$1" in
    status | performance | validators | bond | queue | ejector | dashboard)
      OPERATION="$1"
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
  esac
fi

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-endpoint)
      CSM_API_ENDPOINT="$2"
      shift 2
      ;;
    --metrics-endpoint)
      CSM_METRICS_ENDPOINT="$2"
      shift 2
      ;;
    -c | --continuous)
      CONTINUOUS=true
      shift
      ;;
    -i | --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --grafana-port)
      GRAFANA_PORT="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      echo ""
      show_help
      exit 1
      ;;
  esac
done

# Function to print debug messages
function debug_log {
  if [[ "${DEBUG_MODE}" == true ]]; then
    echo -e "${YELLOW}[DEBUG] $1${NC}"
  fi
}

# Function to check if CSM container is running
function check_csm_container {
  debug_log "Checking if CSM container is running"
  if ! docker ps --format '{{.Names}}' | grep -q "^${CSM_CONTAINER}$"; then
    echo -e "${RED}Error: CSM container is not running: ${CSM_CONTAINER}${NC}"
    echo "Please start the CSM container or run the setup script first:"
    echo "  ${REPO_ROOT}/scripts/deployment/setup_lido_csm.sh"
    exit 1
  fi
}

# Function to fetch CSM API status
function fetch_csm_status {
  debug_log "Fetching CSM status from API: ${CSM_API_ENDPOINT}/status"
  local status
  status=$(curl -s "${CSM_API_ENDPOINT}/status" 2>/dev/null)
  if [[ $? -ne 0 || -z "${status}" ]]; then
    echo -e "${RED}Error: Failed to fetch CSM status from API${NC}"
    return 1
  fi
  echo "${status}"
}

# Function to fetch CSM metrics
function fetch_csm_metrics {
  debug_log "Fetching CSM metrics from: ${CSM_METRICS_ENDPOINT}"
  local metrics
  metrics=$(curl -s "${CSM_METRICS_ENDPOINT}" 2>/dev/null)
  if [[ $? -ne 0 || -z "${metrics}" ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi
  echo "${metrics}"
}

# Function to extract metric value from metrics output
function extract_metric {
  local metrics=$1
  local metric_name=$2

  debug_log "Extracting metric: ${metric_name}"

  local value
  value=$(echo "${metrics}" | grep "^${metric_name} " | cut -d' ' -f2)

  if [[ -z "${value}" ]]; then
    debug_log "Metric not found: ${metric_name}"
    echo "N/A"
  else
    echo "${value}"
  fi
}

# Function to show CSM status
function show_csm_status {
  echo -e "${BLUE}Lido CSM Status${NC}"
  echo "---------------------"

  # Check container status
  local container_status
  container_status=$(docker ps --filter "name=${CSM_CONTAINER}" --format "{{.Status}}")

  if [[ -z "${container_status}" ]]; then
    echo -e "${RED}Container Status: Not running${NC}"
    return 1
  else
    echo -e "${GREEN}Container Status: Running${NC} (${container_status})"
  fi

  # Fetch CSM status from API
  local status
  status=$(fetch_csm_status)

  if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}API Status: Not responding${NC}"
  else
    echo -e "${GREEN}API Status: Healthy${NC}"

    # Parse status JSON if available
    if command -v jq &>/dev/null; then
      local version
      local uptime
      local connection_status

      version=$(echo "${status}" | jq -r '.version // "N/A"')
      uptime=$(echo "${status}" | jq -r '.uptime // "N/A"')
      connection_status=$(echo "${status}" | jq -r '.connection_status // "N/A"')

      echo "Version: ${version}"
      echo "Uptime: ${uptime}"
      echo "Connection Status: ${connection_status}"
    else
      echo "${status}"
    fi
  fi

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}Metrics Status: Not available${NC}"
  else
    echo -e "${GREEN}Metrics Status: Available${NC}"

    # Extract basic metrics
    local active_validators
    local pending_validators
    local bond_health

    active_validators=$(extract_metric "${metrics}" "csm_validators_active")
    pending_validators=$(extract_metric "${metrics}" "csm_validators_pending")
    bond_health=$(extract_metric "${metrics}" "csm_bond_health_percentage")

    echo "Active Validators: ${active_validators}"
    echo "Pending Validators: ${pending_validators}"
    echo "Bond Health: ${bond_health}%"
  fi

  echo ""
}

# Function to show CSM performance metrics
function show_csm_performance {
  echo -e "${BLUE}Lido CSM Performance Metrics${NC}"
  echo "------------------------------"

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi

  # Extract performance metrics
  local attestation_effectiveness
  local proposal_effectiveness
  local missed_attestations
  local missed_proposals
  local average_inclusion_distance
  local total_rewards
  local validator_balance

  attestation_effectiveness=$(extract_metric "${metrics}" "csm_attestation_effectiveness_percentage")
  proposal_effectiveness=$(extract_metric "${metrics}" "csm_proposal_effectiveness_percentage")
  missed_attestations=$(extract_metric "${metrics}" "csm_missed_attestations_total")
  missed_proposals=$(extract_metric "${metrics}" "csm_missed_proposals_total")
  average_inclusion_distance=$(extract_metric "${metrics}" "csm_attestation_inclusion_distance_average")
  total_rewards=$(extract_metric "${metrics}" "csm_rewards_total")
  validator_balance=$(extract_metric "${metrics}" "csm_validator_balance_total")

  echo -e "Attestation Effectiveness: ${CYAN}${attestation_effectiveness}%${NC}"
  echo -e "Proposal Effectiveness: ${CYAN}${proposal_effectiveness}%${NC}"
  echo -e "Missed Attestations: ${YELLOW}${missed_attestations}${NC}"
  echo -e "Missed Proposals: ${YELLOW}${missed_proposals}${NC}"
  echo -e "Avg Inclusion Distance: ${CYAN}${average_inclusion_distance}${NC}"
  echo -e "Total Rewards: ${GREEN}${total_rewards} ETH${NC}"
  echo -e "Total Validator Balance: ${GREEN}${validator_balance} ETH${NC}"

  # Show additional performance metrics if verbose is enabled
  if [[ "${VERBOSE}" == true ]]; then
    echo ""
    echo "Detailed Performance Metrics:"
    echo "---------------------------"

    local cpu_usage
    local memory_usage
    local disk_usage
    local network_tx
    local network_rx
    local api_request_rate
    local api_error_rate

    cpu_usage=$(extract_metric "${metrics}" "csm_resource_usage_cpu_percentage")
    memory_usage=$(extract_metric "${metrics}" "csm_resource_usage_memory_percentage")
    disk_usage=$(extract_metric "${metrics}" "csm_resource_usage_disk_percentage")
    network_tx=$(extract_metric "${metrics}" "csm_network_tx_bytes_total")
    network_rx=$(extract_metric "${metrics}" "csm_network_rx_bytes_total")
    api_request_rate=$(extract_metric "${metrics}" "csm_api_requests_total")
    api_error_rate=$(extract_metric "${metrics}" "csm_api_errors_total")

    echo -e "CPU Usage: ${CYAN}${cpu_usage}%${NC}"
    echo -e "Memory Usage: ${CYAN}${memory_usage}%${NC}"
    echo -e "Disk Usage: ${CYAN}${disk_usage}%${NC}"
    echo -e "Network TX: ${CYAN}${network_tx} bytes${NC}"
    echo -e "Network RX: ${CYAN}${network_rx} bytes${NC}"
    echo -e "API Request Rate: ${CYAN}${api_request_rate} req/s${NC}"
    echo -e "API Error Rate: ${CYAN}${api_error_rate} err/s${NC}"
  fi

  echo ""
}

# Function to show CSM validators status
function show_csm_validators {
  echo -e "${BLUE}Lido CSM Validators Status${NC}"
  echo "----------------------------"

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi

  # Extract validator metrics
  local active_validators
  local pending_validators
  local total_validators
  local exited_validators
  local slashed_validators

  active_validators=$(extract_metric "${metrics}" "csm_validators_active")
  pending_validators=$(extract_metric "${metrics}" "csm_validators_pending")
  total_validators=$(extract_metric "${metrics}" "csm_validators_total")
  exited_validators=$(extract_metric "${metrics}" "csm_validators_exited")
  slashed_validators=$(extract_metric "${metrics}" "csm_validators_slashed")

  echo -e "Active Validators: ${GREEN}${active_validators}${NC}"
  echo -e "Pending Validators: ${YELLOW}${pending_validators}${NC}"
  echo -e "Total Validators: ${CYAN}${total_validators}${NC}"
  echo -e "Exited Validators: ${PURPLE}${exited_validators}${NC}"
  echo -e "Slashed Validators: ${RED}${slashed_validators}${NC}"

  # Fetch detailed validator status from API
  if [[ "${VERBOSE}" == true ]]; then
    echo ""
    echo "Detailed Validator Status:"
    echo "-------------------------"

    local validators_status
    validators_status=$(curl -s "${CSM_API_ENDPOINT}/validators" 2>/dev/null)

    if [[ $? -ne 0 || -z "${validators_status}" ]]; then
      echo -e "${YELLOW}Detailed status not available from API${NC}"
    else
      # Display detailed validator status if jq is available
      if command -v jq &>/dev/null; then
        echo "${validators_status}" | jq -r '.validators[] | "\(.index): Status: \(.status), Balance: \(.balance) ETH, Effectiveness: \(.effectiveness)%"'
      else
        echo "${validators_status}"
      fi
    fi
  fi

  echo ""
}

# Function to show bond status
function show_bond_status {
  echo -e "${BLUE}Lido CSM Bond Status${NC}"
  echo "---------------------"

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi

  # Extract bond metrics
  local bond_amount
  local bond_health
  local minimum_bond_ratio
  local bond_rebase_count
  local bond_penalty_count
  local excess_bond

  bond_amount=$(extract_metric "${metrics}" "csm_bond_amount_total")
  bond_health=$(extract_metric "${metrics}" "csm_bond_health_percentage")
  minimum_bond_ratio=$(extract_metric "${metrics}" "csm_bond_minimum_ratio")
  bond_rebase_count=$(extract_metric "${metrics}" "csm_bond_rebase_count")
  bond_penalty_count=$(extract_metric "${metrics}" "csm_bond_penalty_count")
  excess_bond=$(extract_metric "${metrics}" "csm_bond_excess_amount")

  # Determine bond health status
  local health_status
  if [[ $(echo "${bond_health} > 90" | bc -l) -eq 1 ]]; then
    health_status="${GREEN}Excellent${NC}"
  elif [[ $(echo "${bond_health} > 70" | bc -l) -eq 1 ]]; then
    health_status="${CYAN}Good${NC}"
  elif [[ $(echo "${bond_health} > 50" | bc -l) -eq 1 ]]; then
    health_status="${YELLOW}Moderate${NC}"
  else
    health_status="${RED}Poor${NC}"
  fi

  echo -e "Bond Amount: ${GREEN}${bond_amount} ETH${NC}"
  echo -e "Bond Health: ${bond_health}% (${health_status})"
  echo -e "Minimum Bond Ratio: ${CYAN}${minimum_bond_ratio}${NC}"
  echo -e "Bond Rebases: ${YELLOW}${bond_rebase_count}${NC}"
  echo -e "Bond Penalties: ${RED}${bond_penalty_count}${NC}"
  echo -e "Excess Bond: ${GREEN}${excess_bond} ETH${NC}"

  # Show additional bond metrics if verbose is enabled
  if [[ "${VERBOSE}" == true ]]; then
    echo ""
    echo "Bond Optimization Analysis:"
    echo "-------------------------"

    local optimal_bond
    local bond_efficiency
    local claim_eligibility
    local risk_factor

    optimal_bond=$(extract_metric "${metrics}" "csm_bond_optimal_amount")
    bond_efficiency=$(extract_metric "${metrics}" "csm_bond_efficiency_percentage")
    claim_eligibility=$(extract_metric "${metrics}" "csm_bond_claim_eligible")
    risk_factor=$(extract_metric "${metrics}" "csm_bond_risk_factor")

    echo -e "Optimal Bond: ${CYAN}${optimal_bond} ETH${NC}"
    echo -e "Bond Efficiency: ${CYAN}${bond_efficiency}%${NC}"
    echo -e "Claim Eligibility: ${claim_eligibility}"
    echo -e "Risk Factor: ${YELLOW}${risk_factor}${NC}"

    # Bond recommendations
    echo ""
    echo "Recommendations:"

    if [[ $(echo "${bond_amount} > ${optimal_bond}" | bc -l) -eq 1 ]]; then
      echo -e "${YELLOW}Your bond amount exceeds the optimal value.${NC}"
      echo -e "${GREEN}Consider claiming excess bond to improve capital efficiency.${NC}"
    elif [[ $(echo "${bond_amount} < ${optimal_bond}" | bc -l) -eq 1 ]]; then
      echo -e "${YELLOW}Your bond amount is below the optimal value.${NC}"
      echo -e "${GREEN}Consider increasing bond to improve health and capacity.${NC}"
    else
      echo -e "${GREEN}Your bond amount is optimal.${NC}"
    fi
  fi

  echo ""
}

# Function to show queue status
function show_queue_status {
  echo -e "${BLUE}Lido CSM Queue Status${NC}"
  echo "----------------------"

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi

  # Extract queue metrics
  local queue_position
  local queue_length
  local queue_wait_time
  local queue_throughput
  local queue_percentile

  queue_position=$(extract_metric "${metrics}" "csm_queue_position")
  queue_length=$(extract_metric "${metrics}" "csm_queue_length")
  queue_wait_time=$(extract_metric "${metrics}" "csm_queue_estimated_wait_time_seconds")
  queue_throughput=$(extract_metric "${metrics}" "csm_queue_throughput_per_day")
  queue_percentile=$(extract_metric "${metrics}" "csm_queue_position_percentile")

  # Convert wait time to days and hours
  local wait_days
  local wait_hours

  if [[ "${queue_wait_time}" != "N/A" ]]; then
    wait_days=$(echo "scale=0; ${queue_wait_time} / 86400" | bc)
    wait_hours=$(echo "scale=0; (${queue_wait_time} % 86400) / 3600" | bc)
  else
    wait_days="N/A"
    wait_hours="N/A"
  fi

  echo -e "Queue Position: ${CYAN}${queue_position}${NC}"
  echo -e "Queue Length: ${YELLOW}${queue_length}${NC}"
  echo -e "Estimated Wait Time: ${CYAN}${wait_days} days, ${wait_hours} hours${NC}"
  echo -e "Queue Throughput: ${GREEN}${queue_throughput} validators/day${NC}"
  echo -e "Position Percentile: ${PURPLE}${queue_percentile}%${NC}"

  # Show additional queue metrics if verbose is enabled
  if [[ "${VERBOSE}" == true ]]; then
    echo ""
    echo "Queue Analytics:"
    echo "--------------"

    local queue_velocity
    local queue_acceleration
    local queue_fluctuation
    local stake_distribution

    queue_velocity=$(extract_metric "${metrics}" "csm_queue_velocity")
    queue_acceleration=$(extract_metric "${metrics}" "csm_queue_acceleration")
    queue_fluctuation=$(extract_metric "${metrics}" "csm_queue_fluctuation_percentage")
    stake_distribution=$(extract_metric "${metrics}" "csm_queue_stake_distribution")

    echo -e "Queue Velocity: ${CYAN}${queue_velocity} positions/day${NC}"
    echo -e "Queue Acceleration: ${CYAN}${queue_acceleration} positions/day²${NC}"
    echo -e "Queue Fluctuation: ${YELLOW}${queue_fluctuation}%${NC}"
    echo -e "Stake Distribution: ${PURPLE}${stake_distribution}${NC}"

    # Forecast
    echo ""
    echo "Forecast:"

    local activation_date
    activation_date=$(date -d "+${wait_days} days +${wait_hours} hours" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")

    echo -e "Estimated Activation Date: ${GREEN}${activation_date}${NC}"

    if [[ $(echo "${queue_acceleration} > 0" | bc -l) -eq 1 ]]; then
      echo -e "${GREEN}Queue is accelerating - wait time may decrease${NC}"
    elif [[ $(echo "${queue_acceleration} < 0" | bc -l) -eq 1 ]]; then
      echo -e "${YELLOW}Queue is decelerating - wait time may increase${NC}"
    else
      echo -e "${CYAN}Queue velocity is stable${NC}"
    fi
  fi

  echo ""
}

# Function to show ejector status
function show_ejector_status {
  echo -e "${BLUE}Lido CSM Ejector Status${NC}"
  echo "------------------------"

  # Fetch metrics
  local metrics
  metrics=$(fetch_csm_metrics)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to fetch CSM metrics${NC}"
    return 1
  fi

  # Extract ejector metrics
  local ejector_enabled
  local ejector_active
  local ejections_processed
  local ejections_pending
  local ejection_success_rate
  local ejection_failure_count

  ejector_enabled=$(extract_metric "${metrics}" "csm_ejector_enabled")
  ejector_active=$(extract_metric "${metrics}" "csm_ejector_active")
  ejections_processed=$(extract_metric "${metrics}" "csm_ejections_processed_total")
  ejections_pending=$(extract_metric "${metrics}" "csm_ejections_pending")
  ejection_success_rate=$(extract_metric "${metrics}" "csm_ejection_success_rate_percentage")
  ejection_failure_count=$(extract_metric "${metrics}" "csm_ejection_failures_total")

  # Convert ejector_enabled and ejector_active to text
  if [[ "${ejector_enabled}" == "1" ]]; then
    ejector_enabled="${GREEN}Enabled${NC}"
  else
    ejector_enabled="${RED}Disabled${NC}"
  fi

  if [[ "${ejector_active}" == "1" ]]; then
    ejector_active="${GREEN}Active${NC}"
  else
    ejector_active="${RED}Inactive${NC}"
  fi

  echo -e "Ejector Status: ${ejector_enabled}, ${ejector_active}"
  echo -e "Ejections Processed: ${CYAN}${ejections_processed}${NC}"
  echo -e "Ejections Pending: ${YELLOW}${ejections_pending}${NC}"
  echo -e "Success Rate: ${GREEN}${ejection_success_rate}%${NC}"
  echo -e "Failures: ${RED}${ejection_failure_count}${NC}"

  # Show additional ejector metrics if verbose is enabled
  if [[ "${VERBOSE}" == true ]]; then
    echo ""
    echo "Ejector Performance:"
    echo "------------------"

    local ejection_rate
    local avg_processing_time
    local resource_usage
    local last_ejection_time
    local recovery_count

    ejection_rate=$(extract_metric "${metrics}" "csm_ejection_rate_per_hour")
    avg_processing_time=$(extract_metric "${metrics}" "csm_ejection_processing_time_average_seconds")
    resource_usage=$(extract_metric "${metrics}" "csm_ejector_resource_usage_percentage")
    last_ejection_time=$(extract_metric "${metrics}" "csm_last_ejection_timestamp_seconds")
    recovery_count=$(extract_metric "${metrics}" "csm_ejector_recovery_operations_total")

    echo -e "Ejection Rate: ${CYAN}${ejection_rate} ejections/hour${NC}"
    echo -e "Avg Processing Time: ${CYAN}${avg_processing_time} seconds${NC}"
    echo -e "Resource Usage: ${YELLOW}${resource_usage}%${NC}"

    # Convert timestamp to readable date if available
    if [[ "${last_ejection_time}" != "N/A" ]]; then
      last_ejection_time=$(date -d "@${last_ejection_time}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
    fi

    echo -e "Last Ejection: ${PURPLE}${last_ejection_time}${NC}"
    echo -e "Recovery Operations: ${YELLOW}${recovery_count}${NC}"

    # Categorized ejections
    echo ""
    echo "Ejection Categories:"

    local underperforming_ejections
    local manual_ejections
    local protocol_ejections
    local error_ejections

    underperforming_ejections=$(extract_metric "${metrics}" "csm_ejections_underperforming_total")
    manual_ejections=$(extract_metric "${metrics}" "csm_ejections_manual_total")
    protocol_ejections=$(extract_metric "${metrics}" "csm_ejections_protocol_total")
    error_ejections=$(extract_metric "${metrics}" "csm_ejections_error_total")

    echo -e "Underperforming: ${YELLOW}${underperforming_ejections}${NC}"
    echo -e "Manual: ${CYAN}${manual_ejections}${NC}"
    echo -e "Protocol: ${PURPLE}${protocol_ejections}${NC}"
    echo -e "Error: ${RED}${error_ejections}${NC}"
  fi

  echo ""
}

# Function to launch monitoring dashboard
function launch_dashboard {
  echo -e "${BLUE}Launching Lido CSM Monitoring Dashboard${NC}"

  # Check if Grafana container exists
  if ! docker ps --format '{{.Names}}' | grep -q "ephemery-grafana"; then
    echo -e "${YELLOW}Warning: Grafana container not found. Starting a temporary one.${NC}"

    # Create temporary dashboard
    echo -e "Creating temporary dashboard configuration..."

    # Create dashboard directory
    ensure_directory "${EPHEMERY_DATA_DIR}/grafana/dashboards/lido-csm"

    # Create dashboard configuration file
    cat >"${EPHEMERY_DATA_DIR}/grafana/dashboards/lido-csm/csm-dashboard.json" <<EOF
{
  "title": "Lido CSM Dashboard",
  "panels": [
    {
      "title": "CSM Status",
      "type": "stat",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "csm_status"
        }
      ]
    },
    {
      "title": "Active Validators",
      "type": "gauge",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "csm_validators_active"
        }
      ]
    },
    {
      "title": "Bond Health",
      "type": "gauge",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "csm_bond_health_percentage"
        }
      ]
    },
    {
      "title": "Attestation Effectiveness",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "csm_attestation_effectiveness_percentage"
        }
      ]
    }
  ]
}
EOF

    echo -e "${GREEN}Dashboard configuration created${NC}"

    # Start Grafana container if not running
    if ! docker ps --format '{{.Names}}' | grep -q "ephemery-grafana"; then
      echo -e "${BLUE}Starting Grafana container...${NC}"

      docker run -d \
        --name ephemery-grafana \
        --network "${EPHEMERY_DOCKER_NETWORK}" \
        -p "${GRAFANA_PORT}:3000" \
        -v "${EPHEMERY_DATA_DIR}/grafana:/var/lib/grafana" \
        -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
        -e "GF_SECURITY_ADMIN_USER=admin" \
        -e "GF_AUTH_ANONYMOUS_ENABLED=true" \
        -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer" \
        grafana/grafana:latest

      if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to start Grafana container${NC}"
        return 1
      fi

      echo -e "${GREEN}Grafana container started${NC}"
      echo -e "Please wait a few moments for Grafana to initialize..."
      sleep 5
    fi
  fi

  # Open dashboard URL
  echo -e "${GREEN}Lido CSM Dashboard available at: http://localhost:${GRAFANA_PORT}/d/csm/lido-csm-dashboard${NC}"

  # Try to open dashboard in browser
  if command -v open &>/dev/null; then
    open "http://localhost:${GRAFANA_PORT}/d/csm/lido-csm-dashboard"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "http://localhost:${GRAFANA_PORT}/d/csm/lido-csm-dashboard"
  else
    echo -e "${YELLOW}Cannot open browser automatically, please open the URL manually${NC}"
  fi
}

# Function to clear screen for continuous monitoring
function clear_screen {
  if [[ "${CONTINUOUS}" == true ]]; then
    clear
  fi
}

# Main execution flow
function main {
  # Check if CSM container is running
  check_csm_container

  # Execute operation in continuous loop if enabled
  if [[ "${CONTINUOUS}" == true ]]; then
    while true; do
      clear_screen
      echo -e "${CYAN}Continuous monitoring (${INTERVAL}s intervals) - Press Ctrl+C to exit${NC}"
      echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""

      case "${OPERATION}" in
        status)
          show_csm_status
          ;;
        performance)
          show_csm_performance
          ;;
        validators)
          show_csm_validators
          ;;
        bond)
          show_bond_status
          ;;
        queue)
          show_queue_status
          ;;
        ejector)
          show_ejector_status
          ;;
        dashboard)
          launch_dashboard
          break
          ;;
      esac

      sleep "${INTERVAL}"
    done
  else
    # Execute operation once
    case "${OPERATION}" in
      status)
        show_csm_status
        ;;
      performance)
        show_csm_performance
        ;;
      validators)
        show_csm_validators
        ;;
      bond)
        show_bond_status
        ;;
      queue)
        show_queue_status
        ;;
      ejector)
        show_ejector_status
        ;;
      dashboard)
        launch_dashboard
        ;;
    esac
  fi
}

# Run main function
main
