#!/bin/bash

# Lido CSM Integration Setup Script for Ephemery
# ==============================================
#
# This script sets up Lido Community Staking Module (CSM) integration with Ephemery nodes.
# It configures and deploys all necessary components for supporting liquid staking functionality
# through Lido's staking protocol in the Ephemery environment.
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
  EPHEMERY_DOCKER_NETWORK="ephemery-net"
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
NC=${NC:-'\033[0m'}

# CSM-specific defaults
CSM_CONTAINER="ephemery-lido-csm"
CSM_DATA_DIR="${EPHEMERY_DATA_DIR}/lido-csm"
CSM_CONFIG_DIR="${EPHEMERY_CONFIG_DIR}/lido-csm"
CSM_LOGS_DIR="${EPHEMERY_LOGS_DIR}/lido-csm"
CSM_METRICS_PORT=8888
CSM_API_PORT=9000
CSM_DOCKER_IMAGE="lidofinance/csm:latest"
CSM_BOND_AMOUNT="2.0"
CSM_PROFITABILITY_CALCULATOR=false
CSM_VALIDATOR_MONITORING=false
CSM_EJECTOR_MONITORING=false
CSM_PROTOCOL_MONITORING=false

# Script-specific defaults
DEBUG_MODE=false
FORCE_RESET=false
SKIP_CONFIRMATION=false

# Help function
function show_help {
  echo -e "${BLUE}Lido CSM Integration Setup for Ephemery${NC}"
  echo ""
  echo "This script sets up Lido Community Staking Module (CSM) integration with Ephemery nodes."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --base-dir DIR               Base directory for Ephemery (default: ${EPHEMERY_BASE_DIR})"
  echo "  --bond-amount AMOUNT         Initial bond amount in ETH (default: ${CSM_BOND_AMOUNT})"
  echo "  --metrics-port PORT          Port for CSM metrics (default: ${CSM_METRICS_PORT})"
  echo "  --api-port PORT              Port for CSM API (default: ${CSM_API_PORT})"
  echo "  --docker-image IMAGE         Docker image for CSM (default: ${CSM_DOCKER_IMAGE})"
  echo "  --enable-profitability       Enable profitability calculator"
  echo "  --enable-validator-monitor   Enable specialized validator monitoring"
  echo "  --enable-ejector-monitor     Enable ejector monitoring system"
  echo "  --enable-protocol-monitor    Enable protocol health monitoring"
  echo "  --reset                      Force reset of CSM configuration and data"
  echo "  --yes                        Skip confirmations"
  echo "  --debug                      Enable debug output"
  echo "  -h, --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --bond-amount 3.0 --enable-validator-monitor"
  echo "  $0 --reset --yes"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    --bond-amount)
      CSM_BOND_AMOUNT="$2"
      shift 2
      ;;
    --metrics-port)
      CSM_METRICS_PORT="$2"
      shift 2
      ;;
    --api-port)
      CSM_API_PORT="$2"
      shift 2
      ;;
    --docker-image)
      CSM_DOCKER_IMAGE="$2"
      shift 2
      ;;
    --enable-profitability)
      CSM_PROFITABILITY_CALCULATOR=true
      shift
      ;;
    --enable-validator-monitor)
      CSM_VALIDATOR_MONITORING=true
      shift
      ;;
    --enable-ejector-monitor)
      CSM_EJECTOR_MONITORING=true
      shift
      ;;
    --enable-protocol-monitor)
      CSM_PROTOCOL_MONITORING=true
      shift
      ;;
    --reset)
      FORCE_RESET=true
      shift
      ;;
    --yes)
      SKIP_CONFIRMATION=true
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

# Function to create directory if it doesn't exist
function ensure_directory {
  local dir=$1
  debug_log "Ensuring directory exists: ${dir}"
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}"
    echo -e "${GREEN}Created directory: ${dir}${NC}"
  fi
}

# Function to check if Docker is installed and running
function check_docker {
  debug_log "Checking Docker installation"
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker first. See https://docs.docker.com/get-docker/"
    exit 1
  fi

  debug_log "Checking if Docker daemon is running"
  if ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo "Please start the Docker service"
    exit 1
  fi
}

# Function to check if Ephemery is already set up
function check_ephemery {
  debug_log "Checking if Ephemery is set up"
  if [[ ! -d "${EPHEMERY_BASE_DIR}" ]]; then
    echo -e "${RED}Error: Ephemery base directory not found: ${EPHEMERY_BASE_DIR}${NC}"
    echo "Please run the Ephemery setup script first"
    exit 1
  fi

  debug_log "Checking if Ephemery network exists"
  if ! docker network inspect "${EPHEMERY_DOCKER_NETWORK}" &>/dev/null; then
    echo -e "${RED}Error: Ephemery Docker network not found: ${EPHEMERY_DOCKER_NETWORK}${NC}"
    echo "Please run the Ephemery setup script first to initialize the network"
    exit 1
  fi
}

