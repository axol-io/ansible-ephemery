#!/bin/bash

# Script to run Ephemery with Geth and Lighthouse on a remote host
set -e

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -i, --inventory FILE     Specify inventory file (required)"
    echo "  -c, --config FILE        Optional: Specify config file (default: /opt/ephemery/config/ephemery_paths.conf)"
    echo "  -h, --help               Display this help message"
    echo
    echo "Examples:"
    echo "  $0 --inventory config/remote-inventory.yaml"
    echo "  $0 -i my-inventory.yaml"
    echo
    echo "You can create an inventory file based on the example in config/remote-inventory.yaml.example"
}

# Parse command line options
INVENTORY_FILE=""
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if inventory file is provided
if [ -z "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file is required"
    show_help
    exit 1
fi

# Source the inventory parser utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/parse_inventory.sh"

# Load configuration file if available
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "Configuration file not found, using default paths"
    # Define default paths for local script - these don't affect remote deployment
    EPHEMERY_BASE_DIR="$HOME/ephemery"
    EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
    EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
    EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
    EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file '$INVENTORY_FILE' not found"
    exit 1
fi

# Parse inventory file
echo "Loading configuration from $INVENTORY_FILE"
parse_remote_inventory "$INVENTORY_FILE"

echo "Deploying Ephemery to remote host: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
echo "--------------------------------------------------------------"

# Create temporary deployment script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash
set -e

# Create base directories
EPHEMERY_BASE_DIR=$HOME/ephemery
EPHEMERY_CONFIG_DIR=$EPHEMERY_BASE_DIR/config

# Create essential directories
mkdir -p $EPHEMERY_BASE_DIR
mkdir -p $EPHEMERY_CONFIG_DIR

# Create standardized configuration file
CONFIG_FILE="$EPHEMERY_CONFIG_DIR/ephemery_paths.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating standard configuration file..."
    cat > "$CONFIG_FILE" << 'CONFEND'
# Ephemery Paths Configuration
# This file defines standard paths used across all Ephemery scripts and services

# Base directory for Ephemery installation
EPHEMERY_BASE_DIR="$HOME/ephemery"

# Directory for Ephemery scripts
EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"

# Directory for Ephemery data
EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"

# Directory for Ephemery logs
EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"

# Directory for Ephemery configuration
EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"

# JWT secret path
EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"

# Validator keys directory
EPHEMERY_VALIDATOR_KEYS="${EPHEMERY_DATA_DIR}/validator_keys"

# Metrics directory
EPHEMERY_METRICS_DIR="${EPHEMERY_DATA_DIR}/metrics"

# Default endpoints
LIGHTHOUSE_API_ENDPOINT="http://localhost:5052"
GETH_API_ENDPOINT="http://localhost:8545"
VALIDATOR_API_ENDPOINT="http://localhost:5062"
CONFEND
fi

# Load configuration
source "$CONFIG_FILE"

# Create directories
mkdir -p $EPHEMERY_DATA_DIR/geth
mkdir -p $EPHEMERY_DATA_DIR/lighthouse
mkdir -p $EPHEMERY_LOGS_DIR

# Generate JWT secret
if [ ! -f $EPHEMERY_JWT_SECRET ]; then
    echo "Generating JWT secret..."
    mkdir -p "$(dirname "$EPHEMERY_JWT_SECRET")"
    echo "0x$(openssl rand -hex 32)" > $EPHEMERY_JWT_SECRET
    chmod 600 $EPHEMERY_JWT_SECRET
fi

# Create Docker network
if ! docker network inspect ephemery &>/dev/null; then
    docker network create ephemery
fi

# Create dedicated network for better container communication
if ! docker network inspect ephemery-net &>/dev/null; then
    docker network create ephemery-net
fi

# Clean existing containers
echo "Removing any existing containers..."
docker rm -f ephemery-geth 2>/dev/null || true
docker rm -f ephemery-lighthouse 2>/dev/null || true

# Start Geth with optimizations
echo "Starting Geth execution client with optimizations..."
docker run -d --name ephemery-geth \
    --network ephemery \
    --restart unless-stopped \
    -v $EPHEMERY_DATA_DIR/geth:/ethdata \
    -v $EPHEMERY_JWT_SECRET:/config/jwt-secret \
    -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
    pk910/ephemery-geth:v1.15.3 \
    --datadir /ethdata \
    --http --http.api eth,net,engine,admin --http.addr 0.0.0.0 \
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /config/jwt-secret \
    --cache=4096 \
    --txlookuplimit=0 \
    --syncmode=snap \
    --maxpeers=100 \
    --db.engine=pebble

# Connect Geth to the dedicated network
docker network connect ephemery-net ephemery-geth

# Wait for Geth
echo "Waiting for Geth to initialize..."
sleep 10

# Get Geth IP address from the dedicated network
GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-geth)
if [ -z "$GETH_IP" ]; then
    GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
