#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Obol SquadStaking Integration Setup Script
# This script sets up Obol's distributed validator technology (DVT) for Ephemery
#
# Usage: ./setup_obol_squadstaking.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --cluster-size N       Number of nodes in the DV cluster (default: 4)
#   --threshold N          Consensus threshold (default: 3)
#   --reset                Reset existing installation
#   --yes                  Skip confirmation prompts
#   --help                 Show this help message

set -e

# Default settings
BASE_DIR="/opt/ephemery"
OBOL_DATA_DIR="${BASE_DIR}/data/obol"
OBOL_CONFIG_DIR="${BASE_DIR}/config/obol"
OBOL_LOGS_DIR="${BASE_DIR}/logs/obol"
CHARON_VERSION="v0.17.0"
CLUSTER_SIZE=4
THRESHOLD=3
RESET=false
SKIP_CONFIRMATION=false
VERBOSE=false
NETWORK="ephemery"
ENR_PRIVATE_KEY=""
BEACON_NODE_ENDPOINT="http://localhost:5052"
EXECUTION_NODE_ENDPOINT="http://localhost:8545"

# Function to display usage information
usage() {
    echo "Obol SquadStaking Integration Setup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --base-dir DIR         Base directory (default: $BASE_DIR)"
    echo "  --cluster-size N       Number of nodes in the DV cluster (default: $CLUSTER_SIZE)"
    echo "  --threshold N          Consensus threshold (default: $THRESHOLD)"
    echo "  --reset                Reset existing installation"
    echo "  --yes                  Skip confirmation prompts"
    echo "  --verbose              Enable verbose output"
    echo "  --help                 Show this help message"
    exit 1
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    case "$level" in
        "INFO")
            echo -e "${BLUE}[${timestamp}] [INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] [ERROR]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} $message"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${PURPLE}[${timestamp}] [DEBUG]${NC} $message"
            fi
            ;;
        *)
            echo -e "[${timestamp}] [$level] $message"
            ;;
    esac
}

# Shortened aliases for log functions
log_info() { log_message "INFO" "$1"; }
log_warning() { log_message "WARNING" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-dir)
            BASE_DIR="$2"
            OBOL_DATA_DIR="${BASE_DIR}/data/obol"
            OBOL_CONFIG_DIR="${BASE_DIR}/config/obol"
            OBOL_LOGS_DIR="${BASE_DIR}/logs/obol"
            shift 2
            ;;
        --cluster-size)
            CLUSTER_SIZE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --reset)
            RESET=true
            shift
            ;;
        --yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [[ $THRESHOLD -gt $CLUSTER_SIZE ]]; then
    log_error "Threshold ($THRESHOLD) cannot be greater than cluster size ($CLUSTER_SIZE)"
    exit 1
fi

if [[ $THRESHOLD -lt $(( $CLUSTER_SIZE / 2 + 1 )) ]]; then
    log_warning "Threshold ($THRESHOLD) is less than the recommended minimum ($(( $CLUSTER_SIZE / 2 + 1 )))"
    log_warning "This may compromise security of the distributed validator"

    if [[ "$SKIP_CONFIRMATION" != true ]]; then
        read -p "Do you want to continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborting setup"
            exit 1
        fi
    fi
fi

# Function to check if Docker is installed
check_docker() {
    log_debug "Checking if Docker is installed"
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker and try again."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or you don't have permission to access it."
        exit 1
    }

    log_debug "Docker is installed and running"
}

# Function to check if Docker Compose is installed
check_docker_compose() {
    log_debug "Checking if Docker Compose is installed"
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose and try again."
        exit 1
    fi

    log_debug "Docker Compose is installed"
}

# Function to create necessary directories
create_directories() {
    log_debug "Creating necessary directories"

    mkdir -p "$OBOL_DATA_DIR"
    mkdir -p "$OBOL_CONFIG_DIR"
    mkdir -p "$OBOL_LOGS_DIR"
    mkdir -p "${OBOL_DATA_DIR}/charon"
    mkdir -p "${OBOL_DATA_DIR}/validator_keys"
    mkdir -p "${OBOL_DATA_DIR}/lighthouse"

    log_debug "Directories created"
}