# Function to check if CSM is already set up
function check_csm_exists {
  debug_log "Checking if CSM container exists"
  if docker ps -a --format '{{.Names}}' | grep -q "^${CSM_CONTAINER}$"; then
    if [[ "${FORCE_RESET}" != true ]]; then
      echo -e "${YELLOW}CSM container already exists: ${CSM_CONTAINER}${NC}"
      echo "Use --reset to force reset the CSM configuration and data"
      exit 0
    fi
  fi
}

# Function to create CSM configuration
function create_csm_config {
  debug_log "Creating CSM configuration"
  ensure_directory "${CSM_CONFIG_DIR}"

  # Create CSM configuration file
  cat >"${CSM_CONFIG_DIR}/config.yaml" <<EOF
# Lido CSM Configuration for Ephemery
csm:
  enabled: true
  endpoint: "http://localhost:${CSM_API_PORT}"
  data_dir: "${CSM_DATA_DIR}"
  bond:
    initial_amount: ${CSM_BOND_AMOUNT}
    minimum_ratio: 0.1
    rebase_monitoring: true
    claim_threshold: 0.5
    automatic_optimization: false
  queue:
    monitoring_enabled: true
    position_alerts: true
    forecast_horizon_days: 30
  monitoring:
    enabled: true
    metrics_port: ${CSM_METRICS_PORT}
    alerting:
      enabled: true
      notification_channels: ["log"]
      threshold_missed_attestations: 3
      threshold_missed_proposals: 1
      threshold_ejection_rate: 0.05
      bond_health_threshold: 0.8
      queue_movement_threshold: 5
  validators:
    count: 10
    start_index: 0
    performance_monitoring: ${CSM_VALIDATOR_MONITORING}
    automatic_recovery: true
    exit_monitoring: true
    withdrawal_tracking: true
  ejector:
    enabled: ${CSM_EJECTOR_MONITORING}
    monitoring_interval: 60
    automatic_recovery: true
    max_concurrent_ejections: 5
  performance:
    max_concurrent_operations: 100
    timeout_multiplier: 3
    resource_allocation:
      cpu_percentage: 40
      memory_percentage: 30
  profitability:
    update_interval: 3600
    historical_data_retention_days: 90
    enabled: ${CSM_PROFITABILITY_CALCULATOR}
    cost_inputs:
      hardware_cost_monthly: 100
      power_cost_monthly: 20
      bandwidth_cost_monthly: 30
      maintenance_hours_monthly: 5
      maintenance_hourly_rate: 50
EOF

  echo -e "${GREEN}Created CSM configuration at ${CSM_CONFIG_DIR}/config.yaml${NC}"
}

# Function to deploy CSM container
function deploy_csm_container {
  debug_log "Deploying CSM container"

  # Pull the latest image
  echo -e "${BLUE}Pulling CSM Docker image: ${CSM_DOCKER_IMAGE}${NC}"
  docker pull "${CSM_DOCKER_IMAGE}"

  # Remove existing container if it exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CSM_CONTAINER}$"; then
    echo -e "${YELLOW}Removing existing CSM container: ${CSM_CONTAINER}${NC}"
    docker stop "${CSM_CONTAINER}" 2>/dev/null || true
    docker rm "${CSM_CONTAINER}" 2>/dev/null || true
  fi

  # Create and start the CSM container
  echo -e "${BLUE}Creating CSM container: ${CSM_CONTAINER}${NC}"
  docker run -d \
    --name "${CSM_CONTAINER}" \
    --network "${EPHEMERY_DOCKER_NETWORK}" \
    -p "${CSM_API_PORT}:${CSM_API_PORT}" \
    -p "${CSM_METRICS_PORT}:${CSM_METRICS_PORT}" \
    -v "${CSM_CONFIG_DIR}:/config" \
    -v "${CSM_DATA_DIR}:/data" \
    -e "CSM_BOND_AMOUNT=${CSM_BOND_AMOUNT}" \
    -e "CSM_API_PORT=${CSM_API_PORT}" \
    -e "CSM_METRICS_PORT=${CSM_METRICS_PORT}" \
    -e "CSM_CONFIG_FILE=/config/config.yaml" \
    -e "CSM_DATA_DIR=/data" \
    --restart unless-stopped \
    "${CSM_DOCKER_IMAGE}"

  # Verify container is running
  if docker ps --format '{{.Names}}' | grep -q "^${CSM_CONTAINER}$"; then
    echo -e "${GREEN}CSM container deployed successfully: ${CSM_CONTAINER}${NC}"
  else
    echo -e "${RED}Failed to deploy CSM container${NC}"
    echo "Check container logs for details:"
    echo "  docker logs ${CSM_CONTAINER}"
    exit 1
  fi
}