fi

echo "Geth IP address: $GETH_IP"

# Start Lighthouse with optimizations and IP-based connection
echo "Starting Lighthouse consensus client with optimizations..."
docker run -d --name ephemery-lighthouse \
    --network ephemery-net \
    --restart unless-stopped \
    -v $EPHEMERY_DATA_DIR/lighthouse:/ethdata \
    -v $EPHEMERY_JWT_SECRET:/config/jwt-secret \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    pk910/ephemery-lighthouse:latest \
    lighthouse beacon \
    --datadir /ethdata \
    --testnet-dir /ephemery_config \
    --execution-jwt /config/jwt-secret \
    --execution-endpoint http://$GETH_IP:8551 \
    --http --http-address 0.0.0.0 --http-port 5052 \
    --target-peers=100 \
    --execution-timeout-multiplier=5 \
    --allow-insecure-genesis-sync \
    --genesis-backfill \
    --disable-backfill-rate-limiting \
    --disable-deposit-contract-sync

# Setup monitoring
echo "Setting up monitoring..."
mkdir -p $EPHEMERY_CONFIG_DIR/prometheus

# Create Prometheus configuration
cat > $EPHEMERY_CONFIG_DIR/prometheus/prometheus.yml << PROMEOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'geth'
    metrics_path: /debug/metrics/prometheus
    static_configs:
      - targets: ['ephemery-geth:6060']

  - job_name: 'lighthouse'
    static_configs:
      - targets: ['ephemery-lighthouse:5054']
PROMEOF

# Start Prometheus
docker run -d --name prometheus \
    --network host \
    --restart unless-stopped \
    -v $EPHEMERY_CONFIG_DIR/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus:v2.47.2

# Start Grafana
docker run -d --name grafana \
    --network host \
    --restart unless-stopped \
    -e GF_SECURITY_ADMIN_USER=admin \
    -e GF_SECURITY_ADMIN_PASSWORD=ephemery \
    -e GF_AUTH_ANONYMOUS_ENABLED=true \
    -e GF_USERS_ALLOW_SIGN_UP=false \
    -e GF_SERVER_HTTP_PORT=3000 \
    grafana/grafana:latest

# Copy monitoring dashboards if available
MONITORING_DIR="$SCRIPT_DIR/../../dashboard"
if [ -d "$MONITORING_DIR" ]; then
    echo "Copying monitoring dashboards..."
    # We'll use SCP later to copy these
    TEMP_DASHBOARDS=$(mktemp -d)
    cp -r "$MONITORING_DIR"/* "$TEMP_DASHBOARDS"
fi

# Copy the script to the remote host
echo "Copying deployment script to the remote host..."
scp -P "$REMOTE_PORT" -o StrictHostKeyChecking=no "$TEMP_SCRIPT" "$REMOTE_USER@$REMOTE_HOST:/tmp/deploy.sh"

# Make the script executable
ssh -p "$REMOTE_PORT" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "chmod +x /tmp/deploy.sh"

# Execute the script on the remote host
echo "Executing deployment script on the remote host..."
ssh -p "$REMOTE_PORT" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "/tmp/deploy.sh"

# Clean up
rm "$TEMP_SCRIPT"

echo "--------------------------------------------------------------"
echo "Ephemery has been deployed to $REMOTE_USER@$REMOTE_HOST"
echo "You can access the services at:"
echo "  - Geth execution API: http://$REMOTE_HOST:8545"
echo "  - Lighthouse consensus API: http://$REMOTE_HOST:5052"
echo "  - Prometheus: http://$REMOTE_HOST:9090"
echo "  - Grafana: http://$REMOTE_HOST:3000 (admin/ephemery)"
echo "--------------------------------------------------------------"