# Function to reset existing installation
reset_installation() {
    if [[ "$RESET" != true ]]; then
        return
    }

    log_info "Resetting existing installation"

    # Stop running containers
    if docker ps -a --format '{{.Names}}' | grep -q "ephemery-obol-charon"; then
        log_debug "Stopping and removing Obol Charon container"
        docker stop ephemery-obol-charon || true
        docker rm ephemery-obol-charon || true
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "ephemery-obol-validator"; then
        log_debug "Stopping and removing Obol Validator container"
        docker stop ephemery-obol-validator || true
        docker rm ephemery-obol-validator || true
    fi

    # Remove data directories
    if [[ -d "$OBOL_DATA_DIR" ]]; then
        log_debug "Removing data directory: $OBOL_DATA_DIR"
        rm -rf "$OBOL_DATA_DIR"
    fi

    # Remove configuration
    if [[ -d "$OBOL_CONFIG_DIR" ]]; then
        log_debug "Removing configuration directory: $OBOL_CONFIG_DIR"
        rm -rf "$OBOL_CONFIG_DIR"
    fi

    log_success "Reset completed"
}

# Function to generate ENR private key
generate_enr_private_key() {
    log_debug "Generating ENR private key"

    # Generate a random 32-byte private key
    ENR_PRIVATE_KEY=$(openssl rand -hex 32)

    # Save to file
    echo "$ENR_PRIVATE_KEY" > "${OBOL_CONFIG_DIR}/enr_private_key"
    chmod 600 "${OBOL_CONFIG_DIR}/enr_private_key"

    log_debug "ENR private key generated and saved"
}

# Function to create Charon configuration
create_charon_config() {
    log_debug "Creating Charon configuration"

    # Create charon.yaml
    cat > "${OBOL_CONFIG_DIR}/charon.yaml" << EOF
# Charon configuration for Ephemery SquadStaking

data-dir: /data/charon
log-level: info
log-format: console

p2p:
  tcp-address: 0.0.0.0:3610
  udp-address: 0.0.0.0:3630
  bootnodes: []
  relays: []

monitoring:
  enabled: true
  address: 0.0.0.0:3620

validator-api:
  address: 0.0.0.0:3600

beacon-node-endpoints:
  - ${BEACON_NODE_ENDPOINT}

builder-api: false
EOF

    log_debug "Charon configuration created"
}

# Function to create cluster definition
create_cluster_definition() {
    log_debug "Creating cluster definition"

    # Create cluster-definition.json
    cat > "${OBOL_CONFIG_DIR}/cluster-definition.json" << EOF
{
  "name": "ephemery-squad-${CLUSTER_SIZE}-${THRESHOLD}",
  "operators": [
    {
      "address": "0x0000000000000000000000000000000000000000",
      "enr": "",
      "config_signature": "",
      "enr_signature": ""
    }
  ],
  "uuid": "$(uuidgen)",
  "version": "v1.5.0",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "num_validators": 1,
  "threshold": ${THRESHOLD},
  "validators": [
    {
      "fee_recipient_address": "0x0000000000000000000000000000000000000000",
      "withdrawal_address": "0x0000000000000000000000000000000000000000"
    }
  ],
  "dkg_algorithm": "frost",
  "fork_version": "0x00000000",
  "config": {
    "network": "${NETWORK}",
    "beacon_node_endpoints": ["${BEACON_NODE_ENDPOINT}"],
    "monitoring": {
      "enabled": true,
      "metrics_address": "0.0.0.0:3620"
    }
  }
}
EOF

    log_debug "Cluster definition created"
}

# Function to create Docker Compose file
create_docker_compose() {
    log_debug "Creating Docker Compose file"

    # Create docker-compose.yaml
    cat > "${OBOL_CONFIG_DIR}/docker-compose.yaml" << EOF
version: '3.8'

services:
  charon:
    image: obolnetwork/charon:${CHARON_VERSION}
    container_name: ephemery-obol-charon
    restart: unless-stopped
    command: run
    volumes:
      - ${OBOL_CONFIG_DIR}/charon.yaml:/config/charon.yaml
      - ${OBOL_DATA_DIR}/charon:/data/charon
      - ${OBOL_CONFIG_DIR}/cluster-definition.json:/config/cluster-definition.json
      - ${OBOL_CONFIG_DIR}/enr_private_key:/config/enr_private_key
    ports:
      - "3610:3610"
      - "3630:3630/udp"
      - "3620:3620"
      - "3600:3600"
    networks:
      - ephemery-net

  validator:
    image: sigp/lighthouse:latest
    container_name: ephemery-obol-validator
    restart: unless-stopped
    command: >
      lighthouse validator
      --network ephemery
      --datadir /data/lighthouse
      --beacon-nodes http://charon:3600
      --suggested-fee-recipient 0x0000000000000000000000000000000000000000
      --metrics
      --metrics-address 0.0.0.0
      --metrics-port 5064
    volumes:
      - ${OBOL_DATA_DIR}/lighthouse:/data/lighthouse
      - ${OBOL_DATA_DIR}/validator_keys:/data/validator_keys:ro
    depends_on:
      - charon
    networks:
      - ephemery-net

networks:
  ephemery-net:
    external: true
EOF

    log_debug "Docker Compose file created"
}