# Function to set up monitoring for CSM
function setup_csm_monitoring {
  debug_log "Setting up CSM monitoring"

  # Create monitoring directory
  ensure_directory "${EPHEMERY_DATA_DIR}/monitoring/lido-csm"

  # Create Prometheus scrape config for CSM
  cat >"${EPHEMERY_CONFIG_DIR}/prometheus/lido-csm.yaml" <<EOF
scrape_configs:
  - job_name: 'lido-csm'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:${CSM_METRICS_PORT}']
        labels:
          instance: 'csm'
EOF

  echo -e "${GREEN}Created Prometheus scrape config for CSM${NC}"

  # Check if Prometheus container exists and reload configuration
  if docker ps --format '{{.Names}}' | grep -q "ephemery-prometheus"; then
    echo -e "${BLUE}Reloading Prometheus configuration${NC}"
    docker exec ephemery-prometheus kill -HUP 1
  fi
}

# Function to set up profitability calculator
function setup_profitability_calculator {
  if [[ "${CSM_PROFITABILITY_CALCULATOR}" != true ]]; then
    return
  fi

  debug_log "Setting up CSM profitability calculator"

  # Create profitability calculator directory
  ensure_directory "${CSM_DATA_DIR}/profitability"

  # Create empty profitability data file
  touch "${CSM_DATA_DIR}/profitability/data.json"

  echo -e "${GREEN}Set up profitability calculator${NC}"
}

# Function to set up validator monitoring
function setup_validator_monitoring {
  if [[ "${CSM_VALIDATOR_MONITORING}" != true ]]; then
    return
  fi

  debug_log "Setting up CSM validator monitoring"

  # Create validator monitoring directory
  ensure_directory "${CSM_DATA_DIR}/validator-monitoring"

  echo -e "${GREEN}Set up validator monitoring${NC}"
}

# Function to set up ejector monitoring
function setup_ejector_monitoring {
  if [[ "${CSM_EJECTOR_MONITORING}" != true ]]; then
    return
  fi

  debug_log "Setting up CSM ejector monitoring"

  # Create ejector monitoring directory
  ensure_directory "${CSM_DATA_DIR}/ejector-monitoring"

  echo -e "${GREEN}Set up ejector monitoring${NC}"
}

# Function to set up protocol monitoring
function setup_protocol_monitoring {
  if [[ "${CSM_PROTOCOL_MONITORING}" != true ]]; then
    return
  fi

  debug_log "Setting up CSM protocol monitoring"

  # Create protocol monitoring directory
  ensure_directory "${CSM_DATA_DIR}/protocol-monitoring"

  echo -e "${GREEN}Set up protocol monitoring${NC}"
}

# Main execution flow
function main {
  echo -e "${BLUE}Lido CSM Integration Setup for Ephemery${NC}"
  echo ""

  # Check prerequisites
  check_docker
  check_ephemery
  check_csm_exists

  # Print configuration
  echo -e "${CYAN}Configuration:${NC}"
  echo "  Base Directory:        ${EPHEMERY_BASE_DIR}"
  echo "  CSM Data Directory:    ${CSM_DATA_DIR}"
  echo "  CSM Config Directory:  ${CSM_CONFIG_DIR}"
  echo "  Bond Amount:           ${CSM_BOND_AMOUNT} ETH"
  echo "  API Port:              ${CSM_API_PORT}"
  echo "  Metrics Port:          ${CSM_METRICS_PORT}"
  echo "  Docker Image:          ${CSM_DOCKER_IMAGE}"
  echo "  Profitability Calc:    ${CSM_PROFITABILITY_CALCULATOR}"
  echo "  Validator Monitoring:  ${CSM_VALIDATOR_MONITORING}"
  echo "  Ejector Monitoring:    ${CSM_EJECTOR_MONITORING}"
  echo "  Protocol Monitoring:   ${CSM_PROTOCOL_MONITORING}"
  echo ""

  # Confirm action
  if [[ "${SKIP_CONFIRMATION}" != true ]]; then
    read -p "Continue with this configuration? (y/n) " -n 1 -r
    echo ""
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Aborted by user${NC}"
      exit 0
    fi
  fi

  # Create necessary directories
  ensure_directory "${CSM_DATA_DIR}"
  ensure_directory "${CSM_CONFIG_DIR}"
  ensure_directory "${CSM_LOGS_DIR}"

  # Set up CSM
  create_csm_config
  deploy_csm_container
  setup_csm_monitoring

  # Set up optional components
  setup_profitability_calculator
  setup_validator_monitoring
  setup_ejector_monitoring
  setup_protocol_monitoring

  echo ""
  echo -e "${GREEN}Lido CSM integration setup completed successfully${NC}"
  echo ""
  echo "CSM API Endpoint:  http://localhost:${CSM_API_PORT}"
  echo "CSM Metrics:       http://localhost:${CSM_METRICS_PORT}"
  echo ""
  echo "To view CSM logs, run:"
  echo "  docker logs -f ${CSM_CONTAINER}"
  echo ""
  echo "To stop CSM, run:"
  echo "  docker stop ${CSM_CONTAINER}"
  echo ""
  echo "To uninstall CSM, run:"
  echo "  docker stop ${CSM_CONTAINER}"
  echo "  docker rm ${CSM_CONTAINER}"
  echo "  rm -rf ${CSM_CONFIG_DIR} ${CSM_DATA_DIR}"
}

# Run main function
main