# Function to create Prometheus configuration
create_prometheus_config() {
    log_debug "Creating Prometheus configuration"

    # Create prometheus.yaml
    cat > "${OBOL_CONFIG_DIR}/prometheus.yaml" << EOF
- job_name: 'obol-charon'
  scrape_interval: 15s
  static_configs:
    - targets: ['ephemery-obol-charon:3620']
      labels:
        instance: charon

- job_name: 'obol-validator'
  scrape_interval: 15s
  static_configs:
    - targets: ['ephemery-obol-validator:5064']
      labels:
        instance: validator
EOF

    # Check if Prometheus container exists and copy config
    if docker ps --format '{{.Names}}' | grep -q "ephemery-prometheus"; then
        log_debug "Copying Prometheus configuration to Prometheus container"
        cp "${OBOL_CONFIG_DIR}/prometheus.yaml" "${BASE_DIR}/config/prometheus/obol.yaml"

        # Reload Prometheus configuration
        docker exec ephemery-prometheus kill -HUP 1
    else
        log_warning "Prometheus container not found. Skipping Prometheus configuration."
    fi

    log_debug "Prometheus configuration created"
}

# Function to create systemd service
create_systemd_service() {
    log_debug "Creating systemd service"

    # Create systemd service file
    cat > "${OBOL_CONFIG_DIR}/obol-squadstaking.service" << EOF
[Unit]
Description=Obol SquadStaking Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=${OBOL_CONFIG_DIR}
ExecStart=/usr/bin/docker-compose -f ${OBOL_CONFIG_DIR}/docker-compose.yaml up
ExecStop=/usr/bin/docker-compose -f ${OBOL_CONFIG_DIR}/docker-compose.yaml down

[Install]
WantedBy=multi-user.target
EOF

    # Copy to systemd directory if running as root
    if [[ $EUID -eq 0 ]]; then
        cp "${OBOL_CONFIG_DIR}/obol-squadstaking.service" /etc/systemd/system/
        systemctl daemon-reload
        log_info "Systemd service installed. You can start it with: systemctl start obol-squadstaking"
    else
        log_info "Systemd service file created at: ${OBOL_CONFIG_DIR}/obol-squadstaking.service"
        log_info "To install it, run: sudo cp ${OBOL_CONFIG_DIR}/obol-squadstaking.service /etc/systemd/system/ && sudo systemctl daemon-reload"
    fi

    log_debug "Systemd service created"
}

# Function to start the services
start_services() {
    log_info "Starting Obol SquadStaking services"

    # Check if Docker network exists
    if ! docker network ls | grep -q "ephemery-net"; then
        log_debug "Creating Docker network: ephemery-net"
        docker network create ephemery-net
    fi

    # Start services using Docker Compose
    cd "${OBOL_CONFIG_DIR}"
    docker-compose up -d

    log_success "Obol SquadStaking services started"
}

# Function to check service status
check_service_status() {
    log_info "Checking service status"

    # Check if containers are running
    if ! docker ps | grep -q "ephemery-obol-charon"; then
        log_error "Charon container is not running"
        docker logs ephemery-obol-charon
        exit 1
    fi

    if ! docker ps | grep -q "ephemery-obol-validator"; then
        log_error "Validator container is not running"
        docker logs ephemery-obol-validator
        exit 1
    fi

    log_success "All services are running"

    # Display connection information
    local charon_enr=$(docker exec ephemery-obol-charon charon enr)

    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}Obol SquadStaking Setup Complete${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "Charon ENR: ${CYAN}${charon_enr}${NC}"
    echo -e "Charon API: ${CYAN}http://localhost:3600${NC}"
    echo -e "Charon Metrics: ${CYAN}http://localhost:3620/metrics${NC}"
    echo -e "Validator Metrics: ${CYAN}http://localhost:5064/metrics${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

# Main execution flow
main() {
    log_info "Starting Obol SquadStaking setup"
    log_info "Cluster size: $CLUSTER_SIZE, Threshold: $THRESHOLD"

    # Check prerequisites
    check_docker
    check_docker_compose

    # Reset if requested
    reset_installation

    # Create directories
    create_directories

    # Generate ENR private key
    generate_enr_private_key

    # Create configurations
    create_charon_config
    create_cluster_definition
    create_docker_compose
    create_prometheus_config
    create_systemd_service

    # Start services
    start_services

    # Check service status
    check_service_status

    log_success "Obol SquadStaking setup completed successfully"
}

# Run main function
main
